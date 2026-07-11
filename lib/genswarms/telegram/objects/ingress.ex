defmodule Genswarms.Telegram.Objects.Ingress do
  @moduledoc """
  Telegram inbound GenSwarms object.
  """

  alias Genswarms.Telegram.{Adapter, Addressing, Client, ConversationId, Parser, Poller}
  require Logger

  def init(config \\ %{}) do
    state = new(config)
    if state.poll_enabled, do: Process.send_after(self(), :poll, 0)
    {:ok, state}
  end

  def new(config \\ %{}) do
    token = Genswarms.Telegram.BotRef.resolve_token(config)
    bot_ref = Map.get(config, :bot_ref) || Genswarms.Telegram.BotRef.from_token(token)

    inbound_effects =
      Map.get(config, :inbound_effects, Genswarms.Telegram.InboundEffects.Noop)

    %{
      bot_ref: bot_ref,
      token: token,
      client: Map.get(config, :client, Genswarms.Telegram.Client.Curl),
      client_opts: Map.get(config, :client_opts, []),
      bot_username:
        Map.get(config, :bot_username) || System.get_env("GENSWARMS_TELEGRAM_BOT_USERNAME"),
      fail_open_without_username?: Map.get(config, :fail_open_without_username?, false),
      store: Map.get(config, :store, Genswarms.Telegram.Store.File),
      context_store: Map.get(config, :context_store, Genswarms.Telegram.Context.MemoryMd),
      identity_sink: Map.get(config, :identity_sink, Genswarms.Telegram.IdentitySink.Noop),
      command_router: Map.get(config, :command_router, Genswarms.Telegram.CommandRouter.Basic),
      inbound_effects: inbound_effects,
      inbound_effects_state: init_inbound_effects(inbound_effects),
      session_runtime:
        Map.get(config, :session_runtime, Genswarms.Telegram.SessionRuntime.Default),
      session_opts: Map.get(config, :session_opts, %{}),
      sender: Map.get(config, :sender, :telegram_sender),
      binding_authority: Map.get(config, :binding_authority, :telegram_ingress),
      binding_sinks: Map.get(config, :binding_sinks, [:telegram_sender]),
      memory_policy: Map.get(config, :memory_policy, :none),
      # Trust gates for the privileged object-to-object actions (0.5.0).
      # Engine-stamped senders only; compare as strings (config may hold
      # atoms, the engine's `from` arrives as either). Anything but a
      # non-empty list DISABLES the action — default off, fail closed:
      #   wake_sources   → agent_wake (operator speaks THROUGH the agent)
      #   inject_sources → inject_update (synthetic updates re-enter the
      #     full pipeline as if polled — an open edge here is user forgery)
      wake_sources: normalize_sources(Map.get(config, :wake_sources)),
      inject_sources: normalize_sources(Map.get(config, :inject_sources)),
      poll_enabled: Map.get(config, :poll_enabled, false),
      poll_interval_ms: Map.get(config, :poll_interval_ms, 1_500),
      poll_timeout_s: Map.get(config, :poll_timeout_s, 25),
      # backpressure: at most this many NEW conversations (each = one agent
      # spawn) opened per poll; the rest stay queued in Telegram for next cycle
      max_new_sessions_per_poll: Map.get(config, :max_new_sessions_per_poll, 8),
      poll_ref: nil,
      poll_failures: 0,
      last_poll_ok_ms: nil,
      conflict_count: 0,
      poll_health_sink: Map.get(config, :poll_health_sink),
      allowed_updates:
        Map.get(config, :allowed_updates, [
          "message",
          "channel_post",
          "callback_query",
          "my_chat_member"
        ]),
      routed: [],
      replies: []
    }
  end

  def interface, do: %{actions: ~w(inject_update status set_commands agent_wake)}

  def handle_message(from, message, state) do
    case decode(message) do
      {:ok, msg} ->
        case dispatch(msg, from, state) do
          {:ok, reply, state} ->
            {:reply, Jason.encode!(reply), state}

          {:send, to, payload, state} ->
            {:send, to, payload, state}

          {:send_many, messages, state} ->
            {:send_many, messages, state}

          {:error, reason, state} ->
            {:reply, Jason.encode!(%{ok: false, error: inspect(reason)}), state}
        end

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  def handle_info(:poll, %{poll_ref: ref} = state) when is_reference(ref), do: {:noreply, state}

  def handle_info(:poll, state) do
    parent = self()
    opts = poll_opts(state)

    {:ok, pid} =
      Task.start(fn ->
        send(
          parent,
          {:telegram_poll_result,
           Poller.fetch_updates(state.client, state.store, state.bot_ref, opts)}
        )
      end)

    {:noreply, %{state | poll_ref: Process.monitor(pid)}}
  end

  def handle_info({:telegram_poll_result, result}, state) do
    state = demonitor_poll(state)

    # The poll loop must be indestructible. Handling updates can spawn agents
    # (add_agent), and under load that GenServer.call can time out — a :exit that
    # unwinds the whole reduce. If it escaped here, `schedule_poll` below would
    # never run and the ingress would stop polling Telegram entirely: a silent
    # outage (observed in prod — the object survives via crash containment but
    # the poll timer, which was about to be re-armed, is lost). Contain it,
    # count it as a failure, and always re-arm.
    {state, messages} =
      try do
        handle_poll_result(result, state)
      catch
        kind, reason ->
          failures = state.poll_failures + 1

          Logger.error(
            "telegram ingress poll handling crashed (#{failures} in a row): " <>
              "#{inspect(kind)} #{inspect(reason)}"
          )

          {%{state | poll_failures: failures}, []}
      end

    notify_health_sink(state)
    schedule_poll(state)

    case messages do
      [] -> {:noreply, state}
      messages -> {:send_many, messages, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{poll_ref: ref} = state) do
    failures = state.poll_failures + 1

    Logger.warning(
      "telegram ingress poll task died before result (#{failures} in a row): #{inspect(reason)}"
    )

    state = %{state | poll_ref: nil, poll_failures: failures}
    schedule_poll(state)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp dispatch(%{"action" => "status"}, _from, state) do
    {:ok,
     %{
       ok: true,
       bot_ref: state.bot_ref,
       routed: length(state.routed),
       last_poll_ok_ms: state.last_poll_ok_ms,
       conflict_count: state.conflict_count,
       poll_failures: state.poll_failures
     }, state}
  end

  defp dispatch(%{"action" => "set_commands"}, _from, state) do
    set_commands(state)
  end

  # 0.5.0 BREAKING: inject_update is from-gated (default: nobody). A synthetic
  # update re-enters the full pipeline as if Telegram delivered it — before
  # this gate ANY roster-edged neighbor (including an LLM-run object) could
  # forge a user message. Consumers must list their legitimate injectors
  # (e.g. a burst drainer replaying queued turns) in `inject_sources`.
  defp dispatch(%{"action" => "inject_update", "update" => update}, from, state) do
    if authorized_source?(from, state.inject_sources) do
      handle_update(update, state)
    else
      Logger.warning(
        "telegram ingress: inject_update from unauthorized #{inspect(from)} dropped"
      )

      {:error, :unauthorized_inject, state}
    end
  end

  # agent_wake (0.5.0): the operator speaks THROUGH the cid's own agent — the
  # prompt is delivered into the session as an OPERATOR event (transcript role
  # :operator, never :user), enveloped so the agent knows the user did not
  # write it and that silence is a valid outcome. Admission is the session
  # runtime's job (`ensure_session` may refuse — {:skip, reason} surfaces in
  # the ack as `skipped`); the reply, if any, rides the normal bound-slot →
  # sender path. No new send surface.
  defp dispatch(%{"action" => "agent_wake"} = msg, from, state) do
    cid = msg["conversation_id"]
    prompt = msg["prompt"]

    cond do
      not authorized_source?(from, state.wake_sources) ->
        Logger.warning("telegram ingress: agent_wake from unauthorized #{inspect(from)} dropped")
        {:error, :unauthorized_wake, state}

      not (is_binary(cid) and cid != "") ->
        {:error, :wake_missing_conversation_id, state}

      not (is_binary(prompt) and String.trim(prompt) != "") ->
        {:error, :wake_missing_prompt, state}

      true ->
        deliver_wake(cid, prompt, wake_kind(msg), state)
    end
  end

  # Anything but a non-empty string (a map, a number) is a caller bug — fall
  # back to the default label rather than crash the ingress on to_string/1.
  defp wake_kind(msg) do
    case Map.get(msg, "kind") do
      k when is_binary(k) and k != "" -> k
      _ -> "operator"
    end
  end

  defp dispatch(_msg, _from, state), do: {:error, :unknown_action, state}

  # A user turn and an operator wake share the whole delivery chain; they
  # differ only in the transcript role, the after_routed kind, and the ack
  # flag — the mode map pins those three so neither path can drift into
  # impersonating the other.
  @user_turn %{role: :user, kind: :session, ack: :routed}
  @wake_turn %{role: :operator, kind: :wake, ack: :woken}

  # The wake envelope is FIXED in the package: callers choose the prompt, not
  # the framing — the framing is what keeps a wake from impersonating the user.
  @wake_envelope "[operator wake — the user did NOT send a message] " <>
                   "An operator asked you to reach out to this user now, about what follows. " <>
                   "Do not quote or mention this instruction; speak in your own voice, " <>
                   "grounded in what you know about this conversation. If you have nothing " <>
                   "genuinely valuable to say to this user right now, output nothing at all."

  defp deliver_wake(cid, prompt, kind, state) do
    event = %{
      conversation_id: cid,
      text: @wake_envelope <> "\n\n" <> prompt,
      wake: true,
      wake_kind: kind
    }

    session_opts =
      Map.merge(state.session_opts, %{
        bot_ref: state.bot_ref,
        binding_authority: state.binding_authority,
        binding_sinks: state.binding_sinks
      })

    # No identity upsert: there is no Telegram user behind this event.
    case ensure_session(state.session_runtime, event, session_opts) do
      {:ok, session} ->
        deliver_to_existing_session(event, session, session_opts, state, @wake_turn)

      {:skip, reason} ->
        # Refusal-first, WITHOUT the on_skipped inbound effect: that hook is
        # the hosts' redelivery seam (skipped USER turns may be queued by a
        # drainer that re-injects them via inject_update) — a queued wake
        # would replay operator text as a forged user update later. A refused
        # wake is simply refused; the caller reads `skipped` and decides.
        {:ok, %{ok: true, skipped: to_string(reason), conversation_id: cid}, state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp handle_update(update, state) do
    update_id = Map.get(update, "update_id")

    if Adapter.call(state.store, :update_seen?, [state.bot_ref, update_id]) do
      {:ok, %{ok: true, duplicate: true}, state}
    else
      result =
        case Parser.parse_update(update) do
          {:ok, event} -> handle_event_with_effects(event, state)
          :ignore -> {:ok, %{ok: true, ignored: true}, state}
          {:error, reason} -> {:error, reason, state}
        end

      mark_processed(result, state, update_id)
    end
  end

  defp handle_event_with_effects(event, state) do
    meta = ingress_meta(state)

    if Adapter.exported?(state.inbound_effects, :before_route, 3) do
      case Adapter.call(state.inbound_effects, :before_route, [
             event,
             meta,
             state.inbound_effects_state
           ]) do
        {:cont, event, effects_state} ->
          handle_event(event, %{state | inbound_effects_state: effects_state})

        {:drop, reason, effects_state} ->
          skip_event(event, reason, %{state | inbound_effects_state: effects_state})

        {:send, to, payload, effects_state} ->
          {:send, to, encode_payload(payload), %{state | inbound_effects_state: effects_state}}

        {:send_many, messages, effects_state} ->
          {:send_many, encode_messages(messages), %{state | inbound_effects_state: effects_state}}
      end
    else
      handle_event(event, state)
    end
  end

  defp handle_event(%{type: :member, conversation_id: cid, reachable?: true} = event, state) do
    with :ok <- Adapter.call(state.identity_sink, :mark_reachable, [state.bot_ref, cid, event]) do
      {:ok, %{ok: true, member: true}, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp handle_event(%{type: :member, conversation_id: cid, reachable?: false} = event, state) do
    with :ok <- Adapter.call(state.identity_sink, :mark_unreachable, [state.bot_ref, cid, event]) do
      {:ok, %{ok: true, member: true}, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp handle_event(%{type: :callback, callback_query_id: id} = event, state) do
    _ = Client.answer_callback_query(state.client, %{callback_query_id: id}, client_opts(state))
    _ = maybe_upsert_identity(state, event)
    route_command(:callback, event, state)
  end

  defp handle_event(%{type: :non_text} = event, state) do
    meta = ingress_meta(state)

    result =
      if Adapter.exported?(state.inbound_effects, :on_non_text, 3) do
        Adapter.call(state.inbound_effects, :on_non_text, [
          event,
          meta,
          state.inbound_effects_state
        ])
      else
        {:ok, state.inbound_effects_state}
      end

    case result do
      {:ok, effects_state} ->
        {:ok, %{ok: true, non_text: true, conversation_id: event.conversation_id},
         %{state | inbound_effects_state: effects_state}}

      {:send, to, payload, effects_state} ->
        {:send, to, encode_payload(payload), %{state | inbound_effects_state: effects_state}}

      {:send_many, messages, effects_state} ->
        {:send_many, encode_messages(messages), %{state | inbound_effects_state: effects_state}}
    end
  end

  defp handle_event(%{type: :text} = event, state) do
    if command_event?(event) do
      handle_command_event(event, state)
    else
      handle_text_event(event, state)
    end
  end

  defp handle_command_event(event, state) do
    if Addressing.command_addressed?(event.text, state.bot_username || discover_username(state)) do
      _ = maybe_upsert_identity(state, event)
      route_command(:command, event, state)
    else
      skip_event(event, "not_addressed", state)
    end
  end

  defp handle_text_event(event, state) do
    if addressed?(event, state) do
      deliver_to_session(event, state)
    else
      skip_event(event, "not_addressed", state)
    end
  end

  defp command_event?(event),
    do: Addressing.command_target(Map.get(event, :text, "")) != :not_command

  defp route_command(kind, event, state) do
    result =
      case kind do
        :command -> Adapter.call(state.command_router, :handle_command, [event, state])
        :callback -> Adapter.call(state.command_router, :handle_callback, [event, state])
      end

    case result do
      {:reply, text} ->
        state =
          maybe_after_routed(state, event, %{kind: kind, conversation_id: event.conversation_id})

        send_command_reply(event, text, state)

      {:send, to, payload} ->
        state =
          maybe_after_routed(state, event, %{
            kind: kind,
            target: to,
            conversation_id: event.conversation_id
          })

        {:send, to, encode_payload(payload), state}

      {:send_many, messages} ->
        state =
          maybe_after_routed(state, event, %{
            kind: kind,
            targets: Enum.map(messages, fn {to, _payload} -> to end),
            conversation_id: event.conversation_id
          })

        {:send_many, encode_messages(messages), state}

      :ok ->
        state =
          maybe_after_routed(state, event, %{kind: kind, conversation_id: event.conversation_id})

        {:ok, %{ok: true, command: true, conversation_id: event.conversation_id}, state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp deliver_to_session(event, state) do
    session_opts =
      Map.merge(state.session_opts, %{
        bot_ref: state.bot_ref,
        binding_authority: state.binding_authority,
        binding_sinks: state.binding_sinks
      })

    with :ok <- maybe_upsert_identity(state, event) do
      case ensure_session(state.session_runtime, event, session_opts) do
        {:ok, session} ->
          deliver_to_existing_session(event, session, session_opts, state)

        {:skip, reason} ->
          skip_event(event, reason, state)

        {:error, reason} ->
          {:error, reason, state}
      end
    else
      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp deliver_to_existing_session(event, session, session_opts, state, mode \\ @user_turn) do
    with :ok <-
           maybe_init_context(state, event.conversation_id, session[:workspace]),
         :ok <-
           bind_session(
             state.session_runtime,
             session,
             event.conversation_id,
             state.binding_sinks,
             session_opts
           ),
         context <- maybe_before_turn(state, event.conversation_id, event.text),
         :ok <-
           deliver_to_runtime(
             state.session_runtime,
             session,
             # `role` (0.5.0) rides the turn so runtimes that OWN a transcript
             # can record it honestly — the context-store after_turn below is
             # not enough (hosts running memory_policy :none never see it,
             # and a transcript-owning deliver_turn appends its own rows).
             # Absent/`:user` = the pre-0.5.0 contract; `:operator` = wake.
             %{
               conversation_id: event.conversation_id,
               text: event.text,
               event: event,
               context: context,
               role: mode.role
             },
             session_opts
           ),
         :ok <-
           maybe_after_turn(state, event.conversation_id, mode.role, event.text) do
      state =
        maybe_after_routed(state, event, %{
          kind: mode.kind,
          session: session,
          conversation_id: event.conversation_id
        })

      state = count_new_session(state, session)
      state = %{state | routed: [%{event: event, session: session} | state.routed]}

      {:ok, %{ok: true, conversation_id: event.conversation_id} |> Map.put(mode.ack, true),
       state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  # Only a freshly-spawned session (a brand-new conversation) counts against the
  # per-poll cap; reusing a warm pool slot is cheap and shouldn't be throttled.
  defp count_new_session(state, session) do
    if session_fresh?(session) do
      Map.update(state, :new_sessions_this_poll, 1, &(&1 + 1))
    else
      state
    end
  end

  defp session_fresh?(session) when is_map(session), do: Map.get(session, :fresh?, false) == true
  defp session_fresh?(_), do: false

  defp handle_poll_result({:ok, updates, _next_offset}, state) do
    {state, messages, offset, status} = process_polled_updates(updates, state)

    if is_integer(offset),
      do: Adapter.call(state.store, :write_offset, [state.bot_ref, offset])

    state =
      if status == :ok do
        %{state | poll_failures: 0, last_poll_ok_ms: System.system_time(:millisecond)}
      else
        %{state | poll_failures: state.poll_failures + 1}
      end

    {state, messages}
  end

  defp handle_poll_result({:error, reason} = result, state) do
    failures = state.poll_failures + 1
    log_poll_error(failures, result)

    conflict_count =
      if match?({:failed, 409, _}, reason),
        do: state.conflict_count + 1,
        else: state.conflict_count

    {%{state | poll_failures: failures, conflict_count: conflict_count}, []}
  end

  defp process_polled_updates(updates, state) do
    start_offset = Adapter.call(state.store, :read_offset, [state.bot_ref])
    cap = Map.get(state, :max_new_sessions_per_poll, 8)
    state = Map.put(state, :new_sessions_this_poll, 0)

    Enum.reduce_while(updates, {state, [], start_offset, :ok}, fn update,
                                                                  {acc, messages, offset, _status} ->
      case handle_update(update, acc) do
        {:ok, _reply, next} ->
          cont_or_halt(next, {next, messages, next_update_offset(update, offset), :ok}, cap)

        {:send, to, payload, next} ->
          cont_or_halt(
            next,
            {next, messages ++ [{:send, to, payload}], next_update_offset(update, offset), :ok},
            cap
          )

        {:send_many, new_messages, next} ->
          cont_or_halt(
            next,
            {next, messages ++ new_messages, next_update_offset(update, offset), :ok},
            cap
          )

        {:error, reason, next} ->
          {:halt, {next, messages, offset, {:error, reason}}}
      end
    end)
  end

  # Backpressure queue. Each brand-new conversation costs an agent spawn
  # (add_agent), which is the expensive, saturating operation. Cap how many NEW
  # sessions one poll opens; once the cap is hit, stop advancing the offset — the
  # remaining updates stay queued in Telegram and come back on the next poll.
  # A burst of hundreds thus drains a few per cycle instead of stampeding the
  # SwarmManager, and once the load falls the backlog clears on its own. Updates
  # for EXISTING sessions don't count against the cap (they're cheap).
  defp cont_or_halt(state, acc, cap) do
    if Map.get(state, :new_sessions_this_poll, 0) >= cap do
      {:halt, acc}
    else
      {:cont, acc}
    end
  end

  defp next_update_offset(%{"update_id" => update_id}, offset) when is_integer(update_id),
    do: max(offset, update_id + 1)

  defp next_update_offset(_update, offset), do: offset

  defp mark_processed({:error, _reason, _state} = result, _current_state, _update_id), do: result
  defp mark_processed(result, _state, update_id) when not is_integer(update_id), do: result

  defp mark_processed(result, state, update_id) do
    case Adapter.call(state.store, :mark_update_seen, [state.bot_ref, update_id]) do
      :new -> result
      :duplicate -> result
      {:error, reason} -> replace_result_with_error(result, reason)
    end
  end

  defp replace_result_with_error({:ok, _reply, state}, reason), do: {:error, reason, state}

  defp replace_result_with_error({:send, _to, _payload, state}, reason),
    do: {:error, reason, state}

  defp replace_result_with_error({:send_many, _messages, state}, reason),
    do: {:error, reason, state}

  # Fires after EVERY poll result fold (success and error branches alike) so an
  # injected observer sees a steady heartbeat, not just failure spikes. Total:
  # a raising/throwing/exiting sink must never break the poll loop — the sink
  # is host-supplied and this package has no way to vet it ahead of time.
  defp notify_health_sink(%{poll_health_sink: nil}), do: :ok

  defp notify_health_sink(state) do
    health = %{
      last_poll_ok_ms: state.last_poll_ok_ms,
      conflict_count: state.conflict_count,
      poll_failures: state.poll_failures,
      at_ms: System.system_time(:millisecond)
    }

    try do
      state.poll_health_sink.(health)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end

    :ok
  end

  defp log_poll_error(failures, {:error, reason}) do
    Logger.warning("telegram ingress poll error (#{failures} in a row): #{inspect(reason)}")
  end

  defp send_command_reply(event, text, state) do
    payload = %{action: "send", conversation_id: event.conversation_id, text: text}

    state = %{
      state
      | replies: [
          %{
            conversation_id: event.conversation_id,
            text: text,
            target: state.sender,
            routed: true
          }
          | state.replies
        ]
    }

    {:send, state.sender, encode_payload(payload), state}
  end

  defp maybe_init_context(state, conversation_id, workspace) do
    if context_enabled?(state, conversation_id) do
      Adapter.call(state.context_store, :init_session, [
        state.bot_ref,
        conversation_id,
        %{workspace: workspace}
      ])
    else
      :ok
    end
  end

  defp maybe_before_turn(state, conversation_id, text) do
    if context_enabled?(state, conversation_id) do
      Adapter.call(state.context_store, :before_turn, [state.bot_ref, conversation_id, text, %{}])
    else
      ""
    end
  end

  defp maybe_after_turn(state, conversation_id, role, text) do
    if context_enabled?(state, conversation_id) do
      Adapter.call(state.context_store, :after_turn, [
        state.bot_ref,
        conversation_id,
        role,
        text,
        %{}
      ])
    else
      :ok
    end
  end

  defp context_enabled?(state, conversation_id) do
    case state.memory_policy do
      :all -> true
      :none -> false
      :dm_only -> ConversationId.dm?(conversation_id)
      fun when is_function(fun, 1) -> fun.(conversation_id)
      fun when is_function(fun, 2) -> fun.(conversation_id, state)
      _ -> false
    end
  end

  defp bind_session(runtime, session, conversation_id, sinks, opts) do
    if Adapter.exported?(runtime, :bind_session, 4) do
      Adapter.call(runtime, :bind_session, [session, conversation_id, sinks, opts])
    else
      :ok
    end
  end

  defp ensure_session(runtime, event, opts) do
    if Adapter.exported?(runtime, :ensure_session, 3) do
      Adapter.call(runtime, :ensure_session, [event.conversation_id, event, opts])
    else
      Adapter.call(runtime, :ensure_session, [event.conversation_id, opts])
    end
  end

  defp deliver_to_runtime(runtime, session, turn, opts) do
    cond do
      Adapter.exported?(runtime, :deliver_turn, 3) ->
        Adapter.call(runtime, :deliver_turn, [session, turn, opts])

      Adapter.exported?(runtime, :deliver_to_session, 3) ->
        prefix = if String.trim(to_string(turn.context)) == "", do: "", else: turn.context <> "\n"
        Adapter.call(runtime, :deliver_to_session, [session, prefix <> turn.text, opts])

      true ->
        {:error, :no_session_delivery_callback}
    end
  end

  defp maybe_upsert_identity(state, event) do
    Adapter.call(state.identity_sink, :upsert_identity, [
      state.bot_ref,
      event.conversation_id,
      Map.get(event, :identity, %{})
    ])
  end

  defp maybe_after_routed(state, event, route) do
    if Adapter.exported?(state.inbound_effects, :after_routed, 4) do
      case Adapter.call(state.inbound_effects, :after_routed, [
             event,
             route,
             ingress_meta(state),
             state.inbound_effects_state
           ]) do
        {:ok, effects_state} -> %{state | inbound_effects_state: effects_state}
        _ -> state
      end
    else
      state
    end
  end

  defp skip_event(event, reason, state) do
    state =
      if Adapter.exported?(state.inbound_effects, :on_skipped, 4) do
        case Adapter.call(state.inbound_effects, :on_skipped, [
               event,
               reason,
               ingress_meta(state),
               state.inbound_effects_state
             ]) do
          {:ok, effects_state} -> %{state | inbound_effects_state: effects_state}
          _ -> state
        end
      else
        state
      end

    {:ok,
     %{ok: true, skipped: to_string(reason), conversation_id: Map.get(event, :conversation_id)},
     state}
  end

  defp init_inbound_effects(adapter) do
    if Adapter.exported?(adapter, :init, 1) do
      case Adapter.call(adapter, :init, [Adapter.opts(adapter)]) do
        {:ok, state} -> state
        state -> state
      end
    else
      %{}
    end
  end

  defp ingress_meta(state) do
    %{
      bot_ref: state.bot_ref,
      bot_username: state.bot_username,
      sender: state.sender,
      binding_authority: state.binding_authority
    }
  end

  defp encode_messages(messages),
    do: Enum.map(messages, fn {to, payload} -> {to, encode_payload(payload)} end)

  defp encode_payload(payload) when is_binary(payload), do: payload
  defp encode_payload(payload) when is_map(payload), do: Jason.encode!(payload)

  defp set_commands(state) do
    if Adapter.exported?(state.command_router, :command_menu, 2) do
      with {:ok, dm} <- set_command_scope(state, :dm, "all_private_chats"),
           {:ok, group} <- set_command_scope(state, :group, "all_group_chats") do
        {:ok, %{ok: true, command_menus: %{dm: dm, group: group}}, state}
      else
        {:error, reason} -> {:error, {:set_commands_failed, reason}, state}
      end
    else
      {:ok, %{ok: true, command_menus: :unsupported}, state}
    end
  end

  defp set_command_scope(state, scope_name, telegram_scope) do
    commands = Adapter.call(state.command_router, :command_menu, [scope_name, state])

    payload = %{
      commands: commands,
      scope: %{type: telegram_scope}
    }

    case Client.set_my_commands(state.client, payload, client_opts(state)) do
      {:ok, _response} -> {:ok, length(commands)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp addressed?(event, state) do
    Addressing.addressed?(event, state.bot_username || discover_username(state),
      fail_open_without_username?: state.fail_open_without_username?
    )
  end

  defp discover_username(state) do
    case Client.get_me(state.client, client_opts(state)) do
      {:ok, %{"username" => username}} -> username
      _ -> nil
    end
  end

  defp demonitor_poll(%{poll_ref: ref} = state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    %{state | poll_ref: nil}
  end

  defp demonitor_poll(state), do: state

  defp schedule_poll(%{poll_enabled: true} = state) do
    Process.send_after(self(), :poll, poll_delay(state.poll_interval_ms, state.poll_failures))
  end

  defp schedule_poll(_state), do: :ok

  defp poll_delay(base, failures) do
    factor = :math.pow(2, min(failures, 5)) |> round()
    min(base * factor, 60_000)
  end

  defp poll_opts(state) do
    [
      client_opts: client_opts(state),
      timeout_s: state.poll_timeout_s,
      allowed_updates: state.allowed_updates
    ]
  end

  # Trust-gate helpers (0.5.0): sources compare as strings (config may hold
  # atoms, the engine's `from` arrives as either); [] denies everyone.
  defp normalize_sources(l) when is_list(l), do: Enum.map(l, &to_string/1)
  defp normalize_sources(_), do: []

  defp authorized_source?(from, sources), do: to_string(from) in sources

  defp client_opts(state), do: Keyword.merge([token: state.token], state.client_opts)
  defp decode(message) when is_binary(message), do: Jason.decode(message)
  defp decode(message) when is_map(message), do: {:ok, message}
end

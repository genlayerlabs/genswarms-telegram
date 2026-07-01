defmodule Genswarms.Telegram.Objects.Ingress do
  @moduledoc """
  Telegram inbound GenSwarms object.
  """

  alias Genswarms.Telegram.{Client, ConversationId, Delivery, Parser, Poller}

  def init(config \\ %{}) do
    state = new(config)
    if state.poll_enabled, do: Process.send_after(self(), :poll, 0)
    {:ok, state}
  end

  def new(config \\ %{}) do
    token = Map.get(config, :bot_token) || System.get_env("GENSWARMS_TELEGRAM_BOT_TOKEN")
    bot_ref = Map.get(config, :bot_ref) || Genswarms.Telegram.BotRef.from_token(token)

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
      session_runtime:
        Map.get(config, :session_runtime, Genswarms.Telegram.SessionRuntime.Default),
      session_opts: Map.get(config, :session_opts, %{}),
      sender: Map.get(config, :sender, :telegram_sender),
      binding_authority: Map.get(config, :binding_authority, :telegram_ingress),
      binding_sinks: Map.get(config, :binding_sinks, [:telegram_sender]),
      memory_policy: Map.get(config, :memory_policy, :dm_only),
      poll_enabled: Map.get(config, :poll_enabled, false),
      poll_interval_ms: Map.get(config, :poll_interval_ms, 1_500),
      poll_timeout_s: Map.get(config, :poll_timeout_s, 25),
      poll_ref: nil,
      poll_failures: 0,
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

  def interface, do: %{actions: ~w(inject_update status)}

  def handle_message(_from, message, state) do
    case decode(message) do
      {:ok, msg} ->
        case dispatch(msg, state) do
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

    {state, messages} =
      case result do
        {:ok, updates, _next_offset} ->
          {state, messages, offset, status} = process_polled_updates(updates, state)
          if is_integer(offset), do: state.store.write_offset(state.bot_ref, offset)
          failures = if status == :ok, do: 0, else: state.poll_failures + 1
          {%{state | poll_failures: failures}, messages}

        {:error, _reason} ->
          {%{state | poll_failures: state.poll_failures + 1}, []}
      end

    schedule_poll(state)

    case messages do
      [] -> {:noreply, state}
      messages -> {:send_many, messages, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{poll_ref: ref} = state) do
    state = %{state | poll_ref: nil, poll_failures: state.poll_failures + 1}
    schedule_poll(state)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp dispatch(%{"action" => "status"}, state) do
    {:ok, %{ok: true, bot_ref: state.bot_ref, routed: length(state.routed)}, state}
  end

  defp dispatch(%{"action" => "inject_update", "update" => update}, state) do
    handle_update(update, state)
  end

  defp dispatch(_msg, state), do: {:error, :unknown_action, state}

  defp handle_update(update, state) do
    update_id = Map.get(update, "update_id")

    if state.store.update_seen?(state.bot_ref, update_id) do
      {:ok, %{ok: true, duplicate: true}, state}
    else
      result =
        case Parser.parse_update(update) do
          {:ok, event} -> handle_event(event, state)
          :ignore -> {:ok, %{ok: true, ignored: true}, state}
          {:error, reason} -> {:error, reason, state}
        end

      mark_processed(result, state, update_id)
    end
  end

  defp handle_event(%{type: :member, conversation_id: cid, reachable?: true} = event, state) do
    with :ok <- state.identity_sink.mark_reachable(state.bot_ref, cid, event) do
      {:ok, %{ok: true, member: true}, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp handle_event(%{type: :member, conversation_id: cid, reachable?: false} = event, state) do
    with :ok <- state.identity_sink.mark_unreachable(state.bot_ref, cid, event) do
      {:ok, %{ok: true, member: true}, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp handle_event(%{type: :callback, callback_query_id: id} = event, state) do
    _ = Client.answer_callback_query(state.client, %{callback_query_id: id}, client_opts(state))
    route_command(:callback, event, state)
  end

  defp handle_event(%{type: :non_text} = event, state) do
    {:ok, %{ok: true, non_text: true, conversation_id: event.conversation_id}, state}
  end

  defp handle_event(%{type: :text, text: "/" <> _} = event, state) do
    if command_addressed?(event.text, state.bot_username || discover_username(state)) do
      route_command(:command, event, state)
    else
      {:ok, %{ok: true, skipped: "not_addressed", conversation_id: event.conversation_id}, state}
    end
  end

  defp handle_event(%{type: :text} = event, state) do
    if addressed?(event, state) do
      deliver_to_session(event, state)
    else
      {:ok, %{ok: true, skipped: "not_addressed", conversation_id: event.conversation_id}, state}
    end
  end

  defp route_command(kind, event, state) do
    result =
      case kind do
        :command -> state.command_router.handle_command(event, state)
        :callback -> state.command_router.handle_callback(event, state)
      end

    case result do
      {:reply, text} ->
        send_command_reply(event, text, state)

      :ok ->
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

    with :ok <-
           state.identity_sink.upsert_identity(
             state.bot_ref,
             event.conversation_id,
             event.identity
           ),
         {:ok, session} <-
           state.session_runtime.ensure_session(event.conversation_id, session_opts),
         :ok <-
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
           state.session_runtime.deliver_to_session(
             session,
             context <> "\n" <> event.text,
             session_opts
           ),
         :ok <-
           maybe_after_turn(state, event.conversation_id, :user, event.text) do
      state = %{state | routed: [%{event: event, session: session} | state.routed]}
      {:ok, %{ok: true, routed: true, conversation_id: event.conversation_id}, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp process_polled_updates(updates, state) do
    start_offset = state.store.read_offset(state.bot_ref)

    Enum.reduce_while(updates, {state, [], start_offset, :ok}, fn update,
                                                                  {acc, messages, offset, _status} ->
      case handle_update(update, acc) do
        {:ok, _reply, next} ->
          {:cont, {next, messages, next_update_offset(update, offset), :ok}}

        {:send, to, payload, next} ->
          {:cont,
           {next, messages ++ [{:send, to, payload}], next_update_offset(update, offset), :ok}}

        {:send_many, new_messages, next} ->
          {:cont, {next, messages ++ new_messages, next_update_offset(update, offset), :ok}}

        {:error, reason, next} ->
          {:halt, {next, messages, offset, {:error, reason}}}
      end
    end)
  end

  defp next_update_offset(%{"update_id" => update_id}, offset) when is_integer(update_id),
    do: max(offset, update_id + 1)

  defp next_update_offset(_update, offset), do: offset

  defp mark_processed({:error, _reason, _state} = result, _current_state, _update_id), do: result
  defp mark_processed(result, _state, update_id) when not is_integer(update_id), do: result

  defp mark_processed(result, state, update_id) do
    case state.store.mark_update_seen(state.bot_ref, update_id) do
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

  defp send_command_reply(event, text, state) do
    payload = Delivery.build_send_message(%{conversation_id: event.conversation_id, text: text})

    case Client.send_message(state.client, payload, client_opts(state)) do
      {:ok, response} ->
        state = %{
          state
          | replies: [
              %{conversation_id: event.conversation_id, text: text, result: response}
              | state.replies
            ]
        }

        {:ok, %{ok: true, command: true, replied: true, conversation_id: event.conversation_id},
         state}

      {:error, reason} ->
        {:error, {:command_reply_failed, reason}, state}
    end
  end

  defp maybe_init_context(state, conversation_id, workspace) do
    if context_enabled?(state, conversation_id) do
      state.context_store.init_session(state.bot_ref, conversation_id, %{workspace: workspace})
    else
      :ok
    end
  end

  defp maybe_before_turn(state, conversation_id, text) do
    if context_enabled?(state, conversation_id) do
      state.context_store.before_turn(state.bot_ref, conversation_id, text, %{})
    else
      ""
    end
  end

  defp maybe_after_turn(state, conversation_id, role, text) do
    if context_enabled?(state, conversation_id) do
      state.context_store.after_turn(state.bot_ref, conversation_id, role, text, %{})
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
    if function_exported?(runtime, :bind_session, 4) do
      runtime.bind_session(session, conversation_id, sinks, opts)
    else
      :ok
    end
  end

  defp addressed?(event, state) do
    case ConversationId.chat_type(event.conversation_id) do
      :dm -> true
      :group -> group_addressed?(event, state)
      :unknown -> false
    end
  end

  defp group_addressed?(event, state) do
    username = state.bot_username || discover_username(state)

    cond do
      is_nil(username) ->
        state.fail_open_without_username?

      event.reply_to_bot_username &&
          String.downcase(event.reply_to_bot_username) == String.downcase(username) ->
        true

      String.match?(event.text || "", mention_regex(username)) ->
        true

      true ->
        false
    end
  end

  defp discover_username(state) do
    case Client.get_me(state.client, client_opts(state)) do
      {:ok, %{"username" => username}} -> username
      _ -> nil
    end
  end

  defp command_addressed?(text, bot_username) do
    case command_target(text) do
      :bare ->
        true

      {:target, target} when is_binary(bot_username) ->
        String.downcase(target) == String.downcase(bot_username)

      {:target, _target} ->
        false

      :not_command ->
        false
    end
  end

  defp command_target(text) do
    case text |> to_string() |> String.trim_leading() |> String.split(~r/\s+/, parts: 2) do
      ["/" <> raw | _] ->
        case String.split(raw, "@", parts: 2) do
          [_verb, target] when target != "" -> {:target, target}
          _ -> :bare
        end

      _ ->
        :not_command
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

  defp mention_regex(username), do: ~r/(^|[^\w])@#{Regex.escape(username)}([^\w]|$)/i
  defp client_opts(state), do: Keyword.merge([token: state.token], state.client_opts)
  defp decode(message) when is_binary(message), do: Jason.decode(message)
  defp decode(message) when is_map(message), do: {:ok, message}
end

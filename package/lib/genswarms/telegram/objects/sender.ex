defmodule Genswarms.Telegram.Objects.Sender do
  @moduledoc """
  Telegram outbound GenSwarms object.

  The object owns generic Telegram delivery mechanics: target authorization,
  slot-bound replies, reply threading, typing keepalive, progress edits, bounded
  batch sending, rate limiting, chunking, media fallback, and delivery audit.
  Host-specific persistence, metrics, and roster side effects belong in the
  configured `Genswarms.Telegram.DeliveryEffects` adapter.
  """

  alias Genswarms.Telegram.{Adapter, Buttons, Client, ConversationId, Delivery}

  require Logger

  @audit_max 1_000
  @caption_limit 1_024
  @inbound_max 8
  @inbound_cids_max 2_048
  @max_typing_ticks 15
  @progress_text_max 200
  @spam_window_ms 30_000

  def init(config \\ %{}) do
    {:ok, new(config)}
  end

  def new(config \\ %{}) do
    token = Map.get(config, :bot_token) || System.get_env("GENSWARMS_TELEGRAM_BOT_TOKEN")

    %{
      bot_ref: Map.get(config, :bot_ref) || Genswarms.Telegram.BotRef.from_token(token),
      token: token,
      client: Map.get(config, :client, Genswarms.Telegram.Client.Curl),
      client_opts: Map.get(config, :client_opts, []),
      dry_run: Map.get(config, :dry_run, false),
      rate_per_sec: Map.get(config, :rate_per_sec, 25),
      window: [],
      binding_authority: Map.get(config, :binding_authority, :telegram_ingress),
      slot_prefix: Map.get(config, :slot_prefix, "telegram_agent"),
      slots: %{},
      send_sources:
        Map.get(config, :send_sources, [Map.get(config, :binding_authority, :telegram_ingress)]),
      progress_sources:
        Map.get(config, :progress_sources, [
          Map.get(config, :binding_authority, :telegram_ingress)
        ]),
      typing_sources:
        Map.get(config, :typing_sources, [Map.get(config, :binding_authority, :telegram_ingress)]),
      batch_sources: Map.get(config, :batch_sources, []),
      slot_reply_sources: Map.get(config, :slot_reply_sources, []),
      delivery_effects:
        Map.get(config, :delivery_effects, Genswarms.Telegram.DeliveryEffects.Noop),
      identity_sink: Map.get(config, :identity_sink, Genswarms.Telegram.IdentitySink.Noop),
      inbound: %{},
      typing: %{},
      owed: %{},
      last_reply_ms: %{},
      progress: %{},
      progress_min_interval_ms: Map.get(config, :progress_min_interval_ms, 1_500),
      progress_max_edits: Map.get(config, :progress_max_edits, 20),
      progress_ttl_ms: Map.get(config, :progress_ttl_ms, 600_000),
      outbox: :queue.new(),
      outbox_max: Map.get(config, :outbox_max, 50_000),
      pumping: false,
      sent: []
    }
  end

  def interface do
    %{
      actions:
        ~w(reply send send_batch progress typing bind_session unbind_session audit slot_reply)
    }
  end

  def dashboard(state) do
    {items, _seen} =
      Enum.reduce(state.sent, {[], MapSet.new()}, fn entry, {acc, seen} ->
        cid = Map.get(entry, :conversation_id)

        if is_binary(cid) and not MapSet.member?(seen, cid) do
          item = %{
            session_id: cid,
            at: Map.get(entry, :at),
            status: delivery_status(Map.get(entry, :result))
          }

          {[item | acc], MapSet.put(seen, cid)}
        else
          {acc, seen}
        end
      end)

    [%{kind: :extension, name: "deliveries", data: %{count: length(items), items: items}}]
  end

  def handle_message(from, message, state) do
    with {:ok, msg} <- decode(message),
         {:ok, state} <- dispatch(from, msg, state) do
      {:noreply, state}
    else
      {:reply, reply, state} ->
        {:reply, Jason.encode!(reply), state}

      {:error, reason, state} ->
        {:reply, Jason.encode!(%{ok: false, error: inspect(reason)}), state}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  def handle_info(:pump, state) do
    case :queue.out(state.outbox) do
      {:empty, _} ->
        {:noreply, %{state | pumping: false}}

      {{:value, job}, rest} ->
        state = %{state | outbox: rest, pumping: false}

        state =
          case send_text(:internal, job.message, state, :batch) do
            {:ok, state} ->
              state

            {:error, reason, state} ->
              Logger.warning("telegram sender dropped queued batch job: #{inspect(reason)}")
              state
          end

        {:noreply, schedule_pump(state)}
    end
  end

  def handle_info({:typing, cid}, state) do
    case Map.get(state.typing, cid) do
      nil ->
        {:noreply, state}

      n when n <= 1 ->
        {:noreply,
         %{
           state
           | typing: Map.delete(state.typing, cid),
             owed: Map.delete(state.owed, cid),
             last_reply_ms: Map.delete(state.last_reply_ms, cid)
         }}

      n ->
        send_chat_action(state, cid)
        Process.send_after(self(), {:typing, cid}, 4_000)
        {:noreply, %{state | typing: Map.put(state.typing, cid, n - 1)}}
    end
  end

  def handle_info({:progress_flush, cid}, state) do
    case Map.get(state.progress, cid) do
      %{pending: text} = entry when is_binary(text) ->
        state =
          if entry.edits < state.progress_max_edits do
            state = throttle(state)
            _ = edit_status(cid, entry.message_id, text, state)

            entry = %{
              entry
              | last_edit_ms: monotonic_ms(),
                edits: entry.edits + 1,
                pending: nil
            }

            %{state | progress: Map.put(state.progress, cid, entry)}
          else
            %{state | progress: Map.put(state.progress, cid, %{entry | pending: nil})}
          end

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:progress_expire, cid}, state) do
    case Map.get(state.progress, cid) do
      nil ->
        {:noreply, state}

      %{last_edit_ms: t} ->
        idle = monotonic_ms() - t

        if idle >= state.progress_ttl_ms do
          {:noreply, %{state | progress: Map.delete(state.progress, cid)}}
        else
          Process.send_after(self(), {:progress_expire, cid}, state.progress_ttl_ms - idle)
          {:noreply, state}
        end
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp dispatch(
         from,
         %{"action" => "bind_session", "slot" => slot, "conversation_id" => cid},
         state
       ) do
    if from == state.binding_authority do
      {:ok, %{state | slots: Map.put(state.slots, to_string(slot), cid)}}
    else
      {:error, :unauthorized_binding, state}
    end
  end

  defp dispatch(from, %{"action" => "unbind_session", "slot" => slot}, state) do
    if from == state.binding_authority do
      {:ok, %{state | slots: Map.delete(state.slots, to_string(slot))}}
    else
      {:error, :unauthorized_binding, state}
    end
  end

  defp dispatch(from, %{"action" => "typing", "conversation_id" => cid} = msg, state) do
    with {:ok, cid} <- resolve_target(from, cid, state, state.typing_sources) do
      state =
        if from == state.binding_authority do
          state
          |> note_inbound(cid, Map.get(msg, "message_id"))
          |> Map.update!(:owed, &Map.update(&1, cid, 1, fn n -> n + 1 end))
        else
          state
        end

      {:ok, start_typing(cid, state)}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp dispatch(from, %{"action" => "progress"} = msg, state), do: send_progress(from, msg, state)

  defp dispatch(from, %{"action" => "reply"} = msg, state),
    do: send_text(from, msg, state, :reply)

  defp dispatch(from, %{"action" => "send"} = msg, state),
    do: send_text(from, msg, state, :proactive)

  defp dispatch(
         from,
         %{"action" => "send_batch", "recipients" => recipients, "text" => text} = msg,
         state
       )
       when is_list(recipients) do
    if from in state.batch_sources do
      common = Map.take(msg, ["buttons", "photo", "mark"])

      jobs =
        Enum.map(recipients, fn recipient ->
          cid = recipient_conversation_id(recipient)
          %{message: Map.merge(common, %{"conversation_id" => cid, "text" => text})}
        end)

      {:ok, enqueue(state, jobs)}
    else
      {:error, :unauthorized_batch, state}
    end
  end

  defp dispatch(from, %{"action" => "slot_reply", "slot" => slot, "content" => content}, state) do
    if from in state.slot_reply_sources do
      case Map.get(state.slots, to_string(slot)) do
        nil -> {:error, :unbound_slot, state}
        cid -> send_slot_reply(from, cid, content, state)
      end
    else
      {:error, :unauthorized_slot_reply, state}
    end
  end

  defp dispatch(_from, %{"action" => "audit"}, state),
    do: {:reply, %{ok: true, sent: state.sent}, state}

  defp dispatch(_from, _msg, state), do: {:error, :unknown_action, state}

  defp send_text(from, msg, state, origin) do
    with {:ok, cid} <-
           resolve_target(from, Map.get(msg, "conversation_id"), state, state.send_sources),
         {:cont, state} <- prepare_delivery(from, cid, origin, state) do
      text =
        Adapter.call(state.delivery_effects, :redact_outbound, [
          Map.get(msg, "text", ""),
          %{conversation_id: cid, origin: origin, from: from}
        ])

      state = clear_progress(cid, state)

      if String.trim(to_string(text)) == "" do
        result = {:error, :empty}

        state =
          state
          |> record_logical_delivery(cid, %{text: text}, result, %{
            origin: origin,
            from: from,
            text: text,
            mark: Map.get(msg, "mark")
          })
          |> stamp_reply(cid, origin)

        {:ok, state}
      else
        case do_send_text(cid, text, msg, state, %{
               origin: origin,
               from: from,
               mark: Map.get(msg, "mark")
             }) do
          {:ok, state} -> {:ok, stamp_reply(state, cid, origin)}
          other -> other
        end
      end
    else
      {:suppress, state} -> {:ok, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp do_send_text(cid, text, msg, state, meta) do
    chunks = Delivery.chunk_text(text)
    last = length(chunks) - 1
    reply_to = validate_reply_tag(cid, Map.get(msg, "reply_to_message_id"), state)
    buttons = Buttons.normalize(Map.get(msg, "buttons"))
    photo = photo_for_text(Map.get(msg, "photo"), text)

    {results, state} =
      chunks
      |> Enum.with_index()
      |> Enum.reduce({[], state}, fn {chunk, idx}, {results, acc} ->
        attrs = %{
          conversation_id: cid,
          text: chunk,
          reply_to_message_id: if(idx == 0, do: reply_to),
          buttons: if(idx == last, do: buttons)
        }

        payload =
          case {idx, photo} do
            {0, photo} when is_binary(photo) and photo != "" ->
              Delivery.build_send_photo(Map.put(attrs, :photo, photo))

            _ ->
              Delivery.build_send_message(attrs)
          end

        acc = throttle(acc)
        result = dispatch_payload(payload, acc, chunk)
        {[result | results], record_send(acc, cid, payload, result)}
      end)

    result = logical_result(Enum.reverse(results))
    state = record_logical_delivery(state, cid, %{text: text}, result, meta)

    {:ok, state}
  end

  defp send_progress(from, msg, state) do
    with {:ok, cid} <-
           resolve_target(from, Map.get(msg, "conversation_id"), state, state.progress_sources) do
      text =
        msg
        |> Map.get("text", "")
        |> to_string()
        |> String.trim()
        |> String.slice(0, @progress_text_max)

      cond do
        text == "" ->
          {:ok, state}

        entry = Map.get(state.progress, cid) ->
          {:ok, update_status(cid, entry, text, state)}

        true ->
          reply_to = validate_reply_tag(cid, Map.get(msg, "reply_to_message_id"), state)

          case post_status(cid, text, reply_to, state) do
            {:ok, message_id, state} ->
              entry = %{
                message_id: message_id,
                last_edit_ms: monotonic_ms(),
                edits: 0,
                pending: nil
              }

              Process.send_after(self(), {:progress_expire, cid}, state.progress_ttl_ms)
              {:ok, %{state | progress: Map.put(state.progress, cid, entry)}}

            {:error, state} ->
              {:ok, state}
          end
      end
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp update_status(cid, entry, text, state) do
    now = monotonic_ms()

    cond do
      entry.edits >= state.progress_max_edits ->
        state

      now - entry.last_edit_ms >= state.progress_min_interval_ms ->
        state = throttle(state)
        _ = edit_status(cid, entry.message_id, text, state)
        entry = %{entry | last_edit_ms: now, edits: entry.edits + 1, pending: nil}
        %{state | progress: Map.put(state.progress, cid, entry)}

      true ->
        if entry.pending == nil do
          delay = max(state.progress_min_interval_ms - (now - entry.last_edit_ms), 50)
          Process.send_after(self(), {:progress_flush, cid}, delay)
        end

        %{state | progress: Map.put(state.progress, cid, %{entry | pending: text})}
    end
  end

  defp post_status(cid, text, reply_to, state) do
    payload =
      %{
        conversation_id: cid,
        text: text,
        reply_to_message_id: reply_to
      }
      |> Delivery.build_send_message()

    state = throttle(state)
    result = dispatch_payload(payload, state, text)
    state = record_send(state, cid, payload, result)

    case message_id_from_result(result) do
      {:ok, id} -> {:ok, id, state}
      :error -> {:error, state}
    end
  end

  defp edit_status(cid, message_id, text, state) do
    payload =
      %{
        chat_id: ConversationId.chat_id(cid),
        message_id: message_id,
        text: Genswarms.Telegram.Format.to_html(text),
        parse_mode: "HTML",
        disable_web_page_preview: true
      }
      |> maybe_thread(cid)

    unless state.dry_run do
      _ = Client.edit_message_text(state.client, payload, client_opts(state))
    end

    :ok
  end

  defp send_slot_reply(from, cid, content, state) do
    cond do
      not trusted_slot_reply_content?(from, content) ->
        {:error, :invalid_slot_reply, state}

      Map.get(state.owed, cid, 0) == 0 and answered_recently?(cid, state) ->
        {:ok, state}

      true ->
        send_text(:internal, %{"conversation_id" => cid, "text" => content}, state, :slot_reply)
    end
  end

  defp dispatch_payload(payload, state, fallback_text) do
    result =
      case Adapter.call(state.delivery_effects, :before_send, [payload]) do
        :ok -> do_dispatch_payload(payload, state, fallback_text)
        {:error, reason} -> {:error, {:before_send, reason}}
      end

    case result do
      {:ok, response} ->
        _ = Adapter.call(state.delivery_effects, :after_send, [payload, response])

      {:error, reason} ->
        _ = Adapter.call(state.delivery_effects, :delivery_failed, [payload, reason])
    end

    result
  end

  defp do_dispatch_payload(payload, state, fallback_text) do
    cond do
      state.dry_run ->
        {:ok, %{"message_id" => System.unique_integer([:positive]), "dry_run" => true}}

      Map.has_key?(payload, :photo) ->
        case Client.send_photo(state.client, payload, client_opts(state)) do
          {:ok, _} = ok ->
            ok

          {:error, _reason} ->
            payload
            |> Map.delete(:photo)
            |> Map.delete(:caption)
            |> Map.put(:text, Map.get(payload, :caption, ""))
            |> send_message_with_fallback(state, fallback_text)
        end

      true ->
        send_message_with_fallback(payload, state, fallback_text)
    end
  end

  defp send_message_with_fallback(payload, state, fallback_text) do
    case Client.send_message(state.client, payload, client_opts(state)) do
      {:error, {:parse_error, _}} ->
        send_plain_fallback(payload, state, fallback_text)

      {:error, {:rate_limited, seconds, _}} ->
        Process.sleep(min(seconds, 5) * 1_000)
        retry_send_message(payload, state, fallback_text)

      {:error, {:transient, _status, _description}} ->
        retry_send_message(payload, state, fallback_text)

      other ->
        other
    end
  end

  defp retry_send_message(payload, state, fallback_text) do
    case Client.send_message(state.client, payload, client_opts(state)) do
      {:error, {:parse_error, _}} -> send_plain_fallback(payload, state, fallback_text)
      other -> other
    end
  end

  defp send_plain_fallback(payload, state, fallback_text) do
    plain_text = Genswarms.Telegram.Format.plain(fallback_text || Map.get(payload, :text, ""))

    payload
    |> Map.put(:text, plain_text)
    |> Map.delete(:parse_mode)
    |> then(&Client.send_message(state.client, &1, client_opts(state)))
  end

  defp record_send(state, cid, payload, result) do
    entry = %{
      conversation_id: cid,
      payload: payload,
      result: result,
      at: System.system_time(:second)
    }

    %{state | sent: Enum.take([entry | state.sent], @audit_max)}
  end

  defp record_logical_delivery(state, cid, delivery, result, meta) do
    delivery = Map.merge(delivery || %{}, %{conversation_id: cid})
    outcome = %{ok: match?({:ok, _}, result), result: result}
    _ = maybe_after_delivery(state, delivery, outcome, meta)

    case result do
      {:error, reason} ->
        if unreachable_reason?(reason) do
          _ = maybe_on_unreachable(state, cid, reason, meta)
        end

      _ ->
        :ok
    end

    state
  end

  defp maybe_after_delivery(state, delivery, outcome, meta) do
    if Adapter.exported?(state.delivery_effects, :after_delivery, 3) do
      Adapter.call(state.delivery_effects, :after_delivery, [delivery, outcome, meta])
    else
      :ok
    end
  end

  defp maybe_on_unreachable(state, cid, reason, meta) do
    if Adapter.exported?(state.delivery_effects, :on_unreachable, 3) do
      Adapter.call(state.delivery_effects, :on_unreachable, [cid, reason, meta])
    else
      :ok
    end
  end

  defp logical_result([]), do: {:error, :empty}

  defp logical_result(results),
    do: Enum.find(results, &match?({:error, _}, &1)) || List.last(results)

  defp unreachable_reason?({:dead_chat, _code, _description}), do: true
  defp unreachable_reason?({:failed, 403, _description}), do: true
  defp unreachable_reason?(_reason), do: false

  defp resolve_target(from, payload_cid, state, direct_sources) do
    from_s = to_string(from)

    case Map.get(state.slots, from_s) do
      nil ->
        cond do
          agent_like?(from_s, state) -> {:error, :unbound_slot}
          valid_cid?(payload_cid) -> direct_target(from, payload_cid, direct_sources)
          true -> direct_target(from, from_s, direct_sources)
        end

      bound_cid ->
        {:ok, bound_cid}
    end
  end

  defp direct_target(from, cid, direct_sources) do
    cond do
      not valid_cid?(cid) ->
        {:error, :invalid_conversation_id}

      from == :internal or from in direct_sources ->
        {:ok, cid}

      true ->
        {:error, :unauthorized_target}
    end
  end

  defp valid_cid?(cid), do: is_binary(cid) and ConversationId.valid?(cid)

  defp agent_like?(from, state), do: String.starts_with?(from, state.slot_prefix <> "_")

  defp prepare_delivery(from, cid, :reply, state) do
    if agent_slot?(from, state) and Map.get(state.owed, cid, 0) == 0 and
         answered_recently?(cid, state) do
      {:suppress, state}
    else
      {:cont, reply_typing(cid, state)}
    end
  end

  defp prepare_delivery(_from, _cid, _origin, state), do: {:cont, state}

  defp stamp_reply(state, cid, :reply),
    do: %{state | last_reply_ms: Map.put(state.last_reply_ms, cid, monotonic_ms())}

  defp stamp_reply(state, _cid, _origin), do: state

  defp agent_slot?(from, state), do: Map.has_key?(state.slots, to_string(from))

  defp answered_recently?(cid, state) do
    case Map.get(state.last_reply_ms, cid) do
      nil -> false
      t -> monotonic_ms() - t < @spam_window_ms
    end
  end

  defp note_inbound(state, cid, id) when is_integer(id) do
    inbound = if map_size(state.inbound) > @inbound_cids_max, do: %{}, else: state.inbound
    ids = [id | Map.get(inbound, cid, []) |> List.delete(id)] |> Enum.take(@inbound_max)
    %{state | inbound: Map.put(inbound, cid, ids)}
  end

  defp note_inbound(state, _cid, _id), do: state

  def validate_reply_tag(cid, id, state) when is_integer(id) do
    if id in Map.get(state.inbound, cid, []), do: id, else: nil
  end

  def validate_reply_tag(cid, id, state) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> validate_reply_tag(cid, n, state)
      _ -> nil
    end
  end

  def validate_reply_tag(_cid, _id, _state), do: nil

  defp trusted_slot_reply_content?(_from, content) do
    is_binary(content) and String.trim(content) != "" and byte_size(content) <= 500 and
      not String.contains?(content, "tg:")
  end

  defp start_typing(cid, state) do
    unless Map.has_key?(state.typing, cid) do
      send_chat_action(state, cid)
      Process.send_after(self(), {:typing, cid}, 4_000)
    end

    %{state | typing: Map.put(state.typing, cid, @max_typing_ticks)}
  end

  defp reply_typing(cid, state) do
    owed = max(0, Map.get(state.owed, cid, 0) - 1)

    if owed > 0 do
      keep_typing(cid, %{state | owed: Map.put(state.owed, cid, owed)})
    else
      %{state | typing: Map.delete(state.typing, cid), owed: Map.delete(state.owed, cid)}
    end
  end

  defp keep_typing(cid, state) do
    unless Map.has_key?(state.typing, cid) do
      send_chat_action(state, cid)
      Process.send_after(self(), {:typing, cid}, 4_000)
    end

    %{state | typing: Map.put(state.typing, cid, @max_typing_ticks)}
  end

  defp send_chat_action(%{dry_run: true}, _cid), do: :ok
  defp send_chat_action(%{token: nil}, _cid), do: :ok

  defp send_chat_action(state, cid) do
    payload = %{chat_id: ConversationId.chat_id(cid), action: "typing"} |> maybe_thread(cid)
    _ = Client.send_chat_action(state.client, payload, client_opts(state))
    :ok
  rescue
    _ -> :ok
  end

  defp enqueue(state, jobs) do
    {outbox, _len} =
      Enum.reduce(jobs, {state.outbox, :queue.len(state.outbox)}, fn job, {q, n} ->
        if n >= state.outbox_max do
          Logger.warning("telegram sender outbox full; dropping batch job")
          {q, n}
        else
          {:queue.in(job, q), n + 1}
        end
      end)

    schedule_pump(%{state | outbox: outbox})
  end

  defp schedule_pump(%{pumping: true} = state), do: state

  defp schedule_pump(state) do
    if :queue.is_empty(state.outbox) do
      state
    else
      Process.send_after(self(), :pump, 0)
      %{state | pumping: true}
    end
  end

  defp throttle(state) do
    now = monotonic_ms()

    case throttle_decision(state.window, now, state.rate_per_sec) do
      {:proceed, window} ->
        %{state | window: window}

      {:sleep, ms, window} ->
        Process.sleep(ms)
        throttle(%{state | window: window})
    end
  end

  def throttle_decision(window, now, rate_per_sec) when rate_per_sec <= 0,
    do: {:proceed, [now | window]}

  def throttle_decision(window, now, rate_per_sec) do
    trimmed = Enum.filter(window, fn t -> now - t < 1000 end)

    if length(trimmed) >= rate_per_sec do
      {:sleep, 1000 - (now - List.last(trimmed)), trimmed}
    else
      {:proceed, [now | trimmed]}
    end
  end

  def mark_after_attempt?(status), do: status in ["sent", "failed"]

  def resolve_photo({"sent", _err}, state, _text_fun), do: {"sent", nil, state}
  def resolve_photo(_failed, state, text_fun), do: text_fun.(state)

  def use_photo?(photo, text),
    do: is_binary(photo) and photo != "" and not is_nil(photo_for_text(photo, text))

  def chunk_text(text, limit \\ 4_096), do: Delivery.chunk_text(text, limit)

  def build_send_body(cid, text, parse_mode, reply_markup \\ nil, reply_to \\ nil) do
    base = %{chat_id: ConversationId.chat_id(cid), text: text, disable_web_page_preview: true}
    base = maybe_thread(base, cid)
    base = if parse_mode, do: Map.put(base, :parse_mode, parse_mode), else: base
    base = if reply_markup, do: Map.put(base, :reply_markup, reply_markup), else: base

    if is_integer(reply_to) do
      Map.put(base, :reply_parameters, %{message_id: reply_to, allow_sending_without_reply: true})
    else
      base
    end
  end

  def build_photo_body(cid, photo, caption, parse_mode, reply_markup \\ nil, reply_to \\ nil) do
    base = %{chat_id: ConversationId.chat_id(cid), photo: photo, caption: caption}
    base = maybe_thread(base, cid)
    base = if parse_mode, do: Map.put(base, :parse_mode, parse_mode), else: base
    base = if reply_markup, do: Map.put(base, :reply_markup, reply_markup), else: base

    if is_integer(reply_to) do
      Map.put(base, :reply_parameters, %{message_id: reply_to, allow_sending_without_reply: true})
    else
      base
    end
  end

  def build_reply_markup(buttons), do: Buttons.reply_markup(buttons)

  def extract_message_id(resp) do
    case Client.classify_response(200, resp) do
      {:ok, %{"message_id" => id}} when is_integer(id) -> {:ok, id}
      {:ok, %{message_id: id}} when is_integer(id) -> {:ok, id}
      {:ok, _} -> {:failed, "no message_id in response"}
      {:error, reason} -> client_error_to_send_response(reason)
    end
  end

  def classify_send_response(resp) do
    200
    |> Client.classify_response(resp)
    |> client_result_to_send_response()
  end

  def permanent_dead_chat?(description), do: Client.dead_chat_description?(description)

  defp client_result_to_send_response({:ok, _result}), do: :ok
  defp client_result_to_send_response({:error, reason}), do: client_error_to_send_response(reason)

  defp client_error_to_send_response({:parse_error, description}), do: {:parse_error, description}

  defp client_error_to_send_response({:dead_chat, _code, description}),
    do: {:unreachable, description}

  defp client_error_to_send_response({:rate_limited, seconds, _description}),
    do: {:retry_after, seconds}

  defp client_error_to_send_response({:transient, _status, description}),
    do: {:transient, to_string(description)}

  defp client_error_to_send_response({:failed, 403, description}), do: {:unreachable, description}
  defp client_error_to_send_response({:failed, _code, description}), do: {:failed, description}

  defp client_error_to_send_response({:bad_json, _status, body}),
    do: {:failed, "unexpected: #{body}"}

  defp client_error_to_send_response({:curl, code, message}),
    do: {:failed, "curl #{code}: #{message}"}

  defp client_error_to_send_response(reason), do: {:failed, inspect(reason)}

  defp recipient_conversation_id(recipient) when is_binary(recipient), do: recipient

  defp recipient_conversation_id(recipient) when is_map(recipient) do
    Map.get(recipient, "conversation_id") || Map.get(recipient, :conversation_id)
  end

  defp delivery_status({:ok, _}), do: "sent"
  defp delivery_status({:error, :empty}), do: "empty"

  defp delivery_status({:error, reason}) when is_tuple(reason),
    do: reason |> elem(0) |> to_string()

  defp delivery_status({:error, reason}), do: to_string(reason)
  defp delivery_status(_), do: "unknown"

  defp client_opts(state), do: Keyword.merge([token: state.token], state.client_opts)

  defp maybe_thread(payload, cid) do
    case ConversationId.thread_integer(cid) do
      nil -> payload
      thread -> Map.put(payload, :message_thread_id, thread)
    end
  end

  defp photo_for_text(photo, text) when is_binary(photo) and photo != "" do
    if Delivery.utf16_units(text) <= @caption_limit, do: photo, else: nil
  end

  defp photo_for_text(_photo, _text), do: nil

  defp clear_progress(cid, state), do: %{state | progress: Map.delete(state.progress, cid)}

  defp message_id_from_result({:ok, %{"message_id" => id}}) when is_integer(id), do: {:ok, id}
  defp message_id_from_result({:ok, %{message_id: id}}) when is_integer(id), do: {:ok, id}
  defp message_id_from_result(_), do: :error

  defp monotonic_ms, do: System.monotonic_time(:millisecond)

  defp decode(message) when is_binary(message), do: Jason.decode(message)
  defp decode(message) when is_map(message), do: {:ok, message}
end

defmodule Genswarms.Telegram.Objects.Sender do
  @moduledoc """
  Telegram outbound GenSwarms object.
  """

  alias Genswarms.Telegram.{Adapter, Buttons, Client, ConversationId, Delivery}

  @audit_max 1_000
  @inbound_max 8
  @progress_text_max 200
  @caption_limit 1_024

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
      progress: %{},
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
        if from == state.binding_authority,
          do: note_inbound(state, cid, Map.get(msg, "message_id")),
          else: state

      payload = %{chat_id: ConversationId.chat_id(cid), action: "typing"} |> maybe_thread(cid)
      _ = Client.send_chat_action(state.client, payload, client_opts(state))
      {:ok, state}
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
      Enum.reduce_while(recipients, state, fn recipient, acc ->
        cid = recipient_conversation_id(recipient)

        msg =
          msg
          |> Map.take(["buttons", "photo", "mark"])
          |> Map.merge(%{"conversation_id" => cid, "text" => text})

        case send_text(:internal, msg, acc, :batch) do
          {:ok, next} -> {:cont, next}
          {:error, reason, next} -> {:halt, {:error, reason, next}}
        end
      end)
      |> case do
        {:error, reason, next} -> {:error, reason, next}
        next -> {:ok, next}
      end
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
           resolve_target(from, Map.get(msg, "conversation_id"), state, state.send_sources) do
      text =
        Adapter.call(state.delivery_effects, :redact_outbound, [
          Map.get(msg, "text", ""),
          %{conversation_id: cid, origin: origin, from: from}
        ])

      if String.trim(text) == "" do
        state =
          record_logical_delivery(state, cid, nil, {:error, :empty}, %{
            origin: origin,
            from: from,
            text: text
          })

        {:ok, state}
      else
        do_send_text(cid, text, msg, state, %{
          origin: origin,
          from: from,
          mark: Map.get(msg, "mark")
        })
      end
    else
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

        result = dispatch_payload(payload, acc, chunk)
        {[result | results], record_send(acc, cid, payload, result)}
      end)

    result = logical_result(Enum.reverse(results))
    state = record_logical_delivery(state, cid, %{text: text}, result, meta)

    {:ok, %{state | progress: Map.delete(state.progress, cid)}}
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
          payload =
            %{
              chat_id: ConversationId.chat_id(cid),
              message_id: entry.message_id,
              text: Genswarms.Telegram.Format.to_html(text),
              parse_mode: "HTML"
            }
            |> maybe_thread(cid)

          _ = Client.edit_message_text(state.client, payload, client_opts(state))
          {:ok, state}

        true ->
          payload = Delivery.build_send_message(%{conversation_id: cid, text: text})
          result = dispatch_payload(payload, state, text)
          state = record_send(state, cid, payload, result)

          state =
            case result do
              {:ok, %{"message_id" => message_id}} ->
                %{state | progress: Map.put(state.progress, cid, %{message_id: message_id})}

              _ ->
                state
            end

          {:ok, state}
      end
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp send_slot_reply(from, cid, content, state) do
    if trusted_slot_reply_content?(from, content) do
      send_text(:internal, %{"conversation_id" => cid, "text" => content}, state, :slot_reply)
    else
      {:error, :invalid_slot_reply, state}
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
        {:ok, %{"message_id" => nil, "dry_run" => true}}

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
        plain_text = Genswarms.Telegram.Format.plain(fallback_text || Map.get(payload, :text, ""))
        plain = %{payload | text: plain_text}
        plain = Map.delete(plain, :parse_mode)
        Client.send_message(state.client, plain, client_opts(state))

      other ->
        other
    end
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

  defp note_inbound(state, cid, id) when is_integer(id) do
    ids = [id | Map.get(state.inbound, cid, []) |> List.delete(id)] |> Enum.take(@inbound_max)
    %{state | inbound: Map.put(state.inbound, cid, ids)}
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

  defp decode(message) when is_binary(message), do: Jason.decode(message)
  defp decode(message) when is_map(message), do: {:ok, message}
end

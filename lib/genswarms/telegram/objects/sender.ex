defmodule Genswarms.Telegram.Objects.Sender do
  @moduledoc """
  Telegram outbound GenSwarms object.

  The object owns generic Telegram delivery mechanics: target authorization,
  slot-bound replies, reply threading, typing keepalive, progress edits, bounded
  batch sending, rate limiting, chunking, media fallback, and delivery audit.
  Host-specific persistence, metrics, and roster side effects belong in the
  configured `Genswarms.Telegram.DeliveryEffects` adapter.
  """

  alias Genswarms.Telegram.{
    Actions,
    Adapter,
    Buttons,
    Card,
    Client,
    Capabilities,
    ConversationId,
    Delivery,
    RichMessage
  }

  require Logger

  @audit_max 1_000
  @caption_limit 1_024
  @inbound_max 8
  @inbound_cids_max 2_048
  @max_typing_ticks 15
  @progress_text_max 200
  @spam_window_ms 30_000
  # Coalesce-instead-of-swallow bounds (2026-07-07): extra agent replies inside
  # the spam window are HELD and flushed as one message when it expires; these
  # caps make overflow degrade to the original pure suppression.
  @held_max_texts 3
  @held_max_chars 3_000
  @held_cids_max 500
  @gate_key "__telegram_gate__"
  @utility_actions ~w(
    get_user_profile_photos
    get_user_profile_audios
    set_user_emoji_status
    get_file
  )
  @utility_methods Enum.map(@utility_actions, &String.to_atom/1)
  @chat_admin_actions ~w(
    delete_message_reaction
    delete_all_message_reactions
    ban_chat_member
    unban_chat_member
    restrict_chat_member
    promote_chat_member
    set_chat_administrator_custom_title
    set_chat_member_tag
    ban_chat_sender_chat
    unban_chat_sender_chat
    set_chat_permissions
    export_chat_invite_link
    create_chat_invite_link
    edit_chat_invite_link
    create_chat_subscription_invite_link
    edit_chat_subscription_invite_link
    revoke_chat_invite_link
    approve_chat_join_request
    decline_chat_join_request
    answer_chat_join_request_query
    send_chat_join_request_web_app
    set_chat_photo
    delete_chat_photo
    set_chat_title
    set_chat_description
    pin_chat_message
    unpin_chat_message
    unpin_all_chat_messages
    leave_chat
    get_chat
    get_chat_administrators
    get_chat_member_count
    get_chat_member
    set_chat_sticker_set
    delete_chat_sticker_set
    get_forum_topic_icon_stickers
    create_forum_topic
    edit_forum_topic
    close_forum_topic
    reopen_forum_topic
    delete_forum_topic
    unpin_all_forum_topic_messages
    edit_general_forum_topic
    close_general_forum_topic
    reopen_general_forum_topic
    hide_general_forum_topic
    unhide_general_forum_topic
    unpin_all_general_forum_topic_messages
  )
  @chat_admin_methods Enum.map(@chat_admin_actions, &String.to_atom/1)
  @sticker_actions ~w(
    get_sticker_set
    get_custom_emoji_stickers
    upload_sticker_file
    create_new_sticker_set
    add_sticker_to_set
    set_sticker_position_in_set
    delete_sticker_from_set
    replace_sticker_in_set
    set_sticker_emoji_list
    set_sticker_keywords
    set_sticker_mask_position
    set_sticker_set_title
    set_sticker_set_thumbnail
    set_custom_emoji_sticker_set_thumbnail
    delete_sticker_set
  )
  @sticker_methods Enum.map(@sticker_actions, &String.to_atom/1)

  def init(config \\ %{}) do
    {:ok, new(config)}
  end

  def new(config \\ %{}) do
    validate_action_table!()

    token = Genswarms.Telegram.BotRef.resolve_token(config)
    binding_authority = Map.get(config, :binding_authority, :telegram_ingress)

    delivery_effects =
      Map.get(config, :delivery_effects, Genswarms.Telegram.DeliveryEffects.Noop)

    %{
      bot_ref: Map.get(config, :bot_ref) || Genswarms.Telegram.BotRef.from_token(token),
      token: token,
      client: Map.get(config, :client, Genswarms.Telegram.Client.Curl),
      client_opts: Map.get(config, :client_opts, []),
      dry_run: Map.get(config, :dry_run, false),
      rate_per_sec: Map.get(config, :rate_per_sec, 25),
      window: [],
      binding_authority: binding_authority,
      slot_prefix: Map.get(config, :slot_prefix, "telegram_agent"),
      slots: restore_bindings(delivery_effects),
      send_sources: Map.get(config, :send_sources, [binding_authority]),
      progress_sources: Map.get(config, :progress_sources, [binding_authority]),
      typing_sources: Map.get(config, :typing_sources, [binding_authority]),
      batch_sources: Map.get(config, :batch_sources, []),
      slot_reply_sources: Map.get(config, :slot_reply_sources, []),
      agent_surface: normalize_agent_surface(Map.get(config, :agent_surface, :standard)),
      action_grants: normalize_action_grants(Map.get(config, :action_grants, %{})),
      audit_sources: Map.get(config, :audit_sources, [binding_authority]) || [binding_authority],
      own_message_window: Map.get(config, :own_message_window, 200),
      own_messages: %{},
      delivery_effects: delivery_effects,
      identity_sink: Map.get(config, :identity_sink, Genswarms.Telegram.IdentitySink.Noop),
      inbound: %{},
      typing: %{},
      owed: %{},
      last_reply_ms: %{},
      last_reply_sig: %{},
      held: %{},
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
        ~w(reply send send_batch progress typing bind_session unbind_session audit slot_reply capabilities examples validate_card stream_text answer_callback answer_web_app answer_inline_query answer_guest_query save_prepared_inline_message save_prepared_keyboard_button get_user_chat_boosts get_business_connection get_managed_bot_token replace_managed_bot_token get_managed_bot_access_settings set_managed_bot_access_settings get_user_personal_chat_messages set_my_commands delete_my_commands get_my_commands set_my_name get_my_name set_my_description get_my_description set_my_short_description get_my_short_description set_my_profile_photo remove_my_profile_photo set_chat_menu_button get_chat_menu_button set_my_default_administrator_rights get_my_default_administrator_rights create_invoice_link answer_shipping_query answer_pre_checkout_query get_my_star_balance get_star_transactions get_available_gifts send_gift gift_premium_subscription get_business_account_star_balance transfer_business_account_stars get_business_account_gifts get_user_gifts get_chat_gifts convert_gift_to_stars upgrade_gift transfer_gift verify_user verify_chat remove_user_verification remove_chat_verification read_business_message delete_business_messages set_business_account_name set_business_account_username set_business_account_bio set_business_account_profile_photo remove_business_account_profile_photo set_business_account_gift_settings approve_suggested_post decline_suggested_post set_passport_data_errors set_game_score get_game_high_scores refund_star_payment edit_user_star_subscription post_story repost_story edit_story delete_story send_card stream_card edit_card edit_message edit_caption edit_media edit_live_location stop_live_location edit_checklist edit_reply_markup stop_poll copy_message copy_messages forward_message forward_messages delete_message delete_messages send_media send_video_note send_live_photo send_sticker send_media_group send_paid_media send_poll send_checklist send_invoice send_game send_location send_venue send_contact send_dice send_chat_action set_reaction send_rich_raw) ++
          @utility_actions ++ @chat_admin_actions ++ @sticker_actions
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
        {:reply, Jason.encode!(error_payload(reason)), state}

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
             last_reply_ms: Map.delete(state.last_reply_ms, cid),
             last_reply_sig: Map.delete(state.last_reply_sig, cid)
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

  def handle_info({:flush_held, cid}, state), do: {:noreply, flush_held(cid, state)}

  def handle_info(_msg, state), do: {:noreply, state}

  defp dispatch(from, %{"action" => action} = msg, state) do
    case authorize_action(from, action, msg, state) do
      {:ok, gate} ->
        dispatch_authorized(from, Map.put(msg, @gate_key, gate), state)

      {:error, :unbound_slot} when action == "reply" ->
        # An agent slot replied but has no session binding: the user's turn
        # goes unanswered and the delivery never happens — the modern shape of
        # the legacy "unresolvable reply". Surface it to the host.
        _ = maybe_effect(state, :reply_unresolvable, [from, %{origin: :reply}])
        {:error, :unbound_slot, state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp dispatch(_from, _msg, state), do: {:error, :unknown_action, state}

  defp authorize_action(from, action, msg, state) do
    caller = caller_scope(from, state)

    case caller do
      %{kind: :unbound_slot} ->
        {:error, :unbound_slot}

      _scope ->
        case Actions.classify(action) do
          :unknown -> {:error, :unknown_action}
          {:agent, group} -> authorize_agent_action(from, action, group, msg, state, caller)
          {:operator, group} -> authorize_operator_action(from, group, caller, state)
          {:plumbing, plumbing} -> authorize_plumbing_action(from, plumbing, msg, state)
        end
    end
  end

  defp authorize_agent_action(from, action, group, msg, state, caller) do
    cond do
      delete_action?(action) and operator_granted?(from, :message_ops, state) ->
        {:ok, %{class: :operator, group: :message_ops, caller: caller.kind}}

      not agent_group_enabled?(state.agent_surface, group) ->
        {:error, :unauthorized_action}

      targetless_agent_action?(action, group) ->
        {:ok, %{class: :agent, group: group, caller: caller.kind}}

      caller.kind == :bound_slot ->
        authorize_bound_agent_action(action, group, msg, state, caller)

      delete_action?(action) ->
        {:error, :unauthorized_action}

      true ->
        authorize_named_agent_action(from, action, group, msg, state, caller)
    end
  end

  defp authorize_bound_agent_action(action, :own_messages = group, msg, state, caller) do
    with :ok <- authorize_own_message(action, msg, state, caller) do
      {:ok, %{class: :agent, group: group, caller: caller.kind, target: caller.cid}}
    end
  end

  defp authorize_bound_agent_action(_action, group, _msg, _state, caller) do
    {:ok, %{class: :agent, group: group, caller: caller.kind, target: caller.cid}}
  end

  defp authorize_named_agent_action(from, action, group, msg, state, caller) do
    direct_sources =
      case action do
        "progress" -> state.progress_sources
        _action -> state.send_sources
      end

    case direct_target(from, Map.get(msg, "conversation_id") || to_string(from), direct_sources) do
      {:ok, cid} -> {:ok, %{class: :agent, group: group, caller: caller.kind, target: cid}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authorize_operator_action(from, group, caller, state) do
    if operator_granted?(from, group, state) do
      {:ok, %{class: :operator, group: group, caller: caller.kind}}
    else
      {:error, :unauthorized_action}
    end
  end

  defp authorize_plumbing_action(from, :bind_session, _msg, state) do
    if from == state.binding_authority,
      do: {:ok, %{class: :plumbing}},
      else: {:error, :unauthorized_binding}
  end

  defp authorize_plumbing_action(from, :unbind_session, _msg, state) do
    if from == state.binding_authority,
      do: {:ok, %{class: :plumbing}},
      else: {:error, :unauthorized_binding}
  end

  defp authorize_plumbing_action(from, :typing, msg, state) do
    case direct_target(from, Map.get(msg, "conversation_id"), state.typing_sources) do
      {:ok, cid} -> {:ok, %{class: :plumbing, target: cid}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authorize_plumbing_action(from, :send_batch, _msg, state) do
    if from in state.batch_sources,
      do: {:ok, %{class: :plumbing}},
      else: {:error, :unauthorized_batch}
  end

  defp authorize_plumbing_action(from, :slot_reply, _msg, state) do
    if from in state.slot_reply_sources,
      do: {:ok, %{class: :plumbing}},
      else: {:error, :unauthorized_slot_reply}
  end

  defp authorize_plumbing_action(from, :audit, _msg, state) do
    if from in state.audit_sources,
      do: {:ok, %{class: :plumbing}},
      else: {:error, :unauthorized_audit}
  end

  defp dispatch_authorized(
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

  defp dispatch_authorized(from, %{"action" => "unbind_session", "slot" => slot}, state) do
    if from == state.binding_authority do
      {:ok, %{state | slots: Map.delete(state.slots, to_string(slot))}}
    else
      {:error, :unauthorized_binding, state}
    end
  end

  defp dispatch_authorized(from, %{"action" => "typing", "conversation_id" => cid} = msg, state) do
    with {:ok, cid} <- resolve_target(from, cid, state, state.typing_sources) do
      state =
        if from == state.binding_authority do
          state
          |> note_inbound(cid, Map.get(msg, "message_id"))
          |> Map.update!(:owed, &Map.update(&1, cid, 1, fn n -> n + 1 end))
          # a held tail from the PREVIOUS turn flushes now, so it lands before
          # the answer to this new message (order preserved for the user)
          |> then(&flush_held(cid, &1))
        else
          state
        end

      {:ok, start_typing(cid, state)}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp dispatch_authorized(from, %{"action" => "progress"} = msg, state),
    do: send_progress(from, msg, state)

  defp dispatch_authorized(from, %{"action" => "reply"} = msg, state),
    do: send_text(from, msg, state, :reply)

  defp dispatch_authorized(from, %{"action" => "send"} = msg, state),
    do: send_text(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "capabilities"}, state),
    do: {:reply, %{ok: true, capabilities: capabilities_for(from, state)}, state}

  defp dispatch_authorized(_from, %{"action" => "examples"}, state),
    do: {:reply, %{ok: true, examples: Card.examples()}, state}

  defp dispatch_authorized(_from, %{"action" => "validate_card", "card" => card} = msg, state) do
    opts = if truthy?(Map.get(msg, "draft")), do: %{draft?: true}, else: %{}

    case Card.validate(card, opts) do
      :ok -> {:reply, %{ok: true}, state}
      {:error, errors} -> {:reply, %{ok: false, error: "invalid_card", errors: errors}, state}
    end
  end

  defp dispatch_authorized(from, %{"action" => "stream_text"} = msg, state),
    do: stream_text(from, msg, state)

  defp dispatch_authorized(from, %{"action" => "answer_callback"} = msg, state),
    do:
      send_query_payload(from, msg, state, :answer_callback, fn ->
        Delivery.build_answer_callback_query(%{
          callback_query_id: Map.get(msg, "callback_query_id"),
          text: Map.get(msg, "text"),
          show_alert: Map.get(msg, "show_alert"),
          url: Map.get(msg, "url"),
          cache_time: Map.get(msg, "cache_time")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "answer_web_app"} = msg, state),
    do:
      send_query_payload(from, msg, state, :answer_web_app, fn ->
        Delivery.build_answer_web_app_query(%{
          web_app_query_id: Map.get(msg, "web_app_query_id"),
          result: Map.get(msg, "result")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "answer_inline_query"} = msg, state),
    do:
      send_query_payload(from, msg, state, :answer_inline_query, fn ->
        Delivery.build_answer_inline_query(%{
          inline_query_id: Map.get(msg, "inline_query_id"),
          results: Map.get(msg, "results"),
          cache_time: Map.get(msg, "cache_time"),
          is_personal: Map.get(msg, "is_personal"),
          next_offset: Map.get(msg, "next_offset"),
          button: Map.get(msg, "button")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "answer_guest_query"} = msg, state),
    do:
      send_query_payload(from, msg, state, :answer_guest_query, fn ->
        Delivery.build_answer_guest_query(%{
          guest_query_id: Map.get(msg, "guest_query_id"),
          result: Map.get(msg, "result")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "save_prepared_inline_message"} = msg, state),
    do:
      send_query_payload(from, msg, state, :save_prepared_inline_message, fn ->
        Delivery.build_save_prepared_inline_message(%{
          user_id: Map.get(msg, "user_id"),
          result: Map.get(msg, "result"),
          allow_user_chats: Map.get(msg, "allow_user_chats"),
          allow_bot_chats: Map.get(msg, "allow_bot_chats"),
          allow_group_chats: Map.get(msg, "allow_group_chats"),
          allow_channel_chats: Map.get(msg, "allow_channel_chats")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "save_prepared_keyboard_button"} = msg, state),
    do:
      send_query_payload(from, msg, state, :save_prepared_keyboard_button, fn ->
        Delivery.build_save_prepared_keyboard_button(%{
          user_id: Map.get(msg, "user_id"),
          button: Map.get(msg, "button")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "get_user_chat_boosts"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_user_chat_boosts, fn ->
        Delivery.build_get_user_chat_boosts(%{
          chat_id: Map.get(msg, "chat_id"),
          user_id: Map.get(msg, "user_id")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "get_business_connection"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_business_connection, fn ->
        Delivery.build_get_business_connection(%{
          business_connection_id: Map.get(msg, "business_connection_id")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "get_managed_bot_token"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_managed_bot_token, fn ->
        Delivery.build_get_managed_bot_token(%{user_id: Map.get(msg, "user_id")})
      end)

  defp dispatch_authorized(from, %{"action" => "replace_managed_bot_token"} = msg, state),
    do:
      send_query_payload(from, msg, state, :replace_managed_bot_token, fn ->
        Delivery.build_replace_managed_bot_token(%{user_id: Map.get(msg, "user_id")})
      end)

  defp dispatch_authorized(from, %{"action" => "get_managed_bot_access_settings"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_managed_bot_access_settings, fn ->
        Delivery.build_get_managed_bot_access_settings(%{user_id: Map.get(msg, "user_id")})
      end)

  defp dispatch_authorized(from, %{"action" => "set_managed_bot_access_settings"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_managed_bot_access_settings, fn ->
        Delivery.build_set_managed_bot_access_settings(%{
          user_id: Map.get(msg, "user_id"),
          is_access_restricted: Map.get(msg, "is_access_restricted"),
          added_user_ids: Map.get(msg, "added_user_ids")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "get_user_personal_chat_messages"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_user_personal_chat_messages, fn ->
        Delivery.build_get_user_personal_chat_messages(%{
          user_id: Map.get(msg, "user_id"),
          limit: Map.get(msg, "limit")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "set_my_commands"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_my_commands, fn ->
        Delivery.build_set_my_commands(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "delete_my_commands"} = msg, state),
    do:
      send_query_payload(from, msg, state, :delete_my_commands, fn ->
        Delivery.build_delete_my_commands(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "get_my_commands"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_my_commands, fn ->
        Delivery.build_get_my_commands(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "set_my_name"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_my_name, fn ->
        Delivery.build_set_my_name(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "get_my_name"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_my_name, fn ->
        Delivery.build_get_my_name(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "set_my_description"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_my_description, fn ->
        Delivery.build_set_my_description(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "get_my_description"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_my_description, fn ->
        Delivery.build_get_my_description(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "set_my_short_description"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_my_short_description, fn ->
        Delivery.build_set_my_short_description(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "get_my_short_description"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_my_short_description, fn ->
        Delivery.build_get_my_short_description(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "set_my_profile_photo"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_my_profile_photo, fn ->
        Delivery.build_set_my_profile_photo(%{photo: Map.get(msg, "photo")})
      end)

  defp dispatch_authorized(from, %{"action" => "remove_my_profile_photo"} = msg, state),
    do:
      send_query_payload(from, msg, state, :remove_my_profile_photo, fn ->
        Delivery.build_remove_my_profile_photo()
      end)

  defp dispatch_authorized(from, %{"action" => "set_chat_menu_button"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_chat_menu_button, fn ->
        Delivery.build_set_chat_menu_button(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "get_chat_menu_button"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_chat_menu_button, fn ->
        Delivery.build_get_chat_menu_button(bot_profile_attrs(msg))
      end)

  defp dispatch_authorized(
         from,
         %{"action" => "set_my_default_administrator_rights"} = msg,
         state
       ),
       do:
         send_query_payload(from, msg, state, :set_my_default_administrator_rights, fn ->
           Delivery.build_set_my_default_administrator_rights(bot_profile_attrs(msg))
         end)

  defp dispatch_authorized(
         from,
         %{"action" => "get_my_default_administrator_rights"} = msg,
         state
       ),
       do:
         send_query_payload(from, msg, state, :get_my_default_administrator_rights, fn ->
           Delivery.build_get_my_default_administrator_rights(bot_profile_attrs(msg))
         end)

  defp dispatch_authorized(from, %{"action" => "create_invoice_link"} = msg, state),
    do:
      send_query_payload(from, msg, state, :create_invoice_link, fn ->
        Delivery.build_create_invoice_link(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          title: Map.get(msg, "title"),
          description: Map.get(msg, "description"),
          payload: Map.get(msg, "payload"),
          provider_token: Map.get(msg, "provider_token"),
          currency: Map.get(msg, "currency"),
          prices: Map.get(msg, "prices"),
          subscription_period: Map.get(msg, "subscription_period"),
          max_tip_amount: Map.get(msg, "max_tip_amount"),
          suggested_tip_amounts: Map.get(msg, "suggested_tip_amounts"),
          provider_data: Map.get(msg, "provider_data"),
          photo_url: Map.get(msg, "photo_url"),
          photo_size: Map.get(msg, "photo_size"),
          photo_width: Map.get(msg, "photo_width"),
          photo_height: Map.get(msg, "photo_height"),
          need_name: Map.get(msg, "need_name"),
          need_phone_number: Map.get(msg, "need_phone_number"),
          need_email: Map.get(msg, "need_email"),
          need_shipping_address: Map.get(msg, "need_shipping_address"),
          send_phone_number_to_provider: Map.get(msg, "send_phone_number_to_provider"),
          send_email_to_provider: Map.get(msg, "send_email_to_provider"),
          is_flexible: Map.get(msg, "is_flexible")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "answer_shipping_query"} = msg, state),
    do:
      send_query_payload(from, msg, state, :answer_shipping_query, fn ->
        Delivery.build_answer_shipping_query(%{
          shipping_query_id: Map.get(msg, "shipping_query_id"),
          ok: Map.get(msg, "ok"),
          shipping_options: Map.get(msg, "shipping_options"),
          error_message: Map.get(msg, "error_message")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "answer_pre_checkout_query"} = msg, state),
    do:
      send_query_payload(from, msg, state, :answer_pre_checkout_query, fn ->
        Delivery.build_answer_pre_checkout_query(%{
          pre_checkout_query_id: Map.get(msg, "pre_checkout_query_id"),
          ok: Map.get(msg, "ok"),
          error_message: Map.get(msg, "error_message")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "get_my_star_balance"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_my_star_balance, fn ->
        Delivery.build_get_my_star_balance()
      end)

  defp dispatch_authorized(from, %{"action" => "get_star_transactions"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_star_transactions, fn ->
        Delivery.build_get_star_transactions(%{
          offset: Map.get(msg, "offset"),
          limit: Map.get(msg, "limit")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "get_available_gifts"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_available_gifts, fn ->
        Delivery.build_get_available_gifts()
      end)

  defp dispatch_authorized(from, %{"action" => "send_gift"} = msg, state),
    do:
      send_query_payload(from, msg, state, :send_gift, fn ->
        Delivery.build_send_gift(%{
          user_id: Map.get(msg, "user_id"),
          chat_id: Map.get(msg, "chat_id"),
          gift_id: Map.get(msg, "gift_id"),
          pay_for_upgrade: Map.get(msg, "pay_for_upgrade"),
          text: Map.get(msg, "text"),
          text_parse_mode: Map.get(msg, "text_parse_mode") || Map.get(msg, "parse_mode"),
          text_entities: Map.get(msg, "text_entities")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "gift_premium_subscription"} = msg, state),
    do:
      send_query_payload(from, msg, state, :gift_premium_subscription, fn ->
        Delivery.build_gift_premium_subscription(%{
          user_id: Map.get(msg, "user_id"),
          month_count: Map.get(msg, "month_count"),
          star_count: Map.get(msg, "star_count"),
          text: Map.get(msg, "text"),
          text_parse_mode: Map.get(msg, "text_parse_mode") || Map.get(msg, "parse_mode"),
          text_entities: Map.get(msg, "text_entities")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "get_business_account_star_balance"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_business_account_star_balance, fn ->
        Delivery.build_get_business_account_star_balance(%{
          business_connection_id: Map.get(msg, "business_connection_id")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "transfer_business_account_stars"} = msg, state),
    do:
      send_query_payload(from, msg, state, :transfer_business_account_stars, fn ->
        Delivery.build_transfer_business_account_stars(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          star_count: Map.get(msg, "star_count")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "get_business_account_gifts"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_business_account_gifts, fn ->
        Delivery.build_get_business_account_gifts(gift_query_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "get_user_gifts"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_user_gifts, fn ->
        Delivery.build_get_user_gifts(gift_query_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "get_chat_gifts"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_chat_gifts, fn ->
        Delivery.build_get_chat_gifts(gift_query_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "convert_gift_to_stars"} = msg, state),
    do:
      send_query_payload(from, msg, state, :convert_gift_to_stars, fn ->
        Delivery.build_convert_gift_to_stars(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          owned_gift_id: Map.get(msg, "owned_gift_id")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "upgrade_gift"} = msg, state),
    do:
      send_query_payload(from, msg, state, :upgrade_gift, fn ->
        Delivery.build_upgrade_gift(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          owned_gift_id: Map.get(msg, "owned_gift_id"),
          keep_original_details: Map.get(msg, "keep_original_details"),
          star_count: Map.get(msg, "star_count")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "transfer_gift"} = msg, state),
    do:
      send_query_payload(from, msg, state, :transfer_gift, fn ->
        Delivery.build_transfer_gift(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          owned_gift_id: Map.get(msg, "owned_gift_id"),
          new_owner_chat_id: Map.get(msg, "new_owner_chat_id"),
          star_count: Map.get(msg, "star_count")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "verify_user"} = msg, state),
    do:
      send_query_payload(from, msg, state, :verify_user, fn ->
        Delivery.build_verify_user(%{
          user_id: Map.get(msg, "user_id"),
          custom_description: Map.get(msg, "custom_description")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "verify_chat"} = msg, state),
    do:
      send_query_payload(from, msg, state, :verify_chat, fn ->
        Delivery.build_verify_chat(%{
          chat_id: Map.get(msg, "chat_id"),
          custom_description: Map.get(msg, "custom_description")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "remove_user_verification"} = msg, state),
    do:
      send_query_payload(from, msg, state, :remove_user_verification, fn ->
        Delivery.build_remove_user_verification(%{user_id: Map.get(msg, "user_id")})
      end)

  defp dispatch_authorized(from, %{"action" => "remove_chat_verification"} = msg, state),
    do:
      send_query_payload(from, msg, state, :remove_chat_verification, fn ->
        Delivery.build_remove_chat_verification(%{chat_id: Map.get(msg, "chat_id")})
      end)

  defp dispatch_authorized(from, %{"action" => "read_business_message"} = msg, state),
    do:
      send_query_payload(from, msg, state, :read_business_message, fn ->
        Delivery.build_read_business_message(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          chat_id: Map.get(msg, "chat_id"),
          message_id: Map.get(msg, "message_id")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "delete_business_messages"} = msg, state),
    do:
      send_query_payload(from, msg, state, :delete_business_messages, fn ->
        Delivery.build_delete_business_messages(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          message_ids: Map.get(msg, "message_ids")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "set_business_account_name"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_business_account_name, fn ->
        Delivery.build_set_business_account_name(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          first_name: Map.get(msg, "first_name"),
          last_name: Map.get(msg, "last_name")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "set_business_account_username"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_business_account_username, fn ->
        Delivery.build_set_business_account_username(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          username: Map.get(msg, "username")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "set_business_account_bio"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_business_account_bio, fn ->
        Delivery.build_set_business_account_bio(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          bio: Map.get(msg, "bio")
        })
      end)

  defp dispatch_authorized(
         from,
         %{"action" => "set_business_account_profile_photo"} = msg,
         state
       ),
       do:
         send_query_payload(from, msg, state, :set_business_account_profile_photo, fn ->
           Delivery.build_set_business_account_profile_photo(%{
             business_connection_id: Map.get(msg, "business_connection_id"),
             photo: Map.get(msg, "photo"),
             is_public: Map.get(msg, "is_public")
           })
         end)

  defp dispatch_authorized(
         from,
         %{"action" => "remove_business_account_profile_photo"} = msg,
         state
       ),
       do:
         send_query_payload(from, msg, state, :remove_business_account_profile_photo, fn ->
           Delivery.build_remove_business_account_profile_photo(%{
             business_connection_id: Map.get(msg, "business_connection_id"),
             is_public: Map.get(msg, "is_public")
           })
         end)

  defp dispatch_authorized(
         from,
         %{"action" => "set_business_account_gift_settings"} = msg,
         state
       ),
       do:
         send_query_payload(from, msg, state, :set_business_account_gift_settings, fn ->
           Delivery.build_set_business_account_gift_settings(%{
             business_connection_id: Map.get(msg, "business_connection_id"),
             show_gift_button: Map.get(msg, "show_gift_button"),
             accepted_gift_types: Map.get(msg, "accepted_gift_types")
           })
         end)

  defp dispatch_authorized(from, %{"action" => "approve_suggested_post"} = msg, state),
    do:
      send_query_payload(from, msg, state, :approve_suggested_post, fn ->
        Delivery.build_approve_suggested_post(%{
          chat_id: Map.get(msg, "chat_id"),
          message_id: Map.get(msg, "message_id"),
          send_date: Map.get(msg, "send_date")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "decline_suggested_post"} = msg, state),
    do:
      send_query_payload(from, msg, state, :decline_suggested_post, fn ->
        Delivery.build_decline_suggested_post(%{
          chat_id: Map.get(msg, "chat_id"),
          message_id: Map.get(msg, "message_id"),
          comment: Map.get(msg, "comment")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "set_passport_data_errors"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_passport_data_errors, fn ->
        Delivery.build_set_passport_data_errors(%{
          user_id: Map.get(msg, "user_id"),
          errors: Map.get(msg, "errors")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "set_game_score"} = msg, state),
    do:
      send_query_payload(from, msg, state, :set_game_score, fn ->
        Delivery.build_set_game_score(game_score_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "get_game_high_scores"} = msg, state),
    do:
      send_query_payload(from, msg, state, :get_game_high_scores, fn ->
        Delivery.build_get_game_high_scores(game_score_attrs(msg))
      end)

  defp dispatch_authorized(from, %{"action" => "refund_star_payment"} = msg, state),
    do:
      send_query_payload(from, msg, state, :refund_star_payment, fn ->
        Delivery.build_refund_star_payment(%{
          user_id: Map.get(msg, "user_id"),
          telegram_payment_charge_id: Map.get(msg, "telegram_payment_charge_id")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "edit_user_star_subscription"} = msg, state),
    do:
      send_query_payload(from, msg, state, :edit_user_star_subscription, fn ->
        Delivery.build_edit_user_star_subscription(%{
          user_id: Map.get(msg, "user_id"),
          telegram_payment_charge_id: Map.get(msg, "telegram_payment_charge_id"),
          is_canceled: Map.get(msg, "is_canceled")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "post_story"} = msg, state),
    do:
      send_query_payload(from, msg, state, :post_story, fn ->
        Delivery.build_post_story(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          content: Map.get(msg, "content"),
          active_period: Map.get(msg, "active_period"),
          caption: Map.get(msg, "caption") || Map.get(msg, "text"),
          caption_entities: Map.get(msg, "caption_entities"),
          areas: Map.get(msg, "areas"),
          post_to_chat_page: Map.get(msg, "post_to_chat_page"),
          protect_content: Map.get(msg, "protect_content")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "repost_story"} = msg, state),
    do:
      send_query_payload(from, msg, state, :repost_story, fn ->
        Delivery.build_repost_story(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          from_chat_id: Map.get(msg, "from_chat_id"),
          from_story_id: Map.get(msg, "from_story_id"),
          active_period: Map.get(msg, "active_period"),
          post_to_chat_page: Map.get(msg, "post_to_chat_page"),
          protect_content: Map.get(msg, "protect_content")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "edit_story"} = msg, state),
    do:
      send_query_payload(from, msg, state, :edit_story, fn ->
        Delivery.build_edit_story(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          story_id: Map.get(msg, "story_id"),
          content: Map.get(msg, "content"),
          caption: Map.get(msg, "caption") || Map.get(msg, "text"),
          caption_entities: Map.get(msg, "caption_entities"),
          areas: Map.get(msg, "areas")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "delete_story"} = msg, state),
    do:
      send_query_payload(from, msg, state, :delete_story, fn ->
        Delivery.build_delete_story(%{
          business_connection_id: Map.get(msg, "business_connection_id"),
          story_id: Map.get(msg, "story_id")
        })
      end)

  defp dispatch_authorized(from, %{"action" => "send_card"} = msg, state),
    do: send_card(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "stream_card"} = msg, state),
    do: stream_card(from, msg, state)

  defp dispatch_authorized(from, %{"action" => "edit_card"} = msg, state),
    do: edit_card(from, msg, state)

  defp dispatch_authorized(from, %{"action" => "edit_message"} = msg, state),
    do: edit_message(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "edit_caption"} = msg, state),
    do: edit_caption(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "edit_media"} = msg, state),
    do: edit_media(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "edit_live_location"} = msg, state),
    do: edit_live_location(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "stop_live_location"} = msg, state),
    do: stop_live_location(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "edit_checklist"} = msg, state),
    do: edit_checklist(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "edit_reply_markup"} = msg, state),
    do: edit_reply_markup(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "stop_poll"} = msg, state),
    do: stop_poll(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "copy_message"} = msg, state),
    do: copy_message(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "copy_messages"} = msg, state),
    do: copy_messages(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "forward_message"} = msg, state),
    do: forward_message(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "forward_messages"} = msg, state),
    do: forward_messages(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "delete_message"} = msg, state),
    do: delete_message(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "delete_messages"} = msg, state),
    do: delete_messages(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_media"} = msg, state),
    do: send_media(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_video_note"} = msg, state),
    do: send_video_note(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_live_photo"} = msg, state),
    do: send_live_photo(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_sticker"} = msg, state),
    do: send_sticker(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_media_group"} = msg, state),
    do: send_media_group(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_paid_media"} = msg, state),
    do: send_paid_media(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_poll"} = msg, state),
    do: send_poll(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_checklist"} = msg, state),
    do: send_checklist(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_invoice"} = msg, state),
    do: send_invoice(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_game"} = msg, state),
    do: send_game(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_location"} = msg, state),
    do: send_location(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_venue"} = msg, state),
    do: send_venue(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_contact"} = msg, state),
    do: send_contact(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_dice"} = msg, state),
    do: send_dice(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_chat_action"} = msg, state),
    do: send_chat_action(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "set_reaction"} = msg, state),
    do: set_reaction(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => "send_rich_raw"} = msg, state),
    do: send_rich_raw(from, msg, state, :proactive)

  defp dispatch_authorized(from, %{"action" => action} = msg, state)
       when action in @utility_actions do
    send_query_payload(from, msg, state, String.to_atom(action), fn ->
      build_utility_payload(action, msg)
    end)
  end

  defp dispatch_authorized(from, %{"action" => action} = msg, state)
       when action in @chat_admin_actions do
    send_query_payload(from, msg, state, String.to_atom(action), fn ->
      build_chat_admin_payload(action, msg)
    end)
  end

  defp dispatch_authorized(from, %{"action" => action} = msg, state)
       when action in @sticker_actions do
    send_query_payload(from, msg, state, String.to_atom(action), fn ->
      build_sticker_payload(action, msg)
    end)
  end

  defp dispatch_authorized(
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

  defp dispatch_authorized(
         from,
         %{"action" => "slot_reply", "slot" => slot, "content" => content},
         state
       ) do
    if from in state.slot_reply_sources do
      case Map.get(state.slots, to_string(slot)) do
        nil -> {:error, :unbound_slot, state}
        cid -> send_slot_reply(from, cid, content, state)
      end
    else
      {:error, :unauthorized_slot_reply, state}
    end
  end

  defp dispatch_authorized(_from, %{"action" => "audit"}, state),
    do: {:reply, %{ok: true, sent: state.sent}, state}

  defp dispatch_authorized(_from, _msg, state), do: {:error, :unknown_action, state}

  defp error_payload({:invalid_payload, message}) do
    %{ok: false, error: "invalid_payload", reason: message}
  end

  defp error_payload({:invalid_card, errors}) do
    %{ok: false, error: "invalid_card", errors: errors}
  end

  defp error_payload({:invalid_rich_message, error}) do
    %{ok: false, error: "invalid_rich_message", reason: error}
  end

  defp error_payload(reason), do: %{ok: false, error: inspect(reason)}

  defp send_text(from, msg, state, origin) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
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
          {:ok, state} -> {:ok, state |> stamp_reply(cid, origin) |> stamp_sig(cid, text, origin)}
          other -> other
        end
      end
    else
      {:suppress, cid, state} ->
        {:ok, hold_reply(from, cid, Map.get(msg, "text", ""), state)}

      {:error, reason} ->
        # A conversational reply that never resolved to a target is a real
        # fault (the user is left unanswered) — surface it to the host.
        if origin in [:reply, :slot_reply],
          do: _ = maybe_effect(state, :reply_unresolvable, [from, %{origin: origin}])

        {:error, reason, state}
    end
  end

  defp do_send_text(cid, text, msg, state, meta) do
    chunks = Delivery.chunk_text(text)
    last = length(chunks) - 1
    reply_to = validate_reply_tag(cid, Map.get(msg, "reply_to_message_id"), state)
    reply_attrs = reply_attrs(reply_to, msg)
    reply_markup = message_reply_markup(msg)
    photo = photo_for_text(Map.get(msg, "photo"), text)

    {results, state} =
      chunks
      |> Enum.with_index()
      |> Enum.reduce({[], state}, fn {chunk, idx}, {results, acc} ->
        attrs = %{
          conversation_id: cid,
          text: chunk,
          reply_markup: if(idx == last, do: reply_markup)
        }

        attrs = if idx == 0, do: Map.merge(attrs, reply_attrs), else: attrs

        payload =
          case {idx, photo} do
            {0, photo} when is_binary(photo) and photo != "" ->
              Delivery.build_send_photo(Map.put(attrs, :photo, photo))

            _ ->
              Delivery.build_send_message(attrs)
          end

        acc = throttle(acc)
        result = dispatch_payload(payload, acc, chunk)
        {[result | results], record_send(acc, cid, payload, result, Map.get(meta, :from))}
      end)

    result = logical_result(Enum.reverse(results))
    state = record_logical_delivery(state, cid, %{text: text}, result, meta)

    {:ok, state}
  end

  defp send_progress(from, msg, state) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.progress_sources) do
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

  defp send_card(from, msg, state, origin) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:cont, state} <- prepare_delivery(from, cid, origin, state),
         {:ok, rich_message} <- Card.to_rich_message(Map.get(msg, "card", %{})),
         {:ok, state} <-
           send_rich_payload(
             cid,
             rich_message,
             Map.merge(msg, %{"buttons" => card_buttons(msg)}),
             state,
             %{origin: origin, from: from, mark: Map.get(msg, "mark")}
           ) do
      {:ok, stamp_reply(state, cid, origin)}
    else
      {:suppress, _cid, state} -> {:ok, state}
      {:error, errors} when is_list(errors) -> {:error, {:invalid_card, errors}, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp stream_card(from, msg, state) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         draft_id when not is_nil(draft_id) <- Map.get(msg, "draft_id"),
         {:ok, rich_message} <- Card.to_rich_message(Map.get(msg, "card", %{}), %{draft?: true}),
         {:ok, payload} <-
           safe_build_payload(fn ->
             Delivery.build_send_rich_message_draft(%{
               conversation_id: cid,
               draft_id: draft_id,
               rich_message: rich_message
             })
           end) do
      state = throttle(state)
      result = dispatch_payload(payload, state, nil)
      {:ok, record_send(state, cid, payload, result, from)}
    else
      nil -> {:error, :missing_draft_id, state}
      {:error, errors} when is_list(errors) -> {:error, {:invalid_card, errors}, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp stream_text(from, msg, state) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:ok, payload} <-
           safe_build_payload(fn ->
             Delivery.build_send_message_draft(%{
               conversation_id: cid,
               draft_id: Map.get(msg, "draft_id"),
               text: Map.get(msg, "text", "")
             })
           end) do
      state = throttle(state)
      result = dispatch_payload(payload, state, Map.get(msg, "text", ""))
      {:ok, record_send(state, cid, payload, result, from)}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp edit_card(from, msg, state) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:ok, rich_message} <- Card.to_rich_message(Map.get(msg, "card", %{})),
         {:ok, payload} <-
           safe_build_payload(fn ->
             Delivery.build_edit_rich_message(%{
               conversation_id: cid,
               message_id: Map.get(msg, "message_id"),
               rich_message: rich_message,
               buttons: Buttons.normalize(Map.get(msg, "buttons"))
             })
           end) do
      state = throttle(state)
      result = dispatch_payload(payload, state, nil)
      {:ok, record_send(state, cid, payload, result)}
    else
      {:error, errors} when is_list(errors) -> {:error, {:invalid_card, errors}, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp edit_message(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :edit_message, fn cid ->
      Delivery.build_edit_message_text(%{
        conversation_id: cid,
        message_id: Map.get(msg, "message_id"),
        text: Map.get(msg, "text"),
        reply_markup: inline_message_reply_markup(msg),
        link_preview_options: Map.get(msg, "link_preview_options")
      })
    end)
  end

  defp edit_caption(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :edit_caption, fn cid ->
      Delivery.build_edit_message_caption(%{
        conversation_id: cid,
        message_id: Map.get(msg, "message_id"),
        caption: Map.get(msg, "caption") || Map.get(msg, "text"),
        show_caption_above_media: Map.get(msg, "show_caption_above_media"),
        reply_markup: inline_message_reply_markup(msg)
      })
    end)
  end

  defp edit_media(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :edit_media, fn cid ->
      Delivery.build_edit_message_media(%{
        conversation_id: cid,
        message_id: Map.get(msg, "message_id"),
        media_type: Map.get(msg, "media_type"),
        media: Map.get(msg, "media") || Map.get(msg, "url"),
        reply_markup: inline_message_reply_markup(msg)
      })
    end)
  end

  defp edit_live_location(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :edit_live_location, fn cid ->
      Delivery.build_edit_live_location(%{
        conversation_id: cid,
        message_id: Map.get(msg, "message_id"),
        latitude: Map.get(msg, "latitude"),
        longitude: Map.get(msg, "longitude"),
        horizontal_accuracy: Map.get(msg, "horizontal_accuracy"),
        heading: Map.get(msg, "heading"),
        proximity_alert_radius: Map.get(msg, "proximity_alert_radius"),
        reply_markup: inline_message_reply_markup(msg)
      })
    end)
  end

  defp stop_live_location(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :stop_live_location, fn cid ->
      Delivery.build_stop_live_location(%{
        conversation_id: cid,
        message_id: Map.get(msg, "message_id"),
        reply_markup: inline_message_reply_markup(msg)
      })
    end)
  end

  defp edit_checklist(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :edit_checklist, fn cid ->
      Delivery.build_edit_message_checklist(%{
        conversation_id: cid,
        message_id: Map.get(msg, "message_id"),
        business_connection_id: Map.get(msg, "business_connection_id"),
        checklist: Map.get(msg, "checklist"),
        title: Map.get(msg, "title"),
        tasks: Map.get(msg, "tasks"),
        reply_markup: inline_message_reply_markup(msg)
      })
    end)
  end

  defp edit_reply_markup(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :edit_reply_markup, fn cid ->
      Delivery.build_edit_message_reply_markup(%{
        conversation_id: cid,
        message_id: Map.get(msg, "message_id"),
        reply_markup: inline_message_reply_markup(msg)
      })
    end)
  end

  defp copy_message(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :copy_message, fn cid ->
      Delivery.build_copy_message(
        %{
          conversation_id: cid,
          from_chat_id: Map.get(msg, "from_chat_id"),
          message_id: Map.get(msg, "message_id"),
          caption: Map.get(msg, "caption") || Map.get(msg, "text"),
          show_caption_above_media: Map.get(msg, "show_caption_above_media"),
          video_start_timestamp: Map.get(msg, "video_start_timestamp"),
          reply_markup: message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )
    end)
  end

  defp copy_messages(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :copy_messages, fn cid ->
      Delivery.build_copy_messages(%{
        conversation_id: cid,
        from_chat_id: Map.get(msg, "from_chat_id"),
        message_ids: Map.get(msg, "message_ids"),
        disable_notification: Map.get(msg, "disable_notification"),
        protect_content: Map.get(msg, "protect_content")
      })
    end)
  end

  defp forward_message(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :forward_message, fn cid ->
      Delivery.build_forward_message(%{
        conversation_id: cid,
        from_chat_id: Map.get(msg, "from_chat_id"),
        message_id: Map.get(msg, "message_id"),
        video_start_timestamp: Map.get(msg, "video_start_timestamp"),
        disable_notification: Map.get(msg, "disable_notification"),
        protect_content: Map.get(msg, "protect_content")
      })
    end)
  end

  defp forward_messages(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :forward_messages, fn cid ->
      Delivery.build_forward_messages(%{
        conversation_id: cid,
        from_chat_id: Map.get(msg, "from_chat_id"),
        message_ids: Map.get(msg, "message_ids"),
        disable_notification: Map.get(msg, "disable_notification"),
        protect_content: Map.get(msg, "protect_content")
      })
    end)
  end

  defp delete_message(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :delete_message, fn cid ->
      Delivery.build_delete_message(%{
        conversation_id: cid,
        message_id: Map.get(msg, "message_id")
      })
    end)
  end

  defp delete_messages(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :delete_messages, fn cid ->
      Delivery.build_delete_messages(%{
        conversation_id: cid,
        message_ids: Map.get(msg, "message_ids")
      })
    end)
  end

  defp stop_poll(from, msg, state, origin) do
    send_edit_payload(from, msg, state, origin, :stop_poll, fn cid ->
      Delivery.build_stop_poll(%{
        conversation_id: cid,
        message_id: Map.get(msg, "message_id"),
        reply_markup: inline_message_reply_markup(msg)
      })
    end)
  end

  defp send_rich_raw(from, msg, state, origin) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         :ok <- RichMessage.validate(Map.get(msg, "rich_message", %{})),
         {:ok, state} <-
           send_rich_payload(cid, Map.get(msg, "rich_message"), msg, state, %{
             origin: origin,
             from: from,
             mark: Map.get(msg, "mark")
           }) do
      {:ok, state}
    else
      {:error, %{path: _} = error} -> {:error, {:invalid_rich_message, error}, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp send_rich_payload(cid, rich_message, msg, state, meta) do
    payload =
      Delivery.build_send_rich_message(
        %{
          conversation_id: cid,
          rich_message: rich_message,
          reply_markup: message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content"),
          message_effect_id: Map.get(msg, "message_effect_id"),
          allow_paid_broadcast: Map.get(msg, "allow_paid_broadcast")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )

    state = clear_progress(cid, state) |> throttle()
    result = dispatch_payload(payload, state, Map.get(msg, "fallback_text", ""))

    state =
      state
      |> record_send(cid, payload, result, Map.get(meta, :from))
      |> record_logical_delivery(cid, %{rich_message: rich_message}, result, meta)

    {:ok, state}
  end

  defp send_media(from, msg, state, origin) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:cont, state} <- prepare_delivery(from, cid, origin, state),
         {:ok, payload} <-
           safe_build_payload(fn ->
             Delivery.build_send_media(
               %{
                 conversation_id: cid,
                 media_type: Map.get(msg, "media_type"),
                 media: Map.get(msg, "media") || Map.get(msg, "url"),
                 caption: Map.get(msg, "caption") || Map.get(msg, "text"),
                 reply_markup: message_reply_markup(msg),
                 spoiler: Map.get(msg, "spoiler"),
                 disable_notification: Map.get(msg, "disable_notification"),
                 protect_content: Map.get(msg, "protect_content")
               }
               |> Map.merge(message_reply_attrs(cid, msg, state))
             )
           end) do
      state = clear_progress(cid, state) |> throttle()

      result =
        dispatch_payload(payload, state, Map.get(msg, "caption") || Map.get(msg, "text", ""))

      state =
        state
        |> record_send(cid, payload, result, from)
        |> record_logical_delivery(
          cid,
          %{media: Map.get(msg, "media") || Map.get(msg, "url")},
          result,
          %{
            origin: origin,
            from: from,
            mark: Map.get(msg, "mark")
          }
        )

      {:ok, stamp_reply(state, cid, origin)}
    else
      {:suppress, _cid, state} -> {:ok, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp send_video_note(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :video_note, fn cid ->
      Delivery.build_send_video_note(
        %{
          conversation_id: cid,
          video_note: Map.get(msg, "video_note") || Map.get(msg, "media"),
          duration: Map.get(msg, "duration"),
          length: Map.get(msg, "length"),
          thumbnail: Map.get(msg, "thumbnail"),
          reply_markup: message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )
    end)
  end

  defp send_live_photo(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :live_photo, fn cid ->
      Delivery.build_send_live_photo(
        %{
          conversation_id: cid,
          live_photo: Map.get(msg, "live_photo"),
          photo: Map.get(msg, "photo"),
          caption: Map.get(msg, "caption") || Map.get(msg, "text"),
          show_caption_above_media: Map.get(msg, "show_caption_above_media"),
          spoiler: Map.get(msg, "spoiler"),
          reply_markup: message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )
    end)
  end

  defp send_sticker(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :sticker, fn cid ->
      Delivery.build_send_sticker(
        %{
          conversation_id: cid,
          sticker: Map.get(msg, "sticker") || Map.get(msg, "media"),
          emoji: Map.get(msg, "emoji"),
          reply_markup: message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content"),
          allow_paid_broadcast: Map.get(msg, "allow_paid_broadcast"),
          message_effect_id: Map.get(msg, "message_effect_id")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )
    end)
  end

  defp send_media_group(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :media_group, fn cid ->
      Delivery.build_send_media_group(
        %{
          conversation_id: cid,
          media: Map.get(msg, "media"),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )
    end)
  end

  defp send_paid_media(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :paid_media, fn cid ->
      Delivery.build_send_paid_media(%{
        conversation_id: cid,
        business_connection_id: Map.get(msg, "business_connection_id"),
        star_count: Map.get(msg, "star_count"),
        media: Map.get(msg, "media"),
        payload: Map.get(msg, "payload"),
        caption: Map.get(msg, "caption") || Map.get(msg, "text"),
        caption_entities: Map.get(msg, "caption_entities"),
        show_caption_above_media: Map.get(msg, "show_caption_above_media"),
        direct_messages_topic_id: Map.get(msg, "direct_messages_topic_id"),
        suggested_post_parameters: Map.get(msg, "suggested_post_parameters"),
        reply_markup: inline_message_reply_markup(msg),
        disable_notification: Map.get(msg, "disable_notification"),
        protect_content: Map.get(msg, "protect_content"),
        allow_paid_broadcast: Map.get(msg, "allow_paid_broadcast")
      })
    end)
  end

  defp send_poll(from, msg, state, origin) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:ok, payload} <-
           safe_build_payload(fn ->
             Delivery.build_send_poll(
               %{
                 conversation_id: cid,
                 question: Map.get(msg, "question"),
                 options: Map.get(msg, "options"),
                 reply_markup: message_reply_markup(msg),
                 is_anonymous: Map.get(msg, "is_anonymous"),
                 allows_multiple_answers: Map.get(msg, "allows_multiple_answers"),
                 allows_revoting: Map.get(msg, "allows_revoting"),
                 shuffle_options: Map.get(msg, "shuffle_options"),
                 allow_adding_options: Map.get(msg, "allow_adding_options"),
                 hide_results_until_closes: Map.get(msg, "hide_results_until_closes"),
                 members_only: Map.get(msg, "members_only"),
                 country_codes: Map.get(msg, "country_codes"),
                 poll_type: Map.get(msg, "poll_type"),
                 correct_option_id: Map.get(msg, "correct_option_id"),
                 correct_option_ids: Map.get(msg, "correct_option_ids"),
                 explanation: Map.get(msg, "explanation"),
                 explanation_media: Map.get(msg, "explanation_media"),
                 description: Map.get(msg, "description"),
                 media: Map.get(msg, "media")
               }
               |> Map.merge(message_reply_attrs(cid, msg, state))
             )
           end) do
      state = throttle(state)
      result = dispatch_payload(payload, state, Map.get(msg, "question", ""))

      state =
        state
        |> record_send(cid, payload, result, from)
        |> record_logical_delivery(cid, %{poll: Map.get(msg, "question")}, result, %{
          origin: origin,
          from: from,
          mark: Map.get(msg, "mark")
        })

      {:ok, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp send_checklist(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :checklist, fn cid ->
      Delivery.build_send_checklist(
        %{
          conversation_id: cid,
          business_connection_id: Map.get(msg, "business_connection_id"),
          checklist: Map.get(msg, "checklist"),
          title: Map.get(msg, "title"),
          tasks: Map.get(msg, "tasks"),
          reply_markup: inline_message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content"),
          message_effect_id: Map.get(msg, "message_effect_id")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )
    end)
  end

  defp send_invoice(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :invoice, fn cid ->
      Delivery.build_send_invoice(
        %{
          conversation_id: cid,
          title: Map.get(msg, "title"),
          description: Map.get(msg, "description"),
          payload: Map.get(msg, "payload"),
          provider_token: Map.get(msg, "provider_token"),
          currency: Map.get(msg, "currency"),
          prices: Map.get(msg, "prices"),
          max_tip_amount: Map.get(msg, "max_tip_amount"),
          suggested_tip_amounts: Map.get(msg, "suggested_tip_amounts"),
          start_parameter: Map.get(msg, "start_parameter"),
          provider_data: Map.get(msg, "provider_data"),
          photo_url: Map.get(msg, "photo_url"),
          photo_size: Map.get(msg, "photo_size"),
          photo_width: Map.get(msg, "photo_width"),
          photo_height: Map.get(msg, "photo_height"),
          need_name: Map.get(msg, "need_name"),
          need_phone_number: Map.get(msg, "need_phone_number"),
          need_email: Map.get(msg, "need_email"),
          need_shipping_address: Map.get(msg, "need_shipping_address"),
          send_phone_number_to_provider: Map.get(msg, "send_phone_number_to_provider"),
          send_email_to_provider: Map.get(msg, "send_email_to_provider"),
          is_flexible: Map.get(msg, "is_flexible"),
          direct_messages_topic_id: Map.get(msg, "direct_messages_topic_id"),
          suggested_post_parameters: Map.get(msg, "suggested_post_parameters"),
          reply_markup: inline_message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content"),
          allow_paid_broadcast: Map.get(msg, "allow_paid_broadcast"),
          message_effect_id: Map.get(msg, "message_effect_id")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )
    end)
  end

  defp send_game(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :game, fn cid ->
      Delivery.build_send_game(
        %{
          conversation_id: cid,
          business_connection_id: Map.get(msg, "business_connection_id"),
          game_short_name: Map.get(msg, "game_short_name"),
          reply_markup: inline_message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content"),
          allow_paid_broadcast: Map.get(msg, "allow_paid_broadcast"),
          message_effect_id: Map.get(msg, "message_effect_id")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )
    end)
  end

  defp send_location(from, msg, state, origin) do
    attrs = %{
      latitude: Map.get(msg, "latitude"),
      longitude: Map.get(msg, "longitude"),
      horizontal_accuracy: Map.get(msg, "horizontal_accuracy"),
      live_period: Map.get(msg, "live_period"),
      heading: Map.get(msg, "heading"),
      proximity_alert_radius: Map.get(msg, "proximity_alert_radius")
    }

    send_place(from, msg, state, origin, :location, attrs)
  end

  defp send_venue(from, msg, state, origin) do
    attrs = %{
      latitude: Map.get(msg, "latitude"),
      longitude: Map.get(msg, "longitude"),
      title: Map.get(msg, "title"),
      address: Map.get(msg, "address"),
      foursquare_id: Map.get(msg, "foursquare_id"),
      foursquare_type: Map.get(msg, "foursquare_type"),
      google_place_id: Map.get(msg, "google_place_id"),
      google_place_type: Map.get(msg, "google_place_type")
    }

    send_place(from, msg, state, origin, :venue, attrs)
  end

  defp send_contact(from, msg, state, origin) do
    attrs = %{
      phone_number: Map.get(msg, "phone_number"),
      first_name: Map.get(msg, "first_name"),
      last_name: Map.get(msg, "last_name"),
      vcard: Map.get(msg, "vcard")
    }

    send_place(from, msg, state, origin, :contact, attrs)
  end

  defp send_dice(from, msg, state, origin) do
    send_built_payload(from, msg, state, origin, :dice, fn cid ->
      Delivery.build_send_dice(
        %{
          conversation_id: cid,
          emoji: Map.get(msg, "emoji"),
          reply_markup: message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content")
        }
        |> Map.merge(message_reply_attrs(cid, msg, state))
      )
    end)
  end

  defp send_chat_action(from, msg, state, origin) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:ok, payload} <-
           safe_build_payload(fn ->
             Delivery.build_send_chat_action(%{
               conversation_id: cid,
               action:
                 Map.get(msg, "chat_action") || Map.get(msg, "typing_action") ||
                   Map.get(msg, "action_type") || "typing",
               business_connection_id: Map.get(msg, "business_connection_id")
             })
           end) do
      state = throttle(state)
      result = dispatch_payload(payload, state, nil)

      state =
        state
        |> record_send(cid, payload, result, from)
        |> record_logical_delivery(cid, %{chat_action: payload.action}, result, %{
          origin: origin,
          from: from,
          mark: Map.get(msg, "mark")
        })

      {:ok, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp set_reaction(from, msg, state, origin) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:ok, payload} <-
           safe_build_payload(fn ->
             Delivery.build_set_message_reaction(%{
               conversation_id: cid,
               message_id: Map.get(msg, "message_id"),
               reaction: Map.get(msg, "reaction") || Map.get(msg, "reactions"),
               is_big: Map.get(msg, "is_big")
             })
           end) do
      state = throttle(state)
      result = dispatch_payload(payload, state, nil)

      state =
        state
        |> record_send(cid, payload, result)
        |> record_logical_delivery(cid, %{reaction: Map.get(payload, :reaction, [])}, result, %{
          origin: origin,
          from: from,
          mark: Map.get(msg, "mark")
        })

      {:ok, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp send_built_payload(from, msg, state, origin, logical_kind, builder) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:cont, state} <- prepare_delivery(from, cid, origin, state),
         {:ok, payload} <- safe_build_payload(fn -> builder.(cid) end) do
      state = clear_progress(cid, state) |> throttle()
      result = dispatch_payload(payload, state, Map.get(msg, "caption") || Map.get(msg, "text"))

      state =
        state
        |> record_send(cid, payload, result, from)
        |> record_logical_delivery(cid, %{logical_kind => payload}, result, %{
          origin: origin,
          from: from,
          mark: Map.get(msg, "mark")
        })

      {:ok, stamp_reply(state, cid, origin)}
    else
      {:suppress, _cid, state} -> {:ok, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp send_edit_payload(from, msg, state, origin, logical_kind, builder) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:ok, payload} <- safe_build_payload(fn -> builder.(cid) end) do
      state = throttle(state)
      result = dispatch_payload(payload, state, Map.get(msg, "text") || Map.get(msg, "caption"))

      state =
        state
        |> record_send(cid, payload, result)
        |> record_logical_delivery(cid, %{logical_kind => payload}, result, %{
          origin: origin,
          from: from,
          mark: Map.get(msg, "mark")
        })

      {:ok, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp send_query_payload(from, msg, state, logical_kind, builder) do
    with {:ok, payload} <- safe_build_payload(builder) do
      state = throttle(state)
      result = dispatch_payload(payload, state, nil)

      state =
        state
        |> record_send(Map.get(msg, "conversation_id") || "telegram:query", payload, result)
        |> record_logical_delivery(
          Map.get(msg, "conversation_id") || "telegram:query",
          %{logical_kind => payload},
          result,
          %{
            origin: :query,
            from: from,
            mark: Map.get(msg, "mark")
          }
        )

      {:ok, state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp gift_query_attrs(msg) do
    [
      :business_connection_id,
      :user_id,
      :chat_id,
      :exclude_unsaved,
      :exclude_saved,
      :exclude_unlimited,
      :exclude_limited_upgradable,
      :exclude_limited_non_upgradable,
      :exclude_from_blockchain,
      :exclude_unique,
      :sort_by_price,
      :offset,
      :limit
    ]
    |> Enum.reduce(%{}, fn key, acc ->
      case Map.get(msg, to_string(key)) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp game_score_attrs(msg) do
    [
      :user_id,
      :score,
      :force,
      :disable_edit_message,
      :chat_id,
      :message_id,
      :inline_message_id
    ]
    |> Enum.reduce(%{}, fn key, acc ->
      case Map.get(msg, to_string(key)) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp bot_profile_attrs(msg) do
    [
      :commands,
      :scope,
      :language_code,
      :name,
      :description,
      :short_description,
      :chat_id,
      :menu_button,
      :rights,
      :for_channels
    ]
    |> Enum.reduce(%{}, fn key, acc ->
      case Map.get(msg, to_string(key)) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp build_utility_payload("get_user_profile_photos", msg),
    do: Delivery.build_get_user_profile_photos(utility_attrs(msg))

  defp build_utility_payload("get_user_profile_audios", msg),
    do: Delivery.build_get_user_profile_audios(utility_attrs(msg))

  defp build_utility_payload("set_user_emoji_status", msg),
    do: Delivery.build_set_user_emoji_status(utility_attrs(msg))

  defp build_utility_payload("get_file", msg), do: Delivery.build_get_file(utility_attrs(msg))

  defp utility_attrs(msg) do
    [
      :user_id,
      :offset,
      :limit,
      :emoji_status_custom_emoji_id,
      :emoji_status_expiration_date,
      :file_id
    ]
    |> Enum.reduce(%{}, fn key, acc ->
      case Map.get(msg, to_string(key)) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp build_chat_admin_payload("delete_message_reaction", msg),
    do: Delivery.build_delete_message_reaction(chat_admin_attrs(msg))

  defp build_chat_admin_payload("delete_all_message_reactions", msg),
    do: Delivery.build_delete_all_message_reactions(chat_admin_attrs(msg))

  defp build_chat_admin_payload("ban_chat_member", msg),
    do: Delivery.build_ban_chat_member(chat_admin_attrs(msg))

  defp build_chat_admin_payload("unban_chat_member", msg),
    do: Delivery.build_unban_chat_member(chat_admin_attrs(msg))

  defp build_chat_admin_payload("restrict_chat_member", msg),
    do: Delivery.build_restrict_chat_member(chat_admin_attrs(msg))

  defp build_chat_admin_payload("promote_chat_member", msg),
    do: Delivery.build_promote_chat_member(chat_admin_attrs(msg))

  defp build_chat_admin_payload("set_chat_administrator_custom_title", msg),
    do: Delivery.build_set_chat_administrator_custom_title(chat_admin_attrs(msg))

  defp build_chat_admin_payload("set_chat_member_tag", msg),
    do: Delivery.build_set_chat_member_tag(chat_admin_attrs(msg))

  defp build_chat_admin_payload("ban_chat_sender_chat", msg),
    do: Delivery.build_ban_chat_sender_chat(chat_admin_attrs(msg))

  defp build_chat_admin_payload("unban_chat_sender_chat", msg),
    do: Delivery.build_unban_chat_sender_chat(chat_admin_attrs(msg))

  defp build_chat_admin_payload("set_chat_permissions", msg),
    do: Delivery.build_set_chat_permissions(chat_admin_attrs(msg))

  defp build_chat_admin_payload("export_chat_invite_link", msg),
    do: Delivery.build_export_chat_invite_link(chat_admin_attrs(msg))

  defp build_chat_admin_payload("create_chat_invite_link", msg),
    do: Delivery.build_create_chat_invite_link(chat_admin_attrs(msg))

  defp build_chat_admin_payload("edit_chat_invite_link", msg),
    do: Delivery.build_edit_chat_invite_link(chat_admin_attrs(msg))

  defp build_chat_admin_payload("create_chat_subscription_invite_link", msg),
    do: Delivery.build_create_chat_subscription_invite_link(chat_admin_attrs(msg))

  defp build_chat_admin_payload("edit_chat_subscription_invite_link", msg),
    do: Delivery.build_edit_chat_subscription_invite_link(chat_admin_attrs(msg))

  defp build_chat_admin_payload("revoke_chat_invite_link", msg),
    do: Delivery.build_revoke_chat_invite_link(chat_admin_attrs(msg))

  defp build_chat_admin_payload("approve_chat_join_request", msg),
    do: Delivery.build_approve_chat_join_request(chat_admin_attrs(msg))

  defp build_chat_admin_payload("decline_chat_join_request", msg),
    do: Delivery.build_decline_chat_join_request(chat_admin_attrs(msg))

  defp build_chat_admin_payload("answer_chat_join_request_query", msg),
    do: Delivery.build_answer_chat_join_request_query(chat_admin_attrs(msg))

  defp build_chat_admin_payload("send_chat_join_request_web_app", msg),
    do: Delivery.build_send_chat_join_request_web_app(chat_admin_attrs(msg))

  defp build_chat_admin_payload("set_chat_photo", msg),
    do: Delivery.build_set_chat_photo(chat_admin_attrs(msg))

  defp build_chat_admin_payload("delete_chat_photo", msg),
    do: Delivery.build_delete_chat_photo(chat_admin_attrs(msg))

  defp build_chat_admin_payload("set_chat_title", msg),
    do: Delivery.build_set_chat_title(chat_admin_attrs(msg))

  defp build_chat_admin_payload("set_chat_description", msg),
    do: Delivery.build_set_chat_description(chat_admin_attrs(msg))

  defp build_chat_admin_payload("pin_chat_message", msg),
    do: Delivery.build_pin_chat_message(chat_admin_attrs(msg))

  defp build_chat_admin_payload("unpin_chat_message", msg),
    do: Delivery.build_unpin_chat_message(chat_admin_attrs(msg))

  defp build_chat_admin_payload("unpin_all_chat_messages", msg),
    do: Delivery.build_unpin_all_chat_messages(chat_admin_attrs(msg))

  defp build_chat_admin_payload("leave_chat", msg),
    do: Delivery.build_leave_chat(chat_admin_attrs(msg))

  defp build_chat_admin_payload("get_chat", msg),
    do: Delivery.build_get_chat(chat_admin_attrs(msg))

  defp build_chat_admin_payload("get_chat_administrators", msg),
    do: Delivery.build_get_chat_administrators(chat_admin_attrs(msg))

  defp build_chat_admin_payload("get_chat_member_count", msg),
    do: Delivery.build_get_chat_member_count(chat_admin_attrs(msg))

  defp build_chat_admin_payload("get_chat_member", msg),
    do: Delivery.build_get_chat_member(chat_admin_attrs(msg))

  defp build_chat_admin_payload("set_chat_sticker_set", msg),
    do: Delivery.build_set_chat_sticker_set(chat_admin_attrs(msg))

  defp build_chat_admin_payload("delete_chat_sticker_set", msg),
    do: Delivery.build_delete_chat_sticker_set(chat_admin_attrs(msg))

  defp build_chat_admin_payload("get_forum_topic_icon_stickers", msg),
    do: Delivery.build_get_forum_topic_icon_stickers(chat_admin_attrs(msg))

  defp build_chat_admin_payload("create_forum_topic", msg),
    do: Delivery.build_create_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("edit_forum_topic", msg),
    do: Delivery.build_edit_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("close_forum_topic", msg),
    do: Delivery.build_close_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("reopen_forum_topic", msg),
    do: Delivery.build_reopen_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("delete_forum_topic", msg),
    do: Delivery.build_delete_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("unpin_all_forum_topic_messages", msg),
    do: Delivery.build_unpin_all_forum_topic_messages(chat_admin_attrs(msg))

  defp build_chat_admin_payload("edit_general_forum_topic", msg),
    do: Delivery.build_edit_general_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("close_general_forum_topic", msg),
    do: Delivery.build_close_general_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("reopen_general_forum_topic", msg),
    do: Delivery.build_reopen_general_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("hide_general_forum_topic", msg),
    do: Delivery.build_hide_general_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("unhide_general_forum_topic", msg),
    do: Delivery.build_unhide_general_forum_topic(chat_admin_attrs(msg))

  defp build_chat_admin_payload("unpin_all_general_forum_topic_messages", msg),
    do: Delivery.build_unpin_all_general_forum_topic_messages(chat_admin_attrs(msg))

  defp chat_admin_attrs(msg) do
    [
      :chat_id,
      :message_id,
      :message_thread_id,
      :user_id,
      :actor_chat_id,
      :sender_chat_id,
      :permissions,
      :until_date,
      :revoke_messages,
      :only_if_banned,
      :use_independent_chat_permissions,
      :is_anonymous,
      :can_manage_chat,
      :can_delete_messages,
      :can_manage_video_chats,
      :can_restrict_members,
      :can_promote_members,
      :can_change_info,
      :can_invite_users,
      :can_post_stories,
      :can_edit_stories,
      :can_delete_stories,
      :can_post_messages,
      :can_edit_messages,
      :can_pin_messages,
      :can_manage_topics,
      :can_manage_direct_messages,
      :custom_title,
      :tag,
      :name,
      :expire_date,
      :member_limit,
      :creates_join_request,
      :invite_link,
      :subscription_period,
      :subscription_price,
      :chat_join_request_query_id,
      :query_id,
      :result,
      :web_app_url,
      :photo,
      :title,
      :description,
      :disable_notification,
      :business_connection_id,
      :return_bots,
      :sticker_set_name,
      :icon_color,
      :icon_custom_emoji_id
    ]
    |> Enum.reduce(%{}, fn key, acc ->
      case Map.get(msg, to_string(key)) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
    |> normalize_chat_join_query_alias()
  end

  defp normalize_chat_join_query_alias(%{query_id: query_id} = attrs) do
    attrs
    |> Map.put_new(:chat_join_request_query_id, query_id)
    |> Map.delete(:query_id)
  end

  defp normalize_chat_join_query_alias(attrs), do: attrs

  defp build_sticker_payload("get_sticker_set", msg),
    do: Delivery.build_get_sticker_set(sticker_attrs(msg))

  defp build_sticker_payload("get_custom_emoji_stickers", msg),
    do: Delivery.build_get_custom_emoji_stickers(sticker_attrs(msg))

  defp build_sticker_payload("upload_sticker_file", msg),
    do: Delivery.build_upload_sticker_file(sticker_attrs(msg))

  defp build_sticker_payload("create_new_sticker_set", msg),
    do: Delivery.build_create_new_sticker_set(sticker_attrs(msg))

  defp build_sticker_payload("add_sticker_to_set", msg),
    do: Delivery.build_add_sticker_to_set(sticker_attrs(msg))

  defp build_sticker_payload("set_sticker_position_in_set", msg),
    do: Delivery.build_set_sticker_position_in_set(sticker_attrs(msg))

  defp build_sticker_payload("delete_sticker_from_set", msg),
    do: Delivery.build_delete_sticker_from_set(sticker_attrs(msg))

  defp build_sticker_payload("replace_sticker_in_set", msg),
    do: Delivery.build_replace_sticker_in_set(sticker_attrs(msg))

  defp build_sticker_payload("set_sticker_emoji_list", msg),
    do: Delivery.build_set_sticker_emoji_list(sticker_attrs(msg))

  defp build_sticker_payload("set_sticker_keywords", msg),
    do: Delivery.build_set_sticker_keywords(sticker_attrs(msg))

  defp build_sticker_payload("set_sticker_mask_position", msg),
    do: Delivery.build_set_sticker_mask_position(sticker_attrs(msg))

  defp build_sticker_payload("set_sticker_set_title", msg),
    do: Delivery.build_set_sticker_set_title(sticker_attrs(msg))

  defp build_sticker_payload("set_sticker_set_thumbnail", msg),
    do: Delivery.build_set_sticker_set_thumbnail(sticker_attrs(msg))

  defp build_sticker_payload("set_custom_emoji_sticker_set_thumbnail", msg),
    do: Delivery.build_set_custom_emoji_sticker_set_thumbnail(sticker_attrs(msg))

  defp build_sticker_payload("delete_sticker_set", msg),
    do: Delivery.build_delete_sticker_set(sticker_attrs(msg))

  defp sticker_attrs(msg) do
    [
      :user_id,
      :name,
      :title,
      :sticker,
      :stickers,
      :sticker_format,
      :format,
      :sticker_type,
      :needs_repainting,
      :custom_emoji_ids,
      :position,
      :old_sticker,
      :emoji_list,
      :keywords,
      :mask_position,
      :thumbnail,
      :custom_emoji_id
    ]
    |> Enum.reduce(%{}, fn key, acc ->
      case Map.get(msg, to_string(key)) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp send_place(from, msg, state, origin, kind, attrs) do
    with {:ok, cid} <-
           resolve_message_target(from, msg, state, state.send_sources),
         {:cont, state} <- prepare_delivery(from, cid, origin, state) do
      base =
        attrs
        |> Map.merge(%{
          conversation_id: cid,
          reply_markup: message_reply_markup(msg),
          disable_notification: Map.get(msg, "disable_notification"),
          protect_content: Map.get(msg, "protect_content")
        })
        |> Map.merge(message_reply_attrs(cid, msg, state))

      case safe_build_payload(fn ->
             case kind do
               :location -> Delivery.build_send_location(base)
               :venue -> Delivery.build_send_venue(base)
               :contact -> Delivery.build_send_contact(base)
             end
           end) do
        {:ok, payload} ->
          state = clear_progress(cid, state) |> throttle()
          result = dispatch_payload(payload, state, nil)

          state =
            state
            |> record_send(cid, payload, result, from)
            |> record_logical_delivery(cid, %{kind => attrs}, result, %{
              origin: origin,
              from: from,
              mark: Map.get(msg, "mark")
            })

          {:ok, stamp_reply(state, cid, origin)}

        {:error, reason} ->
          {:error, reason, state}
      end
    else
      {:suppress, _cid, state} -> {:ok, state}
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
      {:ok, id} ->
        _ = maybe_effect(state, :progress_sent, [cid, :post, %{}])
        {:ok, id, state}

      :error ->
        {:error, state}
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

    _ = maybe_effect(state, :progress_sent, [cid, :edit, %{}])
    :ok
  end

  defp send_slot_reply(from, cid, content, state) do
    cond do
      not trusted_slot_reply_content?(from, content) ->
        {:error, :invalid_slot_reply, state}

      Map.get(state.owed, cid, 0) == 0 and answered_recently?(cid, state) ->
        _ = maybe_effect(state, :reply_suppressed, [cid, %{origin: :slot_reply, from: from}])
        {:ok, hold_reply(from, cid, content, state)}

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
    method = Map.get(payload, :_method, :send_message)
    telegram_payload = Map.delete(payload, :_method)

    cond do
      state.dry_run ->
        {:ok, %{"message_id" => System.unique_integer([:positive]), "dry_run" => true}}

      method == :send_photo ->
        case Client.send_photo(state.client, telegram_payload, client_opts(state)) do
          {:ok, _} = ok ->
            ok

          {:error, reason} ->
            # The downgrade used to be SILENT — an imageless delivery left zero
            # trace of Telegram's rejection (undiagnosable in prod, 2026-07-09).
            # Warn here and fire the optional photo_fallback host hook (log +
            # metrics live host-side; absent hook = the old behavior).
            Logger.warning(
              "sender: send_photo failed, falling back to text: chat=#{inspect(Map.get(telegram_payload, :chat_id))} reason=#{inspect(reason)}"
            )

            if Adapter.exported?(state.delivery_effects, :photo_fallback, 2),
              do: _ = Adapter.call(state.delivery_effects, :photo_fallback, [telegram_payload, reason])

            telegram_payload
            |> Map.delete(:photo)
            |> Map.delete(:caption)
            |> Map.put(:text, Map.get(payload, :caption, ""))
            |> send_message_with_fallback(state, fallback_text)
        end

      method in [
        :answer_callback_query,
        :answer_web_app_query,
        :answer_inline_query,
        :answer_guest_query,
        :save_prepared_inline_message,
        :save_prepared_keyboard_button,
        :get_user_chat_boosts,
        :get_business_connection,
        :get_managed_bot_token,
        :replace_managed_bot_token,
        :get_managed_bot_access_settings,
        :set_managed_bot_access_settings,
        :get_user_personal_chat_messages,
        :set_my_commands,
        :delete_my_commands,
        :get_my_commands,
        :set_my_name,
        :get_my_name,
        :set_my_description,
        :get_my_description,
        :set_my_short_description,
        :get_my_short_description,
        :set_my_profile_photo,
        :remove_my_profile_photo,
        :set_chat_menu_button,
        :get_chat_menu_button,
        :set_my_default_administrator_rights,
        :get_my_default_administrator_rights,
        :create_invoice_link,
        :answer_shipping_query,
        :answer_pre_checkout_query,
        :get_my_star_balance,
        :get_star_transactions,
        :get_available_gifts,
        :send_gift,
        :gift_premium_subscription,
        :get_business_account_star_balance,
        :transfer_business_account_stars,
        :get_business_account_gifts,
        :get_user_gifts,
        :get_chat_gifts,
        :convert_gift_to_stars,
        :upgrade_gift,
        :transfer_gift,
        :verify_user,
        :verify_chat,
        :remove_user_verification,
        :remove_chat_verification,
        :read_business_message,
        :delete_business_messages,
        :set_business_account_name,
        :set_business_account_username,
        :set_business_account_bio,
        :set_business_account_profile_photo,
        :remove_business_account_profile_photo,
        :set_business_account_gift_settings,
        :approve_suggested_post,
        :decline_suggested_post,
        :set_passport_data_errors,
        :set_game_score,
        :get_game_high_scores,
        :refund_star_payment,
        :edit_user_star_subscription,
        :post_story,
        :repost_story,
        :edit_story,
        :delete_story,
        :send_message_draft,
        :send_video,
        :send_animation,
        :send_audio,
        :send_voice,
        :send_video_note,
        :send_document,
        :send_sticker,
        :send_live_photo,
        :send_media_group,
        :send_paid_media,
        :send_poll,
        :send_checklist,
        :send_invoice,
        :send_game,
        :send_location,
        :send_venue,
        :send_contact,
        :send_dice,
        :send_chat_action,
        :set_message_reaction,
        :forward_message,
        :forward_messages,
        :copy_message,
        :copy_messages,
        :delete_message,
        :delete_messages,
        :delete_message_reaction,
        :delete_all_message_reactions,
        :send_rich_message,
        :send_rich_message_draft,
        :edit_message_caption,
        :edit_message_media,
        :edit_message_live_location,
        :edit_message_checklist,
        :stop_message_live_location,
        :edit_message_reply_markup,
        :stop_poll,
        :edit_message_text
      ] or method in @utility_methods or method in @chat_admin_methods or
          method in @sticker_methods ->
        dispatch_client_method(method, telegram_payload, state, fallback_text)

      true ->
        send_message_with_fallback(telegram_payload, state, fallback_text)
    end
  end

  defp dispatch_client_method(:send_video, payload, state, _fallback),
    do: Client.send_video(state.client, payload, client_opts(state))

  defp dispatch_client_method(:answer_callback_query, payload, state, _fallback),
    do: Client.answer_callback_query(state.client, payload, client_opts(state))

  defp dispatch_client_method(:answer_web_app_query, payload, state, _fallback),
    do: Client.answer_web_app_query(state.client, payload, client_opts(state))

  defp dispatch_client_method(:answer_inline_query, payload, state, _fallback),
    do: Client.answer_inline_query(state.client, payload, client_opts(state))

  defp dispatch_client_method(:answer_guest_query, payload, state, _fallback),
    do: Client.answer_guest_query(state.client, payload, client_opts(state))

  defp dispatch_client_method(:save_prepared_inline_message, payload, state, _fallback),
    do: Client.save_prepared_inline_message(state.client, payload, client_opts(state))

  defp dispatch_client_method(:save_prepared_keyboard_button, payload, state, _fallback),
    do: Client.save_prepared_keyboard_button(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_user_chat_boosts, payload, state, _fallback),
    do: Client.get_user_chat_boosts(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_business_connection, payload, state, _fallback),
    do: Client.get_business_connection(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_managed_bot_token, payload, state, _fallback),
    do: Client.get_managed_bot_token(state.client, payload, client_opts(state))

  defp dispatch_client_method(:replace_managed_bot_token, payload, state, _fallback),
    do: Client.replace_managed_bot_token(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_managed_bot_access_settings, payload, state, _fallback),
    do: Client.get_managed_bot_access_settings(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_managed_bot_access_settings, payload, state, _fallback),
    do: Client.set_managed_bot_access_settings(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_user_personal_chat_messages, payload, state, _fallback),
    do: Client.get_user_personal_chat_messages(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_my_commands, payload, state, _fallback),
    do: Client.set_my_commands(state.client, payload, client_opts(state))

  defp dispatch_client_method(:delete_my_commands, payload, state, _fallback),
    do: Client.delete_my_commands(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_my_commands, payload, state, _fallback),
    do: Client.get_my_commands(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_my_name, payload, state, _fallback),
    do: Client.set_my_name(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_my_name, payload, state, _fallback),
    do: Client.get_my_name(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_my_description, payload, state, _fallback),
    do: Client.set_my_description(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_my_description, payload, state, _fallback),
    do: Client.get_my_description(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_my_short_description, payload, state, _fallback),
    do: Client.set_my_short_description(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_my_short_description, payload, state, _fallback),
    do: Client.get_my_short_description(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_my_profile_photo, payload, state, _fallback),
    do: Client.set_my_profile_photo(state.client, payload, client_opts(state))

  defp dispatch_client_method(:remove_my_profile_photo, _payload, state, _fallback),
    do: Client.remove_my_profile_photo(state.client, %{}, client_opts(state))

  defp dispatch_client_method(:set_chat_menu_button, payload, state, _fallback),
    do: Client.set_chat_menu_button(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_chat_menu_button, payload, state, _fallback),
    do: Client.get_chat_menu_button(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_my_default_administrator_rights, payload, state, _fallback),
    do: Client.set_my_default_administrator_rights(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_my_default_administrator_rights, payload, state, _fallback),
    do: Client.get_my_default_administrator_rights(state.client, payload, client_opts(state))

  defp dispatch_client_method(:create_invoice_link, payload, state, _fallback),
    do: Client.create_invoice_link(state.client, payload, client_opts(state))

  defp dispatch_client_method(:answer_shipping_query, payload, state, _fallback),
    do: Client.answer_shipping_query(state.client, payload, client_opts(state))

  defp dispatch_client_method(:answer_pre_checkout_query, payload, state, _fallback),
    do: Client.answer_pre_checkout_query(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_my_star_balance, _payload, state, _fallback),
    do: Client.get_my_star_balance(state.client, client_opts(state))

  defp dispatch_client_method(:get_star_transactions, payload, state, _fallback),
    do: Client.get_star_transactions(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_available_gifts, _payload, state, _fallback),
    do: Client.get_available_gifts(state.client, client_opts(state))

  defp dispatch_client_method(:send_gift, payload, state, _fallback),
    do: Client.send_gift(state.client, payload, client_opts(state))

  defp dispatch_client_method(:gift_premium_subscription, payload, state, _fallback),
    do: Client.gift_premium_subscription(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_business_account_star_balance, payload, state, _fallback),
    do: Client.get_business_account_star_balance(state.client, payload, client_opts(state))

  defp dispatch_client_method(:transfer_business_account_stars, payload, state, _fallback),
    do: Client.transfer_business_account_stars(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_business_account_gifts, payload, state, _fallback),
    do: Client.get_business_account_gifts(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_user_gifts, payload, state, _fallback),
    do: Client.get_user_gifts(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_chat_gifts, payload, state, _fallback),
    do: Client.get_chat_gifts(state.client, payload, client_opts(state))

  defp dispatch_client_method(:convert_gift_to_stars, payload, state, _fallback),
    do: Client.convert_gift_to_stars(state.client, payload, client_opts(state))

  defp dispatch_client_method(:upgrade_gift, payload, state, _fallback),
    do: Client.upgrade_gift(state.client, payload, client_opts(state))

  defp dispatch_client_method(:transfer_gift, payload, state, _fallback),
    do: Client.transfer_gift(state.client, payload, client_opts(state))

  defp dispatch_client_method(:verify_user, payload, state, _fallback),
    do: Client.verify_user(state.client, payload, client_opts(state))

  defp dispatch_client_method(:verify_chat, payload, state, _fallback),
    do: Client.verify_chat(state.client, payload, client_opts(state))

  defp dispatch_client_method(:remove_user_verification, payload, state, _fallback),
    do: Client.remove_user_verification(state.client, payload, client_opts(state))

  defp dispatch_client_method(:remove_chat_verification, payload, state, _fallback),
    do: Client.remove_chat_verification(state.client, payload, client_opts(state))

  defp dispatch_client_method(:read_business_message, payload, state, _fallback),
    do: Client.read_business_message(state.client, payload, client_opts(state))

  defp dispatch_client_method(:delete_business_messages, payload, state, _fallback),
    do: Client.delete_business_messages(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_business_account_name, payload, state, _fallback),
    do: Client.set_business_account_name(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_business_account_username, payload, state, _fallback),
    do: Client.set_business_account_username(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_business_account_bio, payload, state, _fallback),
    do: Client.set_business_account_bio(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_business_account_profile_photo, payload, state, _fallback),
    do: Client.set_business_account_profile_photo(state.client, payload, client_opts(state))

  defp dispatch_client_method(:remove_business_account_profile_photo, payload, state, _fallback),
    do: Client.remove_business_account_profile_photo(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_business_account_gift_settings, payload, state, _fallback),
    do: Client.set_business_account_gift_settings(state.client, payload, client_opts(state))

  defp dispatch_client_method(:approve_suggested_post, payload, state, _fallback),
    do: Client.approve_suggested_post(state.client, payload, client_opts(state))

  defp dispatch_client_method(:decline_suggested_post, payload, state, _fallback),
    do: Client.decline_suggested_post(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_passport_data_errors, payload, state, _fallback),
    do: Client.set_passport_data_errors(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_game_score, payload, state, _fallback),
    do: Client.set_game_score(state.client, payload, client_opts(state))

  defp dispatch_client_method(:get_game_high_scores, payload, state, _fallback),
    do: Client.get_game_high_scores(state.client, payload, client_opts(state))

  defp dispatch_client_method(:refund_star_payment, payload, state, _fallback),
    do: Client.refund_star_payment(state.client, payload, client_opts(state))

  defp dispatch_client_method(:edit_user_star_subscription, payload, state, _fallback),
    do: Client.edit_user_star_subscription(state.client, payload, client_opts(state))

  defp dispatch_client_method(:post_story, payload, state, _fallback),
    do: Client.post_story(state.client, payload, client_opts(state))

  defp dispatch_client_method(:repost_story, payload, state, _fallback),
    do: Client.repost_story(state.client, payload, client_opts(state))

  defp dispatch_client_method(:edit_story, payload, state, _fallback),
    do: Client.edit_story(state.client, payload, client_opts(state))

  defp dispatch_client_method(:delete_story, payload, state, _fallback),
    do: Client.delete_story(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_message_draft, payload, state, _fallback),
    do: Client.send_message_draft(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_animation, payload, state, _fallback),
    do: Client.send_animation(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_audio, payload, state, _fallback),
    do: Client.send_audio(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_voice, payload, state, _fallback),
    do: Client.send_voice(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_video_note, payload, state, _fallback),
    do: Client.send_video_note(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_document, payload, state, _fallback),
    do: Client.send_document(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_sticker, payload, state, _fallback),
    do: Client.send_sticker(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_live_photo, payload, state, _fallback),
    do: Client.send_live_photo(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_media_group, payload, state, _fallback),
    do: Client.send_media_group(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_paid_media, payload, state, _fallback),
    do: Client.send_paid_media(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_poll, payload, state, _fallback),
    do: Client.send_poll(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_checklist, payload, state, _fallback),
    do: Client.send_checklist(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_invoice, payload, state, _fallback),
    do: Client.send_invoice(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_game, payload, state, _fallback),
    do: Client.send_game(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_location, payload, state, _fallback),
    do: Client.send_location(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_venue, payload, state, _fallback),
    do: Client.send_venue(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_contact, payload, state, _fallback),
    do: Client.send_contact(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_dice, payload, state, _fallback),
    do: Client.send_dice(state.client, payload, client_opts(state))

  defp dispatch_client_method(:send_chat_action, payload, state, _fallback),
    do: Client.send_chat_action(state.client, payload, client_opts(state))

  defp dispatch_client_method(:set_message_reaction, payload, state, _fallback),
    do: Client.set_message_reaction(state.client, payload, client_opts(state))

  defp dispatch_client_method(:forward_message, payload, state, _fallback),
    do: Client.forward_message(state.client, payload, client_opts(state))

  defp dispatch_client_method(:forward_messages, payload, state, _fallback),
    do: Client.forward_messages(state.client, payload, client_opts(state))

  defp dispatch_client_method(:copy_message, payload, state, _fallback),
    do: Client.copy_message(state.client, payload, client_opts(state))

  defp dispatch_client_method(:copy_messages, payload, state, _fallback),
    do: Client.copy_messages(state.client, payload, client_opts(state))

  defp dispatch_client_method(:delete_message, payload, state, _fallback),
    do: Client.delete_message(state.client, payload, client_opts(state))

  defp dispatch_client_method(:delete_messages, payload, state, _fallback),
    do: Client.delete_messages(state.client, payload, client_opts(state))

  defp dispatch_client_method(:logout, _payload, state, _fallback),
    do: Client.logout(state.client, client_opts(state))

  defp dispatch_client_method(:close, _payload, state, _fallback),
    do: Client.close(state.client, client_opts(state))

  defp dispatch_client_method(method, payload, state, _fallback)
       when method in @utility_methods do
    apply(Client, method, [state.client, payload, client_opts(state)])
  end

  defp dispatch_client_method(:get_forum_topic_icon_stickers, _payload, state, _fallback),
    do: Client.get_forum_topic_icon_stickers(state.client, client_opts(state))

  defp dispatch_client_method(method, payload, state, _fallback)
       when method in @chat_admin_methods do
    apply(Client, method, [state.client, payload, client_opts(state)])
  end

  defp dispatch_client_method(method, payload, state, _fallback)
       when method in @sticker_methods do
    apply(Client, method, [state.client, payload, client_opts(state)])
  end

  defp dispatch_client_method(:send_rich_message, payload, state, fallback_text) do
    case Client.send_rich_message(state.client, payload, client_opts(state)) do
      {:error, {:parse_error, _}} -> rich_plain_fallback(payload, state, fallback_text)
      other -> other
    end
  end

  defp dispatch_client_method(:send_rich_message_draft, payload, state, _fallback),
    do: Client.send_rich_message_draft(state.client, payload, client_opts(state))

  defp dispatch_client_method(:edit_message_text, payload, state, fallback_text) do
    case Client.edit_message_text(state.client, payload, client_opts(state)) do
      {:error, {:parse_error, _}} -> rich_edit_plain_fallback(payload, state, fallback_text)
      other -> other
    end
  end

  defp dispatch_client_method(:edit_message_caption, payload, state, _fallback),
    do: Client.edit_message_caption(state.client, payload, client_opts(state))

  defp dispatch_client_method(:edit_message_media, payload, state, _fallback),
    do: Client.edit_message_media(state.client, payload, client_opts(state))

  defp dispatch_client_method(:edit_message_live_location, payload, state, _fallback),
    do: Client.edit_message_live_location(state.client, payload, client_opts(state))

  defp dispatch_client_method(:edit_message_checklist, payload, state, _fallback),
    do: Client.edit_message_checklist(state.client, payload, client_opts(state))

  defp dispatch_client_method(:stop_message_live_location, payload, state, _fallback),
    do: Client.stop_message_live_location(state.client, payload, client_opts(state))

  defp dispatch_client_method(:edit_message_reply_markup, payload, state, _fallback),
    do: Client.edit_message_reply_markup(state.client, payload, client_opts(state))

  defp dispatch_client_method(:stop_poll, payload, state, _fallback),
    do: Client.stop_poll(state.client, payload, client_opts(state))

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

  defp rich_plain_fallback(payload, state, fallback_text) do
    text = String.trim(to_string(fallback_text))

    if text == "" do
      {:error, {:parse_error, "rich message parse failed and no fallback_text was provided"}}
    else
      payload
      |> Map.delete(:rich_message)
      |> Map.put(:text, Genswarms.Telegram.Format.plain(text))
      |> then(&Client.send_message(state.client, &1, client_opts(state)))
    end
  end

  defp rich_edit_plain_fallback(payload, state, fallback_text) do
    text = String.trim(to_string(fallback_text))

    if text == "" do
      {:error, {:parse_error, "rich edit parse failed and no fallback_text was provided"}}
    else
      payload
      |> Map.delete(:rich_message)
      |> Map.put(:text, Genswarms.Telegram.Format.plain(text))
      |> then(&Client.edit_message_text(state.client, &1, client_opts(state)))
    end
  end

  defp safe_build_payload(fun) do
    {:ok, fun.()}
  rescue
    error in ArgumentError -> {:error, {:invalid_payload, Exception.message(error)}}
  end

  defp record_send(state, cid, payload, result, from \\ nil) do
    entry = %{
      conversation_id: cid,
      payload: payload,
      result: result,
      at: System.system_time(:second)
    }

    state
    |> Map.put(:sent, Enum.take([entry | state.sent], @audit_max))
    |> record_own_message(from, cid, result)
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

  # Optional observability hooks (reply_suppressed / progress_sent /
  # reply_unresolvable) — paths with no logical delivery, so after_delivery
  # never sees them. No-op unless the host effects module exports the callback.
  defp maybe_effect(state, fun, args) do
    if Adapter.exported?(state.delivery_effects, fun, length(args)) do
      _ = Adapter.call(state.delivery_effects, fun, args)
    end

    :ok
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

  defp validate_action_table! do
    case Enum.reject(interface().actions, &(Actions.classify(&1) != :unknown)) do
      [] ->
        :ok

      unknown ->
        raise ArgumentError,
              "unclassified Telegram sender actions: #{Enum.map_join(unknown, ", ", &to_string/1)}"
    end
  end

  defp normalize_agent_surface(:standard), do: MapSet.new(agent_groups())
  defp normalize_agent_surface(:none), do: MapSet.new()
  defp normalize_agent_surface(:cards_only), do: MapSet.new([:core, :cards, :discovery])

  defp normalize_agent_surface(groups) when is_list(groups) do
    allowed = MapSet.new(agent_groups())

    groups
    |> Enum.map(&normalize_group/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&MapSet.member?(allowed, &1))
    |> MapSet.new()
  end

  defp normalize_agent_surface(_surface), do: normalize_agent_surface(:standard)

  defp normalize_action_grants(grants) when is_map(grants) do
    Enum.reduce(grants, %{}, fn {group, sources}, acc ->
      case normalize_group(group) do
        nil -> acc
        group -> Map.put(acc, group, List.wrap(sources))
      end
    end)
  end

  defp normalize_action_grants(_grants), do: %{}

  defp normalize_group(group) when is_atom(group) do
    if group in Actions.groups(), do: group
  end

  defp normalize_group(group) when is_binary(group) do
    Enum.find(Actions.groups(), &(Atom.to_string(&1) == group))
  end

  defp normalize_group(_group), do: nil

  defp agent_groups do
    Enum.filter(Actions.groups(), fn group ->
      Actions.actions_in(group)
      |> Enum.any?(&(Actions.classify(&1) == {:agent, group}))
    end)
  end

  defp agent_group_enabled?(_surface, :discovery), do: true
  defp agent_group_enabled?(surface, group), do: MapSet.member?(surface, group)

  defp operator_granted?(from, group, state) do
    from in Map.get(state.action_grants, group, [])
  end

  defp capabilities_for(from, state) do
    caller = caller_scope(from, state)

    from
    |> capability_group_actions(state, caller)
    |> Capabilities.for_action_groups()
  end

  defp capability_group_actions(from, state, %{kind: :bound_slot}) do
    state.agent_surface
    |> MapSet.put(:discovery)
    |> Map.new(&{&1, Actions.actions_in(&1)})
    |> merge_capability_groups(operator_capability_groups(from, state))
  end

  defp capability_group_actions(from, state, %{kind: kind})
       when kind in [:named_object, :internal] do
    named_agent_capability_groups(from, state)
    |> merge_capability_groups(operator_capability_groups(from, state))
  end

  defp capability_group_actions(_from, _state, _caller), do: %{}

  defp named_agent_capability_groups(from, state) do
    state.agent_surface
    |> MapSet.put(:discovery)
    |> Enum.reduce(%{}, fn group, acc ->
      actions =
        group
        |> Actions.actions_in()
        |> Enum.filter(&named_agent_capability_action?(&1, group, from, state))

      if actions == [], do: acc, else: Map.put(acc, group, actions)
    end)
  end

  defp named_agent_capability_action?(_action, :discovery, _from, _state), do: true

  defp named_agent_capability_action?("progress", _group, from, state) do
    from in state.progress_sources
  end

  defp named_agent_capability_action?(action, group, from, state) do
    cond do
      targetless_agent_action?(action, group) -> true
      delete_action?(action) -> operator_granted?(from, :message_ops, state)
      true -> from in state.send_sources
    end
  end

  defp operator_capability_groups(from, state) do
    state.action_grants
    |> Enum.filter(fn {_group, sources} -> from in sources end)
    |> Map.new(fn {group, _sources} -> {group, Actions.actions_in(group)} end)
  end

  defp merge_capability_groups(left, right) do
    Map.merge(left, right, fn _group, left_actions, right_actions ->
      Enum.uniq(left_actions ++ right_actions)
    end)
  end

  defp caller_scope(from, state) do
    from_s = to_string(from)

    cond do
      from == :internal ->
        %{kind: :internal}

      cid = Map.get(state.slots, from_s) ->
        %{kind: :bound_slot, slot: from_s, cid: cid}

      agent_like?(from_s, state) ->
        %{kind: :unbound_slot, slot: from_s}

      true ->
        %{kind: :named_object}
    end
  end

  defp delete_action?(action), do: action in ["delete_message", "delete_messages"]

  defp targetless_agent_action?(action, group) do
    group == :discovery or action == "validate_card"
  end

  defp authorize_own_message(action, msg, state, %{slot: slot, cid: cid}) do
    case own_message_ids(action, msg) do
      {:ok, ids} ->
        if Enum.all?(ids, &own_message?(state, slot, cid, &1)) do
          :ok
        else
          {:error, :unauthorized_message}
        end

      :skip ->
        {:error, :unauthorized_message}
    end
  end

  defp authorize_own_message(_action, _msg, _state, _caller), do: {:error, :unauthorized_message}

  defp own_message_ids("delete_messages", msg) do
    msg
    |> Map.get("message_ids")
    |> parse_message_ids()
  end

  defp own_message_ids(_action, msg) do
    case parse_message_id(Map.get(msg, "message_id")) do
      {:ok, id} -> {:ok, [id]}
      :error -> :skip
    end
  end

  defp parse_message_ids(ids) when is_list(ids) do
    parsed =
      ids
      |> Enum.map(&parse_message_id/1)
      |> Enum.flat_map(fn
        {:ok, id} -> [id]
        :error -> []
      end)

    if parsed == [], do: :skip, else: {:ok, parsed}
  end

  defp parse_message_ids(_ids), do: :skip

  defp parse_message_id(id) when is_integer(id), do: {:ok, id}

  defp parse_message_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> {:ok, int}
      _other -> :error
    end
  end

  defp parse_message_id(_id), do: :error

  defp own_message?(state, slot, cid, message_id) do
    {cid, message_id} in Map.get(state.own_messages, slot, [])
  end

  defp record_own_message(state, from, cid, result) do
    with from when not is_nil(from) <- from,
         %{kind: :bound_slot, slot: slot} <- caller_scope(from, state),
         {:ok, message_id} <- message_id_from_result(result),
         true <- state.own_message_window > 0 do
      entries =
        state.own_messages
        |> Map.get(slot, [])
        |> Enum.reject(&(&1 == {cid, message_id}))
        |> then(&[{cid, message_id} | &1])
        |> Enum.take(state.own_message_window)

      %{state | own_messages: Map.put(state.own_messages, slot, entries)}
    else
      _other -> state
    end
  end

  defp resolve_message_target(from, msg, state, direct_sources) do
    case Map.get(msg, @gate_key) do
      %{class: :operator} ->
        case Map.get(msg, "conversation_id") do
          cid when is_binary(cid) and cid != "" -> direct_target(:internal, cid, [:internal])
          _other -> {:error, :invalid_conversation_id}
        end

      _gate ->
        resolve_target(from, Map.get(msg, "conversation_id"), state, direct_sources)
    end
  end

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

  # Re-seed slot→conversation claims from the host at init (2026-07-07): the
  # claims are process-local, so any sender restart used to drop in-flight
  # agent replies as "no target" until the conversation's next inbound
  # re-bound it. TOTAL on purpose — a host bug here must degrade to the old
  # cold-start behavior, never block the sender from booting.
  defp restore_bindings(effects) do
    if Adapter.exported?(effects, :current_bindings, 0) do
      case Adapter.call(effects, :current_bindings, []) do
        bindings when is_list(bindings) ->
          for b when is_map(b) <- bindings,
              slot = Map.get(b, :slot) || Map.get(b, "slot"),
              cid = Map.get(b, :conversation_id) || Map.get(b, "conversation_id"),
              (is_binary(slot) or is_atom(slot)) and valid_cid?(cid),
              into: %{} do
            {to_string(slot), cid}
          end

        _other ->
          %{}
      end
    else
      %{}
    end
  rescue
    _ -> %{}
  end

  defp agent_like?(from, state), do: String.starts_with?(from, state.slot_prefix <> "_")

  defp prepare_delivery(from, cid, :reply, state) do
    if agent_slot?(from, state) and Map.get(state.owed, cid, 0) == 0 and
         answered_recently?(cid, state) do
      _ = maybe_effect(state, :reply_suppressed, [cid, %{origin: :reply, from: from}])
      # the resolved cid travels with :suppress — the caller's `with` else
      # can't see the chain's bindings, and the hold needs the target
      {:suppress, cid, state}
    else
      {:cont, reply_typing(cid, state)}
    end
  end

  defp prepare_delivery(_from, _cid, _origin, state), do: {:cont, state}

  defp stamp_reply(state, cid, :reply),
    do: %{state | last_reply_ms: Map.put(state.last_reply_ms, cid, monotonic_ms())}

  defp stamp_reply(state, _cid, _origin), do: state

  defp agent_slot?(from, state), do: Map.has_key?(state.slots, to_string(from))

  # ── coalesce-instead-of-swallow (2026-07-07) ────────────────────────────────
  # A legit multi-part answer used to die at the gate above: part 1 consumed
  # `owed` and armed the window, part 2 — often the substance ("am I
  # whitelisted?" answers in prod) — was dropped. Held texts flush as ONE real
  # message when the window expires (edits don't notify on Telegram, so
  # append-by-edit would deliver the answer silently). Exact replays of the
  # just-delivered text — the original spam case — still die.
  defp hold_reply(from, cid, text, state) do
    text = String.trim(to_string(text))
    cur = Map.get(state.held, cid)
    held_len = if cur, do: cur.texts |> Enum.map(&String.length/1) |> Enum.sum(), else: 0

    cond do
      text == "" -> state
      sig(text) == Map.get(state.last_reply_sig, cid) -> state
      cur != nil and text in cur.texts -> state
      cur == nil and map_size(state.held) >= @held_cids_max -> state
      cur != nil and length(cur.texts) >= @held_max_texts -> state
      held_len + String.length(text) > @held_max_chars -> state
      true ->
        state = if cur == nil, do: schedule_held_flush(cid, state), else: state

        held =
          Map.update(state.held, cid, %{texts: [text], from: from}, fn h ->
            %{h | texts: h.texts ++ [text], from: from}
          end)

        %{state | held: held}
    end
  end

  # fire when the window expires; the margin absorbs monotonic/timer jitter so
  # the flush never lands answered_recently? still true
  defp schedule_held_flush(cid, state) do
    elapsed =
      case Map.get(state.last_reply_ms, cid) do
        nil -> @spam_window_ms
        t -> monotonic_ms() - t
      end

    Process.send_after(self(), {:flush_held, cid}, max(@spam_window_ms - elapsed, 0) + 250)
    state
  end

  # Deliberately BYPASSES prepare_delivery: the flush is the gate's own output.
  # Stamping last_reply re-arms the window, so a relentlessly chatty agent
  # converges to one message per window — a rate limit, not censorship.
  defp flush_held(cid, state) do
    case Map.pop(state.held, cid) do
      {nil, _held} ->
        state

      {%{texts: texts, from: from}, held} ->
        state = %{state | held: held}
        text = Enum.join(texts, "\n\n")

        text =
          Adapter.call(state.delivery_effects, :redact_outbound, [
            text,
            %{conversation_id: cid, origin: :reply, from: from}
          ])

        if String.trim(to_string(text)) == "" do
          state
        else
          state = clear_progress(cid, state)

          # do_send_text records chunk failures itself and returns {:ok, state}
          # today — but this runs on a handle_info timer, where a non-ok return
          # (any future error shape) would MatchError and kill the sender: dead
          # slot claims, wiped mailbox (the 2026-07-07 crash-loop signature).
          # A failed flush costs one coalesced tail, never the sender.
          case do_send_text(cid, text, %{}, state, %{origin: :reply, from: from, coalesced: true}) do
            {:ok, state} -> state |> stamp_reply(cid, :reply) |> stamp_sig(cid, text, :reply)
            {:error, _reason, state} -> state
            _other -> state
          end
        end
    end
  end

  defp sig(text), do: :erlang.phash2(text |> to_string() |> String.trim())

  defp stamp_sig(state, cid, text, origin) when origin in [:reply, :slot_reply] do
    sigs = if map_size(state.last_reply_sig) > 10_000, do: %{}, else: state.last_reply_sig
    %{state | last_reply_sig: Map.put(sigs, cid, sig(text))}
  end

  defp stamp_sig(state, _cid, _text, _origin), do: state


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

  defp card_buttons(%{"card" => card} = msg) when is_map(card) do
    Map.get(msg, "buttons") || Map.get(card, "buttons") || Map.get(card, :buttons)
  end

  defp card_buttons(msg), do: Map.get(msg, "buttons")

  defp message_reply_attrs(cid, msg, state) do
    cid
    |> validate_reply_tag(Map.get(msg, "reply_to_message_id"), state)
    |> reply_attrs(msg)
  end

  defp reply_attrs(reply_to_message_id, msg) do
    %{
      reply_to_message_id: reply_to_message_id,
      quote: Map.get(msg, "quote"),
      quote_position: Map.get(msg, "quote_position"),
      quote_parse_mode: Map.get(msg, "quote_parse_mode")
    }
  end

  defp message_reply_markup(msg) do
    Buttons.normalize_reply_markup(Map.get(msg, "reply_markup")) ||
      Buttons.normalize(Map.get(msg, "buttons"))
  end

  defp inline_message_reply_markup(msg) do
    case Buttons.normalize(Map.get(msg, "buttons")) do
      nil ->
        case Buttons.normalize_reply_markup(Map.get(msg, "reply_markup")) do
          %{inline_keyboard: _rows} = markup -> markup
          _ -> nil
        end

      buttons ->
        buttons
    end
  end

  defp message_id_from_result({:ok, %{"message_id" => id}}) when is_integer(id), do: {:ok, id}
  defp message_id_from_result({:ok, %{message_id: id}}) when is_integer(id), do: {:ok, id}
  defp message_id_from_result(_), do: :error

  defp monotonic_ms, do: System.monotonic_time(:millisecond)

  defp decode(message) when is_binary(message), do: Jason.decode(message)
  defp decode(message) when is_map(message), do: {:ok, message}

  defp truthy?(value), do: value in [true, "true", 1, "1"]
end

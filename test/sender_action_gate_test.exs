defmodule Genswarms.Telegram.SenderActionGateTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Actions
  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.Sender

  @bound_slot "telegram_agent_0"
  @bound_cid "tg:1:0"
  @payload_cid "tg:999:0"
  @operator_representatives [
    chat_admin: "ban_chat_member",
    message_ops: "copy_message",
    payments: "create_invoice_link",
    gifts: "get_available_gifts",
    business: "get_business_connection",
    stories: "delete_story",
    stickers_mgmt: "get_sticker_set",
    bot_profile: "get_my_commands",
    managed_bots: "get_managed_bot_token",
    inline: "answer_callback",
    verification: "verify_user",
    passport: "set_passport_data_errors",
    games: "get_game_high_scores",
    utility: "get_file",
    infra: "send_chat_action"
  ]

  @agent_representatives [
    core: "send",
    cards: "send_card",
    discovery: "capabilities",
    media: "send_location",
    own_messages: "edit_message",
    reactions: "set_reaction"
  ]

  test "every sender interface action is classified by the action table" do
    unknown =
      Sender.interface().actions
      |> Enum.reject(&(Actions.classify(&1) != :unknown))

    assert unknown == []
  end

  test "operator groups are denied by default for bound, named, and unbound callers" do
    for {group, action} <- @operator_representatives do
      assert Actions.classify(action) == {:operator, group}

      assert_gate_denied(action, bound_state(), @bound_slot, ":unauthorized_action")
      assert_gate_denied(action, fresh_state(), :worker, ":unauthorized_action")
      assert_gate_denied(action, fresh_state(), "telegram_agent_missing", ":unbound_slot")
    end
  end

  test "named_surface opens extra agent groups to trusted named objects, never to slots" do
    # Without the knob the minimal surface denies cards for everyone.
    denied = fresh_state(agent_surface: [:core, :own_messages], send_sources: [:worker])
    assert_gate_denied("send_card", denied, :worker, ":unauthorized_action")

    {fake, state} =
      fresh_state(
        agent_surface: [:core, :own_messages],
        named_surface: [:cards],
        send_sources: [:worker]
      )

    {:noreply, _state} = Sender.handle_message(:worker, payload_for("send_card"), state)
    assert Enum.any?(Fake.calls(fake), &(&1.method == :send_rich_message))

    # A bound slot does NOT inherit the named surface.
    bound = bound_state(agent_surface: [:core, :own_messages], named_surface: [:cards])
    assert_gate_denied("send_card", bound, @bound_slot, ":unauthorized_action")

    # Default stays exactly the pre-knob behavior.
    default_denied = fresh_state(agent_surface: [:core, :own_messages], send_sources: [:worker2])
    assert_gate_denied("send_card", default_denied, :worker2, ":unauthorized_action")

    # Capabilities stay gate-exact for the widened named caller.
    {_fake, cap_state} =
      fresh_state(
        agent_surface: [:core, :own_messages],
        named_surface: [:cards],
        send_sources: [:worker]
      )

    {:reply, body, _state} =
      Sender.handle_message(:worker, %{"action" => "capabilities"}, cap_state)

    listed = listed_capability_actions(Jason.decode!(body)["capabilities"])
    assert MapSet.member?(listed, "send_card")
  end

  test "bound slots can use each agent group only in their bound conversation" do
    for {group, action} <- @agent_representatives do
      assert Actions.classify(action) == {:agent, group}

      {fake, state} =
        case group do
          :own_messages -> state_with_own_message()
          _group -> bound_state()
        end

      result =
        Sender.handle_message(@bound_slot, payload_for(action), state)

      assert_allowed(result)
      assert_agent_call_scoped(fake, group)
    end
  end

  test "bound slots can edit and delete only recent messages they sent" do
    {_fake, state} = state_with_own_message(own_message_window: 1)

    {:noreply, state} =
      Sender.handle_message(
        @bound_slot,
        payload_for("edit_message", %{"message_id" => 1, "text" => "allowed edit"}),
        state
      )

    {:noreply, state} =
      Sender.handle_message(
        @bound_slot,
        payload_for("delete_message", %{"message_id" => 1}),
        state
      )

    assert_denied(
      Sender.handle_message(
        @bound_slot,
        payload_for("edit_message", %{"message_id" => 2}),
        state
      ),
      ":unauthorized_message"
    )

    assert_denied(
      Sender.handle_message(
        @bound_slot,
        payload_for("delete_messages", %{"message_ids" => [2]}),
        state
      ),
      ":unauthorized_message"
    )

    {_fake, other_state} = bind_slot(state, "telegram_agent_1", "tg:2:0")

    assert_denied(
      Sender.handle_message(
        "telegram_agent_1",
        payload_for("edit_message", %{"message_id" => 1}),
        other_state
      ),
      ":unauthorized_message"
    )

    {fake, aged_state} = state_with_own_message(own_message_window: 1)

    Fake.push_response(fake, {:ok, %{"message_id" => 2}})

    {:noreply, aged_state} =
      Sender.handle_message(
        @bound_slot,
        payload_for("send", %{"text" => "newer", "photo" => nil}),
        aged_state
      )

    assert_denied(
      Sender.handle_message(
        @bound_slot,
        payload_for("delete_message", %{"message_id" => 1}),
        aged_state
      ),
      ":unauthorized_message"
    )
  end

  test "bound own-message actions require a resolvable message id" do
    {fake, state} = bound_state()

    for action <- Actions.actions_in(:own_messages) do
      payload = Map.drop(payload_for(action), ["message_id", "message_ids"])

      assert_denied(
        Sender.handle_message(@bound_slot, payload, state),
        ":unauthorized_message"
      )
    end

    assert Fake.calls(fake) == []
  end

  test "audit is scoped to audit_sources" do
    {_fake, state} = fresh_state(audit_sources: [:auditor])

    {:reply, body, state} =
      Sender.handle_message(:auditor, %{"action" => "audit"}, state)

    assert %{"ok" => true, "sent" => []} = Jason.decode!(body)

    assert_denied(
      Sender.handle_message(:worker, %{"action" => "audit"}, state),
      ":unauthorized_audit"
    )
  end

  test "gate behavior matches the action table for caller classes" do
    {_fake, state} =
      bound_state(
        send_sources: [:named, :operator],
        progress_sources: [:named, :operator],
        typing_sources: [:telegram_ingress],
        batch_sources: [:batcher],
        slot_reply_sources: [:slotter],
        action_grants: all_operator_grants([:operator])
      )

    {_fake, state} = seed_own_message(state)

    callers = [
      bound_slot: @bound_slot,
      named_object: :named,
      operator_object: :operator,
      unbound_slot: "telegram_agent_missing"
    ]

    for action <- Actions.actions(),
        {caller_class, caller} <- callers do
      result = Sender.handle_message(caller, payload_for(action), state)

      assert gate_allowed?(result) == expected_allowed?(action, caller_class),
             "unexpected gate decision for #{inspect(action)} from #{inspect(caller_class)}"
    end
  end

  test "capabilities list exactly the actions allowed by the gate for representative callers" do
    {_fake, state} =
      bound_state(
        agent_surface: [:core],
        send_sources: [:named],
        progress_sources: [:named],
        action_grants: %{message_ops: [:named]}
      )

    callers = [
      bound_slot: @bound_slot,
      named_object_granted_message_ops: :named,
      ungranted_named_object: :observer
    ]

    for {caller_class, caller} <- callers do
      {:reply, body, _state} =
        Sender.handle_message(caller, %{"action" => "capabilities"}, state)

      capabilities = Jason.decode!(body)["capabilities"]
      listed = listed_capability_actions(capabilities)

      assert capabilities["telegram_bot_api_version"] == "10.1"
      assert is_map(capabilities["card_schema"]["limits"])
      assert is_binary(capabilities["card_schema"]["version"])

      for action <- Actions.actions() do
        result = Sender.handle_message(caller, payload_for(action), state)

        assert gate_allowed?(result) == MapSet.member?(listed, action),
               "capabilities drift for #{inspect(action)} from #{inspect(caller_class)}"
      end
    end
  end

  defp assert_gate_denied(action, {fake, state}, caller, expected_error) do
    assert_denied(Sender.handle_message(caller, payload_for(action), state), expected_error)
    assert Fake.calls(fake) == []
  end

  defp assert_allowed({:noreply, _state}), do: :ok
  defp assert_allowed({:reply, body, _state}), do: assert(Jason.decode!(body)["ok"] == true)

  defp assert_denied({:reply, body, _state}, error) do
    assert Jason.decode!(body)["error"] == error
  end

  defp assert_agent_call_scoped(fake, :discovery) do
    assert Fake.calls(fake) == []
  end

  defp assert_agent_call_scoped(fake, _group) do
    [call | _] = Fake.calls(fake)
    assert call.payload.chat_id == "1"
  end

  defp gate_allowed?({:noreply, _state}), do: true

  defp gate_allowed?({:reply, body, _state}) do
    case Jason.decode!(body) do
      %{"error" => error}
      when error in [
             ":unknown_action",
             ":unbound_slot",
             ":unauthorized_action",
             ":unauthorized_target",
             ":unauthorized_binding",
             ":unauthorized_batch",
             ":unauthorized_slot_reply",
             ":unauthorized_audit",
             ":unauthorized_message"
           ] ->
        false

      _reply ->
        true
    end
  end

  defp listed_capability_actions(%{"groups" => groups}) do
    groups
    |> Map.values()
    |> List.flatten()
    |> MapSet.new()
  end

  defp expected_allowed?(action, :unbound_slot) do
    case Actions.classify(action) do
      {:plumbing, _plumbing} -> false
      _classification -> false
    end
  end

  defp expected_allowed?(action, :bound_slot) do
    case Actions.classify(action) do
      {:agent, _group} -> true
      {:operator, _group} -> false
      {:plumbing, _plumbing} -> false
      :unknown -> false
    end
  end

  defp expected_allowed?(action, :named_object) do
    case Actions.classify(action) do
      {:agent, _group} when action in ["delete_message", "delete_messages"] -> false
      {:agent, _group} -> true
      {:operator, _group} -> false
      {:plumbing, _plumbing} -> false
      :unknown -> false
    end
  end

  defp expected_allowed?(action, :operator_object) do
    case Actions.classify(action) do
      {:agent, _group} -> true
      {:operator, _group} -> true
      {:plumbing, _plumbing} -> false
      :unknown -> false
    end
  end

  defp state_with_own_message(opts \\ []) do
    {_fake, state} = bound_state(opts)
    seed_own_message(state)
  end

  defp seed_own_message(state) do
    {:noreply, state} =
      Sender.handle_message(
        @bound_slot,
        payload_for("send", %{"text" => "seed", "conversation_id" => @payload_cid, "photo" => nil}),
        state
      )

    {state.client_opts[:fake], state}
  end

  defp bound_state(opts \\ []) do
    {fake, state} = fresh_state(opts)
    {_fake, state} = bind_slot(state, @bound_slot, @bound_cid)
    {fake, state}
  end

  defp bind_slot(state, slot, cid) do
    {:noreply, state} =
      Sender.handle_message(
        :telegram_ingress,
        %{"action" => "bind_session", "slot" => slot, "conversation_id" => cid},
        state
      )

    {state.client_opts[:fake], state}
  end

  defp fresh_state(opts \\ []) do
    {:ok, fake} = Fake.start_link()

    config =
      opts
      |> Map.new()
      |> Map.merge(%{
        client: Fake,
        client_opts: [fake: fake],
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent",
        rate_per_sec: 1_000
      })

    {fake, Sender.new(config)}
  end

  defp all_operator_grants(callers) do
    Actions.groups()
    |> Enum.filter(fn group ->
      case Actions.actions_in(group) do
        [action | _] -> match?({:operator, ^group}, Actions.classify(action))
        [] -> false
      end
    end)
    |> Map.new(&{&1, callers})
  end

  defp payload_for(action, extra \\ %{}) do
    Map.merge(
      %{
        "action" => action,
        "conversation_id" => @payload_cid,
        "text" => "hello",
        "card" => %{"blocks" => [%{"kind" => "paragraph", "text" => "hello"}]},
        "rich_message" => %{"html" => "<p>hello</p>"},
        "draft_id" => 77,
        "message_id" => 1,
        "message_ids" => [1],
        "from_chat_id" => "@source",
        "chat_id" => -100_999,
        "user_id" => 123,
        "callback_query_id" => "cb-1",
        "web_app_query_id" => "web-1",
        "inline_query_id" => "inline-1",
        "result" => %{"type" => "article", "id" => "result-1", "title" => "Result"},
        "results" => [%{"type" => "article", "id" => "result-1", "title" => "Result"}],
        "button" => %{"text" => "Pick"},
        "business_connection_id" => "biz-1",
        "can_delete_messages" => true,
        "chat_join_request_query_id" => "join-query-1",
        "custom_emoji_id" => "emoji-1",
        "custom_emoji_ids" => ["emoji-1"],
        "custom_title" => "Lead",
        "emoji_status_custom_emoji_id" => "emoji-status-1",
        "emoji_status_expiration_date" => 1_800_000_000,
        "icon_color" => 7_322_096,
        "invite_link" => "https://t.me/+invite",
        "keywords" => ["ai"],
        "mask_position" => %{point: "forehead", x_shift: 0.0, y_shift: 0.0, scale: 1.0},
        "message_thread_id" => 7,
        "old_sticker" => "old-sticker",
        "permissions" => %{can_send_messages: true},
        "sender_chat_id" => -100_125,
        "subscription_period" => 2_592_000,
        "subscription_price" => 100,
        "tag" => "vip",
        "thumbnail" => "file-thumb",
        "web_app_url" => "https://example.com/app",
        "managed_bot_id" => 456,
        "file_id" => "file-1",
        "name" => "example_by_bot",
        "title" => "Title",
        "description" => "Description",
        "short_description" => "Short",
        "commands" => [%{"command" => "start", "description" => "Start"}],
        "scope" => %{"type" => "default"},
        "menu_button" => %{"type" => "commands"},
        "rights" => %{"can_delete_messages" => true},
        "payload" => "payload-1",
        "provider_token" => "",
        "currency" => "XTR",
        "prices" => [%{"label" => "Access", "amount" => 5}],
        "shipping_query_id" => "ship-1",
        "pre_checkout_query_id" => "checkout-1",
        "ok" => true,
        "telegram_payment_charge_id" => "charge-1",
        "is_canceled" => true,
        "gift_id" => "gift-1",
        "owned_gift_id" => "owned-gift-1",
        "star_count" => 5,
        "custom_description" => "Official",
        "passport_data_errors" => [%{"source" => "data", "type" => "personal_details"}],
        "score" => 42,
        "game_short_name" => "game",
        "story_id" => 14,
        "content" => %{"type" => "photo", "photo" => "attach://story-photo"},
        "sticker" => "file-sticker",
        "sticker_set_name" => "example_by_bot",
        "stickers" => [
          %{"sticker" => "file-sticker", "emoji_list" => ["smile"], "format" => "static"}
        ],
        "sticker_format" => "static",
        "sticker_type" => "regular",
        "emoji_list" => ["smile"],
        "position" => 0,
        "format" => "static",
        "media_type" => "photo",
        "media" => "file-photo",
        "video_note" => "file-video-note",
        "live_photo" => "file-live",
        "photo" => "file-photo",
        "question" => "Pick",
        "options" => ["A"],
        "latitude" => 41.38,
        "longitude" => 2.17,
        "address" => "Barcelona",
        "phone_number" => "+34123456789",
        "first_name" => "Example",
        "emoji" => "🎲",
        "reaction" => "👍",
        "chat_action" => "upload_photo",
        "recipients" => [@payload_cid],
        "slot" => @bound_slot
      },
      extra
    )
  end
end

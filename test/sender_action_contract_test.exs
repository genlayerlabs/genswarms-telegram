defmodule Genswarms.Telegram.SenderActionContractTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client.Fake
  alias Genswarms.Telegram.Objects.Sender

  @utility_actions ~w(
    get_user_profile_photos
    get_user_profile_audios
    set_user_emoji_status
    get_file
  )

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

  setup do
    {:ok, fake} = Fake.start_link()

    state =
      Sender.new(%{
        client: Fake,
        client_opts: [fake: fake],
        rate_per_sec: 1_000,
        action_grants: %{
          utility: [:telegram_ingress],
          chat_admin: [:telegram_ingress],
          stickers_mgmt: [:telegram_ingress]
        }
      })

    {:ok, fake: fake, state: state}
  end

  test "utility actions dispatch through the sender filter with normalized payloads", %{
    fake: fake,
    state: state
  } do
    state =
      Enum.reduce(@utility_actions, state, fn action, acc ->
        {:noreply, next} = Sender.handle_message(:telegram_ingress, attrs(action), acc)
        next
      end)

    assert Enum.map(Fake.calls(fake), & &1.method) ==
             Enum.map(@utility_actions, &String.to_atom/1)

    [photos, audios, emoji_status, file] = Fake.calls(fake)
    assert photos.payload.user_id == 123
    assert audios.payload.limit == 2
    assert emoji_status.payload.emoji_status_expiration_date == 1_800_000_000
    assert file.payload.file_id == "file-1"
    assert length(state.sent) == length(@utility_actions)
  end

  test "chat administration actions dispatch through one sender path with typed ids", %{
    fake: fake,
    state: state
  } do
    Enum.reduce(@chat_admin_actions, state, fn action, acc ->
      {:noreply, next} = Sender.handle_message(:telegram_ingress, attrs(action), acc)
      next
    end)

    assert Enum.map(Fake.calls(fake), & &1.method) ==
             Enum.map(@chat_admin_actions, &String.to_atom/1)

    calls_by_method = Map.new(Fake.calls(fake), &{&1.method, &1.payload})
    assert calls_by_method.ban_chat_member.user_id == 123
    assert calls_by_method.restrict_chat_member.permissions == %{can_send_messages: true}
    assert calls_by_method.answer_chat_join_request_query.result == "approve"
    assert calls_by_method.send_chat_join_request_web_app.web_app_url == "https://example.com/app"
    assert calls_by_method.create_forum_topic.icon_color == 7_322_096
    assert calls_by_method.get_forum_topic_icon_stickers == %{}
  end

  test "sticker actions dispatch through the sender filter and preserve object-shaped stickers",
       %{
         fake: fake,
         state: state
       } do
    Enum.reduce(@sticker_actions, state, fn action, acc ->
      {:noreply, next} = Sender.handle_message(:telegram_ingress, attrs(action), acc)
      next
    end)

    assert Enum.map(Fake.calls(fake), & &1.method) ==
             Enum.map(@sticker_actions, &String.to_atom/1)

    calls_by_method = Map.new(Fake.calls(fake), &{&1.method, &1.payload})
    assert calls_by_method.upload_sticker_file.sticker_format == "static"
    assert calls_by_method.create_new_sticker_set.sticker_type == "regular"
    assert calls_by_method.add_sticker_to_set.sticker["sticker"] == "file-sticker"
    assert calls_by_method.replace_sticker_in_set.sticker["sticker"] == "file-sticker"
    assert calls_by_method.set_sticker_emoji_list.emoji_list == ["smile"]
  end

  test "send_media maps agent media types to native Telegram send methods", %{
    fake: fake,
    state: state
  } do
    media_cases = [
      {"video", :send_video, :video},
      {"audio", :send_audio, :audio},
      {"voice", :send_voice, :voice},
      {"document", :send_document, :document}
    ]

    Enum.reduce(media_cases, state, fn {media_type, _method, _field}, acc ->
      {:noreply, next} =
        Sender.handle_message(
          :telegram_ingress,
          %{
            "action" => "send_media",
            "conversation_id" => "tg:123:0",
            "media_type" => media_type,
            "media" => "file-#{media_type}",
            "caption" => "caption"
          },
          acc
        )

      next
    end)

    calls = Fake.calls(fake)
    assert Enum.map(calls, & &1.method) == Enum.map(media_cases, &elem(&1, 1))

    Enum.zip(calls, media_cases)
    |> Enum.each(fn {call, {_media_type, _method, field}} ->
      assert Map.fetch!(call.payload, field) =~ "file-"

      if field in [:video, :audio, :document] do
        assert call.payload.caption == "caption"
      end
    end)
  end

  defp attrs(action) do
    Map.merge(base_attrs(), %{"action" => action})
    |> attrs_for(action)
  end

  defp base_attrs do
    %{
      "business_connection_id" => "biz-1",
      "can_delete_messages" => true,
      "chat_id" => -100_123,
      "chat_join_request_query_id" => "join-query-1",
      "custom_emoji_id" => "emoji-1",
      "custom_emoji_ids" => ["emoji-1"],
      "custom_title" => "Lead",
      "description" => "Description",
      "emoji_list" => ["smile"],
      "emoji_status_custom_emoji_id" => "emoji-status-1",
      "emoji_status_expiration_date" => 1_800_000_000,
      "file_id" => "file-1",
      "format" => "static",
      "icon_color" => 7_322_096,
      "invite_link" => "https://t.me/+invite",
      "keywords" => ["ai"],
      "limit" => "2",
      "mask_position" => %{point: "forehead", x_shift: 0.0, y_shift: 0.0, scale: 1.0},
      "message_id" => "5",
      "message_thread_id" => "7",
      "name" => "example_by_bot",
      "old_sticker" => "old-sticker",
      "permissions" => %{can_send_messages: true},
      "photo" => "file-photo",
      "position" => 0,
      "result" => "approve",
      "sender_chat_id" => -100_125,
      "sticker" => "file-sticker",
      "sticker_format" => "static",
      "sticker_set_name" => "example_by_bot",
      "sticker_type" => "regular",
      "stickers" => [
        %{"sticker" => "file-sticker", "emoji_list" => ["smile"], "format" => "static"}
      ],
      "subscription_period" => 2_592_000,
      "subscription_price" => 100,
      "tag" => "vip",
      "thumbnail" => "file-thumb",
      "title" => "Title",
      "user_id" => "123",
      "web_app_url" => "https://example.com/app"
    }
  end

  defp attrs_for(attrs, action) when action in ["add_sticker_to_set", "replace_sticker_in_set"] do
    Map.put(attrs, "sticker", %{
      "sticker" => "file-sticker",
      "emoji_list" => ["smile"],
      "format" => "static"
    })
  end

  defp attrs_for(attrs, "delete_message_reaction") do
    attrs
    |> Map.delete("user_id")
    |> Map.put("actor_chat_id", -100_126)
  end

  defp attrs_for(attrs, _action), do: attrs
end

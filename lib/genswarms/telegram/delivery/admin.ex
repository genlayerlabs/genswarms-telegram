defmodule Genswarms.Telegram.Delivery.Admin do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared

  def build_ban_chat_member(%{chat_id: chat_id, user_id: user_id} = attrs) do
    %{
      _method: :ban_chat_member,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:until_date, non_negative_integer(option(attrs, :until_date), :until_date))
    |> maybe_put(:revoke_messages, option(attrs, :revoke_messages))
  end

  def build_unban_chat_member(%{chat_id: chat_id, user_id: user_id} = attrs) do
    %{
      _method: :unban_chat_member,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:only_if_banned, option(attrs, :only_if_banned))
  end

  def build_restrict_chat_member(
        %{chat_id: chat_id, user_id: user_id, permissions: permissions} = attrs
      ) do
    %{
      _method: :restrict_chat_member,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id),
      permissions: normalize_non_empty_map!(permissions, :permissions)
    }
    |> maybe_put(
      :use_independent_chat_permissions,
      option(attrs, :use_independent_chat_permissions)
    )
    |> maybe_put(:until_date, non_negative_integer(option(attrs, :until_date), :until_date))
  end

  def build_promote_chat_member(%{chat_id: chat_id, user_id: user_id} = attrs) do
    [
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
      :can_manage_direct_messages
    ]
    |> Enum.reduce(
      %{
        _method: :promote_chat_member,
        chat_id: normalize_chat_id!(chat_id, :chat_id),
        user_id: normalize_positive_integer!(user_id, :user_id)
      },
      fn key, payload -> maybe_put(payload, key, option(attrs, key)) end
    )
  end

  def build_set_chat_administrator_custom_title(%{
        chat_id: chat_id,
        user_id: user_id,
        custom_title: custom_title
      }) do
    %{
      _method: :set_chat_administrator_custom_title,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id),
      custom_title: bounded_string!(custom_title, :custom_title, 1, 16)
    }
  end

  def build_set_chat_member_tag(%{chat_id: chat_id, user_id: user_id} = attrs) do
    %{
      _method: :set_chat_member_tag,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:tag, bounded_string_or_empty!(option(attrs, :tag), :tag, 0, 16))
  end

  def build_ban_chat_sender_chat(%{chat_id: chat_id, sender_chat_id: sender_chat_id}) do
    %{
      _method: :ban_chat_sender_chat,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      sender_chat_id: normalize_integer!(sender_chat_id, :sender_chat_id)
    }
  end

  def build_unban_chat_sender_chat(%{chat_id: chat_id, sender_chat_id: sender_chat_id}) do
    %{
      _method: :unban_chat_sender_chat,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      sender_chat_id: normalize_integer!(sender_chat_id, :sender_chat_id)
    }
  end

  def build_set_chat_permissions(%{chat_id: chat_id, permissions: permissions} = attrs) do
    %{
      _method: :set_chat_permissions,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      permissions: normalize_non_empty_map!(permissions, :permissions)
    }
    |> maybe_put(
      :use_independent_chat_permissions,
      option(attrs, :use_independent_chat_permissions)
    )
  end

  def build_export_chat_invite_link(%{chat_id: chat_id}) do
    %{_method: :export_chat_invite_link, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_create_chat_invite_link(%{chat_id: chat_id} = attrs) do
    %{
      _method: :create_chat_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put_invite_link_attrs(attrs)
  end

  def build_edit_chat_invite_link(%{chat_id: chat_id, invite_link: invite_link} = attrs) do
    %{
      _method: :edit_chat_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      invite_link: non_empty_string!(invite_link, :invite_link)
    }
    |> maybe_put_invite_link_attrs(attrs)
  end

  def build_create_chat_subscription_invite_link(
        %{chat_id: chat_id, subscription_period: period, subscription_price: price} = attrs
      ) do
    %{
      _method: :create_chat_subscription_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      subscription_period: normalize_subscription_period!(period),
      subscription_price: bounded_integer!(price, :subscription_price, 1, 10_000)
    }
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 32))
  end

  def build_edit_chat_subscription_invite_link(
        %{chat_id: chat_id, invite_link: invite_link} = attrs
      ) do
    %{
      _method: :edit_chat_subscription_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      invite_link: non_empty_string!(invite_link, :invite_link)
    }
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 32))
  end

  def build_revoke_chat_invite_link(%{chat_id: chat_id, invite_link: invite_link}) do
    %{
      _method: :revoke_chat_invite_link,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      invite_link: non_empty_string!(invite_link, :invite_link)
    }
  end

  def build_approve_chat_join_request(%{chat_id: chat_id, user_id: user_id}) do
    %{
      _method: :approve_chat_join_request,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_decline_chat_join_request(%{chat_id: chat_id, user_id: user_id}) do
    %{
      _method: :decline_chat_join_request,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_answer_chat_join_request_query(%{
        chat_join_request_query_id: query_id,
        result: result
      }) do
    %{
      _method: :answer_chat_join_request_query,
      chat_join_request_query_id: non_empty_string!(query_id, :chat_join_request_query_id),
      result: normalize_join_request_query_result!(result)
    }
  end

  def build_send_chat_join_request_web_app(%{
        chat_join_request_query_id: query_id,
        web_app_url: web_app_url
      }) do
    %{
      _method: :send_chat_join_request_web_app,
      chat_join_request_query_id: non_empty_string!(query_id, :chat_join_request_query_id),
      web_app_url: safe_optional_url!(web_app_url, :web_app_url)
    }
  end

  def build_set_chat_photo(%{chat_id: chat_id, photo: photo}) do
    %{
      _method: :set_chat_photo,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      photo: non_empty_string!(photo, :photo)
    }
  end

  def build_delete_chat_photo(%{chat_id: chat_id}) do
    %{_method: :delete_chat_photo, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_set_chat_title(%{chat_id: chat_id, title: title}) do
    %{
      _method: :set_chat_title,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      title: bounded_string!(title, :title, 1, 255)
    }
  end

  def build_set_chat_description(%{chat_id: chat_id} = attrs) do
    %{
      _method: :set_chat_description,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put(
      :description,
      bounded_string_or_empty!(option(attrs, :description), :description, 0, 255)
    )
  end

  def build_pin_chat_message(%{chat_id: chat_id, message_id: message_id} = attrs) do
    %{
      _method: :pin_chat_message,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(:disable_notification, option(attrs, :disable_notification))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_unpin_chat_message(%{chat_id: chat_id} = attrs) do
    %{_method: :unpin_chat_message, chat_id: normalize_chat_id!(chat_id, :chat_id)}
    |> maybe_put(:message_id, optional_message_id(option(attrs, :message_id)))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_unpin_all_chat_messages(%{chat_id: chat_id}) do
    %{_method: :unpin_all_chat_messages, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_leave_chat(%{chat_id: chat_id}) do
    %{_method: :leave_chat, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_get_chat(%{chat_id: chat_id}) do
    %{_method: :get_chat, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_get_chat_administrators(%{chat_id: chat_id} = attrs) do
    %{_method: :get_chat_administrators, chat_id: normalize_chat_id!(chat_id, :chat_id)}
    |> maybe_put(:return_bots, option(attrs, :return_bots))
  end

  def build_get_chat_member_count(%{chat_id: chat_id}) do
    %{_method: :get_chat_member_count, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_get_chat_member(%{chat_id: chat_id, user_id: user_id}) do
    %{
      _method: :get_chat_member,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_set_chat_sticker_set(%{chat_id: chat_id, sticker_set_name: sticker_set_name}) do
    %{
      _method: :set_chat_sticker_set,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      sticker_set_name: non_empty_string!(sticker_set_name, :sticker_set_name)
    }
  end

  def build_delete_chat_sticker_set(%{chat_id: chat_id}) do
    %{_method: :delete_chat_sticker_set, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_get_forum_topic_icon_stickers(_attrs \\ %{}),
    do: %{_method: :get_forum_topic_icon_stickers}

  def build_create_forum_topic(%{chat_id: chat_id, name: name} = attrs) do
    %{
      _method: :create_forum_topic,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      name: bounded_string!(name, :name, 1, 128)
    }
    |> maybe_put(:icon_color, normalize_topic_icon_color(option(attrs, :icon_color)))
    |> maybe_put(:icon_custom_emoji_id, option(attrs, :icon_custom_emoji_id))
  end

  def build_edit_forum_topic(%{chat_id: chat_id, message_thread_id: message_thread_id} = attrs) do
    %{
      _method: :edit_forum_topic,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      message_thread_id: normalize_message_id!(message_thread_id)
    }
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 128))
    |> maybe_put(:icon_custom_emoji_id, option(attrs, :icon_custom_emoji_id))
  end

  def build_close_forum_topic(%{chat_id: chat_id, message_thread_id: message_thread_id}) do
    forum_topic_payload(:close_forum_topic, chat_id, message_thread_id)
  end

  def build_reopen_forum_topic(%{chat_id: chat_id, message_thread_id: message_thread_id}) do
    forum_topic_payload(:reopen_forum_topic, chat_id, message_thread_id)
  end

  def build_delete_forum_topic(%{chat_id: chat_id, message_thread_id: message_thread_id}) do
    forum_topic_payload(:delete_forum_topic, chat_id, message_thread_id)
  end

  def build_unpin_all_forum_topic_messages(%{
        chat_id: chat_id,
        message_thread_id: message_thread_id
      }) do
    forum_topic_payload(:unpin_all_forum_topic_messages, chat_id, message_thread_id)
  end

  def build_edit_general_forum_topic(%{chat_id: chat_id, name: name}) do
    %{
      _method: :edit_general_forum_topic,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      name: bounded_string!(name, :name, 1, 128)
    }
  end

  def build_close_general_forum_topic(%{chat_id: chat_id}) do
    %{_method: :close_general_forum_topic, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_reopen_general_forum_topic(%{chat_id: chat_id}) do
    %{_method: :reopen_general_forum_topic, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_hide_general_forum_topic(%{chat_id: chat_id}) do
    %{_method: :hide_general_forum_topic, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_unhide_general_forum_topic(%{chat_id: chat_id}) do
    %{_method: :unhide_general_forum_topic, chat_id: normalize_chat_id!(chat_id, :chat_id)}
  end

  def build_unpin_all_general_forum_topic_messages(%{chat_id: chat_id}) do
    %{
      _method: :unpin_all_general_forum_topic_messages,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
  end
end

defmodule Genswarms.Telegram.Delivery.Utility do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared
  alias Genswarms.Telegram.ConversationId

  def build_get_user_chat_boosts(%{chat_id: chat_id, user_id: user_id}) do
    %{
      _method: :get_user_chat_boosts,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_send_chat_action(%{conversation_id: cid, action: action} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_chat_action,
      chat_id: ConversationId.chat_id(cid),
      action: normalize_chat_action!(action)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_get_user_profile_photos(%{user_id: user_id} = attrs) do
    %{
      _method: :get_user_profile_photos,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:offset, non_negative_integer(option(attrs, :offset), :offset))
    |> maybe_put(:limit, bounded_optional_integer!(option(attrs, :limit), :limit, 1, 100))
  end

  def build_get_user_profile_audios(%{user_id: user_id} = attrs) do
    %{
      _method: :get_user_profile_audios,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(:offset, non_negative_integer(option(attrs, :offset), :offset))
    |> maybe_put(:limit, bounded_optional_integer!(option(attrs, :limit), :limit, 1, 100))
  end

  def build_set_user_emoji_status(%{user_id: user_id} = attrs) do
    %{
      _method: :set_user_emoji_status,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(
      :emoji_status_custom_emoji_id,
      bounded_string_or_empty!(
        option(attrs, :emoji_status_custom_emoji_id),
        :emoji_status_custom_emoji_id,
        0,
        64
      )
    )
    |> maybe_put(
      :emoji_status_expiration_date,
      non_negative_integer(
        option(attrs, :emoji_status_expiration_date),
        :emoji_status_expiration_date
      )
    )
  end

  def build_get_file(%{file_id: file_id}) do
    %{_method: :get_file, file_id: non_empty_string!(file_id, :file_id)}
  end
end

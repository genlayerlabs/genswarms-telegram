defmodule Genswarms.Telegram.Delivery.Business do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared
  alias Genswarms.Telegram.ConversationId

  def build_get_business_connection(%{business_connection_id: business_connection_id}) do
    %{
      _method: :get_business_connection,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
  end

  def build_send_checklist(%{conversation_id: cid} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_checklist,
      chat_id: ConversationId.chat_id(cid),
      business_connection_id:
        non_empty_string!(option(attrs, :business_connection_id), :business_connection_id),
      checklist: normalize_input_checklist!(attrs)
    }
    |> maybe_put(:disable_notification, option(attrs, :disable_notification))
    |> maybe_put(:protect_content, option(attrs, :protect_content))
    |> maybe_put(:message_effect_id, option(attrs, :message_effect_id))
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_edit_message_checklist(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_checklist,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      business_connection_id:
        non_empty_string!(option(attrs, :business_connection_id), :business_connection_id),
      checklist: normalize_input_checklist!(attrs)
    }
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_read_business_message(%{
        business_connection_id: business_connection_id,
        chat_id: chat_id,
        message_id: message_id
      }) do
    %{
      _method: :read_business_message,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      chat_id: normalize_integer!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
  end

  def build_delete_business_messages(%{
        business_connection_id: business_connection_id,
        message_ids: message_ids
      }) do
    %{
      _method: :delete_business_messages,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      message_ids: normalize_message_ids!(message_ids)
    }
  end

  def build_set_business_account_name(
        %{business_connection_id: business_connection_id, first_name: first_name} = attrs
      ) do
    %{
      _method: :set_business_account_name,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      first_name: bounded_string!(first_name, :first_name, 1, 64)
    }
    |> maybe_put(
      :last_name,
      bounded_string_or_empty!(option(attrs, :last_name), :last_name, 0, 64)
    )
  end

  def build_set_business_account_username(
        %{business_connection_id: business_connection_id} = attrs
      ) do
    %{
      _method: :set_business_account_username,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
    |> maybe_put(:username, bounded_string_or_empty!(option(attrs, :username), :username, 0, 32))
  end

  def build_set_business_account_bio(%{business_connection_id: business_connection_id} = attrs) do
    %{
      _method: :set_business_account_bio,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
    |> maybe_put(:bio, bounded_string_or_empty!(option(attrs, :bio), :bio, 0, 140))
  end

  def build_set_business_account_profile_photo(
        %{business_connection_id: business_connection_id, photo: photo} = attrs
      ) do
    %{
      _method: :set_business_account_profile_photo,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      photo: normalize_non_empty_map!(photo, :photo)
    }
    |> maybe_put(:is_public, option(attrs, :is_public))
  end

  def build_remove_business_account_profile_photo(
        %{business_connection_id: business_connection_id} = attrs
      ) do
    %{
      _method: :remove_business_account_profile_photo,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
    |> maybe_put(:is_public, option(attrs, :is_public))
  end

  def build_set_business_account_gift_settings(%{
        business_connection_id: business_connection_id,
        show_gift_button: show_gift_button,
        accepted_gift_types: accepted_gift_types
      }) do
    %{
      _method: :set_business_account_gift_settings,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      show_gift_button: truthy_boolean!(show_gift_button, :show_gift_button),
      accepted_gift_types: normalize_accepted_gift_types!(accepted_gift_types)
    }
  end

  def build_approve_suggested_post(%{chat_id: chat_id, message_id: message_id} = attrs) do
    %{
      _method: :approve_suggested_post,
      chat_id: normalize_integer!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(:send_date, non_negative_integer(option(attrs, :send_date), :send_date))
  end

  def build_decline_suggested_post(%{chat_id: chat_id, message_id: message_id} = attrs) do
    %{
      _method: :decline_suggested_post,
      chat_id: normalize_integer!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(:comment, bounded_string_or_empty!(option(attrs, :comment), :comment, 0, 128))
  end
end

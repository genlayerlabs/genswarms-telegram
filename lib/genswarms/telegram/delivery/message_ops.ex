defmodule Genswarms.Telegram.Delivery.MessageOps do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared
  alias Genswarms.Telegram.ConversationId

  def build_forward_message(
        %{
          conversation_id: cid,
          from_chat_id: from_chat_id,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :forward_message,
      chat_id: ConversationId.chat_id(cid),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:video_start_timestamp, option(attrs, :video_start_timestamp))
  end

  def build_forward_messages(
        %{
          conversation_id: cid,
          from_chat_id: from_chat_id,
          message_ids: message_ids
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :forward_messages,
      chat_id: ConversationId.chat_id(cid),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      message_ids: normalize_message_ids!(message_ids, increasing?: true)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
  end

  def build_copy_message(
        %{
          conversation_id: cid,
          from_chat_id: from_chat_id,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :copy_message,
      chat_id: ConversationId.chat_id(cid),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:caption, edit_caption(attrs))
    |> maybe_put(:parse_mode, edit_caption_parse_mode(attrs))
    |> maybe_put(:show_caption_above_media, option(attrs, :show_caption_above_media))
    |> maybe_put(:video_start_timestamp, option(attrs, :video_start_timestamp))
  end

  def build_copy_messages(
        %{
          conversation_id: cid,
          from_chat_id: from_chat_id,
          message_ids: message_ids
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :copy_messages,
      chat_id: ConversationId.chat_id(cid),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      message_ids: normalize_message_ids!(message_ids, increasing?: true)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
  end

  def build_delete_message(%{conversation_id: cid, message_id: message_id}) do
    validate_conversation_id!(cid)

    %{
      _method: :delete_message,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
  end

  def build_delete_messages(%{conversation_id: cid, message_ids: message_ids}) do
    validate_conversation_id!(cid)

    %{
      _method: :delete_messages,
      chat_id: ConversationId.chat_id(cid),
      message_ids: normalize_message_ids!(message_ids)
    }
  end
end

defmodule Genswarms.Telegram.Delivery.Core do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared
  alias Genswarms.Telegram.ConversationId
  alias Genswarms.Telegram.Format

  def build_send_message(%{conversation_id: cid, text: text} = attrs) do
    validate_conversation_id!(cid)

    base = %{
      chat_id: ConversationId.chat_id(cid),
      text: Format.to_html(text),
      parse_mode: "HTML",
      disable_web_page_preview: true
    }

    base
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_plain_message(%{conversation_id: cid, text: text} = attrs) do
    validate_conversation_id!(cid)

    %{chat_id: ConversationId.chat_id(cid), text: Format.plain(text)}
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_send_message_draft(%{conversation_id: cid, draft_id: draft_id} = attrs) do
    validate_conversation_id!(cid)

    text = Map.get(attrs, :text, Map.get(attrs, "text", ""))

    %{
      _method: :send_message_draft,
      chat_id: ConversationId.chat_id(cid),
      draft_id: normalize_draft_id!(draft_id),
      text: Format.to_html(text)
    }
    |> maybe_put_text_parse_mode(text)
    |> maybe_put_thread(cid)
  end

  def build_send_rich_message(%{conversation_id: cid, rich_message: rich_message} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_rich_message,
      chat_id: ConversationId.chat_id(cid),
      rich_message: normalize_rich_message!(rich_message)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_send_rich_message_draft(%{
        conversation_id: cid,
        draft_id: draft_id,
        rich_message: rich_message
      }) do
    validate_conversation_id!(cid)

    %{
      _method: :send_rich_message_draft,
      chat_id: ConversationId.chat_id(cid),
      draft_id: normalize_draft_id!(draft_id),
      rich_message: normalize_rich_message!(rich_message)
    }
    |> maybe_put_thread(cid)
  end

  def build_edit_rich_message(
        %{
          conversation_id: cid,
          message_id: message_id,
          rich_message: rich_message
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_text,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      rich_message: normalize_rich_message!(rich_message)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end
end

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
      parse_mode: "HTML"
    }

    base
    |> put_link_preview(attrs)
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  # Previews stay OFF unless the caller asks for them — the default every send
  # has always had, and the right one for an agent that quotes a URL mid-thread.
  # An explicit `link_preview_options` (Bot API 7.0, which deprecated
  # `disable_web_page_preview`) wins and the legacy flag is then omitted, so the
  # two never travel together. Same option, same name and same shape that
  # `build_edit_message_text/1` already accepts.
  defp put_link_preview(payload, attrs) do
    case optional_map(option(attrs, :link_preview_options), :link_preview_options) do
      nil -> Map.put(payload, :disable_web_page_preview, true)
      options -> Map.put(payload, :link_preview_options, options)
    end
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

defmodule Genswarms.Telegram.Delivery.Edits do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared
  alias Genswarms.Telegram.ConversationId
  alias Genswarms.Telegram.Format

  def build_edit_message_text(
        %{
          conversation_id: cid,
          message_id: message_id,
          text: text
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_text,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      text: Format.to_html(non_empty_string!(text, :text)),
      parse_mode: "HTML"
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:link_preview_options, option(attrs, :link_preview_options))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_edit_message_caption(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_caption,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:caption, edit_caption(attrs))
    |> maybe_put(:parse_mode, edit_caption_parse_mode(attrs))
    |> maybe_put(:show_caption_above_media, option(attrs, :show_caption_above_media))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_edit_message_reply_markup(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_reply_markup,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_stop_poll(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :stop_poll,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_edit_message_media(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_media,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      media: edit_media!(attrs)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_edit_live_location(
        %{
          conversation_id: cid,
          message_id: message_id,
          latitude: latitude,
          longitude: longitude
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :edit_message_live_location,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id),
      latitude: normalize_coordinate!(latitude, :latitude),
      longitude: normalize_coordinate!(longitude, :longitude)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
    |> maybe_put(:horizontal_accuracy, option(attrs, :horizontal_accuracy))
    |> maybe_put(:heading, option(attrs, :heading))
    |> maybe_put(:proximity_alert_radius, option(attrs, :proximity_alert_radius))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end

  def build_stop_live_location(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :stop_message_live_location,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
  end
end

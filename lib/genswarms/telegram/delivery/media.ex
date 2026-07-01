defmodule Genswarms.Telegram.Delivery.Media do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared
  alias Genswarms.Telegram.ConversationId
  alias Genswarms.Telegram.Format

  def build_send_photo(%{conversation_id: cid, photo: photo} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_photo,
      chat_id: ConversationId.chat_id(cid),
      photo: photo,
      caption: Format.to_html(Map.get(attrs, :caption, Map.get(attrs, :text, ""))),
      parse_mode: "HTML"
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_send_media(%{conversation_id: cid, media_type: type, media: media} = attrs) do
    validate_conversation_id!(cid)

    %{_method: media_method(type), chat_id: ConversationId.chat_id(cid)}
    |> Map.put(media_field(type), non_empty_string!(media, media_field(type)))
    |> maybe_put_media_caption(attrs, type)
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
  end

  def build_send_video_note(%{conversation_id: cid, video_note: video_note} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_video_note,
      chat_id: ConversationId.chat_id(cid),
      video_note: non_empty_string!(video_note, :video_note)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:duration, option(attrs, :duration))
    |> maybe_put(:length, option(attrs, :length))
    |> maybe_put(:thumbnail, option(attrs, :thumbnail))
  end

  def build_send_live_photo(%{conversation_id: cid, live_photo: live_photo, photo: photo} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_live_photo,
      chat_id: ConversationId.chat_id(cid),
      live_photo: non_empty_string!(live_photo, :live_photo),
      photo: non_empty_string!(photo, :photo)
    }
    |> maybe_put_media_caption(attrs, :live_photo)
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:show_caption_above_media, option(attrs, :show_caption_above_media))
  end

  def build_send_sticker(%{conversation_id: cid, sticker: sticker} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_sticker,
      chat_id: ConversationId.chat_id(cid),
      sticker: non_empty_string!(sticker, :sticker)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:emoji, option(attrs, :emoji))
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
    |> maybe_put(:suggested_post_parameters, option(attrs, :suggested_post_parameters))
  end

  def build_send_media_group(%{conversation_id: cid, media: media} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_media_group,
      chat_id: ConversationId.chat_id(cid),
      media: normalize_media_group!(media)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(Map.delete(Map.delete(attrs, :spoiler), "spoiler"))
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
  end

  def build_send_poll(%{conversation_id: cid, question: question, options: options} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_poll,
      chat_id: ConversationId.chat_id(cid),
      question: non_empty_string!(to_string(question), :question),
      options: normalize_poll_options!(options)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:is_anonymous, option(attrs, :is_anonymous))
    |> maybe_put(:allows_multiple_answers, option(attrs, :allows_multiple_answers))
    |> maybe_put(:allows_revoting, option(attrs, :allows_revoting))
    |> maybe_put(:shuffle_options, option(attrs, :shuffle_options))
    |> maybe_put(:allow_adding_options, option(attrs, :allow_adding_options))
    |> maybe_put(:hide_results_until_closes, option(attrs, :hide_results_until_closes))
    |> maybe_put(:members_only, option(attrs, :members_only))
    |> maybe_put(:country_codes, option(attrs, :country_codes))
    |> maybe_put(:type, option(attrs, :poll_type) || option(attrs, :type))
    |> maybe_put(:correct_option_ids, correct_option_ids(attrs))
    |> maybe_put(:explanation, option(attrs, :explanation))
    |> maybe_put(:explanation_media, option(attrs, :explanation_media))
    |> maybe_put(:description, option(attrs, :description))
    |> maybe_put(:media, option(attrs, :media))
  end

  def build_send_location(
        %{conversation_id: cid, latitude: latitude, longitude: longitude} = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :send_location,
      chat_id: ConversationId.chat_id(cid),
      latitude: normalize_coordinate!(latitude, :latitude),
      longitude: normalize_coordinate!(longitude, :longitude)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:horizontal_accuracy, option(attrs, :horizontal_accuracy))
    |> maybe_put(:live_period, option(attrs, :live_period))
    |> maybe_put(:heading, option(attrs, :heading))
    |> maybe_put(:proximity_alert_radius, option(attrs, :proximity_alert_radius))
  end

  def build_send_venue(
        %{
          conversation_id: cid,
          latitude: latitude,
          longitude: longitude,
          title: title,
          address: address
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :send_venue,
      chat_id: ConversationId.chat_id(cid),
      latitude: normalize_coordinate!(latitude, :latitude),
      longitude: normalize_coordinate!(longitude, :longitude),
      title: non_empty_string!(title, :title),
      address: non_empty_string!(address, :address)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:foursquare_id, option(attrs, :foursquare_id))
    |> maybe_put(:foursquare_type, option(attrs, :foursquare_type))
    |> maybe_put(:google_place_id, option(attrs, :google_place_id))
    |> maybe_put(:google_place_type, option(attrs, :google_place_type))
  end

  def build_send_contact(
        %{conversation_id: cid, phone_number: phone_number, first_name: first_name} = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :send_contact,
      chat_id: ConversationId.chat_id(cid),
      phone_number: non_empty_string!(phone_number, :phone_number),
      first_name: non_empty_string!(first_name, :first_name)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:last_name, option(attrs, :last_name))
    |> maybe_put(:vcard, option(attrs, :vcard))
  end

  def build_send_dice(%{conversation_id: cid} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_dice,
      chat_id: ConversationId.chat_id(cid)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, reply_markup_from_attrs(attrs))
    |> maybe_put(:emoji, option(attrs, :emoji))
  end
end

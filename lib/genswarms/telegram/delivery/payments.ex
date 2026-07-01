defmodule Genswarms.Telegram.Delivery.Payments do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared
  alias Genswarms.Telegram.ConversationId

  def build_send_paid_media(%{conversation_id: cid, star_count: star_count, media: media} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_paid_media,
      chat_id: ConversationId.chat_id(cid),
      star_count: bounded_integer!(star_count, :star_count, 1, 25_000),
      media: normalize_paid_media!(media)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
    |> maybe_put(:direct_messages_topic_id, option(attrs, :direct_messages_topic_id))
    |> maybe_put(:payload, bounded_bytes!(option(attrs, :payload), :payload, 0, 128))
    |> maybe_put(:caption, paid_caption(attrs))
    |> maybe_put(:parse_mode, paid_caption_parse_mode(attrs))
    |> maybe_put(:caption_entities, option(attrs, :caption_entities))
    |> maybe_put(:show_caption_above_media, option(attrs, :show_caption_above_media))
    |> maybe_put(:suggested_post_parameters, option(attrs, :suggested_post_parameters))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end

  def build_send_invoice(
        %{
          conversation_id: cid,
          title: title,
          description: description,
          payload: payload,
          currency: currency,
          prices: prices
        } = attrs
      ) do
    validate_conversation_id!(cid)

    currency = normalize_currency!(currency)

    %{
      _method: :send_invoice,
      chat_id: ConversationId.chat_id(cid),
      title: bounded_string!(title, :title, 1, 32),
      description: bounded_string!(description, :description, 1, 255),
      payload: bounded_bytes!(payload, :payload, 1, 128),
      provider_token: provider_token(attrs, currency),
      currency: currency,
      prices: normalize_labeled_prices!(prices, currency)
    }
    |> maybe_put_thread(cid)
    |> maybe_put(:direct_messages_topic_id, option(attrs, :direct_messages_topic_id))
    |> maybe_put(:max_tip_amount, option(attrs, :max_tip_amount))
    |> maybe_put(:suggested_tip_amounts, suggested_tip_amounts(attrs))
    |> maybe_put(:start_parameter, option(attrs, :start_parameter))
    |> maybe_put(:provider_data, option(attrs, :provider_data))
    |> maybe_put(:photo_url, safe_optional_url!(option(attrs, :photo_url), :photo_url))
    |> maybe_put(:photo_size, option(attrs, :photo_size))
    |> maybe_put(:photo_width, option(attrs, :photo_width))
    |> maybe_put(:photo_height, option(attrs, :photo_height))
    |> maybe_put(:need_name, option(attrs, :need_name))
    |> maybe_put(:need_phone_number, option(attrs, :need_phone_number))
    |> maybe_put(:need_email, option(attrs, :need_email))
    |> maybe_put(:need_shipping_address, option(attrs, :need_shipping_address))
    |> maybe_put(:send_phone_number_to_provider, option(attrs, :send_phone_number_to_provider))
    |> maybe_put(:send_email_to_provider, option(attrs, :send_email_to_provider))
    |> maybe_put(:is_flexible, option(attrs, :is_flexible))
    |> maybe_put_common(attrs)
    |> maybe_put(:suggested_post_parameters, option(attrs, :suggested_post_parameters))
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, invoice_reply_markup_from_attrs(attrs))
  end

  def build_create_invoice_link(
        %{
          title: title,
          description: description,
          payload: payload,
          currency: currency,
          prices: prices
        } =
          attrs
      ) do
    currency = normalize_currency!(currency)

    %{
      _method: :create_invoice_link,
      title: bounded_string!(title, :title, 1, 32),
      description: bounded_string!(description, :description, 1, 255),
      payload: bounded_bytes!(payload, :payload, 1, 128),
      provider_token: provider_token(attrs, currency),
      currency: currency,
      prices: normalize_labeled_prices!(prices, currency)
    }
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
    |> maybe_put(:subscription_period, subscription_period(attrs, currency))
    |> maybe_put(:max_tip_amount, option(attrs, :max_tip_amount))
    |> maybe_put(:suggested_tip_amounts, suggested_tip_amounts(attrs))
    |> maybe_put(:provider_data, option(attrs, :provider_data))
    |> maybe_put(:photo_url, safe_optional_url!(option(attrs, :photo_url), :photo_url))
    |> maybe_put(:photo_size, option(attrs, :photo_size))
    |> maybe_put(:photo_width, option(attrs, :photo_width))
    |> maybe_put(:photo_height, option(attrs, :photo_height))
    |> maybe_put(:need_name, option(attrs, :need_name))
    |> maybe_put(:need_phone_number, option(attrs, :need_phone_number))
    |> maybe_put(:need_email, option(attrs, :need_email))
    |> maybe_put(:need_shipping_address, option(attrs, :need_shipping_address))
    |> maybe_put(:send_phone_number_to_provider, option(attrs, :send_phone_number_to_provider))
    |> maybe_put(:send_email_to_provider, option(attrs, :send_email_to_provider))
    |> maybe_put(:is_flexible, option(attrs, :is_flexible))
  end

  def build_answer_shipping_query(%{shipping_query_id: shipping_query_id, ok: ok} = attrs) do
    ok? = truthy_boolean!(ok, :ok)

    %{
      _method: :answer_shipping_query,
      shipping_query_id: non_empty_string!(shipping_query_id, :shipping_query_id),
      ok: ok?
    }
    |> maybe_put_shipping_answer(ok?, attrs)
  end

  def build_answer_pre_checkout_query(%{pre_checkout_query_id: query_id, ok: ok} = attrs) do
    ok? = truthy_boolean!(ok, :ok)

    %{
      _method: :answer_pre_checkout_query,
      pre_checkout_query_id: non_empty_string!(query_id, :pre_checkout_query_id),
      ok: ok?
    }
    |> maybe_put_error_message(ok?, attrs)
  end

  def build_get_my_star_balance(_attrs \\ %{}), do: %{_method: :get_my_star_balance}

  def build_get_star_transactions(attrs \\ %{}) do
    %{_method: :get_star_transactions}
    |> maybe_put(:offset, non_negative_integer(option(attrs, :offset), :offset))
    |> maybe_put(:limit, bounded_optional_integer!(option(attrs, :limit), :limit, 1, 100))
  end

  def build_refund_star_payment(%{user_id: user_id, telegram_payment_charge_id: charge_id}) do
    %{
      _method: :refund_star_payment,
      user_id: normalize_positive_integer!(user_id, :user_id),
      telegram_payment_charge_id: non_empty_string!(charge_id, :telegram_payment_charge_id)
    }
  end

  def build_edit_user_star_subscription(%{
        user_id: user_id,
        telegram_payment_charge_id: charge_id,
        is_canceled: is_canceled
      }) do
    %{
      _method: :edit_user_star_subscription,
      user_id: normalize_positive_integer!(user_id, :user_id),
      telegram_payment_charge_id: non_empty_string!(charge_id, :telegram_payment_charge_id),
      is_canceled: truthy_boolean!(is_canceled, :is_canceled)
    }
  end
end

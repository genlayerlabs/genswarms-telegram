defmodule Genswarms.Telegram.Delivery.Gifts do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared

  def build_get_available_gifts(_attrs \\ %{}), do: %{_method: :get_available_gifts}

  def build_send_gift(%{gift_id: gift_id} = attrs) do
    %{
      _method: :send_gift,
      gift_id: non_empty_string!(gift_id, :gift_id)
    }
    |> maybe_put_gift_recipient(attrs)
    |> maybe_put(:pay_for_upgrade, option(attrs, :pay_for_upgrade))
    |> maybe_put_gift_text(attrs)
  end

  def build_gift_premium_subscription(
        %{user_id: user_id, month_count: month_count, star_count: star_count} = attrs
      ) do
    month_count = normalize_integer!(month_count, :month_count)
    star_count = normalize_integer!(star_count, :star_count)

    unless {month_count, star_count} in [{3, 1000}, {6, 1500}, {12, 2500}] do
      raise ArgumentError,
            "gift premium subscription requires 1000 Stars for 3 months, 1500 for 6, or 2500 for 12"
    end

    %{
      _method: :gift_premium_subscription,
      user_id: normalize_positive_integer!(user_id, :user_id),
      month_count: month_count,
      star_count: star_count
    }
    |> maybe_put_gift_text(attrs)
  end

  def build_get_business_account_star_balance(%{business_connection_id: business_connection_id}) do
    %{
      _method: :get_business_account_star_balance,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
  end

  def build_transfer_business_account_stars(%{
        business_connection_id: business_connection_id,
        star_count: star_count
      }) do
    %{
      _method: :transfer_business_account_stars,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      star_count: bounded_integer!(star_count, :star_count, 1, 10_000)
    }
  end

  def build_get_business_account_gifts(%{business_connection_id: business_connection_id} = attrs) do
    %{
      _method: :get_business_account_gifts,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id)
    }
    |> maybe_put_gift_filters(attrs, [:exclude_unsaved, :exclude_saved, :exclude_unique])
  end

  def build_get_user_gifts(%{user_id: user_id} = attrs) do
    %{
      _method: :get_user_gifts,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put_gift_filters(attrs, [:exclude_unique])
  end

  def build_get_chat_gifts(%{chat_id: chat_id} = attrs) do
    %{
      _method: :get_chat_gifts,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put_gift_filters(attrs, [:exclude_unsaved, :exclude_saved, :exclude_unique])
  end

  def build_convert_gift_to_stars(%{
        business_connection_id: business_connection_id,
        owned_gift_id: owned_gift_id
      }) do
    %{
      _method: :convert_gift_to_stars,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      owned_gift_id: non_empty_string!(owned_gift_id, :owned_gift_id)
    }
  end

  def build_upgrade_gift(
        %{
          business_connection_id: business_connection_id,
          owned_gift_id: owned_gift_id
        } = attrs
      ) do
    %{
      _method: :upgrade_gift,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      owned_gift_id: non_empty_string!(owned_gift_id, :owned_gift_id)
    }
    |> maybe_put(:keep_original_details, option(attrs, :keep_original_details))
    |> maybe_put(:star_count, non_negative_integer(option(attrs, :star_count), :star_count))
  end

  def build_transfer_gift(
        %{
          business_connection_id: business_connection_id,
          owned_gift_id: owned_gift_id,
          new_owner_chat_id: new_owner_chat_id
        } = attrs
      ) do
    %{
      _method: :transfer_gift,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      owned_gift_id: non_empty_string!(owned_gift_id, :owned_gift_id),
      new_owner_chat_id: normalize_chat_id!(new_owner_chat_id, :new_owner_chat_id)
    }
    |> maybe_put(:star_count, non_negative_integer(option(attrs, :star_count), :star_count))
  end
end

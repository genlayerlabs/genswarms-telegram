defmodule Genswarms.Telegram.Delivery.ManagedBots do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared

  def build_get_managed_bot_token(%{user_id: user_id}) do
    %{
      _method: :get_managed_bot_token,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_replace_managed_bot_token(%{user_id: user_id}) do
    %{
      _method: :replace_managed_bot_token,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_get_managed_bot_access_settings(%{user_id: user_id}) do
    %{
      _method: :get_managed_bot_access_settings,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_set_managed_bot_access_settings(
        %{
          user_id: user_id,
          is_access_restricted: is_access_restricted
        } = attrs
      ) do
    %{
      _method: :set_managed_bot_access_settings,
      user_id: normalize_positive_integer!(user_id, :user_id),
      is_access_restricted: truthy_boolean!(is_access_restricted, :is_access_restricted)
    }
    |> maybe_put(:added_user_ids, normalize_added_user_ids(option(attrs, :added_user_ids)))
  end

  def build_get_user_personal_chat_messages(%{user_id: user_id, limit: limit}) do
    %{
      _method: :get_user_personal_chat_messages,
      user_id: normalize_positive_integer!(user_id, :user_id),
      limit: bounded_integer!(limit, :limit, 1, 20)
    }
  end
end

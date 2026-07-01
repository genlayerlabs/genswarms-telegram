defmodule Genswarms.Telegram.Delivery.Passport do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared

  def build_set_passport_data_errors(%{user_id: user_id, errors: errors}) do
    %{
      _method: :set_passport_data_errors,
      user_id: normalize_positive_integer!(user_id, :user_id),
      errors: normalize_passport_errors!(errors)
    }
  end
end

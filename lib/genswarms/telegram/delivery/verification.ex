defmodule Genswarms.Telegram.Delivery.Verification do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared

  def build_verify_user(%{user_id: user_id} = attrs) do
    %{
      _method: :verify_user,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put(
      :custom_description,
      bounded_string_or_empty!(option(attrs, :custom_description), :custom_description, 0, 70)
    )
  end

  def build_verify_chat(%{chat_id: chat_id} = attrs) do
    %{
      _method: :verify_chat,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put(
      :custom_description,
      bounded_string_or_empty!(option(attrs, :custom_description), :custom_description, 0, 70)
    )
  end

  def build_remove_user_verification(%{user_id: user_id}) do
    %{
      _method: :remove_user_verification,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
  end

  def build_remove_chat_verification(%{chat_id: chat_id}) do
    %{
      _method: :remove_chat_verification,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
  end
end

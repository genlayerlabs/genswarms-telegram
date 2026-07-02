defmodule Genswarms.Telegram.Delivery.Profile do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared

  def build_set_my_commands(%{commands: commands} = attrs) do
    %{
      _method: :set_my_commands,
      commands: normalize_bot_commands!(commands)
    }
    |> maybe_put(:scope, optional_map(option(attrs, :scope), :scope))
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_delete_my_commands(attrs \\ %{}) do
    %{_method: :delete_my_commands}
    |> maybe_put(:scope, optional_map(option(attrs, :scope), :scope))
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_get_my_commands(attrs \\ %{}) do
    %{_method: :get_my_commands}
    |> maybe_put(:scope, optional_map(option(attrs, :scope), :scope))
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_set_my_name(attrs \\ %{}) do
    %{_method: :set_my_name}
    |> maybe_put(:name, bounded_string_or_empty!(option(attrs, :name), :name, 0, 64))
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_get_my_name(attrs \\ %{}) do
    %{_method: :get_my_name}
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_set_my_description(attrs \\ %{}) do
    %{_method: :set_my_description}
    |> maybe_put(
      :description,
      bounded_string_or_empty!(option(attrs, :description), :description, 0, 512)
    )
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_get_my_description(attrs \\ %{}) do
    %{_method: :get_my_description}
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_set_my_short_description(attrs \\ %{}) do
    %{_method: :set_my_short_description}
    |> maybe_put(
      :short_description,
      bounded_string_or_empty!(option(attrs, :short_description), :short_description, 0, 120)
    )
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_get_my_short_description(attrs \\ %{}) do
    %{_method: :get_my_short_description}
    |> maybe_put(:language_code, language_code(option(attrs, :language_code)))
  end

  def build_set_my_profile_photo(%{photo: photo}) do
    %{
      _method: :set_my_profile_photo,
      photo: normalize_non_empty_map!(photo, :photo)
    }
  end

  def build_remove_my_profile_photo(_attrs \\ %{}), do: %{_method: :remove_my_profile_photo}

  def build_set_chat_menu_button(attrs \\ %{}) do
    %{_method: :set_chat_menu_button}
    |> maybe_put(:chat_id, optional_positive_integer(option(attrs, :chat_id), :chat_id))
    |> maybe_put(:menu_button, optional_map(option(attrs, :menu_button), :menu_button))
  end

  def build_get_chat_menu_button(attrs \\ %{}) do
    %{_method: :get_chat_menu_button}
    |> maybe_put(:chat_id, optional_positive_integer(option(attrs, :chat_id), :chat_id))
  end

  def build_set_my_default_administrator_rights(attrs \\ %{}) do
    %{_method: :set_my_default_administrator_rights}
    |> maybe_put(:rights, optional_map(option(attrs, :rights), :rights))
    |> maybe_put(:for_channels, option(attrs, :for_channels))
  end

  def build_get_my_default_administrator_rights(attrs \\ %{}) do
    %{_method: :get_my_default_administrator_rights}
    |> maybe_put(:for_channels, option(attrs, :for_channels))
  end
end

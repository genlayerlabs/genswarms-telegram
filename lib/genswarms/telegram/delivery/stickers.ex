defmodule Genswarms.Telegram.Delivery.Stickers do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared

  def build_get_sticker_set(%{name: name}) do
    %{_method: :get_sticker_set, name: non_empty_string!(name, :name)}
  end

  def build_get_custom_emoji_stickers(%{custom_emoji_ids: ids}) do
    %{
      _method: :get_custom_emoji_stickers,
      custom_emoji_ids: normalize_string_list!(ids, :custom_emoji_ids, 1, 200)
    }
  end

  def build_upload_sticker_file(%{user_id: user_id, sticker: sticker, sticker_format: format}) do
    %{
      _method: :upload_sticker_file,
      user_id: normalize_positive_integer!(user_id, :user_id),
      sticker: non_empty_string!(sticker, :sticker),
      sticker_format: normalize_sticker_format!(format)
    }
  end

  def build_create_new_sticker_set(
        %{user_id: user_id, name: name, title: title, stickers: stickers} = attrs
      ) do
    %{
      _method: :create_new_sticker_set,
      user_id: normalize_positive_integer!(user_id, :user_id),
      name: non_empty_string!(name, :name),
      title: bounded_string!(title, :title, 1, 64),
      stickers: normalize_input_stickers!(stickers)
    }
    |> maybe_put(:sticker_type, normalize_sticker_type(option(attrs, :sticker_type)))
    |> maybe_put(:needs_repainting, option(attrs, :needs_repainting))
  end

  def build_add_sticker_to_set(%{user_id: user_id, name: name, sticker: sticker}) do
    %{
      _method: :add_sticker_to_set,
      user_id: normalize_positive_integer!(user_id, :user_id),
      name: non_empty_string!(name, :name),
      sticker: normalize_non_empty_map!(sticker, :sticker)
    }
  end

  def build_set_sticker_position_in_set(%{sticker: sticker, position: position}) do
    %{
      _method: :set_sticker_position_in_set,
      sticker: non_empty_string!(sticker, :sticker),
      position: non_negative_integer!(position, :position)
    }
  end

  def build_delete_sticker_from_set(%{sticker: sticker}) do
    %{_method: :delete_sticker_from_set, sticker: non_empty_string!(sticker, :sticker)}
  end

  def build_replace_sticker_in_set(%{
        user_id: user_id,
        name: name,
        old_sticker: old_sticker,
        sticker: sticker
      }) do
    %{
      _method: :replace_sticker_in_set,
      user_id: normalize_positive_integer!(user_id, :user_id),
      name: non_empty_string!(name, :name),
      old_sticker: non_empty_string!(old_sticker, :old_sticker),
      sticker: normalize_non_empty_map!(sticker, :sticker)
    }
  end

  def build_set_sticker_emoji_list(%{sticker: sticker, emoji_list: emoji_list}) do
    %{
      _method: :set_sticker_emoji_list,
      sticker: non_empty_string!(sticker, :sticker),
      emoji_list: normalize_string_list!(emoji_list, :emoji_list, 1, 20)
    }
  end

  def build_set_sticker_keywords(%{sticker: sticker} = attrs) do
    %{
      _method: :set_sticker_keywords,
      sticker: non_empty_string!(sticker, :sticker)
    }
    |> maybe_put(:keywords, normalize_string_list(option(attrs, :keywords), :keywords, 0, 20))
  end

  def build_set_sticker_mask_position(%{sticker: sticker} = attrs) do
    %{
      _method: :set_sticker_mask_position,
      sticker: non_empty_string!(sticker, :sticker)
    }
    |> maybe_put(:mask_position, optional_map(option(attrs, :mask_position), :mask_position))
  end

  def build_set_sticker_set_title(%{name: name, title: title}) do
    %{
      _method: :set_sticker_set_title,
      name: non_empty_string!(name, :name),
      title: bounded_string!(title, :title, 1, 64)
    }
  end

  def build_set_sticker_set_thumbnail(
        %{
          name: name,
          user_id: user_id,
          format: format
        } = attrs
      ) do
    %{
      _method: :set_sticker_set_thumbnail,
      name: non_empty_string!(name, :name),
      user_id: normalize_positive_integer!(user_id, :user_id),
      format: normalize_sticker_format!(format)
    }
    |> maybe_put(:thumbnail, option(attrs, :thumbnail))
  end

  def build_set_custom_emoji_sticker_set_thumbnail(%{name: name} = attrs) do
    %{
      _method: :set_custom_emoji_sticker_set_thumbnail,
      name: non_empty_string!(name, :name)
    }
    |> maybe_put(
      :custom_emoji_id,
      bounded_string_or_empty!(option(attrs, :custom_emoji_id), :custom_emoji_id, 0, 64)
    )
  end

  def build_delete_sticker_set(%{name: name}) do
    %{_method: :delete_sticker_set, name: non_empty_string!(name, :name)}
  end
end

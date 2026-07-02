defmodule Genswarms.Telegram.Delivery.Stories do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared

  def build_post_story(
        %{
          business_connection_id: business_connection_id,
          content: content,
          active_period: active_period
        } =
          attrs
      ) do
    %{
      _method: :post_story,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      content: normalize_story_content!(content),
      active_period: normalize_story_active_period!(active_period)
    }
    |> maybe_put_story_caption(attrs)
    |> maybe_put(:areas, normalize_story_areas(option(attrs, :areas)))
    |> maybe_put(:post_to_chat_page, option(attrs, :post_to_chat_page))
    |> maybe_put(:protect_content, option(attrs, :protect_content))
  end

  def build_repost_story(
        %{
          business_connection_id: business_connection_id,
          from_chat_id: from_chat_id,
          from_story_id: from_story_id,
          active_period: active_period
        } = attrs
      ) do
    %{
      _method: :repost_story,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      from_chat_id: normalize_chat_id!(from_chat_id, :from_chat_id),
      from_story_id: normalize_positive_integer!(from_story_id, :from_story_id),
      active_period: normalize_story_active_period!(active_period)
    }
    |> maybe_put(:post_to_chat_page, option(attrs, :post_to_chat_page))
    |> maybe_put(:protect_content, option(attrs, :protect_content))
  end

  def build_edit_story(
        %{business_connection_id: business_connection_id, story_id: story_id, content: content} =
          attrs
      ) do
    %{
      _method: :edit_story,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      story_id: normalize_positive_integer!(story_id, :story_id),
      content: normalize_story_content!(content)
    }
    |> maybe_put_story_caption(attrs)
    |> maybe_put(:areas, normalize_story_areas(option(attrs, :areas)))
  end

  def build_delete_story(%{business_connection_id: business_connection_id, story_id: story_id}) do
    %{
      _method: :delete_story,
      business_connection_id: non_empty_string!(business_connection_id, :business_connection_id),
      story_id: normalize_positive_integer!(story_id, :story_id)
    }
  end
end

defmodule Genswarms.Telegram.Delivery.Inline do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared

  def build_answer_callback_query(%{callback_query_id: callback_query_id} = attrs) do
    %{
      _method: :answer_callback_query,
      callback_query_id: non_empty_string!(callback_query_id, :callback_query_id)
    }
    |> maybe_put(:text, bounded_string_or_empty!(option(attrs, :text), :text, 0, 200))
    |> maybe_put(:show_alert, option(attrs, :show_alert))
    |> maybe_put(:url, safe_optional_url!(option(attrs, :url), :url))
    |> maybe_put(:cache_time, option(attrs, :cache_time))
  end

  def build_answer_web_app_query(%{web_app_query_id: web_app_query_id, result: result}) do
    %{
      _method: :answer_web_app_query,
      web_app_query_id: non_empty_string!(web_app_query_id, :web_app_query_id),
      result: normalize_inline_query_result!(result)
    }
  end

  def build_answer_guest_query(%{guest_query_id: guest_query_id, result: result}) do
    %{
      _method: :answer_guest_query,
      guest_query_id: non_empty_string!(guest_query_id, :guest_query_id),
      result: normalize_inline_query_result!(result)
    }
  end

  def build_answer_inline_query(%{inline_query_id: inline_query_id, results: results} = attrs) do
    %{
      _method: :answer_inline_query,
      inline_query_id: non_empty_string!(inline_query_id, :inline_query_id),
      results: normalize_inline_query_results!(results, 50)
    }
    |> maybe_put(:cache_time, option(attrs, :cache_time))
    |> maybe_put(:is_personal, option(attrs, :is_personal))
    |> maybe_put(:next_offset, bounded_bytes!(option(attrs, :next_offset), :next_offset, 0, 64))
    |> maybe_put(:button, normalize_inline_query_results_button(option(attrs, :button)))
  end

  def build_save_prepared_inline_message(%{user_id: user_id, result: result} = attrs) do
    %{
      _method: :save_prepared_inline_message,
      user_id: normalize_positive_integer!(user_id, :user_id),
      result: normalize_inline_query_result!(result)
    }
    |> maybe_put(:allow_user_chats, option(attrs, :allow_user_chats))
    |> maybe_put(:allow_bot_chats, option(attrs, :allow_bot_chats))
    |> maybe_put(:allow_group_chats, option(attrs, :allow_group_chats))
    |> maybe_put(:allow_channel_chats, option(attrs, :allow_channel_chats))
  end

  def build_save_prepared_keyboard_button(%{user_id: user_id, button: button}) do
    %{
      _method: :save_prepared_keyboard_button,
      user_id: normalize_positive_integer!(user_id, :user_id),
      button: normalize_prepared_keyboard_button!(button)
    }
  end
end

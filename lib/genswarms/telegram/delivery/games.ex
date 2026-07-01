defmodule Genswarms.Telegram.Delivery.Games do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared
  alias Genswarms.Telegram.ConversationId

  def build_set_game_score(%{user_id: user_id, score: score} = attrs) do
    %{
      _method: :set_game_score,
      user_id: normalize_positive_integer!(user_id, :user_id),
      score: non_negative_integer!(score, :score)
    }
    |> maybe_put(:force, option(attrs, :force))
    |> maybe_put(:disable_edit_message, option(attrs, :disable_edit_message))
    |> maybe_put_game_message_target(attrs)
  end

  def build_get_game_high_scores(%{user_id: user_id} = attrs) do
    %{
      _method: :get_game_high_scores,
      user_id: normalize_positive_integer!(user_id, :user_id)
    }
    |> maybe_put_game_message_target(attrs)
  end

  def build_send_game(%{conversation_id: cid, game_short_name: game_short_name} = attrs) do
    validate_conversation_id!(cid)

    %{
      _method: :send_game,
      chat_id: ConversationId.chat_id(cid),
      game_short_name: non_empty_string!(game_short_name, :game_short_name)
    }
    |> maybe_put_thread(cid)
    |> maybe_put_common(attrs)
    |> maybe_put(:business_connection_id, option(attrs, :business_connection_id))
    |> maybe_put(:reply_parameters, reply_parameters(attrs))
    |> maybe_put(:reply_markup, inline_reply_markup_from_attrs(attrs))
  end
end

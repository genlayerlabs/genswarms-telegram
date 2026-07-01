defmodule Genswarms.Telegram.Delivery.Reactions do
  @moduledoc false

  import Genswarms.Telegram.Delivery.Shared
  alias Genswarms.Telegram.ConversationId

  def build_set_message_reaction(
        %{
          conversation_id: cid,
          message_id: message_id
        } = attrs
      ) do
    validate_conversation_id!(cid)

    %{
      _method: :set_message_reaction,
      chat_id: ConversationId.chat_id(cid),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put(
      :reaction,
      normalize_reactions!(option(attrs, :reaction) || option(attrs, :reactions))
    )
    |> maybe_put(:is_big, option(attrs, :is_big))
  end

  def build_delete_message_reaction(%{chat_id: chat_id, message_id: message_id} = attrs) do
    %{
      _method: :delete_message_reaction,
      chat_id: normalize_chat_id!(chat_id, :chat_id),
      message_id: normalize_message_id!(message_id)
    }
    |> maybe_put_reaction_actor(attrs)
  end

  def build_delete_all_message_reactions(%{chat_id: chat_id} = attrs) do
    %{
      _method: :delete_all_message_reactions,
      chat_id: normalize_chat_id!(chat_id, :chat_id)
    }
    |> maybe_put_reaction_actor(attrs)
  end
end

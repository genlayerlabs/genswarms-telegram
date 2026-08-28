defmodule Genswarms.Telegram.SenderLinkPreviewTest do
  @moduledoc """
  Link previews are per-message, and OFF unless the caller asks.

  Every send used to carry a hardcoded `disable_web_page_preview: true`, with
  no key a caller could set to change it — while EDITS already accepted
  `link_preview_options`. So a message could be edited into having a preview it
  could never be sent with. These tests pin both halves of the fix: the default
  is unchanged, and an explicit option reaches the payload.
  """
  use ExUnit.Case, async: true

  alias Genswarms.Telegram.Delivery
  alias Genswarms.Telegram.Objects.Sender

  defmodule Effects do
    @behaviour Genswarms.Telegram.DeliveryEffects

    @impl true
    def before_send(payload, %{test_pid: pid}) do
      send(pid, {:payload, payload})
      :ok
    end

    @impl true
    def after_send(_payload, _result), do: :ok
    @impl true
    def delivery_failed(_payload, _reason), do: :ok
    @impl true
    def redact_outbound(text, _meta), do: text
  end

  @cid "tg:-100777:0"

  defp booted_state do
    {:ok, state} =
      Sender.init(%{
        dry_run: true,
        send_sources: [:host],
        delivery_effects: {Effects, %{test_pid: self()}}
      })

    state
  end

  defp send!(msg) do
    {:noreply, _state} = Sender.handle_message(:host, Map.put(msg, "action", "send"), booted_state())
    assert_receive {:payload, payload}
    payload
  end

  # ── the builder ───────────────────────────────────────────────────────────

  test "no option: the long-standing default, previews off" do
    payload = Delivery.build_send_message(%{conversation_id: @cid, text: "see https://x.com/a/1"})

    assert payload.disable_web_page_preview == true
    refute Map.has_key?(payload, :link_preview_options)
  end

  test "an explicit option wins, and the deprecated flag is then omitted" do
    payload =
      Delivery.build_send_message(%{
        conversation_id: @cid,
        text: "see https://x.com/a/1",
        link_preview_options: %{is_disabled: false}
      })

    assert payload.link_preview_options == %{is_disabled: false}

    # Bot API 7.0 deprecated disable_web_page_preview in favour of
    # link_preview_options; sending both would be contradictory.
    refute Map.has_key?(payload, :disable_web_page_preview)
  end

  test "the option can also turn a preview OFF explicitly, and carries its own fields" do
    payload =
      Delivery.build_send_message(%{
        conversation_id: @cid,
        text: "x",
        link_preview_options: %{is_disabled: true}
      })

    assert payload.link_preview_options == %{is_disabled: true}

    large =
      Delivery.build_send_message(%{
        conversation_id: @cid,
        text: "x",
        link_preview_options: %{url: "https://example.com", prefer_large_media: true}
      })

    assert large.link_preview_options == %{url: "https://example.com", prefer_large_media: true}
  end

  test "the option is read by string key too (option/2, as the edit builder does)" do
    payload =
      Delivery.build_send_message(%{
        :conversation_id => @cid,
        :text => "x",
        "link_preview_options" => %{"is_disabled" => false}
      })

    assert payload.link_preview_options == %{"is_disabled" => false}
  end

  test "a non-object option is refused rather than silently dropped" do
    assert_raise ArgumentError, fn ->
      Delivery.build_send_message(%{
        conversation_id: @cid,
        text: "x",
        link_preview_options: "yes please"
      })
    end
  end

  # ── the sender's send path ────────────────────────────────────────────────

  test "send: the message's option reaches the payload" do
    payload =
      send!(%{
        "conversation_id" => @cid,
        "text" => "Read this: https://x.com/genlayer/status/1",
        "link_preview_options" => %{"is_disabled" => false}
      })

    assert payload.link_preview_options == %{"is_disabled" => false}
    refute Map.has_key?(payload, :disable_web_page_preview)
  end

  test "send: without the option nothing changes for existing hosts" do
    payload = send!(%{"conversation_id" => @cid, "text" => "plain https://x.com/a/1"})

    assert payload.disable_web_page_preview == true
    refute Map.has_key?(payload, :link_preview_options)
  end
end

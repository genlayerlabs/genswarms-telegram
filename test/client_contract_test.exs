defmodule Genswarms.Telegram.ClientContractTest do
  use ExUnit.Case

  alias Genswarms.Telegram.Client
  alias Genswarms.Telegram.Client.Fake

  defmodule ProcessAdapter do
    @behaviour Genswarms.Telegram.Client

    @impl true
    def request(method, payload, opts) do
      calls = Process.get(:client_contract_calls, [])
      Process.put(:client_contract_calls, [{method, payload, opts} | calls])
      {:ok, true}
    end
  end

  @helper_functions [
    :classify_response,
    :dead_chat_description?,
    :method_name,
    :request
  ]

  @empty_payload_wrappers [
    :close,
    :get_available_gifts,
    :get_forum_topic_icon_stickers,
    :get_me,
    :get_my_star_balance,
    :get_webhook_info,
    :logout
  ]

  test "every public Bot API wrapper dispatches the matching method through the adapter" do
    {:ok, fake} = Fake.start_link()

    payload = %{
      chat_id: 123,
      user_id: 456,
      message_id: 789,
      file_id: "file-1",
      name: "example"
    }

    wrapper_methods = wrapper_methods()

    assert wrapper_methods != []

    Enum.each(wrapper_methods, fn method ->
      assert {:ok, _} = call_wrapper(method, payload, fake)
    end)

    calls = Fake.calls(fake)
    assert Enum.map(calls, & &1.method) == wrapper_methods

    Enum.each(calls, fn call ->
      assert Client.method_name(call.method) =~ ~r/^[a-zA-Z]+$/

      if call.method in @empty_payload_wrappers do
        assert call.payload == %{}
      else
        assert call.payload == payload
      end
    end)
  end

  test "client wrappers default opts to an empty keyword list without changing method or payload" do
    Process.put(:client_contract_calls, [])

    payload = %{
      chat_id: 123,
      user_id: 456,
      message_id: 789,
      file_id: "file-1",
      name: "example"
    }

    assert {:ok, true} = Client.request(ProcessAdapter, :get_me, %{})

    Enum.each(wrapper_methods(), fn method ->
      assert {:ok, true} = call_wrapper_with_default_opts(method, payload)
    end)

    calls = Process.get(:client_contract_calls) |> Enum.reverse()
    [{:get_me, %{}, []} | wrapper_calls] = calls

    assert Enum.map(wrapper_calls, &elem(&1, 0)) == wrapper_methods()

    Enum.each(wrapper_calls, fn {method, sent_payload, opts} ->
      assert opts == []

      if method in @empty_payload_wrappers do
        assert sent_payload == %{}
      else
        assert sent_payload == payload
      end
    end)
  after
    Process.delete(:client_contract_calls)
  end

  test "response classification distinguishes parse errors, dead chats, transient failures, and bad JSON" do
    assert {:error, {:parse_error, description}} =
             Client.classify_response(
               400,
               Jason.encode!(%{
                 ok: false,
                 error_code: 400,
                 description: "Bad Request: can't parse entities"
               })
             )

    assert description =~ "parse entities"

    assert {:error, {:dead_chat, 403, description}} =
             Client.classify_response(
               403,
               Jason.encode!(%{
                 ok: false,
                 error_code: 403,
                 description: "Forbidden: bot was blocked by the user"
               })
             )

    assert description =~ "blocked"

    assert {:error, {:transient, 502, "upstream unavailable"}} =
             Client.classify_response(
               502,
               Jason.encode!(%{ok: false, error_code: 502, description: "upstream unavailable"})
             )

    assert {:error, {:bad_json, 200, "not json"}} = Client.classify_response(200, "not json")
    refute Client.dead_chat_description?(nil)
  end

  defp telegram_method?(method) do
    _ = Client.method_name(method)
    true
  rescue
    KeyError -> false
  end

  defp wrapper_methods do
    Client.__info__(:functions)
    |> Enum.map(&elem(&1, 0))
    |> Enum.uniq()
    |> Enum.reject(&(&1 in @helper_functions))
    |> Enum.filter(&telegram_method?/1)
    |> Enum.sort()
  end

  defp call_wrapper(method, _payload, fake) when method in @empty_payload_wrappers,
    do: apply(Client, method, [Fake, [fake: fake]])

  defp call_wrapper(method, payload, fake),
    do: apply(Client, method, [Fake, payload, [fake: fake]])

  defp call_wrapper_with_default_opts(method, _payload) when method in @empty_payload_wrappers,
    do: apply(Client, method, [ProcessAdapter])

  defp call_wrapper_with_default_opts(method, payload),
    do: apply(Client, method, [ProcessAdapter, payload])
end

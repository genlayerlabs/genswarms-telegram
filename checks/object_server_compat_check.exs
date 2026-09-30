# Real Genswarms ObjectServer compatibility for the Telegram package.
#
# Run: MIX_ENV=dev mix run checks/object_server_compat_check.exs

Application.ensure_all_started(:genswarms)

alias Genswarms.Objects.ObjectServer
alias Genswarms.Routing.Router
alias Genswarms.Telegram.Objects.{Ingress, Sender}

defmodule Genswarms.Telegram.ObjectServerCompat.CaptureClient do
  @behaviour Genswarms.Telegram.Client

  @impl true
  def request(method, payload, opts) do
    send(Keyword.fetch!(opts, :notify), {:telegram_request, method, payload})

    case method do
      :get_me -> {:ok, %{"username" => "CompatBot", "id" => 1}}
      :send_message -> {:ok, %{"message_id" => 1}}
      _ -> {:ok, true}
    end
  end
end

defmodule Genswarms.Telegram.ObjectServerCompat.CommandRouter do
  @behaviour Genswarms.Telegram.CommandRouter

  @impl true
  def handle_command(event, _state) do
    {:send, :probe, %{action: "probe", text: event.text, conversation_id: event.conversation_id}}
  end

  @impl true
  def handle_callback(_event, _state), do: :ok
end

defmodule Genswarms.Telegram.ObjectServerCompat.Probe do
  def init(config), do: {:ok, config}
  def interface, do: %{}

  def handle_message(from, content, state) do
    send(state.owner, {:probe_received, from, Jason.decode!(content)})
    {:noreply, state}
  end
end

check = fn label, fun ->
  result =
    try do
      fun.()
    rescue
      _ -> false
    catch
      _, _ -> false
    end

  if result do
    IO.puts("ok   #{label}")
  else
    IO.puts("FAIL #{label}")
    Process.put(:object_server_compat_failed, true)
  end
end

stop_server = fn server ->
  try do
    if Process.alive?(server), do: GenServer.stop(server)
  catch
    :exit, _ -> :ok
  end
end

swarm = "telegram-object-compat-#{System.unique_integer([:positive])}"
state_dir = Path.join(System.tmp_dir!(), swarm)
previous_state_dir = Application.get_env(:genswarms_telegram, :state_dir)
Application.put_env(:genswarms_telegram, :state_dir, state_dir)

:ok = Router.register_topology(swarm, [{:telegram_ingress, :probe}])

{:ok, probe} =
  ObjectServer.start_link(
    name: :probe,
    swarm_name: swarm,
    handler: Genswarms.Telegram.ObjectServerCompat.Probe,
    config: %{owner: self()}
  )

{:ok, ingress} =
  ObjectServer.start_link(
    name: :telegram_ingress,
    swarm_name: swarm,
    handler: Ingress,
    config: %{
      bot_token: "test-token",
      bot_username: "CompatBot",
      client: Genswarms.Telegram.ObjectServerCompat.CaptureClient,
      client_opts: [notify: self()],
      command_router: Genswarms.Telegram.ObjectServerCompat.CommandRouter,
      sender: :telegram_sender,
      binding_authority: :telegram_ingress,
      poll_enabled: false
    }
  )

{:ok, sender} =
  ObjectServer.start_link(
    name: :telegram_sender,
    swarm_name: swarm,
    handler: Sender,
    config: %{
      bot_token: "test-token",
      client: Genswarms.Telegram.ObjectServerCompat.CaptureClient,
      client_opts: [notify: self()],
      binding_authority: :telegram_ingress,
      slot_prefix: "telegram_agent",
      send_sources: [:telegram_ingress]
    }
  )

Enum.each([probe, ingress, sender], &Process.unlink/1)

ObjectServer.deliver_message(
  swarm,
  :telegram_ingress,
  :test_driver,
  Jason.encode!(%{
    action: "inject_update",
    update: %{
      "update_id" => 1,
      "message" => %{
        "chat" => %{"id" => 123, "type" => "private"},
        "message_id" => 10,
        "from" => %{"id" => 777, "username" => "alice"},
        "text" => "/probe"
      }
    }
  })
)

check.("inject_update routes a command result through ObjectServer", fn ->
  receive do
    {:probe_received, :telegram_ingress,
     %{"action" => "probe", "text" => "/probe", "conversation_id" => "tg:123:0"}} ->
      true
  after
    1_000 -> false
  end
end)

ObjectServer.deliver_message(
  swarm,
  :telegram_sender,
  :telegram_ingress,
  Jason.encode!(%{action: "bind_session", slot: "telegram_agent_0", conversation_id: "tg:1:0"})
)

ObjectServer.deliver_message(
  swarm,
  :telegram_sender,
  :telegram_agent_0,
  Jason.encode!(%{action: "reply", conversation_id: "tg:999:0", text: "bound reply"})
)

check.("bound reply ignores a forged payload conversation id", fn ->
  receive do
    {:telegram_request, :send_message, %{chat_id: "1", text: "bound reply"}} -> true
  after
    1_000 -> false
  end
end)

Enum.each([probe, ingress, sender], stop_server)
Router.unregister_topology(swarm)
File.rm_rf(state_dir)

if previous_state_dir do
  Application.put_env(:genswarms_telegram, :state_dir, previous_state_dir)
else
  Application.delete_env(:genswarms_telegram, :state_dir)
end

if Process.get(:object_server_compat_failed), do: System.halt(1)

defmodule Genswarms.Telegram.SessionRuntime.Default do
  @moduledoc """
  Small default session runtime.

  This default prepares a local workspace and returns an opaque slot. Hosts can
  provide a `:deliver` function for tests, or provide `:swarm_name` plus an
  `:agent_template` to spawn and deliver through GenSwarms when those modules are
  available.
  """

  @behaviour Genswarms.Telegram.SessionRuntime
  @pool_table :genswarms_telegram_session_runtime_default_pools

  @impl true
  def ensure_session(conversation_id, opts) do
    prefix = slot_prefix(opts)
    pool_size = pool_size(opts)
    bot_ref = Map.get(opts, :bot_ref, "default") |> Genswarms.Telegram.BotRef.path_key()
    {slot, evicted} = lease_slot(conversation_id, prefix, pool_size, bot_ref, opts)

    workspace =
      Path.join([
        workspace_root(opts),
        bot_ref,
        Genswarms.Telegram.ConversationId.encode_for_path(conversation_id)
      ])

    if Map.get(opts, :wipe_workspace_on_ensure, false), do: File.rm_rf(workspace)
    File.mkdir_p!(workspace)

    env = %{
      Map.get(opts, :conversation_env, "GENSWARMS_TELEGRAM_CONVERSATION_ID") => conversation_id
    }

    session = %{
      slot: slot,
      conversation_id: conversation_id,
      workspace: workspace,
      env: env,
      binding_sinks: Map.get(opts, :binding_sinks, []),
      evicted: evicted
    }

    with :ok <- maybe_spawn_agent(session, opts) do
      {:ok, session}
    end
  end

  @impl true
  def bind_session(session, conversation_id, sinks, opts) do
    cond do
      sinks == [] ->
        :ok

      fun = Map.get(opts, :bind) ->
        fun.(session, conversation_id, sinks)

      Map.has_key?(opts, :deliver) ->
        :ok

      true ->
        bind_with_genswarms(session, conversation_id, sinks, opts)
    end
  end

  @impl true
  def deliver_to_session(session, text, opts) do
    case Map.get(opts, :deliver) do
      fun when is_function(fun, 2) -> fun.(session, text)
      nil -> deliver_with_genswarms(session, text, opts)
    end
  end

  @impl true
  def teardown_session(session, _reason, opts) do
    if Map.get(opts, :wipe_workspace, true), do: File.rm_rf(Map.get(session, :workspace))
    release_slot(session, opts)
    :ok
  end

  def workspace_root(opts \\ %{}) do
    Map.get(opts, :workspace_root) ||
      Path.join(System.get_env("TMPDIR") || "/tmp", "genswarms-telegram")
  end

  defp maybe_spawn_agent(_session, %{agent_template: nil}), do: :ok
  defp maybe_spawn_agent(_session, opts) when not is_map_key(opts, :agent_template), do: :ok

  defp maybe_spawn_agent(session, opts) do
    with {:ok, swarm_manager} <- loaded_module(Genswarms.SwarmManager),
         swarm_name when is_binary(swarm_name) <- Map.get(opts, :swarm_name),
         template when is_map(template) <- Map.get(opts, :agent_template) do
      if evicted = Map.get(session, :evicted) do
        maybe_remove_agent(swarm_name, evicted.slot)
      end

      spec = %{
        name: session.slot,
        backend:
          backend_with_session(
            template[:backend] || Map.get(template, "backend") || :local,
            session
          ),
        skills: template[:skills] || Map.get(template, "skills") || []
      }

      route_opts = [
        connections:
          template[:connections] || Map.get(template, "connections") || session.binding_sinks,
        incoming: template[:incoming] || Map.get(template, "incoming") || [],
        persist: template[:persist] || Map.get(template, "persist") || false
      ]

      case apply(swarm_manager, :add_agent, [swarm_name, spec, route_opts]) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
        {:error, {:already_exists, _}} -> :ok
        {:error, reason} -> {:error, reason}
        other -> other
      end
    else
      false -> {:error, :genswarms_not_loaded}
      nil -> {:error, :missing_swarm_name}
      _ -> {:error, :invalid_agent_template}
    end
  end

  defp maybe_remove_agent(swarm_name, slot) do
    case loaded_module(Genswarms.SwarmManager) do
      {:ok, swarm_manager} ->
        if function_exported?(swarm_manager, :remove_agent, 2) do
          apply(swarm_manager, :remove_agent, [swarm_name, slot])
        end

        :ok

      false ->
        :ok
    end
  end

  defp deliver_with_genswarms(session, text, opts) do
    with {:ok, agent_server} <- loaded_module(Genswarms.Agents.AgentServer),
         swarm_name when is_binary(swarm_name) <- Map.get(opts, :swarm_name) do
      apply(agent_server, :send_task, [swarm_name, session.slot, text])
    else
      false -> {:error, :genswarms_not_loaded}
      nil -> {:error, :no_delivery_adapter}
    end
  end

  defp bind_with_genswarms(session, conversation_id, sinks, opts) do
    with {:ok, object_server} <- loaded_module(Genswarms.Objects.ObjectServer),
         swarm_name when is_binary(swarm_name) <- Map.get(opts, :swarm_name) do
      binding_source = Map.get(opts, :binding_authority, :telegram_ingress)

      Enum.reduce_while(sinks, :ok, fn sink, :ok ->
        if evicted = Map.get(session, :evicted) do
          unbind = Jason.encode!(%{action: "unbind_session", slot: to_string(evicted.slot)})
          apply(object_server, :deliver_message, [swarm_name, sink, binding_source, unbind])
        end

        bind =
          Jason.encode!(%{
            action: "bind_session",
            slot: to_string(session.slot),
            conversation_id: conversation_id
          })

        apply(object_server, :deliver_message, [swarm_name, sink, binding_source, bind])

        case binding_barrier(object_server, swarm_name, sink) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    else
      false -> {:error, :genswarms_not_loaded}
      nil -> {:error, :no_binding_adapter}
    end
  end

  defp binding_barrier(object_server, swarm_name, sink) do
    if function_exported?(object_server, :get_state, 2) do
      try do
        _ = apply(object_server, :get_state, [swarm_name, sink])
        :ok
      catch
        :exit, reason -> {:error, {:binding_barrier_failed, reason}}
      end
    else
      {:error, :no_ordered_binding_barrier}
    end
  end

  defp loaded_module(module) do
    if Code.ensure_loaded?(module), do: {:ok, module}, else: false
  end

  defp backend_with_session({:bwrap, backend_opts}, session) when is_map(backend_opts) do
    {:bwrap, Map.merge(backend_opts, %{workspace: session.workspace, extra_env: session.env})}
  end

  defp backend_with_session({:docker, image, backend_opts}, session) when is_map(backend_opts) do
    env = Map.merge(Map.get(backend_opts, :env, %{}), session.env)
    {:docker, image, backend_opts |> Map.put(:workspace, session.workspace) |> Map.put(:env, env)}
  end

  defp backend_with_session(backend, session) when backend in [:local, :bwrap] do
    {backend, %{workspace: session.workspace, extra_env: session.env}}
  end

  defp backend_with_session(backend, _session), do: backend

  defp lease_slot(conversation_id, prefix, pool_size, bot_ref, opts) do
    key = {workspace_root(opts), bot_ref, prefix, pool_size}

    :global.trans({__MODULE__, key}, fn ->
      ensure_pool_table()
      pool = read_pool(key, prefix, pool_size)
      {slot, evicted, pool} = pool_lease(pool, conversation_id)
      :ets.insert(@pool_table, {key, pool})

      if evicted && Map.get(opts, :wipe_workspace_on_evict, true) do
        File.rm_rf(evicted_workspace(evicted.conversation_id, bot_ref, opts))
      end

      {slot, evicted}
    end)
  end

  defp release_slot(%{conversation_id: conversation_id, slot: slot}, opts) do
    bot_ref = Map.get(opts, :bot_ref, "default") |> Genswarms.Telegram.BotRef.path_key()
    prefix = slot_prefix(opts)
    pool_size = pool_size(opts)
    key = {workspace_root(opts), bot_ref, prefix, pool_size}

    :global.trans({__MODULE__, key}, fn ->
      ensure_pool_table()
      pool = read_pool(key, prefix, pool_size)

      if Map.get(pool.assigned, conversation_id) == slot do
        assigned = Map.delete(pool.assigned, conversation_id)
        seq = Map.delete(pool.seq, conversation_id)
        pool = %{pool | assigned: assigned, seq: seq, free: [slot | pool.free]}
        :ets.insert(@pool_table, {key, pool})
      end
    end)
  end

  defp release_slot(_session, _opts), do: :ok

  defp read_pool(key, prefix, pool_size) do
    case :ets.lookup(@pool_table, key) do
      [{^key, pool}] -> pool
      [] -> new_pool(prefix, pool_size)
    end
  end

  defp new_pool(prefix, pool_size) when pool_size > 0 do
    slots = for i <- 0..(pool_size - 1), do: String.to_atom("#{prefix}_#{i}")
    %{free: slots, assigned: %{}, seq: %{}, clock: 0}
  end

  defp pool_lease(pool, conversation_id) do
    case Map.get(pool.assigned, conversation_id) do
      nil ->
        case pool.free do
          [slot | rest] ->
            pool =
              touch(
                %{pool | free: rest, assigned: Map.put(pool.assigned, conversation_id, slot)},
                conversation_id
              )

            {slot, nil, pool}

          [] ->
            {victim, _seq} = Enum.min_by(pool.seq, fn {_cid, seq} -> seq end)
            slot = Map.fetch!(pool.assigned, victim)
            evicted = %{conversation_id: victim, slot: slot}
            assigned = pool.assigned |> Map.delete(victim) |> Map.put(conversation_id, slot)

            pool =
              touch(
                %{pool | assigned: assigned, seq: Map.delete(pool.seq, victim)},
                conversation_id
              )

            {slot, evicted, pool}
        end

      slot ->
        {slot, nil, touch(pool, conversation_id)}
    end
  end

  defp touch(pool, conversation_id) do
    clock = pool.clock + 1
    %{pool | clock: clock, seq: Map.put(pool.seq, conversation_id, clock)}
  end

  defp ensure_pool_table do
    case :ets.whereis(@pool_table) do
      :undefined -> :ets.new(@pool_table, [:named_table, :public, read_concurrency: true])
      _tid -> @pool_table
    end
  rescue
    ArgumentError -> @pool_table
  end

  defp evicted_workspace(conversation_id, bot_ref, opts) do
    Path.join([
      workspace_root(opts),
      bot_ref,
      Genswarms.Telegram.ConversationId.encode_for_path(conversation_id)
    ])
  end

  defp slot_prefix(opts) do
    opts
    |> Map.get(:slot_prefix, "telegram_agent")
    |> Genswarms.Telegram.BotRef.path_key()
  end

  defp pool_size(opts) do
    case Map.get(opts, :pool_size, 32) do
      value when is_integer(value) and value > 0 -> value
      _ -> 32
    end
  end
end

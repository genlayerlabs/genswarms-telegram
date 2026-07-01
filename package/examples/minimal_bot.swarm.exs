%{
  name: "telegram-minimal",
  agents: [],
  objects: [
    %{
      name: :telegram_sender,
      handler: Genswarms.Telegram.Objects.Sender,
      config: %{
        bot_token: System.fetch_env!("GENSWARMS_TELEGRAM_BOT_TOKEN"),
        client: Genswarms.Telegram.Client.Curl,
        binding_authority: :telegram_ingress,
        slot_prefix: "telegram_agent"
      }
    },
    %{
      name: :telegram_ingress,
      handler: Genswarms.Telegram.Objects.Ingress,
      config: %{
        bot_token: System.fetch_env!("GENSWARMS_TELEGRAM_BOT_TOKEN"),
        bot_username: System.get_env("GENSWARMS_TELEGRAM_BOT_USERNAME"),
        client: Genswarms.Telegram.Client.Curl,
        sender: :telegram_sender,
        poll_enabled: true,
        session_opts: %{
          swarm_name: "telegram-minimal",
          slot_prefix: "telegram_agent",
          agent_template: %{
            backend: :local,
            skills: [],
            connections: [:telegram_sender],
            incoming: []
          }
        },
        binding_sinks: [:telegram_sender]
      }
    }
  ],
  topology: []
}

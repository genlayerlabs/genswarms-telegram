defmodule GenswarmsTelegramEditor.MixProject do
  use Mix.Project

  def project do
    [
      app: :genswarms_telegram_editor,
      version: "0.6.0",
      elixir: "~> 1.14",
      description:
        "Telegram rich-message preview renderer and editor shell for genswarms-telegram (dev tooling; zero runtime deps)",
      start_permanent: false,
      deps: deps()
    ]
  end

  def application, do: [extra_applications: []]

  defp deps do
    [
      # Dev/test only: round-trip fixtures come from the sibling main package.
      {:genswarms_telegram, path: "..", only: [:dev, :test]},
      {:jason, "~> 1.4", only: [:dev, :test]}
    ]
  end
end

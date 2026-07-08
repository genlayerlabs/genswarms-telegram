defmodule GenswarmsTelegram.MixProject do
  use Mix.Project

  def project do
    [
      app: :genswarms_telegram,
      version: "0.4.4",
      elixir: "~> 1.14",
      description: "Reusable Telegram transport and GenSwarms object handlers",
      package: package(),
      source_url: "https://github.com/genlayerlabs/genswarms-telegram",
      homepage_url: "https://github.com/genlayerlabs/genswarms-telegram",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["GenLayer Labs"],
      files: [
        "lib",
        "priv",
        "docs",
        "examples",
        "mix.exs",
        "README.md",
        "LICENSE",
        "CHANGELOG.md",
        "swarmidx.json"
      ],
      links: %{"GitHub" => "https://github.com/genlayerlabs/genswarms-telegram"}
    ]
  end
end

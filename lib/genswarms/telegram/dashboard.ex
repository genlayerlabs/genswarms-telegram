defmodule Genswarms.Telegram.Dashboard do
  @moduledoc """
  The REFERENCE dashboard shaping for Telegram-transport swarms, plus this
  package's implementation of the genswarms-dashboard extension contract
  (schema 1).

  Two rules govern this module:

    * *The adapter between two packages lives in the package that owns the
      specifics* — labels, dm/group kinds and `transport_ref` shaping are
      Telegram knowledge, so they live HERE, not copied into every host
      (before this module, every host carried its own duplicate of it).
    * *Peer contract as data* — there is NO compile dependency on
      genswarms-dashboard in either direction. This module only builds maps in
      the documented shapes (`GenswarmsDashboard.Extensions` moduledoc / the
      backend README); the host's `DataSource` passes them along.

  ## Session shaping (for the host's `DataSource.snapshot/1` rows)

      Genswarms.Telegram.Dashboard.session_row("tg:123:0", user: %{"handle" => "fia"})
      #=> %{session_id: "tg:123:0", label: "@fia", transport: "telegram",
      #     transport_ref: %{"chat_id" => "123", "thread_id" => "0"},
      #     user: %{"handle" => "fia"}, metadata: %{"chat_type" => "dm"}}

  ## The extension page

      extensions = GenswarmsDashboard.Extensions.collect(
        [Genswarms.Telegram.Dashboard.dashboard_extension(sessions: rows), MyOtherProvider]
      )

  (or call `dashboard_extension(sessions: rows)` directly and merge by hand).
  """

  alias Genswarms.Telegram.ConversationId

  @schema 1
  @max_table_rows 100

  # ── reference session shaping ────────────────────────────────────────────────

  @doc """
  The display label for a conversation: `@handle` when known, else the user's
  name, else the raw chat id off the cid. Never parses beyond what
  `ConversationId` owns — this IS the module hosts delegate that knowledge to.
  """
  def session_label(user, cid) do
    handle = present(user_field(user, "handle"))
    name = present(user_field(user, "name"))

    cond do
      handle -> "@" <> handle
      name -> name
      true -> ConversationId.chat_id(cid)
    end
  end

  @doc ~s(The dashboard `kind` for a cid: "dm" | "group" | "unknown".)
  def kind(cid), do: cid |> ConversationId.chat_type() |> to_string()

  @doc "The wire `transport_ref` for a Telegram cid."
  def transport_ref(cid) do
    case ConversationId.parse(cid) do
      {:ok, %{chat_id: chat, thread_id: thread}} -> %{"chat_id" => chat, "thread_id" => thread}
      :error -> %{}
    end
  end

  @doc """
  A dashboard session row (the generic shape, Telegram-flavored). `attrs` may
  carry `:user`, `:metadata`, `:last_activity` — merged over the shaped base.
  """
  def session_row(cid, attrs \\ []) do
    user = Keyword.get(attrs, :user)

    %{
      session_id: cid,
      label: session_label(user, cid),
      transport: "telegram",
      transport_ref: transport_ref(cid),
      user: user,
      metadata: Map.merge(%{"chat_type" => kind(cid)}, Keyword.get(attrs, :metadata, %{})),
      last_activity: Keyword.get(attrs, :last_activity)
    }
  end

  # ── the extension contract (schema 1) ────────────────────────────────────────

  @doc """
  This package's `dashboard_extension/1` (contract schema #{@schema}): a
  "Telegram" page with conversation metrics (total / DMs / groups) and a capped
  conversations table, plus a `"telegram"` summary block.

  Pass the host's session rows via `opts[:sessions]` (any maps carrying
  `session_id`/`"session_id"`; label/user/last_activity used when present).
  """
  def dashboard_extension(opts \\ []) do
    sessions = Keyword.get(opts, :sessions, [])
    kinds = Enum.map(sessions, &kind(field(&1, :session_id) || ""))
    dms = Enum.count(kinds, &(&1 == "dm"))
    groups = Enum.count(kinds, &(&1 == "group"))

    %{
      "telegram" => %{
        "conversations" => length(sessions),
        "dms" => dms,
        "groups" => groups
      },
      "dashboard_pages" => [
        %{
          "schema" => @schema,
          "id" => "telegram",
          "label" => "Telegram",
          "icon" => "hero-chat-bubble-left-right",
          "meta" => "transport: telegram",
          "sections" => [
            %{
              "type" => "metrics",
              "title" => "Conversations",
              "items" => [
                %{"label" => "Total", "value" => length(sessions)},
                %{"label" => "DMs", "value" => dms},
                %{"label" => "Groups", "value" => groups}
              ]
            },
            %{
              "type" => "table",
              "title" => "Conversations",
              "meta" => "labels come from the roster; ids stay opaque",
              "columns" => [
                %{"key" => "label", "label" => "conversation"},
                %{"key" => "kind", "label" => "kind"},
                %{"key" => "cid", "label" => "id", "mono" => true},
                %{"key" => "last", "label" => "last activity", "align" => "right"}
              ],
              "rows" =>
                sessions
                |> Enum.take(@max_table_rows)
                |> Enum.map(fn s ->
                  cid = field(s, :session_id) || ""

                  %{
                    "label" => field(s, :label) || session_label(field(s, :user), cid),
                    "kind" => kind(cid),
                    "cid" => cid,
                    "last" => to_string(field(s, :last_activity) || "—")
                  }
                end)
            }
          ]
        }
      ]
    }
  end

  defp field(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp field(_, _), do: nil

  defp user_field(user, "handle") when is_map(user),
    do: Map.get(user, "handle") || Map.get(user, :handle)

  defp user_field(user, "name") when is_map(user),
    do: Map.get(user, "name") || Map.get(user, :name)

  defp user_field(_, _), do: nil

  defp present(v) when is_binary(v), do: if(String.trim(v) == "", do: nil, else: v)
  defp present(_), do: nil
end

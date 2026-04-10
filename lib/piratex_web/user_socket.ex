defmodule PiratexWeb.UserSocket do
  @moduledoc """
  Phoenix Socket for non-LiveView clients (the TUI, and future bots).

  Mounted at `/socket`. Authentication is per-game, not per-socket: the
  socket accepts any `player_token` at connect time and defers validation
  to the channel `join/3`. An empty or missing token is permitted so
  watch-only clients can connect without registering as a player.
  """

  use Phoenix.Socket

  channel "game:*", PiratexWeb.GameChannel

  @impl true
  def connect(params, socket, _connect_info) do
    token = Map.get(params, "player_token", "")
    client = Map.get(params, "client", "unknown")

    socket =
      socket
      |> assign(:player_token, token)
      |> assign(:client, client)

    {:ok, socket}
  end

  @impl true
  def id(%{assigns: %{player_token: ""}}), do: nil
  def id(%{assigns: %{player_token: token}}), do: "users_socket:#{token}"
end

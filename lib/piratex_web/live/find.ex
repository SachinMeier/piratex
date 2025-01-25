defmodule PiratexWeb.Live.FindLive do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  alias Piratex.Game

  def mount(_params, session, socket) do
    case PiratexWeb.GameSession.rejoin_game_from_session(session, socket) do
      {:found, socket} -> {:ok, socket}

      {:not_found, socket} ->
        {:ok, assign(socket,
          valid_game_id: false,
          games: Piratex.DynamicSupervisor.list_games()
        )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto">
      <%= if false do %>
        <.tile_word word="Join Game" />
      <% end %>
      <.form for={%{}} phx-change="validate" phx-submit="join" class="flex flex-col gap-2 mx-auto max-w-48">
        <.ps_text_input id="game_id_input" name="id" field={:id} placeholder="Game ID" value=""/>
        <.ps_button type="submit" disabled={!@valid_game_id} disabled_style={false}>
          <div phx-disable-with="Joining..." class="select-none">Join</div>
        </.ps_button>
      </.form>

      <div class="flex flex-col w-full">
      <%= if length(@games) != 0 do %>
        <.tile_word word="Games" class="my-8 mx-auto" />
        <%= for game <- @games do %>
          <.link class="mx-auto" href={~p"/game/#{game.id}/join"}>
          <%= game.id %>
        </.link>
        <% end %>
      <% end %>
      <.ps_button to={~p"/game/new"} type="button" class="mt-8 mx-auto">
          NEW GAME
      </.ps_button>
    </div>
    </div>
    """
  end

  def handle_event("join", %{"id" => id}, socket) do
    case Game.find_by_id(id) do
      {:ok, %{status: :waiting}} ->
        socket =
          socket
          |> put_flash(:info, "Game found, joining...")
          |> redirect(to: ~p"/game/#{id}/join")

        {:noreply, socket}

      {:ok, %{status: :playing}} ->
        # |> put_flash(:error, "Game already started")
        socket =
          socket
          |> redirect(to: ~p"/game/#{id}/join")

        {:noreply, socket}

      {:ok, %{status: :finished}} ->
        socket = put_flash(socket, :error, "Game already finished")
        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Game not found")
        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"id" => id}, socket) do
    {:noreply, assign(socket, valid_game_id: String.length(id) >= 4)}
  end
end

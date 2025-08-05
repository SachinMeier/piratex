defmodule PiratexWeb.Live.Find do
  use PiratexWeb, :live_view

  import PiratexWeb.Live.Helpers
  import PiratexWeb.Components.PiratexComponents

  alias Piratex.Game

  def mount(_params, session, socket) do
    # if user is already a part of a game, rejoin it automatically
    case PiratexWeb.GameSession.rejoin_game_from_session(session, socket) do
      {:found, socket} ->
        ok(socket)

      {:not_found, socket} ->
        socket
        |> assign(
          valid_game_id: false,
          games: Piratex.DynamicSupervisor.list_games()
        )
        |> ok()
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto">
      <%= if false do %>
        <.tile_word word="Join Game" />
      <% end %>
      <.form
        for={%{}}
        phx-change="validate"
        phx-submit="join"
        class="flex flex-col gap-2 mx-auto max-w-48"
      >
        <.ps_text_input id="game_id_input" name="id" field={:id} placeholder="Game ID" value="" />
        <.ps_button type="submit" disabled={!@valid_game_id} disabled_style={false}>
          <div phx-disable-with="Joining..." class="select-none">JOIN</div>
        </.ps_button>
      </.form>

      <div class="flex flex-col w-full">
        <%= if length(@games) != 0 do %>
          <.tile_word word="Games" class="my-8 mx-auto" />
          <%= for game <- @games do %>
            <.link class="mx-auto" href={~p"/game/#{game.id}/join"}>
              {game.id} ({length(game.players)})
            </.link>
          <% end %>
        <% end %>
        <.ps_button to={~p"/create_game"} class="mt-8 mx-auto">
          NEW GAME
        </.ps_button>
      </div>
    </div>
    """
  end

  def handle_event("join", %{"id" => id}, socket) do
    case Game.find_by_id(id) do
      {:ok, %{status: :waiting}} ->
        socket
        |> put_flash(:info, "Game found, joining...")
        |> redirect(to: ~p"/game/#{id}/join")
        |> noreply()

      {:ok, %{status: :playing}} ->
        # |> put_flash(:error, "Game already started")
        socket
        |> redirect(to: ~p"/game/#{id}/join")
        |> noreply()

      {:ok, %{status: :finished}} ->
        socket
        |> put_flash(:error, "Game already finished")
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Game not found")
        |> noreply()
    end
  end

  def handle_event("validate", %{"id" => id}, socket) do
    socket
    |> assign(valid_game_id: String.length(id) >= 4)
    |> noreply()
  end
end

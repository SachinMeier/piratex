defmodule PiratexWeb.Live.Find do
  use PiratexWeb, :live_view

  import PiratexWeb.Live.Helpers
  import PiratexWeb.Components.PiratexComponents

  alias Piratex.Game
  alias Piratex.DynamicSupervisor

  def mount(_params, session, socket) do
    # if user is already a part of a game, rejoin it automatically
    case PiratexWeb.GameSession.rejoin_game_from_session(session, socket) do
      {:found, socket} ->
        ok(socket)

      {:not_found, socket} ->
        socket
        |> assign(
          valid_game_id: false,
          games: [],
          games_page: 1,
          games_has_next: false
        )
        |> load_games_page(1)
        |> assign_seo_metadata()
        |> ok()
    end
  end

  def assign_seo_metadata(socket) do
    title = "Find Game | Pirate Scrabble"
    description = "Find or create a Pirate Scrabble game"

    assign(socket,
      seo_metadata: %{
        og_title: title,
        og_description: description,
        twitter_title: title,
        twitter_description: description
      }
    )
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
          <div :if={@games_page > 1 or @games_has_next} class="flex items-center justify-center gap-4 mt-4">
            <.ps_button phx-click="prev_page" disabled={@games_page == 1}>
              PREV
            </.ps_button>
            <div>Page {@games_page}</div>
            <.ps_button phx-click="next_page" disabled={!@games_has_next}>
              NEXT
            </.ps_button>
          </div>
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

  def handle_event("next_page", _params, socket) do
    socket
    |> load_games_page(socket.assigns.games_page + 1)
    |> noreply()
  end

  def handle_event("prev_page", _params, socket) do
    socket
    |> load_games_page(socket.assigns.games_page - 1)
    |> noreply()
  end

  defp load_games_page(socket, page) do
    %{games: games, page: current_page, has_next: has_next} =
      DynamicSupervisor.list_games_page(page: page)

    assign(socket,
      games: games,
      games_page: current_page,
      games_has_next: has_next
    )
  end
end

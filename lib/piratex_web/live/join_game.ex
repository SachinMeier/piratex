defmodule PiratexWeb.Live.JoinGame do
  use PiratexWeb, :live_view

  import PiratexWeb.Live.Helpers
  import PiratexWeb.Components.PiratexComponents

  alias Piratex.Config

  @impl true
  def mount(%{"id" => game_id} = _params, _session, socket) do
    case Piratex.Game.find_by_id(game_id) do
      # allow joining a game that is already playing, but only as an existing quit player
      {:ok, %{status: status}} when status in [:waiting, :playing] ->
        socket
        |> assign(
          game_id: game_id,
          valid_player_name: false,
          min_name_length: Config.min_player_name(),
          max_name_length: Config.max_player_name()
        )
        |> ok()

      _ ->
        socket
        |> put_flash(:error, "Game not found")
        |> redirect(to: ~p"/find")
        |> ok()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.form
      for={%{}}
      phx-change="validate"
      phx-submit="join"
      class="flex flex-col gap-2 mx-auto max-w-48"
    >
      <.ps_text_input
        id="player_name_input"
        name="player"
        field={:player}
        placeholder="Name"
        value=""
        maxlength={@max_name_length}
      />
      <.ps_button type="submit" disabled={!@valid_player_name} disabled_style={false}>
        JOIN
      </.ps_button>
    </.form>
    """
  end

  @impl true
  def handle_event("join", %{"player" => player_name}, socket) do
    socket
    |> redirect(to: ~p"/game/#{socket.assigns.game_id}/join_game?player=#{player_name}")
    |> noreply()
  end

  def handle_event("validate", %{"player" => player_name}, socket) do
    name_length =
      player_name
      |> String.trim()
      |> String.length()

    valid? =
      name_length >= socket.assigns.min_name_length and
        name_length <= socket.assigns.max_name_length

    socket
    |> assign(valid_player_name: valid?)
    |> noreply()
  end
end

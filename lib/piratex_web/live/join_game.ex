defmodule PiratexWeb.Live.JoinGame do
  use PiratexWeb, :live_view

  alias Piratex.Config

  import PiratexWeb.Components.PiratexComponents

  @impl true
  def mount(%{"id" => game_id} = _params, _session, socket) do
    case Piratex.Game.find_by_id(game_id) do
      {:ok, %{status: :waiting}} ->
        {:ok,
         assign(socket,
           game_id: game_id,
            valid_player_name: false,
            min_name_length: Config.min_player_name(),
            max_name_length: Config.max_player_name()
          )}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Game not found")
         |> redirect(to: ~p"/find")}
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
    {:noreply,
     redirect(socket, to: ~p"/game/#{socket.assigns.game_id}/join_game?player=#{player_name}")}
  end

  def handle_event("validate", %{"player" => player_name}, socket) do
    name_length =
      player_name
      |> String.trim()
      |> String.length()

    valid? =
      name_length >= socket.assigns.min_name_length and
        name_length <= socket.assigns.max_name_length

    {:noreply, assign(socket, valid_player_name: valid?)}
  end
end

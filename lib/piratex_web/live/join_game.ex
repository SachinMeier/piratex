defmodule PiratexWeb.Live.JoinGameLive do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  @min_player_name 3
  @max_player_name 15

  @impl true
  def mount(%{"id" => game_id} = _params, _session, socket) do
    {:ok, assign(socket,
      game_id: game_id,
      valid_player_name: false,
      min_player_name: @min_player_name,
      max_player_name: @max_player_name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.form for={%{}} phx-change="validate" phx-submit="join" class="flex flex-col gap-2 mx-auto max-w-48">
      <.ps_text_input id="player_name_input" name="player" field={:player} placeholder="Name" value="" maxlength={@max_player_name}/>
      <.ps_button type="submit" disabled={!@valid_player_name} disabled_style={false}>
        JOIN
      </.ps_button>
    </.form>
    """
  end

  @impl true
  def handle_event("join", %{"player" => player_name}, socket) do
    {:noreply, redirect(socket, to: ~p"/game/#{socket.assigns.game_id}/join_game?player=#{player_name}")}
  end

  @impl true
  def handle_event("validate", %{"player" => player_name}, socket) do
    {:noreply, assign(socket,
      valid_player_name: String.length(player_name) >= @min_player_name and String.length(player_name) <= @max_player_name)}
  end
end

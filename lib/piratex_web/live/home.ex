defmodule PiratexWeb.Live.Home do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  def mount(_params, session, socket) do
    case PiratexWeb.GameSession.rejoin_game_from_session(session, socket) do
      {:found, socket} -> {:ok, socket}
      {:not_found, socket} -> {:ok, assign(socket, flipping_title: true)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 justify-center max-w-48 mx-auto">
      <.ps_button to={~p"/create_game"}>
        NEW GAME
      </.ps_button>
      <.ps_button to={~p"/find"}>
        JOIN GAME
      </.ps_button>
      <.ps_button to={~p"/rules"}>
        RULES
      </.ps_button>
    </div>
    """
  end
end

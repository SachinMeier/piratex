defmodule PiratexWeb.Live.HomeLive do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  def mount(_params, session, socket) do
    case PiratexWeb.GameSession.rejoin_game_from_session(session, socket) do
      {:found, socket} -> {:ok, socket}
      {:not_found, socket} -> {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 justify-center max-w-48 mx-auto">
      <.ps_button to={~p"/game/new"} type="button">
        NEW GAME
      </.ps_button>
      <.ps_button to={~p"/find"} type="button">
        JOIN GAME
      </.ps_button>
      <.ps_button to={~p"/rules"} type="button">
        RULES
      </.ps_button>
      <.live_component
        module={PiratexWeb.Components.Timer}
        id="turn"
        initial_time={20}
      />
      <.ps_button phx-click="reset_timer" type="button">
        RESET
      </.ps_button>
    </div>
    """
  end

  def handle_info({:tick, time_remaining}, socket) do
    if time_remaining > 0 do
      IO.inspect("home-tick #{time_remaining}")
      send_update(self(), PiratexWeb.Components.Timer, id: "turn", time_remaining: time_remaining-1)
    end

    {:noreply, socket}
  end

  def handle_event("reset_timer", %{"id" => "turn"}, socket) do
    send_update(self(), PiratexWeb.Components.Timer, id: "turn", time_remaining: 20)
    {:noreply, socket}
  end

  def handle_event("timer_complete", %{"id" => "timer-home"}, socket) do
    socket = put_flash(socket, :info, "Timer complete")
    {:noreply, socket}
  end
end

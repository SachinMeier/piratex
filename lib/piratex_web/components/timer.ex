defmodule PiratexWeb.Components.Timer do
  use PiratexWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket,
      time_remaining: 0,
      initial_time: 0,
      timer_ref: nil
    )}
  end

  def update(%{time_remaining: time_remaining}, socket) do
    Process.send_after(self(), {:tick, time_remaining}, 1000)
    {:ok, socket |> assign(time_remaining: time_remaining)}
  end

  def update(%{initial_time: initial_time} = assigns, socket) do
    if socket.assigns[:timer_ref], do: :timer.cancel(socket.assigns.timer_ref)

    Process.send_after(self(), {:tick, initial_time}, 1000)

    {:ok, socket
    |> assign(assigns)
    |> assign(
      time_remaining: initial_time,
      initial_time: initial_time,
      # timer_ref: timer_ref
    )}
  end

  def handle_info({:tick, time_remaining}, socket) do
    new_time = max(0, time_remaining - 1)

    if new_time == 0 and socket.assigns.timer_ref do
      :timer.cancel(socket.assigns.timer_ref)
    end

    {:noreply, assign(socket, time_remaining: new_time)}
  end

  def render(assigns) do
    # transition-all duration-1000
    ~H"""
    <div class="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
      <div class="h-full bg-blue-500 "
           style={"width: #{percentage_remaining(assigns)}%"}>
      </div>
    </div>
    """
  end

  defp percentage_remaining(%{time_remaining: time_remaining, initial_time: initial_time}) do
    (time_remaining / initial_time) * 100
  end
end

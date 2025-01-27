defmodule PiratexWeb.Components.JsTimer do
  use PiratexWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket,
      time_remaining: 0,
      total_time: 0,
      percentage: 100
    )}
  end

  def update(%{initial_time: initial_time} = assigns, socket) when is_integer(initial_time) do
    socket =
      socket
      |> assign(assigns)
      |> assign(
        time_remaining: initial_time,
        total_time: initial_time,
        percentage: 100
      )
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  attr :radius, :integer, default: 20
  attr :theme, :string, default: "light"
  attr :display_controls, :boolean, default: false
  attr :autostart, :string, default: "true"

  def render(assigns) do
    # Calculate dependent dimensions based on radius
    assigns = assign(assigns,
      svg_size: assigns.radius * 2.5,
      stroke_width: assigns.radius * 0.5,
      circle_radius: assigns.radius,
      circle_center: assigns.radius * 1.25,
      dash_array: assigns.radius * 6.28  # 2 * π * radius
    )

    %{background: background_color, progress: progress_color} = timer_theme(assigns.theme)

    ~H"""
    <div class="timer-container"
      id={"timer-#{@id}"}
      data-total-time={@total_time}
      data-autostart={@autostart}
      phx-hook="Timer">
      <svg class="timer-ring" width={@svg_size} height={@svg_size} viewBox={"0 0 #{@svg_size} #{@svg_size}"}>
        <circle
          class="timer-ring-background"
          r={@circle_radius}
          cx={@circle_center}
          cy={@circle_center}
          fill="transparent"
          stroke={background_color}
          stroke-width={@stroke_width}
        />
        <circle
          class="timer-ring-progress"
          r={@circle_radius}
          cx={@circle_center}
          cy={@circle_center}
          fill="transparent"
          stroke={progress_color}
          stroke-width={@stroke_width}
          stroke-dasharray={@dash_array}
          stroke-dashoffset="0"
          transform={"rotate(-90 #{@circle_center} #{@circle_center})"}
        />
      </svg>
    </div>
    """
  end

  defp timer_theme(theme) do
    case theme do
      "dark" -> %{background: "#fff", progress: "#000"}
      "light" -> %{background: "#000", progress: "#fff"}
    end
  end

  defp timer_controls(assigns) do
    ~H"""
    <div class="timer-text">
      <%= format_time(@time_remaining) %>
    </div>
    <div class="timer-controls">
      <button class="timer-button js-timer-start">Start</button>
      <button class="timer-button js-timer-pause hidden">Pause</button>
      <button class="timer-button js-timer-resume hidden">Resume</button>
      <button class="timer-button js-timer-reset">Reset</button>
    </div>
    """
  end

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, remaining_seconds])
  end
end

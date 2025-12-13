defmodule PiratexWeb.Live.Preview do
  use PiratexWeb, :live_view

  import PiratexWeb.Live.Helpers
  import PiratexWeb.Components.HeatmapComponent

  def mount(_, _session, socket) do
    data =
      1..144
      |> Enum.map(fn k -> {k, :rand.uniform(20)} end)
      |> Map.new()

    socket
    |> assign(
      data: data,
      bar_color: "red",
      max_value: 20
    )
    |> ok()
  end

  def render(assigns) do
    ~H"""
    <.heatmap {assigns} />
    """
  end


end

defmodule PiratexWeb.Components.HeatmapComponent do
  use Phoenix.Component

  attr :data, :map, required: true
  attr :max_value, :integer, default: 25
  attr :range, :integer, default: 144
  attr :bar_color, :string, default: "black"
  attr :class, :string, default: ""

  def heatmap(assigns) do
    assigns = assign(assigns, height: 100)

    ~H"""
    <svg
      viewBox={"0 0 1000 #{@height}"}
      preserveAspectRatio="none"
      class={@class}
    >
      <%!-- "1000 / range minus 1 bar_width so the last one fits" --%>
      <% bar_width = (1000 / @range) - (1000 / (@range * @range)) %>

      <%= for idx <- 1..@range do %>
        <% bar_value = Map.get(@data, idx, 0) %>
        <% height = (bar_value / @max_value) * @height %>
        <% x = idx * (bar_width) %>
        <% y = @height - height %>

        <rect
          :if={height > 0}
          x={x}
          y={y}
          width={bar_width}
          height={height}
          fill={@bar_color}
        >
          <title>{"#{idx}: #{bar_value}"}</title>
        </rect>
      <% end %>
    </svg>
    """
  end

  # TODO: map over the map to do value-based coloring.

end

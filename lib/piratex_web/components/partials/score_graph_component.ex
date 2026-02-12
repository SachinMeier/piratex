defmodule PiratexWeb.Components.ScoreGraphComponent do
  use Phoenix.Component

  @team_colors ["#DC2626", "#2563EB", "#16A34A", "#D97706", "#DB2777", "#7C3AED"]

  attr :timeline, :map, required: true
  attr :teams, :list, required: true
  attr :range, :integer, required: true
  attr :max_score, :integer, required: true
  attr :class, :string, default: ""

  def score_graph(assigns) do
    height = 200
    max_score = max(assigns.max_score, 1)
    range = max(assigns.range, 1)

    series =
      assigns.timeline
      |> Enum.sort_by(fn {team_idx, _} -> team_idx end)
      |> Enum.map(fn {team_idx, points} ->
        polyline = to_step_points(points, range, max_score, height)
        color = Enum.at(@team_colors, team_idx, "#888888")
        {team_idx, polyline, color}
      end)

    team_colors =
      assigns.teams
      |> Enum.with_index()
      |> Enum.map(fn {team, idx} -> {team, Enum.at(@team_colors, idx, "#888888")} end)

    assigns =
      assigns
      |> assign(:series, series)
      |> assign(:height, height)
      |> assign(:team_colors_list, team_colors)

    ~H"""
    <div class={@class}>
      <svg
        viewBox={"0 0 1000 #{@height}"}
        preserveAspectRatio="none"
        class="w-full"
        style="min-height: 120px;"
      >
        <line
          x1="0"
          y1={@height * 0.25}
          x2="1000"
          y2={@height * 0.25}
          stroke="currentColor"
          stroke-opacity="0.12"
          vector-effect="non-scaling-stroke"
        />
        <line
          x1="0"
          y1={@height * 0.5}
          x2="1000"
          y2={@height * 0.5}
          stroke="currentColor"
          stroke-opacity="0.12"
          vector-effect="non-scaling-stroke"
        />
        <line
          x1="0"
          y1={@height * 0.75}
          x2="1000"
          y2={@height * 0.75}
          stroke="currentColor"
          stroke-opacity="0.12"
          vector-effect="non-scaling-stroke"
        />

        <%= for {_team_idx, points_str, color} <- @series do %>
          <polyline
            points={points_str}
            fill="none"
            stroke={color}
            stroke-width="2.5"
            stroke-linejoin="round"
            stroke-linecap="round"
            vector-effect="non-scaling-stroke"
          />
        <% end %>
      </svg>

      <div class="flex flex-wrap gap-x-4 gap-y-1 justify-center mt-2 px-2 pb-2">
        <%= for {team, color} <- @team_colors_list do %>
          <div class="flex items-center gap-1.5">
            <div class="w-3 h-3 rounded-sm flex-shrink-0" style={"background: #{color}"} />
            <span class="text-sm">{team.name}</span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp to_step_points(points, range, max_score, height) do
    pad_top = 10
    chart_height = height - pad_top

    y_for = fn score -> height - score / max_score * chart_height end
    x_for = fn lc -> lc / range * 1000 end

    {step_points, last_score} =
      Enum.reduce(points, {[], 0}, fn {letter_count, score}, {acc, prev_score} ->
        x = x_for.(letter_count)

        if acc == [] do
          {[{x, y_for.(score)}], score}
        else
          {[{x, y_for.(score)}, {x, y_for.(prev_score)} | acc], score}
        end
      end)

    final = [{x_for.(range), y_for.(last_score)} | step_points]

    final
    |> Enum.reverse()
    |> Enum.map_join(" ", fn {x, y} ->
      "#{Float.round(x + 0.0, 1)},#{Float.round(y + 0.0, 1)}"
    end)
  end
end

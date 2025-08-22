defmodule PiratexWeb.Components.TeamStatsComponent do
  use Phoenix.Component

  import PiratexWeb.CoreComponents, only: [rd: 1]

  attr :teams, :list, required: true
  attr :team_stats, :map, required: true

  def team_stats(assigns) do
    max_avg_points =
      assigns.team_stats.avg_points_per_word
      |> Enum.max_by(fn {_idx, avg_points} -> avg_points end)
      |> elem(1)
      |> rd()

    assigns = assign(assigns, :max_avg_points, max_avg_points)

    ~H"""
    <div class="flex flex-col m-2 gap-3">
      <%= for {team_idx, avg_points} <- @team_stats.avg_points_per_word do %>
        <div class="flex flex-row justify-between">
          <div class="w-24 font-medium truncate">
            <%= get_team_name(@teams, team_idx) %>
          </div>
          <.bar show_bar={length(Map.keys(@team_stats.avg_points_per_word)) > 1} max_avg_points={@max_avg_points} avg_points={rd(avg_points)} />
        </div>
      <% end %>
    </div>
    """
  end

  attr :max_avg_points, :integer, required: true
  attr :avg_points, :integer, required: true
  attr :show_bar, :boolean, required: true

  defp bar(assigns) do
    ~H"""
    <div class="mr-2">
      <%= @avg_points %>
    </div>
    <div :if={@show_bar} class="flex-1 h-4 my-auto border-2 border-inset border-black dark:border-white rounded overflow-hidden">
      <div class="h-full bg-green-600 dark:bg-green-500"
        style={"width: #{@avg_points / @max_avg_points * 100}%"}>
      </div>
    </div>
    """
  end

  defp get_team_name(teams, idx) do
    team_name =
      teams
      |> Enum.at(idx)
      |> Map.get(:name)

    max_len = 18

    if String.length(team_name) > max_len do
      String.slice(team_name, 0, max_len-3) <> "..."
    else
      team_name
    end
  end
end

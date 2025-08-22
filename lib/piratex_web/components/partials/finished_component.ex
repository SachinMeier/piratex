defmodule PiratexWeb.Components.FinishedComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents
  import PiratexWeb.Components.PodiumComponent
  import PiratexWeb.Components.StatsComponent

  attr :game_state, :map, required: true

  def finished(assigns) do
    ~H"""
    <div class="flex flex-col w-full mx-auto items-center">
      <div class="mb-4">
        <.tile_word word="game over" />
      </div>
    </div>

    <div class="flex flex-col w-full mx-auto">
      <!-- Tab Navigation -->
      <div class="flex gap-4 mx-auto mb-8" data-tab-switcher>
        <.tab_button tab="podium" active={true} label="Podium" />
        <.tab_button tab="stats" label="Stats" />
      </div>

      <!-- Tab Content -->
      <div id="tab-content" class="flex flex-col">
        <!-- Podium Tab -->
        <div id="podium-tab" class="tab-panel active">
          <div class="flex flex-col w-full mx-auto items-center">
            <.podium ranked_teams={rank_teams(@game_state.teams)} team_ct={length(@game_state.teams)} players={@game_state.players} />
          </div>
        </div>

        <!-- Stats Tab -->
        <div id="stats-tab" class="tab-panel hidden">
          <.stats game_state={@game_state} />
        </div>
      </div>
    </div>
    """
  end

  attr :tab, :string, required: true
  attr :active, :boolean, default: false
  attr :label, :string, required: true

  defp tab_button(assigns) do
    ~H"""
    <button
      class={"tab-button #{if @active, do: "active", else: ""} px-4 py-2 border-b-2 border-transparent hover:border-gray-300 dark:hover:border-gray-600 focus:outline-none focus:border-black dark:focus:border-white"}
      data-tab={@tab}
    >
      <%= @label %>
    </button>
    """
  end

  defp rank_teams(teams_with_scores) do
    {_, ranked_teams} =
      teams_with_scores
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.with_index()
      |> Enum.reduce({0, []}, fn {%{score: score} = team, idx}, {prev_rank, ranked_teams} ->
        if ranked_teams != [] do
          {_, prev_ranked_team} = List.last(ranked_teams)
          # if current team tied with previous team, use same rank
          if prev_ranked_team.score == score do
            {prev_rank, ranked_teams ++ [{prev_rank, team}]}
          else
            # if current team not tied with previous team, use the idx+1
            # ex. if 2 teams tie for 2nd place, next team is 4th, not 3rd
            {prev_rank + 1, ranked_teams ++ [{idx + 1, team}]}
          end
        else
          # if no previous teams, use next rank
          {prev_rank + 1, ranked_teams ++ [{prev_rank + 1, team}]}
        end
      end)

    ranked_teams
  end
end

defmodule PiratexWeb.Components.StatsComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents
  import PiratexWeb.CoreComponents
  import PiratexWeb.Components.TeamStatsComponent
  import PiratexWeb.Components.HeatmapComponent

  attr :game_state, :map, required: true

  def loss_stats(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 w-full mx-auto items-center gap-4">
      <div class="flex flex-col gap-2 mx-auto">
        <.challenge_breakdown players={@game_state.players} challenge_stats={@game_state.game_stats.challenge_stats} />
      </div>

      <div class="flex flex-row gap-2 mx-auto">
        <.game_stats game_state={@game_state} />
        <.summary_stats game_state={@game_state} />
      </div>

      <div class="flex flex-row gap-2  mx-auto">
        <.raw_mvp raw_mvp={@game_state.game_stats.raw_mvp} player={get_player(@game_state, @game_state.game_stats.raw_mvp.player_idx)} />
        <.quality_score
          total_score={@game_state.game_stats.team_stats.total_score}
          possible_score={@game_state.initial_letter_count - 1}
          avg_word_length={@game_state.game_stats.avg_word_length}
          steal_count={@game_state.game_stats.total_steals}
          margin_of_victory={if length(@game_state.teams) > 1, do: @game_state.game_stats.margin_of_victory, else: -1}
        />
      </div>

      <div class="flex flex-row gap-2 mx-auto">
        <div class="border-2 border-black dark:border-white rounded-md flex items-center justify-center">
          <div class="-rotate-90 min-w-24">Best Words</div>
        </div>
        <div class="flex flex-col gap-2 mx-auto">
          <.best_steal
            player={get_player(@game_state, @game_state.game_stats.best_steal.thief_player_idx)}
            thief_word={@game_state.game_stats.best_steal.thief_word}
            victim_word={@game_state.game_stats.best_steal.victim_word}
          />
          <.longest_word longest_word={@game_state.game_stats.longest_word} longest_word_length={@game_state.game_stats.longest_word_length} />
        </div>
      </div>

    </div>
    """
  end

  attr :game_state, :map, required: true

  def stats(assigns) do
    IO.inspect(assigns.game_state.game_stats.heatmap, label: "heatmap")
    ~H"""
    <div class="flex flex-col w-full mx-auto items-center gap-4">
      <.award_box award_title="Heatmap" class="w-full pb-0">
        <.heatmap
          data={@game_state.game_stats.heatmap}
          bar_color="#22C55E"
          range={@game_state.initial_letter_count}
          max_value={@game_state.game_stats.heatmap_max}
          class="w-full p-2 pb-0"
        />
      </.award_box>
      <div class="flex flex-wrap gap-2 mx-auto">
        <.game_stats game_state={@game_state} />
        <.summary_stats game_state={@game_state} />
        <.raw_mvp raw_mvp={@game_state.game_stats.raw_mvp} player={get_player(@game_state, @game_state.game_stats.raw_mvp.player_idx)} />
        <.quality_score
          total_score={@game_state.game_stats.team_stats.total_score}
          possible_score={@game_state.initial_letter_count - 1}
          avg_word_length={rd(@game_state.game_stats.team_stats.avg_word_length)}
          steal_count={@game_state.game_stats.total_steals}
          margin_of_victory={if length(@game_state.teams) > 1, do: @game_state.game_stats.team_stats.margin_of_victory, else: -1}
        />
      </div>

      <div class="flex flex-row gap-2 mx-auto">
        <div class="flex flex-col gap-2 mx-auto">
          <%= if @game_state.game_stats[:best_steal] do %>
          <.best_steal
            player={get_player(@game_state, @game_state.game_stats.best_steal.thief_player_idx)}
              thief_word={@game_state.game_stats.best_steal.thief_word}
              victim_word={@game_state.game_stats.best_steal.victim_word}
            />
          <% end %>
          <%= if @game_state.game_stats[:longest_word] do %>
            <.longest_word longest_word={@game_state.game_stats.longest_word} longest_word_length={@game_state.game_stats.longest_word_length} />
          <% end %>
        </div>
      </div>

      <div class="flex flex-col gap-2 min-w-96">
        <.challenge_breakdown players={@game_state.players} challenge_stats={@game_state.game_stats.challenge_stats} />
      </div>

      <div class="flex flex-col gap-2 min-w-96">
        <.award_box award_title="Points per Word">
          <.team_stats teams={@game_state.teams} team_stats={@game_state.game_stats.team_stats} />
        </.award_box>
      </div>
    </div>
    """
  end

  defp game_stats(assigns) do
    ~H"""
    <.award_box award_title="Game Stats">
      <div class="flex flex-col m-2 gap-2">
        <.stat_line label="Tile Count" value={@game_state.initial_letter_count} />
        <.stat_line label="Teams" value={length(@game_state.teams)} />
        <.stat_line label="Players" value={length(@game_state.players)} />
        <.stat_line label="Duration" value={"#{div(@game_state.game_stats.game_duration, 60)} minute#{if div(@game_state.game_stats.game_duration, 60) > 1, do: "s"}"} />
      </div>
    </.award_box>
    """
  end

  defp summary_stats(assigns) do
    ~H"""
    <.award_box award_title="Summary">
      <div class="flex flex-col m-2 gap-2">
        <.stat_line label="Steals" value={get_in(@game_state.game_stats, [:total_steals])} />
        <.stat_line label="Words" value={get_in(@game_state.game_stats, [:team_stats, :word_count])} />
        <.stat_line label="Total Challenges" value={get_in(@game_state.game_stats, [:challenge_stats, :count])} />
        <.stat_line label="Longest Word" value={get_in(@game_state.game_stats, [:longest_word_length])} />
      </div>
    </.award_box>
    """
  end

  attr :total_score, :integer, required: true
  attr :possible_score, :integer, required: true
  attr :avg_word_length, :integer, required: true
  attr :steal_count, :integer, required: true
  attr :margin_of_victory, :integer, required: true

  defp quality_score(assigns) do
    ~H"""
    <.award_box award_title="Game Quality">
      <div class="flex flex-col m-2 gap-2">
        <div>Score Quality: <%= @total_score %> / <%= @possible_score %></div>
        <.quality_bar width_pct={Float.round(@total_score / @possible_score * 100, 0) |> min(100)} />

        <div>Avg. Word Length: <%= @avg_word_length %></div>
       <.quality_bar width_pct={avg_word_length_quality(@avg_word_length)} />

      <%= if @margin_of_victory > 0 do %>
        <div>Margin of Victory: <%= @margin_of_victory %></div>
        <.quality_bar width_pct={margin_of_victory_quality(@margin_of_victory)} />
      <% end %>

      </div>
    </.award_box>
    """
  end

  defp avg_word_length_quality(avg_word_length) do
    Float.round(avg_word_length / 15 * 100 + 15, 0) |> min(100)
  end

  attr :width_pct, :integer, required: true

  defp quality_bar(assigns) do
    ~H"""
    <div class="flex flex-row w-full max-w-md h-4 border-2 border-inset border-black dark:border-white rounded overflow-hidden">
      <div class="h-full bg-green-600 dark:bg-green-500" style={"width: #{@width_pct}%"}></div>
    </div>
    """
  end

  attr :players, :list, required: true
  attr :challenge_stats, :map, required: true

  defp challenge_breakdown(assigns) do
    ~H"""
    <.award_box award_title="Challenges">
      <%= if @challenge_stats.count > 0 do %>
        <div class="flex flex-col m-2 gap-4">
          <div class="flex flex-col items-center gap-1">
            <div class="font-medium">Overall</div>
            <.challenge_breakdown_bar count={@challenge_stats.count} valid_ct={@challenge_stats.valid_ct} />
          </div>

          <div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <%= for {player_idx, %{count: count, valid_ct: valid_ct}} <- Enum.sort_by(@challenge_stats.player_stats, fn {idx, _} -> idx end) do %>
                <% player = Enum.at(@players, player_idx) %>
                <div class="flex flex-col border-2 border-black dark:border-white rounded-md p-2">
                  <div class="flex flex-row justify-between items-center">
                    <div class="font-medium truncate"><%= player.name %></div>
                    <div class="opacity-70">Total <%= count %></div>
                  </div>
                    <.challenge_breakdown_bar count={count} valid_ct={valid_ct} />
                </div>
              <% end %>
            </div>
          </div>

          <div :if={false and length(@challenge_stats.invalid_word_steals) > 0} class="hidden md:block overflow-x-auto">
            <div class="font-semibold mb-2 text-center">Invalid Words</div>
            <div class="grid grid-cols-1 sm:grid-cols-7 gap-y-3">
              <%= for word_steal <- @challenge_stats.invalid_word_steals do %>
                <div class="sm:col-span-3 ml-auto">
                  <.tile_word word={word_steal.victim_word} />
                </div>
                  <div class="sm:col-span-1 mx-auto">
                  <.icon name="hero-arrow-right-solid" class="h-8 w-8" />
                </div>
                  <div class="sm:col-span-3">
                  <.tile_word word={word_steal.thief_word} />
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% else %>
        <div class="m-2 text-center">No challenges! Well done!</div>
      <% end %>
    </.award_box>
    """
  end

  attr :count, :integer, required: true
  attr :valid_ct, :integer, required: true

  defp challenge_breakdown_bar(assigns) do
    valid_pct = Float.round(assigns.valid_ct / assigns.count * 100, 0) |> trunc()
    invalid_pct = if assigns.count > 0, do: 100 - valid_pct, else: 0

    assigns = assign(assigns, :valid_pct, valid_pct)
    assigns = assign(assigns, :invalid_pct, invalid_pct)

    ~H"""
    <div class="mt-2 w-full max-w-md mx-auto px-8">
      <div class="flex flex-row min-w-48 w-full max-w-md h-4 border-2 border-inset border-black dark:border-white rounded overflow-hidden">
        <div class="h-full bg-green-600 dark:bg-green-500" style={"width: #{@valid_pct}%"}></div>
        <div class="h-full bg-red-600 dark:bg-red-500" style={"width: #{@invalid_pct}%"}></div>
      </div>
      <div class="flex flex-row justify-between mt-1">
        <div class="text-green-700 dark:text-green-400">
          <%= if @valid_ct > 0 do %>
            Valid <%= @valid_ct %>
          <% else %>
            &nbsp;
          <% end %>
        </div>
        <div class="text-red-700 dark:text-red-400">
          <%= if @valid_ct < @count do %>
            Invalid <%= max(@count - @valid_ct, 0) %>
          <% else %>
            &nbsp;
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :raw_mvp, :map, required: true
  attr :player, :map, required: true

  defp raw_mvp(assigns) do
    ~H"""
    <.award_box award_title="MVP">
      <div class="flex flex-col m-2 gap-2">
          <.stat_line label="Name" value={@player.name} />
          <.stat_line label="Team" value={@player.team_name} />
          <.stat_line label="Points" value={@raw_mvp.points} />
          <.stat_line label="Steals" value={@raw_mvp.steals} />
      </div>
    </.award_box>
    """
  end

  attr :total_steals, :integer, required: true

  defp total_steals(assigns) do
    ~H"""
    <.award_box award_title="Total Steals">
      <%= @total_steals %>
    </.award_box>
    """
  end

  defp margin_of_victory_quality(margin_of_victory) do
    100 - (5 * margin_of_victory) |> max(0)
  end

  attr :player, :map, required: true
  attr :thief_word, :string, required: true
  attr :victim_word, :string, required: true

  defp best_steal(assigns) do
    ~H"""
    <.award_box award_title="Best Steal">
      <div class="flex flex-wrap pb-2 pt-3 gap-2 mx-auto">
        <.tile_word :if={@victim_word} word={@victim_word} />
        <.icon :if={@victim_word} name="hero-arrow-right-solid" class="h-8 w-8" />
        <.tile_word word={@thief_word} />
      </div>
    </.award_box>
    """
  end

  defp longest_word(assigns) do
    ~H"""
    <.award_box award_title="Longest Word">
      <div class="flex flex-row pb-2 pt-3 mx-auto max-w-md gap-2 overflow-x-auto no-scrollbar">
        <.tile_word word={@longest_word} />
      </div>
    </.award_box>
    """
  end

  attr :award_title, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true

  defp award_box(assigns) do
    ~H"""
    <div class={"flex flex-col border-2 border-black dark:border-white rounded-md p-2 pt-0 my-4 #{@class}"}>
      <div class="w-full px-auto text-center border-b-2 border-black dark:border-white py-1">
        <%= @award_title %>
      </div>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp stat_line(assigns) do
    ~H"""
    <div class="flex flex-row gap-8 justify-between">
      <div><%= @label %>:</div>
      <div><%= @value %></div>
    </div>
    """
  end

  defp get_player(game_state, player_idx) do
    # TODO: unideal
    player = Enum.at(game_state.players, player_idx)
    team = Enum.find(game_state.teams, fn team -> team.id == player.team_id end)
    Map.put(player, :team_name, team.name)
  end
end

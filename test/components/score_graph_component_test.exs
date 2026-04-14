defmodule PiratexWeb.Components.ScoreGraphComponentTest do
  use PiratexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Piratex.ScoreService
  alias Piratex.Team
  alias Piratex.WordSteal
  alias PiratexWeb.Components.ScoreGraphComponent

  @team_colors [
    "#DC2626",
    "#2563EB",
    "#16A34A",
    "#D97706",
    "#DB2777",
    "#7C3AED",
    "#0891B2",
    "#CA8A04",
    "#BE185D",
    "#059669"
  ]

  describe "score_graph/1" do
    test "legend color of each team matches its polyline color" do
      # Two teams with clearly distinguishable score series:
      #   Alpha (team 0): 0 -> 2 -> 6
      #   Bravo  (team 1): 0 -> 3
      # If labels/colors are swapped, the legend color for a team will
      # not match the polyline drawn from that team's actual scores.
      teams = [
        Team.new("Alpha"),
        Team.new("Bravo")
      ]

      history = [
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 5
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "dogs",
          letter_count: 10
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "birds",
          letter_count: 15
        })
      ]

      state = build_state(teams, history)

      # Sanity check the service-level timeline
      assert state.game_stats.score_timeline == %{
               0 => [{0, 0}, {5, 2}, {15, 6}],
               1 => [{0, 0}, {10, 3}]
             }

      html =
        render_component(&ScoreGraphComponent.score_graph/1,
          timeline: state.game_stats.score_timeline,
          teams: state.teams,
          range: state.initial_letter_count,
          max_score: state.game_stats.score_timeline_max
        )

      legend = parse_legend(html)
      series = parse_series(html)

      # Every team in the legend should get a unique color.
      assert Enum.uniq_by(legend, &elem(&1, 1)) == legend

      legend_by_name = Map.new(legend)
      series_by_color = Map.new(series, fn {color, points} -> {color, points} end)

      # For each team, the polyline drawn with the team's legend color
      # must trace the team's actual score series.
      #
      # Alpha went 0 -> 2 -> 6 ; Bravo went 0 -> 3.
      alpha_color = Map.fetch!(legend_by_name, "Alpha")
      bravo_color = Map.fetch!(legend_by_name, "Bravo")

      alpha_points = Map.fetch!(series_by_color, alpha_color)
      bravo_points = Map.fetch!(series_by_color, bravo_color)

      # Assert the final (highest) y of each polyline matches the expected
      # final score, which is max_score for the leader.
      assert final_score_height(alpha_points) < final_score_height(bravo_points),
             "Alpha's line should be drawn higher than Bravo's " <>
               "(Alpha ends at 6, Bravo ends at 3), but legend/series colors " <>
               "are misaligned. legend=#{inspect(legend)} series=#{inspect(series)}"
    end

    test "cross-team steal subtracts victim team points from the chart" do
      # Alpha takes "dog" from center (+2).
      # Bravo steals "dog" -> "dogs" (cross-team steal).
      #   Bravo: +3 (word_points("dogs") = 3)
      #   Alpha: -2 (lost "dog" worth 2 points)
      # Final team scores from the team.words lists:
      #   Alpha has no words => 0.
      #   Bravo has ["dogs"] => 3.
      # The rendered timeline's last point per team must match the final team score.
      teams = [
        Team.new("Alpha"),
        Team.new("Bravo", ["dogs"])
      ]

      history = [
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "dog",
          letter_count: 10
        }),
        WordSteal.new(%{
          victim_team_idx: 0,
          victim_word: "dog",
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "dogs",
          letter_count: 20
        })
      ]

      state = build_state(teams, history)

      # Final team scores computed from Team.words match expectations.
      assert Enum.at(state.teams, 0).score == 0
      assert Enum.at(state.teams, 1).score == 3

      # Service-level expectation.
      assert state.game_stats.score_timeline == %{
               0 => [{0, 0}, {10, 2}, {20, 0}],
               1 => [{0, 0}, {20, 3}]
             }

      html =
        render_component(&ScoreGraphComponent.score_graph/1,
          timeline: state.game_stats.score_timeline,
          teams: state.teams,
          range: state.initial_letter_count,
          max_score: state.game_stats.score_timeline_max
        )

      legend = parse_legend(html)
      series = parse_series(html)

      legend_by_name = Map.new(legend)
      series_by_color = Map.new(series, fn {color, points} -> {color, points} end)

      alpha_points = Map.fetch!(series_by_color, Map.fetch!(legend_by_name, "Alpha"))
      bravo_points = Map.fetch!(series_by_color, Map.fetch!(legend_by_name, "Bravo"))

      # Bravo's line must finish higher on the chart (lower y) than Alpha's,
      # because Bravo ends at 3 and Alpha ends at 0. If the victim loss is
      # dropped, Alpha's line would incorrectly stay at 2 for the whole
      # second half of the chart.
      assert last_y(bravo_points) < last_y(alpha_points),
             "Bravo (final score 3) should render above Alpha (final score 0). " <>
               "alpha=#{alpha_points} bravo=#{bravo_points}"

      # And Alpha's final y must be the chart baseline (final score = 0).
      assert last_y(alpha_points) == first_y(alpha_points),
             "Alpha's final y should return to baseline (final score 0). " <>
               "alpha=#{alpha_points}"
    end

    test "legend order and polyline order both follow teams list for 3 teams" do
      teams = [
        Team.new("Red"),
        Team.new("Green"),
        Team.new("Blue")
      ]

      # Three distinct final scores so we can unambiguously map team -> series.
      history = [
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "cat",
          letter_count: 10
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "tests",
          letter_count: 20
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 2,
          thief_player_idx: 2,
          thief_word: "elephants",
          letter_count: 30
        })
      ]

      state = build_state(teams, history)

      html =
        render_component(&ScoreGraphComponent.score_graph/1,
          timeline: state.game_stats.score_timeline,
          teams: state.teams,
          range: state.initial_letter_count,
          max_score: state.game_stats.score_timeline_max
        )

      legend = parse_legend(html)

      # Legend order matches teams list order, and each team gets the
      # palette color at its list position.
      assert legend == [
               {"Red", Enum.at(@team_colors, 0)},
               {"Green", Enum.at(@team_colors, 1)},
               {"Blue", Enum.at(@team_colors, 2)}
             ]

      # Each team's expected final score:
      #   Red    (3 letters -> 2 points)
      #   Green  (5 letters -> 4 points)
      #   Blue   (9 letters -> 8 points)
      legend_by_name = Map.new(legend)
      series_by_color = Map.new(parse_series(html))

      red_points = Map.fetch!(series_by_color, Map.fetch!(legend_by_name, "Red"))
      green_points = Map.fetch!(series_by_color, Map.fetch!(legend_by_name, "Green"))
      blue_points = Map.fetch!(series_by_color, Map.fetch!(legend_by_name, "Blue"))

      # Lower y value = higher on the chart = higher score.
      assert final_score_height(blue_points) < final_score_height(green_points)
      assert final_score_height(green_points) < final_score_height(red_points)
    end
  end

  defp build_state(teams, history) do
    players =
      teams
      |> Enum.with_index()
      |> Enum.map(fn {team, idx} ->
        %{name: "player#{idx}", team_id: team.id, score: 0}
      end)

    players_teams =
      players
      |> Enum.with_index()
      |> Map.new(fn {p, idx} -> {idx, p.team_id} end)

    %{
      status: :finished,
      center: [],
      center_sorted: [],
      start_time: DateTime.add(DateTime.utc_now(), -100, :second),
      end_time: DateTime.utc_now(),
      past_challenges: [],
      teams: teams,
      players: players,
      players_teams: players_teams,
      history: history,
      initial_letter_count: 100
    }
    |> ScoreService.calculate_team_scores()
    |> ScoreService.calculate_game_stats()
  end

  # Extract {team_name, hex_color} pairs from the rendered legend.
  defp parse_legend(html) do
    Regex.scan(
      ~r/background:\s*(#[0-9A-Fa-f]{6})[^>]*>\s*<\/div>\s*<span[^>]*>([^<]+)<\/span>/,
      html
    )
    |> Enum.map(fn [_, color, name] -> {String.trim(name), color} end)
  end

  # Extract {hex_color, points_string} pairs from the rendered polylines.
  defp parse_series(html) do
    Regex.scan(
      ~r/<polyline[^>]*points="([^"]+)"[^>]*stroke="(#[0-9A-Fa-f]{6})"/,
      html
    )
    |> Enum.map(fn [_, points, color] -> {color, points} end)
  end

  # Minimum y coordinate in a polyline (SVG y grows downward, so lower y = higher on screen).
  defp final_score_height(points_string) do
    points_string
    |> parse_points()
    |> Enum.map(&elem(&1, 1))
    |> Enum.min()
  end

  defp first_y(points_string) do
    points_string |> parse_points() |> hd() |> elem(1)
  end

  defp last_y(points_string) do
    points_string |> parse_points() |> List.last() |> elem(1)
  end

  defp parse_points(points_string) do
    points_string
    |> String.split(" ", trim: true)
    |> Enum.map(fn point ->
      [x, y] = String.split(point, ",")
      {String.to_float(x), String.to_float(y)}
    end)
  end
end

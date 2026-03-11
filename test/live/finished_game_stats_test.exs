defmodule PiratexWeb.FinishedGameStatsTest do
  use PiratexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Piratex.Player
  alias Piratex.ScoreService
  alias Piratex.Team
  alias Piratex.WordSteal

  describe "finished stats render end-to-end" do
    test "single player game renders", %{conn: conn} do
      teams = [
        Team.new("Solo Crew", ["masts", "sail"])
      ]

      players = [
        Player.new("Solo", "token1", teams |> Enum.at(0) |> Map.fetch!(:id))
      ]

      history = [
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "sail",
          letter_count: 12
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "masts",
          letter_count: 28
        })
      ]

      game_id = start_finished_game!(players, teams, history)

      {:ok, _view, html} = live(conn, ~p"/watch/#{game_id}")

      assert html =~ "Score Timeline"
      assert html =~ "Solo Crew"
      assert html =~ "Solo"
    end

    test "two player game renders", %{conn: conn} do
      teams = [
        Team.new("Red Fleet", ["ate"]),
        Team.new("Blue Fleet", ["steam"])
      ]

      players = [
        Player.new("Anne", "token1", teams |> Enum.at(0) |> Map.fetch!(:id)),
        Player.new("Blackbeard", "token2", teams |> Enum.at(1) |> Map.fetch!(:id))
      ]

      history = [
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "ate",
          letter_count: 9
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "steam",
          letter_count: 24
        })
      ]

      game_id = start_finished_game!(players, teams, history)

      {:ok, _view, html} = live(conn, ~p"/watch/#{game_id}")

      assert html =~ "Score Timeline"
      assert html =~ "Red Fleet"
      assert html =~ "Blue Fleet"
      assert html =~ "Anne"
      assert html =~ "Blackbeard"
    end

    test "two players on one team render", %{conn: conn} do
      teams = [
        Team.new("Shared Deck", ["far", "frame"])
      ]

      team_id = teams |> Enum.at(0) |> Map.fetch!(:id)

      players = [
        Player.new("Jack", "token1", team_id),
        Player.new("Mary", "token2", team_id)
      ]

      history = [
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "far",
          letter_count: 7
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 1,
          thief_word: "frame",
          letter_count: 19
        })
      ]

      game_id = start_finished_game!(players, teams, history)

      {:ok, _view, html} = live(conn, ~p"/watch/#{game_id}")

      assert html =~ "Score Timeline"
      assert html =~ "Shared Deck"
      assert html =~ "Jack"
      assert html =~ "Mary"
    end

    test "four players on two teams render", %{conn: conn} do
      teams = [
        Team.new("North Crew", ["ore", "stone"]),
        Team.new("South Crew", ["east", "tease"])
      ]

      players = [
        Player.new("Ada", "token1", teams |> Enum.at(0) |> Map.fetch!(:id)),
        Player.new("Ben", "token2", teams |> Enum.at(0) |> Map.fetch!(:id)),
        Player.new("Cy", "token3", teams |> Enum.at(1) |> Map.fetch!(:id)),
        Player.new("Dot", "token4", teams |> Enum.at(1) |> Map.fetch!(:id))
      ]

      history = [
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "ore",
          letter_count: 6
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 2,
          thief_word: "east",
          letter_count: 14
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 1,
          thief_word: "stone",
          letter_count: 25
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 3,
          thief_word: "tease",
          letter_count: 32
        })
      ]

      game_id = start_finished_game!(players, teams, history)

      {:ok, _view, html} = live(conn, ~p"/watch/#{game_id}")

      assert html =~ "Score Timeline"
      assert html =~ "North Crew"
      assert html =~ "South Crew"
      assert html =~ "Ada"
      assert html =~ "Dot"
    end

    test "finished stats render when a quit player still wins", %{conn: conn} do
      teams = [
        Team.new("Quitter Winners", ["seals"]),
        Team.new("Still Here", ["ate"])
      ]

      players = [
        Player.new("Quit Winner", "token1", teams |> Enum.at(0) |> Map.fetch!(:id))
        |> Player.quit(),
        Player.new("Closer", "token2", teams |> Enum.at(1) |> Map.fetch!(:id))
      ]

      history = [
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "seals",
          letter_count: 18
        }),
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "ate",
          letter_count: 29
        })
      ]

      game_id = start_finished_game!(players, teams, history)

      {:ok, _view, html} = live(conn, ~p"/watch/#{game_id}")

      assert html =~ "Score Timeline"
      assert html =~ "Quitter Winners"
      assert html =~ "Still Here"
      assert html =~ "Quit Winner"
      assert html =~ "Closer"
    end

    test "finished stats render for a zero-word multi-team game", %{conn: conn} do
      teams = [
        Team.new("North Crew", []),
        Team.new("South Crew", [])
      ]

      players = [
        Player.new("Ada", "token1", teams |> Enum.at(0) |> Map.fetch!(:id)),
        Player.new("Ben", "token2", teams |> Enum.at(1) |> Map.fetch!(:id))
      ]

      game_id = start_finished_game!(players, teams, [])

      {:ok, _view, html} = live(conn, ~p"/watch/#{game_id}")

      assert html =~ "Score Timeline"
      assert html =~ "North Crew"
      assert html =~ "South Crew"
    end
  end

  defp start_finished_game!(players, teams, history) do
    players_teams =
      Map.new(players, fn player ->
        {player.token, player.team_id}
      end)

    state =
      %{
        id: "seed",
        status: :finished,
        start_time: DateTime.add(DateTime.utc_now(), -300, :second),
        end_time: DateTime.utc_now(),
        players: players,
        teams: teams,
        players_teams: players_teams,
        turn: 0,
        total_turn: 0,
        letter_pool: [],
        letter_pool_count: 0,
        initial_letter_count: 40,
        center: [],
        center_sorted: [],
        history: history,
        activity_feed: [],
        challenges: [],
        past_challenges: [],
        end_game_votes: %{},
        active_player_count: Enum.count(players),
        last_action_at: DateTime.utc_now()
      }
      |> ScoreService.calculate_team_scores()
      |> ScoreService.calculate_game_stats()

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)
    game_id
  end
end

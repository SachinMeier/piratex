defmodule PiratexWeb.PlayingActivityFeedTest do
  use PiratexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Piratex.ActivityFeed
  alias Piratex.ChallengeService.Challenge
  alias Piratex.Player
  alias Piratex.Team
  alias Piratex.WordSteal

  describe "playing activity panel" do
    test "renders below the existing history section for players", %{conn: conn} do
      game_id = start_playing_game!()
      conn = player_conn(conn, game_id)

      {:ok, view, html} = live(conn, ~p"/game/#{game_id}")

      assert has_element?(view, "#history_panel")
      assert has_element?(view, "#activity_panel")
      assert has_element?(view, "#chat_message_input")
      assert String.contains?(html, "Ahoy from Anne")
      assert String.contains?(html, "Blackbeard stole ATE to make TEST.")

      assert panel_order(html, "id=\"history_panel\"", "id=\"activity_panel\"")
    end

    test "keeps the activity panel visible while a challenge is open", %{conn: conn} do
      game_id = start_playing_game!(challenge_open: true)
      conn = player_conn(conn, game_id)

      {:ok, view, _html} = live(conn, ~p"/game/#{game_id}")

      assert has_element?(view, "#challenge_panel")
      assert has_element?(view, "#main_playing_area #challenge_panel")
      assert has_element?(view, "#activity_panel")
      assert has_element?(view, "#chat_message_input")
    end

    test "hides the activity panel in zen mode", %{conn: conn} do
      game_id = start_playing_game!()
      conn = player_conn(conn, game_id)

      {:ok, view, _html} = live(conn, ~p"/game/#{game_id}")

      assert has_element?(view, "#activity_panel")

      render_hook(view, "hotkey", %{
        "key" => "8",
        "ctrl" => false,
        "shift" => false,
        "meta" => false
      })

      refute has_element?(view, "#activity_panel")
    end

    test "hides the composer for watchers", %{conn: conn} do
      game_id = start_playing_game!()

      {:ok, view, _html} = live(conn, ~p"/watch/#{game_id}")

      assert has_element?(view, "#activity_panel")
      refute has_element?(view, "#chat_message_input")
    end
  end

  defp start_playing_game!(opts \\ []) do
    teams = [
      red = Team.new("Red Crew", []),
      blue = Team.new("Blue Crew", ["test"])
    ]

    players = [
      Player.new("Anne", "token1", red.id),
      Player.new("Blackbeard", "token2", blue.id)
    ]

    word_steal =
      WordSteal.new(%{
        victim_team_idx: 0,
        victim_word: "ate",
        thief_team_idx: 1,
        thief_player_idx: 1,
        thief_word: "test",
        letter_count: 9
      })

    challenges =
      if Keyword.get(opts, :challenge_open, false) do
        [Challenge.new(word_steal)]
      else
        []
      end

    state = %{
      id: "ignored",
      status: :playing,
      start_time: DateTime.utc_now(),
      end_time: nil,
      players: players,
      players_teams: %{"token1" => red.id, "token2" => blue.id},
      teams: teams,
      turn: 0,
      total_turn: 0,
      letter_pool: ["x", "y", "z"],
      initial_letter_count: 3,
      center: [],
      center_sorted: [],
      history: [word_steal],
      activity_feed: [
        ActivityFeed.player_message("Anne", "Ahoy from Anne"),
        ActivityFeed.event(:word_stolen, "Blackbeard stole ATE to make TEST.")
      ],
      challenges: challenges,
      past_challenges: [],
      end_game_votes: %{},
      last_action_at: DateTime.utc_now(),
      game_stats: nil
    }

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)
    game_id
  end

  defp player_conn(conn, game_id) do
    init_test_session(conn, %{
      "game_id" => game_id,
      "player_name" => "Anne",
      "player_token" => "token1"
    })
  end

  defp panel_order(html, first, second) do
    case String.split(html, first, parts: 2) do
      [_before, after_first] -> String.contains?(after_first, second)
      _ -> false
    end
  end
end

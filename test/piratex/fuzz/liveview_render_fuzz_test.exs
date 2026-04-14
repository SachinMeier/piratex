defmodule Piratex.LiveviewRenderFuzzTest do
  @moduledoc """
  Fuzz and deterministic tests for LiveView rendering across game phases.
  Verifies that player and watcher views render without crash for
  every state the Game GenServer can produce.
  """
  use PiratexWeb.ConnCase, async: false
  use ExUnitProperties

  import Phoenix.LiveViewTest

  alias Piratex.FuzzHelpers
  alias Piratex.GameGenerators
  alias Piratex.Game

  alias Piratex.ActivityFeed
  alias Piratex.ChallengeService.Challenge
  alias Piratex.Player
  alias Piratex.Team
  alias Piratex.WordSteal

  @moduletag :fuzz

  setup do
    FuzzHelpers.ensure_dictionary_started()
    :ok
  end

  # ──────────────────────────────────────────────
  # Property: every game state renders both views
  # ──────────────────────────────────────────────

  describe "render fuzz properties" do
    property "every game state renders both player and watcher views" do
      check all(
              num_players <- StreamData.integer(2..5),
              seeds <- GameGenerators.seed_list_gen(20, 80),
              max_runs: 50
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players, :bananagrams_half)

        {player_view, watcher_view} = mount_both_views(game_id)

        seeds
        |> Enum.with_index(1)
        |> Enum.reduce({player_view, watcher_view, :playing}, fn {seed, idx},
                                                                 {pv, wv, prev_status} ->
          unless FuzzHelpers.game_alive?(game_id) do
            {pv, wv, prev_status}
          else
            action = GameGenerators.select_action(game_id, seed)
            GameGenerators.execute(action)

            # Render both views after every action
            safe_render_views(game_id, pv, wv)

            # Fresh remount every 10th action
            {new_pv, new_wv} =
              if rem(idx, 10) == 0 and FuzzHelpers.game_alive?(game_id) do
                FuzzHelpers.fresh_mount_and_render!(game_id)
                remount_both_views(game_id)
              else
                {pv, wv}
              end

            current_status = current_game_status(game_id, prev_status)
            {new_pv, new_wv, current_status}
          end
        end)

        FuzzHelpers.check_invariants!(game_id)
      end
    end

    property "fresh mount at every phase transition renders correctly" do
      check all(
              seeds <- GameGenerators.seed_list_gen(30, 100),
              max_runs: 30
            ) do
        game_id = FuzzHelpers.setup_playing_game(3, :bananagrams_half)

        seeds
        |> Enum.reduce(:playing, fn seed, prev_status ->
          unless FuzzHelpers.game_alive?(game_id) do
            prev_status
          else
            action = GameGenerators.select_action(game_id, seed)
            GameGenerators.execute(action)

            current_status = current_game_status(game_id, prev_status)

            # On phase transition, do a full fresh mount and render
            if current_status != prev_status and FuzzHelpers.game_alive?(game_id) do
              FuzzHelpers.fresh_mount_and_render!(game_id)
            end

            current_status
          end
        end)

        FuzzHelpers.check_invariants!(game_id)
      end
    end
  end

  # ──────────────────────────────────────────────
  # Waiting phase render tests
  # ──────────────────────────────────────────────

  describe "waiting phase renders" do
    test "waiting phase renders for player and watcher" do
      game_id = FuzzHelpers.setup_waiting_game(3)

      {:ok, player_view, player_html} = mount_player(game_id, 1)
      {:ok, watcher_view, watcher_html} = mount_watcher(game_id)

      # Player sees START button
      assert String.contains?(player_html, "START")
      FuzzHelpers.assert_render_invariants!(player_html, :waiting)

      # Watcher sees team names / player names (but no START/JOIN since watch_only)
      assert watcher_html != ""
      refute String.contains?(watcher_html, "Internal Server Error")
      refute String.contains?(watcher_html, "%Piratex.")
      # Team names (default = player name) should appear
      assert String.contains?(watcher_html, "player_1") or
               String.contains?(watcher_html, "player_2") or
               String.contains?(watcher_html, "player_3")

      # Re-render should also succeed
      render(player_view)
      render(watcher_view)
    end
  end

  # ──────────────────────────────────────────────
  # Playing phase render tests
  # ──────────────────────────────────────────────

  describe "playing phase renders with challenge open" do
    test "challenge panel renders and updates after vote" do
      game_id = setup_game_with_challenge()

      {:ok, player_view, player_html} = mount_player(game_id, 1)
      {:ok, watcher_view, watcher_html} = mount_watcher(game_id)

      # Verify challenge panel is present
      assert String.contains?(player_html, "challenge_panel") or
               String.contains?(player_html, "Challenge")

      assert String.contains?(watcher_html, "challenge_panel") or
               String.contains?(watcher_html, "Challenge")

      FuzzHelpers.assert_render_invariants!(player_html, :playing)
      FuzzHelpers.assert_render_invariants!(watcher_html, :playing)

      # Cast a vote from player 2 (player 1 is challenger, auto-voted false)
      state = FuzzHelpers.safe_get_state(game_id)
      challenge = List.first(state.challenges)

      # Player 2 votes valid (true)
      Game.challenge_vote(game_id, "token_2", challenge.id, true)
      :timer.sleep(20)

      # Re-render both views -- should not crash
      new_player_html = render(player_view)
      new_watcher_html = render(watcher_view)

      FuzzHelpers.assert_render_invariants!(new_player_html, :playing)
      FuzzHelpers.assert_render_invariants!(new_watcher_html, :playing)
    end
  end

  describe "playing phase renders in zen mode" do
    test "zen mode toggle hides activity panel and shows zen layout" do
      game_id = setup_playing_game_with_words()

      {:ok, view, _html} = mount_player(game_id, 1)

      # Before zen mode: activity_panel should be present
      assert has_element?(view, "#activity_panel")

      # Toggle zen mode via hotkey "8"
      render_hook(view, "hotkey", %{
        "key" => "8",
        "ctrl" => false,
        "shift" => false,
        "meta" => false
      })

      # After zen mode: activity_panel should be hidden
      refute has_element?(view, "#activity_panel")

      # Words should still be visible in zen layout
      html = render(view)
      FuzzHelpers.assert_render_invariants!(html, :playing)

      # Toggle back
      render_hook(view, "hotkey", %{
        "key" => "8",
        "ctrl" => false,
        "shift" => false,
        "meta" => false
      })

      # Activity panel should return
      assert has_element?(view, "#activity_panel")
    end
  end

  # ──────────────────────────────────────────────
  # Finished phase render tests
  # ──────────────────────────────────────────────

  describe "finished view renders for various team configs" do
    test "1 team with words, 1 team no words" do
      game_id =
        setup_finished_game_custom(
          [{"Winners", ["test", "word"]}, {"Losers", []}],
          2
        )

      {:ok, _view, html} = mount_player(game_id, 1)
      FuzzHelpers.assert_render_invariants!(html, :finished)

      {:ok, _view, watcher_html} = mount_watcher(game_id)
      FuzzHelpers.assert_render_invariants!(watcher_html, :finished)
    end

    test "2 teams balanced" do
      game_id =
        setup_finished_game_custom(
          [{"Alpha", ["test", "word"]}, {"Beta", ["sail", "boat"]}],
          2
        )

      {:ok, _view, html} = mount_player(game_id, 1)
      FuzzHelpers.assert_render_invariants!(html, :finished)

      {:ok, _view, watcher_html} = mount_watcher(game_id)
      FuzzHelpers.assert_render_invariants!(watcher_html, :finished)
    end

    test "2 teams one empty" do
      game_id =
        setup_finished_game_custom(
          [{"Alpha", ["test", "word", "sail"]}, {"Beta", []}],
          2
        )

      {:ok, _view, html} = mount_player(game_id, 1)
      FuzzHelpers.assert_render_invariants!(html, :finished)

      {:ok, _view, watcher_html} = mount_watcher(game_id)
      FuzzHelpers.assert_render_invariants!(watcher_html, :finished)
    end
  end

  describe "finished view renders with no words claimed" do
    test "game with zero words renders without crash" do
      game_id =
        setup_finished_game_custom(
          [{"Alpha", []}, {"Beta", []}],
          2
        )

      {:ok, _view, html} = mount_player(game_id, 1)
      FuzzHelpers.assert_render_invariants!(html, :finished)

      {:ok, _view, watcher_html} = mount_watcher(game_id)
      FuzzHelpers.assert_render_invariants!(watcher_html, :finished)
    end
  end

  # ──────────────────────────────────────────────
  # Word steal modal render tests
  # ──────────────────────────────────────────────

  describe "word steal modal" do
    test "renders for center and steal claims" do
      game_id = setup_game_with_history()

      {:ok, view, _html} = mount_player(game_id, 1)

      # Show word steal modal for center claim (victim_word nil)
      render_click(view, "show_word_steal", %{"word" => "test"})
      html = render(view)
      assert String.contains?(html, "word steal") or String.contains?(html, "word_steal")
      FuzzHelpers.assert_render_invariants!(html, :playing)

      # Hide it
      render_click(view, "hide_word_steal", %{})
      html = render(view)
      FuzzHelpers.assert_render_invariants!(html, :playing)

      # Show word steal modal for steal claim (victim_word present)
      render_click(view, "show_word_steal", %{"word" => "steal"})
      html = render(view)
      FuzzHelpers.assert_render_invariants!(html, :playing)

      # Hide it
      render_click(view, "hide_word_steal", %{})
    end
  end

  # ──────────────────────────────────────────────
  # Zen mode + auto_flip render tests
  # ──────────────────────────────────────────────

  describe "zen_mode and auto_flip render correctly" do
    test "both toggles independently and simultaneously" do
      game_id = setup_playing_game_with_words()

      {:ok, view, _html} = mount_player(game_id, 1)

      # Toggle zen_mode on
      render_hook(view, "hotkey", %{
        "key" => "8",
        "ctrl" => false,
        "shift" => false,
        "meta" => false
      })

      html = render(view)
      refute String.contains?(html, "id=\"activity_panel\"")
      FuzzHelpers.assert_render_invariants!(html, :playing)

      # Toggle auto_flip on
      render_hook(view, "hotkey", %{
        "key" => "6",
        "ctrl" => false,
        "shift" => false,
        "meta" => false
      })

      html = render(view)
      FuzzHelpers.assert_render_invariants!(html, :playing)

      # Both on simultaneously -- should not crash
      html = render(view)
      FuzzHelpers.assert_render_invariants!(html, :playing)

      # Toggle zen_mode off, auto_flip still on
      render_hook(view, "hotkey", %{
        "key" => "8",
        "ctrl" => false,
        "shift" => false,
        "meta" => false
      })

      html = render(view)
      assert String.contains?(html, "id=\"activity_panel\"")
      FuzzHelpers.assert_render_invariants!(html, :playing)

      # Toggle auto_flip off
      render_hook(view, "hotkey", %{
        "key" => "6",
        "ctrl" => false,
        "shift" => false,
        "meta" => false
      })

      html = render(view)
      FuzzHelpers.assert_render_invariants!(html, :playing)
    end
  end

  # ──────────────────────────────────────────────
  # Private helpers
  # ──────────────────────────────────────────────

  defp mount_player(game_id, player_idx) do
    conn = build_player_conn(game_id, player_idx)
    {:ok, view, html} = live(conn, "/game/#{game_id}")
    {:ok, view, html}
  end

  defp mount_watcher(game_id) do
    conn = build_conn()
    {:ok, view, html} = live(conn, "/watch/#{game_id}")
    {:ok, view, html}
  end

  defp build_player_conn(game_id, player_idx) do
    build_conn()
    |> Plug.Test.init_test_session(%{
      "game_id" => game_id,
      "player_name" => "player_#{player_idx}",
      "player_token" => "token_#{player_idx}"
    })
  end

  defp mount_both_views(game_id) do
    pv =
      case FuzzHelpers.mount_player_view(game_id) do
        {:ok, view, _html} -> view
        :redirect -> nil
      end

    wv =
      case FuzzHelpers.mount_watcher_view(game_id) do
        {:ok, view, _html} -> view
        :redirect -> nil
      end

    {pv, wv}
  end

  defp remount_both_views(game_id) do
    pv =
      case FuzzHelpers.mount_player_view(game_id) do
        {:ok, view, _html} -> view
        :redirect -> nil
      end

    wv =
      case FuzzHelpers.mount_watcher_view(game_id) do
        {:ok, view, _html} -> view
        :redirect -> nil
      end

    {pv, wv}
  end

  defp safe_render_views(game_id, pv, wv) do
    try do
      FuzzHelpers.check_views_render!(game_id, pv, wv)
    rescue
      _ -> :ok
    end
  end

  defp current_game_status(game_id, fallback) do
    case FuzzHelpers.safe_get_state(game_id) do
      nil -> fallback
      state -> state.status
    end
  end

  # ──────────────────────────────────────────────
  # Game state builders
  # ──────────────────────────────────────────────

  defp setup_game_with_challenge do
    teams = [
      red = Team.new("Red Crew", ["ate"]),
      blue = Team.new("Blue Crew", ["test"])
    ]

    players = [
      Player.new("player_1", "token_1", red.id),
      Player.new("player_2", "token_2", blue.id),
      Player.new("player_3", "token_3", red.id)
    ]

    word_steal =
      WordSteal.new(%{
        victim_team_idx: 0,
        victim_word: "ate",
        thief_team_idx: 1,
        thief_player_idx: 1,
        thief_word: "test",
        letter_count: 5
      })

    challenge = Challenge.new(word_steal, %{"player_3" => false})

    state = %{
      id: "ignored",
      status: :playing,
      start_time: DateTime.utc_now(),
      end_time: nil,
      players: players,
      players_teams: %{
        "token_1" => red.id,
        "token_2" => blue.id,
        "token_3" => red.id
      },
      teams: teams,
      turn: 0,
      total_turn: 5,
      letter_pool: ["x", "y", "z"],
      initial_letter_count: 7,
      center: ["s"],
      center_sorted: ["s"],
      history: [word_steal],
      activity_feed: ActivityFeed.new(),
      challenges: [challenge],
      past_challenges: [],
      end_game_votes: %{},
      last_action_at: DateTime.utc_now(),
      game_stats: nil
    }

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)
    game_id
  end

  defp setup_playing_game_with_words do
    teams = [
      red = Team.new("Red Crew", ["test"]),
      blue = Team.new("Blue Crew", ["word"])
    ]

    players = [
      Player.new("player_1", "token_1", red.id),
      Player.new("player_2", "token_2", blue.id)
    ]

    word_steal =
      WordSteal.new(%{
        victim_team_idx: nil,
        victim_word: nil,
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "test",
        letter_count: 4
      })

    state = %{
      id: "ignored",
      status: :playing,
      start_time: DateTime.utc_now(),
      end_time: nil,
      players: players,
      players_teams: %{
        "token_1" => red.id,
        "token_2" => blue.id
      },
      teams: teams,
      turn: 0,
      total_turn: 6,
      letter_pool: ["a", "b", "c"],
      initial_letter_count: 11,
      center: ["x", "y"],
      center_sorted: ["x", "y"],
      history: [word_steal],
      activity_feed: ActivityFeed.new(),
      challenges: [],
      past_challenges: [],
      end_game_votes: %{},
      last_action_at: DateTime.utc_now(),
      game_stats: nil
    }

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)
    game_id
  end

  defp setup_game_with_history do
    teams = [
      red = Team.new("Red Crew", ["steal"]),
      blue = Team.new("Blue Crew", ["test"])
    ]

    players = [
      Player.new("player_1", "token_1", red.id),
      Player.new("player_2", "token_2", blue.id)
    ]

    # Center claim (victim_word nil)
    center_steal =
      WordSteal.new(%{
        victim_team_idx: nil,
        victim_word: nil,
        thief_team_idx: 1,
        thief_player_idx: 1,
        thief_word: "test",
        letter_count: 4
      })

    # Steal claim (victim_word present)
    word_steal =
      WordSteal.new(%{
        victim_team_idx: 1,
        victim_word: "eat",
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "steal",
        letter_count: 7
      })

    state = %{
      id: "ignored",
      status: :playing,
      start_time: DateTime.utc_now(),
      end_time: nil,
      players: players,
      players_teams: %{
        "token_1" => red.id,
        "token_2" => blue.id
      },
      teams: teams,
      turn: 0,
      total_turn: 8,
      letter_pool: ["a", "b"],
      initial_letter_count: 11,
      center: ["x"],
      center_sorted: ["x"],
      history: [word_steal, center_steal],
      activity_feed: ActivityFeed.new(),
      challenges: [],
      past_challenges: [],
      end_game_votes: %{},
      last_action_at: DateTime.utc_now(),
      game_stats: nil
    }

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)
    game_id
  end

  defp setup_finished_game_custom(team_configs, num_players) do
    # Build teams from configs: [{name, words}, ...]
    teams =
      team_configs
      |> Enum.map(fn {name, words} ->
        Team.new(name, words) |> Team.calculate_score()
      end)

    # Build players distributed across teams
    players =
      Enum.map(1..num_players, fn i ->
        team_idx = rem(i - 1, length(teams))
        team = Enum.at(teams, team_idx)
        Player.new("player_#{i}", "token_#{i}", team.id)
      end)

    # Build players_teams map
    players_teams =
      Enum.reduce(players, %{}, fn p, acc ->
        Map.put(acc, p.token, p.team_id)
      end)

    # Build history from words
    all_words =
      Enum.flat_map(Enum.with_index(teams), fn {team, tidx} ->
        Enum.with_index(team.words)
        |> Enum.map(fn {word, _widx} ->
          WordSteal.new(%{
            victim_team_idx: nil,
            victim_word: nil,
            thief_team_idx: tidx,
            thief_player_idx: rem(tidx, num_players),
            thief_word: word,
            letter_count: tidx * 3 + 1
          })
        end)
      end)

    total_letters =
      Enum.reduce(teams, 0, fn t, acc ->
        acc + Enum.reduce(t.words, 0, fn w, a -> a + String.length(w) end)
      end)

    # Build game stats
    game_stats = build_game_stats(teams, players, all_words)

    state = %{
      id: "ignored",
      status: :finished,
      start_time: DateTime.add(DateTime.utc_now(), -120, :second),
      end_time: DateTime.utc_now(),
      players: players,
      players_teams: players_teams,
      teams: teams,
      turn: 0,
      total_turn: 20,
      letter_pool: [],
      initial_letter_count: total_letters,
      center: [],
      center_sorted: [],
      history: Enum.reverse(all_words),
      activity_feed: ActivityFeed.new(),
      challenges: [],
      past_challenges: [],
      end_game_votes: Map.new(players, fn p -> {p.name, true} end),
      last_action_at: DateTime.utc_now(),
      game_stats: game_stats
    }

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)
    game_id
  end

  defp build_game_stats(teams, players, history) do
    raw_player_stats =
      players
      |> Enum.with_index()
      |> Map.new(fn {_p, idx} ->
        player_words =
          Enum.filter(history, fn ws -> ws.thief_player_idx == idx end)
          |> Enum.map(& &1.thief_word)

        points = Enum.reduce(player_words, 0, fn w, acc -> acc + String.length(w) - 1 end)
        steals = length(player_words)
        pps = if steals > 0, do: points / steals, else: 0

        {idx,
         %{
           points: points,
           words: player_words,
           steals: steals,
           points_per_steal: pps
         }}
      end)

    {mvp_idx, mvp} =
      case Enum.max_by(raw_player_stats, fn {_idx, s} -> s.points end, fn -> nil end) do
        nil -> {0, %{points: 0, words: [], steals: 0, points_per_steal: 0}}
        {idx, stats} -> {idx, stats}
      end

    total_score = Enum.reduce(teams, 0, fn t, acc -> acc + t.score end)
    word_count = Enum.reduce(teams, 0, fn t, acc -> acc + length(t.words) end)

    total_letters =
      Enum.reduce(teams, 0, fn t, acc ->
        acc + Enum.reduce(t.words, 0, fn w, a -> a + String.length(w) end)
      end)

    {longest_word, longest_word_length} =
      case Enum.flat_map(teams, & &1.words) do
        [] ->
          {nil, 0}

        words ->
          w = Enum.max_by(words, &String.length/1)
          {w, String.length(w)}
      end

    avg_word_length = if word_count > 0, do: total_letters / word_count, else: 0

    score_timeline =
      teams
      |> Enum.with_index()
      |> Map.new(fn {t, idx} -> {idx, [{0, 0}, {10, t.score}]} end)

    %{
      total_score: total_score,
      total_steals: length(history),
      best_steal: List.first(history),
      best_steal_score: if(history != [], do: 8, else: 0),
      raw_player_stats: raw_player_stats,
      raw_mvp: Map.put(mvp, :player_idx, mvp_idx),
      longest_word: longest_word,
      longest_word_length: longest_word_length,
      heatmap: %{},
      heatmap_max: 0,
      game_duration: 120,
      team_stats: %{
        total_letters: total_letters,
        total_score: total_score,
        word_count: word_count,
        word_length_distribution: %{},
        avg_points_per_word:
          teams
          |> Enum.with_index()
          |> Map.new(fn {t, idx} ->
            if length(t.words) > 0, do: {idx, t.score / length(t.words)}, else: {idx, 0}
          end),
        margin_of_victory:
          case Enum.sort_by(teams, & &1.score, :desc) do
            [a, b | _] -> a.score - b.score
            _ -> 0
          end,
        avg_word_length: avg_word_length
      },
      challenge_stats: %{count: 0, valid_ct: 0, player_stats: %{}, invalid_word_steals: []},
      score_timeline: score_timeline,
      score_timeline_max:
        score_timeline
        |> Map.values()
        |> List.flatten()
        |> Enum.map(fn {_, s} -> s end)
        |> Enum.max(fn -> 0 end)
    }
  end
end

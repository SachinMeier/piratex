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
  alias Piratex.FuzzGame, as: Game

  @moduletag :fuzz
  @moduletag timeout: 300_000

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
              num_players <- StreamData.integer(2..4),
              seeds <- GameGenerators.seed_list_gen(15, 50),
              max_runs: 30
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
      game_id = FuzzHelpers.setup_game_with_challenge(3)

      {:ok, player_view, player_html} = mount_player(game_id, 1)
      {:ok, watcher_view, watcher_html} = mount_watcher(game_id)

      # Verify challenge panel is present
      assert String.contains?(player_html, "challenge_panel") or
               String.contains?(player_html, "Challenge")

      assert String.contains?(watcher_html, "challenge_panel") or
               String.contains?(watcher_html, "Challenge")

      FuzzHelpers.assert_render_invariants!(player_html, :playing)
      FuzzHelpers.assert_render_invariants!(watcher_html, :playing)

      # Cast a vote from a non-challenger player
      state = FuzzHelpers.safe_get_state(game_id)
      challenge = List.first(state.challenges)
      voted_names = Map.keys(challenge.votes)

      non_voter =
        state.players
        |> Enum.with_index(1)
        |> Enum.find(fn {p, _idx} ->
          p.status == :playing and p.name not in voted_names
        end)

      case non_voter do
        {_player, idx} ->
          Game.challenge_vote(game_id, "token_#{idx}", challenge.id, true)
          :timer.sleep(20)

        nil ->
          :ok
      end

      # Re-render both views -- should not crash
      new_player_html = render(player_view)
      new_watcher_html = render(watcher_view)

      FuzzHelpers.assert_render_invariants!(new_player_html, :playing)
      FuzzHelpers.assert_render_invariants!(new_watcher_html, :playing)
    end
  end

  describe "playing phase renders in zen mode" do
    test "zen mode toggle hides activity panel and shows zen layout" do
      game_id = FuzzHelpers.setup_playing_game_with_words(2)

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

  describe "finished view renders" do
    test "finished game with words renders without crash" do
      game_id = FuzzHelpers.setup_finished_game(2, :bananagrams_half, 3)

      {:ok, _view, html} = mount_player(game_id, 1)
      FuzzHelpers.assert_render_invariants!(html, :finished)

      {:ok, _view, watcher_html} = mount_watcher(game_id)
      FuzzHelpers.assert_render_invariants!(watcher_html, :finished)
    end

    test "finished game with zero words renders without crash" do
      game_id = FuzzHelpers.setup_finished_game(2, :bananagrams_half, 0)

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
    test "renders for claimed words" do
      game_id = FuzzHelpers.setup_game_with_history(2)

      {:ok, state} = Game.get_state(game_id)
      all_words = Enum.flat_map(state.teams, & &1.words)

      {:ok, view, _html} = mount_player(game_id, 1)

      # Show word steal modal for a word that's in play
      case all_words do
        [word | _] ->
          render_click(view, "show_word_steal", %{"word" => word})
          html = render(view)
          FuzzHelpers.assert_render_invariants!(html, :playing)

          # Hide it
          render_click(view, "hide_word_steal", %{})
          html = render(view)
          FuzzHelpers.assert_render_invariants!(html, :playing)

        [] ->
          # No words claimed — just verify the view renders
          html = render(view)
          FuzzHelpers.assert_render_invariants!(html, :playing)
      end
    end
  end

  # ──────────────────────────────────────────────
  # Zen mode + auto_flip render tests
  # ──────────────────────────────────────────────

  describe "zen_mode and auto_flip render correctly" do
    test "both toggles independently and simultaneously" do
      game_id = FuzzHelpers.setup_playing_game_with_words(2)

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
    FuzzHelpers.check_views_render!(game_id, pv, wv)
  end

  defp current_game_status(game_id, fallback) do
    case FuzzHelpers.safe_get_state(game_id) do
      nil -> fallback
      state -> state.status
    end
  end

end

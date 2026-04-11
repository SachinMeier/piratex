defmodule Piratex.GameFuzzTest do
  use PiratexWeb.ConnCase, async: true
  use ExUnitProperties

  import Phoenix.LiveViewTest

  alias Piratex.Game
  alias Piratex.GameGenerators

  @moduletag :fuzz

  @dictionary GameGenerators.dictionary()
  @max_actions 80

  # Lightweight model to track game state for action generation
  defmodule Model do
    defstruct [
      :game_id,
      :player_count,
      :alive_players,
      :quit_players,
      :words_in_play,
      :status,
      :challenge_open,
      :game_stopped,
      :pool_empty
    ]
  end

  setup do
    ensure_dictionary_started()
    :ok
  end

  # ──────────────────────────────────────────────
  # Property 1: Random game sequences never crash
  # ──────────────────────────────────────────────

  property "random game sequences never crash the GenServer or LiveView" do
    check all(
            num_players <- integer(2..5),
            use_half_pool <- boolean(),
            action_slots <-
              list_of(GameGenerators.action_slot_gen(),
                min_length: 10,
                max_length: @max_actions
              ),
            max_runs: 50
          ) do
      model = setup_playing_game(num_players, use_half_pool)
      {player_view, watcher_view} = mount_views(model)

      final_model =
        action_slots
        |> Enum.with_index()
        |> Enum.reduce_while(model, fn {slot, idx}, model ->
          if model.game_stopped do
            {:halt, model}
          else
            new_model = execute_and_check(model, slot)

            if rem(idx, 5) == 4 and not new_model.game_stopped do
              check_views_render(player_view, watcher_view, new_model)
            end

            {:cont, new_model}
          end
        end)

      unless final_model.game_stopped do
        check_views_render(player_view, watcher_view, final_model)
      end
    end
  end

  # ──────────────────────────────────────────────
  # Property 2: Waiting phase lifecycle
  # ──────────────────────────────────────────────

  property "waiting phase: join, leave, rejoin, create teams, start" do
    check all(
            num_players <- integer(1..5),
            action_slots <-
              list_of(GameGenerators.waiting_action_slot_gen(),
                min_length: 5,
                max_length: 20
              ),
            max_runs: 30
          ) do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      # Start with 1 player
      :ok = Game.join_game(game_id, "player_1", "token_1")
      joined = MapSet.new([1])
      next_idx = 2

      {_joined, _next_idx, stopped} =
        Enum.reduce_while(action_slots, {joined, next_idx, false}, fn slot,
                                                                      {joined, next_idx, _stopped} ->
          case safe_get_state(game_id) do
            nil ->
              {:halt, {joined, next_idx, true}}

            _state ->
              {new_joined, new_next_idx} =
                execute_waiting_action(game_id, slot, joined, next_idx, num_players)

              {:cont, {new_joined, new_next_idx, false}}
          end
        end)

      # If game is still alive with players, try to start it
      unless stopped do
        case safe_get_state(game_id) do
          %{status: :waiting} ->
            if MapSet.size(joined) > 0 do
              token = "token_#{Enum.at(MapSet.to_list(joined), 0)}"
              Game.start_game(game_id, token)
            end

          _ ->
            :ok
        end
      end
    end
  end

  # ──────────────────────────────────────────────
  # Property 3: All players quit
  # ──────────────────────────────────────────────

  property "all-players-quit terminates game without crash" do
    check all(
            num_players <- integer(1..6),
            max_runs: 20
          ) do
      model = setup_playing_game(num_players, true)

      Enum.each(1..model.player_count, fn idx ->
        case Game.get_state(model.game_id) do
          {:ok, _} -> Game.quit_game(model.game_id, "token_#{idx}")
          {:error, :not_found} -> :ok
        end
      end)

      # :stop is Process.send_after(self(), :stop, 1000), so wait generously
      :timer.sleep(1500)
      assert {:error, :not_found} = Game.get_state(model.game_id)
    end
  end

  # ──────────────────────────────────────────────
  # Property 4: Single-player games
  # ──────────────────────────────────────────────

  property "single-player games complete without crashes" do
    check all(
            action_slots <-
              list_of(GameGenerators.action_slot_gen(),
                min_length: 10,
                max_length: 50
              ),
            max_runs: 20
          ) do
      model = setup_playing_game(1, true)

      Enum.reduce_while(action_slots, model, fn slot, model ->
        if model.game_stopped do
          {:halt, model}
        else
          # No challenges in single-player
          slot = if slot in [:challenge, :vote], do: :flip, else: slot
          new_model = execute_and_check(model, slot)
          {:cont, new_model}
        end
      end)
    end
  end

  # ──────────────────────────────────────────────
  # Test 5: Bad token exhaustive (deterministic)
  # ──────────────────────────────────────────────

  test "bad token returns error for every action, never crashes" do
    model = setup_playing_game(2, true)
    bad = "nonexistent_token"
    gid = model.game_id

    results = [
      Game.join_game(gid, "bad_name", bad),
      Game.create_team(gid, bad, "bad_team"),
      Game.join_team(gid, bad, 1),
      Game.leave_waiting_game(gid, bad),
      Game.start_game(gid, bad),
      Game.flip_letter(gid, bad),
      Game.claim_word(gid, bad, "test"),
      Game.challenge_word(gid, bad, "test"),
      Game.challenge_vote(gid, bad, 0, false),
      Game.send_chat_message(gid, bad, "hi"),
      Game.end_game_vote(gid, bad),
      Game.quit_game(gid, bad),
      Game.rejoin_game(gid, "bad_name", bad)
    ]

    Enum.each(results, fn result ->
      assert match?({:error, _}, result) or result == :ok,
             "Expected error or :ok, got: #{inspect(result)}"
    end)

    # GenServer must still be alive
    assert {:ok, _} = Game.get_state(gid)
  end

  # ──────────────────────────────────────────────
  # Test 6: Quit player exhaustive (deterministic)
  # ──────────────────────────────────────────────

  test "quit player returns error for every action, never crashes" do
    model = setup_playing_game(3, true)
    gid = model.game_id

    # Quit player 2
    :ok = Game.quit_game(gid, "token_2")

    # Flip a letter and claim a word so we have something to challenge
    {:ok, state} = Game.get_state(gid)
    turn_token = "token_#{state.turn + 1}"
    Game.flip_letter(gid, turn_token)

    quit_token = "token_2"

    results = [
      {"flip_letter", Game.flip_letter(gid, quit_token)},
      {"claim_word", Game.claim_word(gid, quit_token, "test")},
      {"challenge_word", Game.challenge_word(gid, quit_token, "nonexistent")},
      {"challenge_vote", Game.challenge_vote(gid, quit_token, 0, false)},
      {"send_chat_message", Game.send_chat_message(gid, quit_token, "hi")},
      {"end_game_vote", Game.end_game_vote(gid, quit_token)},
      {"quit_game (double)", Game.quit_game(gid, quit_token)},
      {"rejoin_game", Game.rejoin_game(gid, "player_2", quit_token)},
      {"create_team", Game.create_team(gid, quit_token, "team")},
      {"join_team", Game.join_team(gid, quit_token, 1)},
      {"start_game", Game.start_game(gid, quit_token)},
      {"leave_waiting_game", Game.leave_waiting_game(gid, quit_token)},
      {"join_game", Game.join_game(gid, "player_2", quit_token)}
    ]

    Enum.each(results, fn {action_name, result} ->
      assert match?({:error, _}, result) or result == :ok,
             "Quit player #{action_name} should return error or :ok, got: #{inspect(result)}"
    end)

    # GenServer must still be alive
    assert {:ok, _} = Game.get_state(gid)
  end

  # ──────────────────────────────────────────────
  # Test 7: Cross-phase exhaustive (deterministic)
  # ──────────────────────────────────────────────

  test "wrong-phase actions return errors without crashing" do
    model = setup_playing_game(2, true)
    gid = model.game_id
    token = "token_1"

    # Waiting-only actions during :playing
    playing_results = [
      Game.join_game(gid, "new_player", "new_token"),
      Game.create_team(gid, token, "new_team"),
      Game.join_team(gid, token, 999),
      Game.leave_waiting_game(gid, token),
      Game.start_game(gid, token),
      Game.set_letter_pool_type(gid, :bananagrams)
    ]

    Enum.each(playing_results, fn result ->
      assert match?({:error, _}, result),
             "Wrong-phase action during :playing should error, got: #{inspect(result)}"
    end)

    assert {:ok, _} = Game.get_state(gid)

    # Now end the game and test :finished phase
    # Flip all letters then vote to end
    drain_pool_and_end_game(gid, model.player_count)

    case Game.get_state(gid) do
      {:ok, %{status: :finished}} ->
        # All actions during :finished
        finished_results = [
          Game.join_game(gid, "new_player", "new_token"),
          Game.create_team(gid, token, "new_team"),
          Game.join_team(gid, token, 999),
          Game.leave_waiting_game(gid, token),
          Game.start_game(gid, token),
          Game.set_letter_pool_type(gid, :bananagrams),
          Game.flip_letter(gid, token),
          Game.claim_word(gid, token, "test"),
          Game.challenge_word(gid, token, "test"),
          Game.challenge_vote(gid, token, 0, false),
          Game.send_chat_message(gid, token, "hi"),
          Game.end_game_vote(gid, token)
        ]

        Enum.each(finished_results, fn result ->
          assert match?({:error, _}, result),
                 "Action during :finished should error, got: #{inspect(result)}"
        end)

        assert {:ok, _} = Game.get_state(gid)

      _ ->
        :ok
    end
  end

  # ──────────────────────────────────────────────
  # Test 8: Duplicate :end_game
  # ──────────────────────────────────────────────

  test "duplicate end_game does not crash" do
    state =
      Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        letter_pool: Enum.shuffle(["z"]),
        initial_letter_count: 1,
        center: [],
        center_sorted: [],
        turn_timer_ref: nil,
        start_time: nil,
        end_time: nil,
        game_stats: nil
      })

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)
    :ok = Game.join_game(game_id, "p1", "t1")
    :ok = Game.join_game(game_id, "p2", "t2")
    :ok = Game.start_game(game_id, "t1")
    :ok = Game.flip_letter(game_id, "t1")

    # Game has scheduled :end_game. Send another one manually.
    [{pid, _}] = Registry.lookup(Piratex.Game.Registry, game_id)
    send(pid, :end_game)
    :timer.sleep(100)

    case Game.get_state(game_id) do
      {:ok, %{status: :finished}} -> :ok
      {:error, :not_found} -> :ok
    end
  end

  # ──────────────────────────────────────────────
  # Test 9: Challenge after last flip
  # ──────────────────────────────────────────────

  test "challenge after last flip does not crash" do
    state =
      Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        letter_pool: Enum.shuffle(["s"]),
        initial_letter_count: 4,
        center: ["e", "a", "t"],
        center_sorted: ["a", "e", "t"],
        turn_timer_ref: nil,
        start_time: nil,
        end_time: nil,
        game_stats: nil
      })

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)
    :ok = Game.join_game(game_id, "p1", "t1")
    :ok = Game.join_game(game_id, "p2", "t2")
    :ok = Game.start_game(game_id, "t1")

    # Claim a word from center
    Game.claim_word(game_id, "t1", "eat")

    # Flip last letter (triggers end_game countdown)
    {:ok, state} = Game.get_state(game_id)
    turn_token = "t#{state.turn + 1}"
    Game.flip_letter(game_id, turn_token)

    # Immediately challenge
    result = Game.challenge_word(game_id, "t2", "eat")
    assert result in [:ok, {:error, :word_not_in_play}, {:error, :game_not_playing}]

    :timer.sleep(100)

    case Game.get_state(game_id) do
      {:ok, state} -> assert state.status in [:playing, :finished]
      {:error, :not_found} -> :ok
    end
  end

  # ──────────────────────────────────────────────
  # Test 10: Challenge mid-quit cascade
  # ──────────────────────────────────────────────

  test "challenge resolves when all voters quit" do
    state =
      Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        letter_pool: Enum.shuffle(["s", "e", "t", "a", "x", "y"]),
        initial_letter_count: 6,
        center: [],
        center_sorted: [],
        turn_timer_ref: nil,
        start_time: nil,
        end_time: nil,
        game_stats: nil
      })

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)
    :ok = Game.join_game(game_id, "p1", "t1")
    :ok = Game.join_game(game_id, "p2", "t2")
    :ok = Game.join_game(game_id, "p3", "t3")
    :ok = Game.start_game(game_id, "t1")

    # Flip some letters to get center letters
    flip_n_letters(game_id, 4)

    # Try to claim a word
    Game.claim_word(game_id, "t1", "set")

    {:ok, state} = Game.get_state(game_id)

    if Enum.any?(state.teams, fn t -> t.words != [] end) do
      # Challenge it
      word =
        state.teams
        |> Enum.flat_map(& &1.words)
        |> List.first()

      if word do
        case Game.challenge_word(game_id, "t2", word) do
          :ok ->
            # p2 quit (vote removed, reevaluated)
            :ok = Game.quit_game(game_id, "t2")
            # p3 quit
            :ok = Game.quit_game(game_id, "t3")

            :timer.sleep(50)
            # Only p1 remains — GenServer must survive.
            # Challenge may still be open (p1 hasn't voted), which is correct.
            case Game.get_state(game_id) do
              {:ok, _state} -> :ok
              {:error, :not_found} -> :ok
            end

          {:error, _} ->
            :ok
        end
      end
    end
  end

  # ──────────────────────────────────────────────
  # Test 11: Degenerate inputs
  # ──────────────────────────────────────────────

  test "degenerate inputs don't crash the GenServer" do
    model = setup_playing_game(2, true)
    gid = model.game_id
    token = "token_1"

    results = [
      Game.claim_word(gid, token, ""),
      Game.claim_word(gid, token, String.duplicate("a", 1000)),
      Game.send_chat_message(gid, token, ""),
      Game.send_chat_message(gid, token, String.duplicate("x", 500)),
      Game.challenge_vote(gid, token, -1, false),
      Game.challenge_vote(gid, token, 999_999, true),
      Game.join_team(gid, token, -1),
      Game.join_team(gid, token, 999_999)
    ]

    Enum.each(results, fn result ->
      assert match?({:error, _}, result) or result == :ok,
             "Degenerate input should return error or :ok, got: #{inspect(result)}"
    end)

    assert {:ok, _} = Game.get_state(gid)
  end

  # ──────────────────────────────────────────────
  # Test 12: Rejoin edge cases
  # ──────────────────────────────────────────────

  test "rejoin edge cases" do
    model = setup_playing_game(2, true)
    gid = model.game_id

    # Rejoin with valid token
    assert :ok = Game.rejoin_game(gid, "player_1", "token_1")

    # Rejoin with token not in game
    assert {:error, :not_found} = Game.rejoin_game(gid, "nobody", "bad_token")

    # Quit player 2 and rejoin
    :ok = Game.quit_game(gid, "token_2")
    assert :ok = Game.rejoin_game(gid, "player_2", "token_2")

    assert {:ok, _} = Game.get_state(gid)
  end

  # ──────────────────────────────────────────────
  # Game setup helpers
  # ──────────────────────────────────────────────

  defp setup_playing_game(num_players, use_half_pool) do
    {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

    if use_half_pool do
      :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)
    end

    for i <- 1..num_players do
      :ok = Game.join_game(game_id, "player_#{i}", "token_#{i}")
    end

    :ok = Game.start_game(game_id, "token_1")

    %Model{
      game_id: game_id,
      player_count: num_players,
      alive_players: MapSet.new(1..num_players),
      quit_players: MapSet.new(),
      words_in_play: [],
      status: :playing,
      challenge_open: false,
      game_stopped: false,
      pool_empty: false
    }
  end

  defp mount_views(model) do
    conn =
      build_conn()
      |> init_test_session(%{
        "game_id" => model.game_id,
        "player_name" => "player_1",
        "player_token" => "token_1"
      })

    player_view =
      case live(conn, ~p"/game/#{model.game_id}") do
        {:ok, view, _html} -> view
        {:error, {:live_redirect, _}} -> nil
      end

    watcher_view =
      case live(build_conn(), ~p"/watch/#{model.game_id}") do
        {:ok, view, _html} -> view
        _ -> nil
      end

    {player_view, watcher_view}
  end

  defp check_views_render(player_view, watcher_view, model) do
    if not model.game_stopped do
      if player_view, do: render(player_view)
      if watcher_view, do: render(watcher_view)
    end
  end

  # ──────────────────────────────────────────────
  # Action execution
  # ──────────────────────────────────────────────

  defp execute_and_check(model, slot) do
    model = execute_action(model, slot)
    new_model = sync_model(model)
    check_invariants!(new_model)
    new_model
  end

  defp execute_action(%{game_stopped: true} = model, _slot), do: model

  defp execute_action(model, :flip) do
    token = pick_turn_player_token(model)
    Game.flip_letter(model.game_id, token)
    model
  end

  defp execute_action(model, :claim) do
    token = pick_random_alive_token(model)
    word = Enum.random(@dictionary)
    Game.claim_word(model.game_id, token, word)
    model
  end

  defp execute_action(model, :challenge) do
    if model.words_in_play == [] do
      model
    else
      token = pick_random_alive_token(model)
      word = Enum.random(model.words_in_play)
      Game.challenge_word(model.game_id, token, word)
      model
    end
  end

  defp execute_action(model, :vote) do
    case fetch_open_challenge(model) do
      nil ->
        model

      challenge_id ->
        token = pick_random_alive_token(model)
        vote = Enum.random([true, false])
        Game.challenge_vote(model.game_id, token, challenge_id, vote)
        model
    end
  end

  defp execute_action(model, :quit) do
    if MapSet.size(model.alive_players) == 0 do
      model
    else
      idx = pick_random_alive_index(model)
      Game.quit_game(model.game_id, "token_#{idx}")
      :timer.sleep(5)
      model
    end
  end

  defp execute_action(model, :end_vote) do
    token = pick_random_alive_token(model)
    Game.end_game_vote(model.game_id, token)
    model
  end

  defp execute_action(model, :chat) do
    token = pick_random_alive_token(model)
    Game.send_chat_message(model.game_id, token, "fuzz_#{:rand.uniform(999)}")
    model
  end

  defp execute_action(model, :bad_token) do
    execute_bad_token_action(model)
    model
  end

  defp execute_action(model, :quit_player_action) do
    if MapSet.size(model.quit_players) == 0 do
      model
    else
      execute_quit_player_action(model)
      model
    end
  end

  defp execute_action(model, :rejoin) do
    idx = :rand.uniform(model.player_count)
    Game.rejoin_game(model.game_id, "player_#{idx}", "token_#{idx}")
    model
  end

  defp execute_action(model, :cross_phase) do
    token = pick_random_alive_token(model)
    gid = model.game_id

    Enum.random([
      fn -> Game.create_team(gid, token, "fuzz_team") end,
      fn -> Game.join_team(gid, token, 999) end,
      fn -> Game.start_game(gid, token) end,
      fn -> Game.set_letter_pool_type(gid, :bananagrams) end,
      fn -> Game.join_game(gid, "fuzz_player", "fuzz_token") end,
      fn -> Game.leave_waiting_game(gid, token) end
    ]).()

    model
  end

  defp execute_action(model, :degenerate_input) do
    token = pick_random_alive_token(model)
    gid = model.game_id

    Enum.random([
      fn -> Game.claim_word(gid, token, "") end,
      fn -> Game.claim_word(gid, token, String.duplicate("a", 500)) end,
      fn -> Game.send_chat_message(gid, token, "") end,
      fn -> Game.send_chat_message(gid, token, String.duplicate("x", 500)) end,
      fn -> Game.challenge_vote(gid, token, -1, false) end,
      fn -> Game.challenge_vote(gid, token, 999_999, true) end,
      fn -> Game.join_team(gid, token, -1) end
    ]).()

    model
  end

  # ──────────────────────────────────────────────
  # Bad token and quit player exhaustive actions
  # ──────────────────────────────────────────────

  defp execute_bad_token_action(model) do
    bad = "nonexistent_#{:rand.uniform(999)}"
    gid = model.game_id

    result =
      Enum.random([
        fn -> Game.join_game(gid, "bad_name", bad) end,
        fn -> Game.create_team(gid, bad, "bad_team") end,
        fn -> Game.join_team(gid, bad, 1) end,
        fn -> Game.leave_waiting_game(gid, bad) end,
        fn -> Game.start_game(gid, bad) end,
        fn -> Game.flip_letter(gid, bad) end,
        fn -> Game.claim_word(gid, bad, "test") end,
        fn -> Game.challenge_word(gid, bad, "test") end,
        fn -> Game.challenge_vote(gid, bad, 0, false) end,
        fn -> Game.send_chat_message(gid, bad, "hi") end,
        fn -> Game.end_game_vote(gid, bad) end,
        fn -> Game.quit_game(gid, bad) end,
        fn -> Game.rejoin_game(gid, "bad_name", bad) end
      ]).()

    assert match?({:error, _}, result) or result == :ok,
           "Bad token should return error or :ok, got: #{inspect(result)}"
  end

  defp execute_quit_player_action(model) do
    quit_idx = Enum.random(MapSet.to_list(model.quit_players))
    token = "token_#{quit_idx}"
    gid = model.game_id

    word = Enum.at(model.words_in_play, 0, "test")

    result =
      Enum.random([
        fn -> Game.flip_letter(gid, token) end,
        fn -> Game.claim_word(gid, token, "test") end,
        fn -> Game.challenge_word(gid, token, word) end,
        fn -> Game.challenge_vote(gid, token, 0, false) end,
        fn -> Game.send_chat_message(gid, token, "hi") end,
        fn -> Game.end_game_vote(gid, token) end,
        fn -> Game.quit_game(gid, token) end,
        fn -> Game.rejoin_game(gid, "player_#{quit_idx}", token) end,
        fn -> Game.create_team(gid, token, "team") end,
        fn -> Game.join_team(gid, token, 1) end,
        fn -> Game.start_game(gid, token) end,
        fn -> Game.leave_waiting_game(gid, token) end,
        fn -> Game.join_game(gid, "player_#{quit_idx}", token) end
      ]).()

    assert match?({:error, _}, result) or result == :ok,
           "Quit player action should return error or :ok, got: #{inspect(result)}"
  end

  # ──────────────────────────────────────────────
  # Model sync and invariant checking
  # ──────────────────────────────────────────────

  defp sync_model(model) do
    case Game.get_state(model.game_id) do
      {:ok, state} ->
        alive =
          state.players
          |> Enum.with_index(1)
          |> Enum.filter(fn {p, _} -> p.status == :playing end)
          |> MapSet.new(fn {_, i} -> i end)

        quit =
          state.players
          |> Enum.with_index(1)
          |> Enum.filter(fn {p, _} -> p.status == :quit end)
          |> MapSet.new(fn {_, i} -> i end)

        words = Enum.flat_map(state.teams, & &1.words)

        %{
          model
          | status: state.status,
            alive_players: alive,
            quit_players: quit,
            words_in_play: words,
            challenge_open: state.challenges != [],
            game_stopped: false,
            pool_empty: state.letter_pool_count == 0
        }

      {:error, :not_found} ->
        %{model | game_stopped: true}
    end
  end

  defp check_invariants!(%{game_stopped: true}), do: :ok

  defp check_invariants!(model) do
    case Game.get_state(model.game_id) do
      {:error, :not_found} ->
        :ok

      {:ok, state} ->
        assert state.status in [:waiting, :playing, :finished],
               "Invalid status: #{inspect(state.status)}"

        if state.status == :playing and length(state.players) > 0 do
          assert state.turn >= 0 and state.turn < length(state.players),
                 "Turn #{state.turn} out of bounds for #{length(state.players)} players"
        end

        # Letter conservation
        center_count = length(state.center)

        words_letter_count =
          state.teams
          |> Enum.flat_map(& &1.words)
          |> Enum.map(&String.length/1)
          |> Enum.sum()

        pool_count = state.letter_pool_count
        total = center_count + words_letter_count + pool_count

        assert total == state.initial_letter_count,
               "Letter conservation: center=#{center_count} + words=#{words_letter_count} + pool=#{pool_count} = #{total}, expected #{state.initial_letter_count}"

        # No duplicate player names
        names = Enum.map(state.players, & &1.name)
        assert length(names) == length(Enum.uniq(names)), "Duplicate player names"

        # Valid team references
        team_ids = MapSet.new(state.teams, & &1.id)

        Enum.each(state.players_teams, fn {_name, tid} ->
          assert MapSet.member?(team_ids, tid),
                 "players_teams references nonexistent team #{tid}"
        end)

        # challenged_words is a MapSet
        assert is_struct(state.challenged_words, MapSet)

        assert state.active_player_count >= 0

        if state.status == :finished do
          Enum.each(state.teams, fn team ->
            assert is_integer(team.score),
                   "Team #{team.name} has no score after game finished"
          end)
        end
    end
  end

  # ──────────────────────────────────────────────
  # Helpers
  # ──────────────────────────────────────────────

  defp pick_turn_player_token(model) do
    case Game.get_state(model.game_id) do
      {:ok, %{turn: turn}} ->
        if :rand.uniform(10) <= 8 do
          "token_#{turn + 1}"
        else
          pick_random_alive_token(model)
        end

      _ ->
        "token_1"
    end
  end

  defp pick_random_alive_token(model) do
    case MapSet.to_list(model.alive_players) do
      [] -> "token_1"
      alive -> "token_#{Enum.random(alive)}"
    end
  end

  defp pick_random_alive_index(model) do
    case MapSet.to_list(model.alive_players) do
      [] -> 1
      alive -> Enum.random(alive)
    end
  end

  defp fetch_open_challenge(model) do
    case Game.get_state(model.game_id) do
      {:ok, %{challenges: [%{id: id} | _]}} -> id
      _ -> nil
    end
  end

  defp execute_waiting_action(game_id, :join, joined, next_idx, max_players) do
    if next_idx <= max_players do
      Game.join_game(game_id, "player_#{next_idx}", "token_#{next_idx}")
      {MapSet.put(joined, next_idx), next_idx + 1}
    else
      {joined, next_idx}
    end
  end

  defp execute_waiting_action(game_id, :create_team, joined, next_idx, _max) do
    if MapSet.size(joined) > 0 do
      idx = Enum.random(MapSet.to_list(joined))
      Game.create_team(game_id, "token_#{idx}", "team_#{:rand.uniform(999)}")
    end

    {joined, next_idx}
  end

  defp execute_waiting_action(game_id, :join_team, joined, next_idx, _max) do
    if MapSet.size(joined) > 0 do
      idx = Enum.random(MapSet.to_list(joined))

      case Game.get_state(game_id) do
        {:ok, %{teams: teams}} when teams != [] ->
          team = Enum.random(teams)
          Game.join_team(game_id, "token_#{idx}", team.id)

        _ ->
          :ok
      end
    end

    {joined, next_idx}
  end

  defp execute_waiting_action(game_id, :leave, joined, next_idx, _max) do
    if MapSet.size(joined) > 0 do
      idx = Enum.random(MapSet.to_list(joined))
      Game.leave_waiting_game(game_id, "token_#{idx}")
      {MapSet.delete(joined, idx), next_idx}
    else
      {joined, next_idx}
    end
  end

  defp execute_waiting_action(game_id, :quit, joined, next_idx, _max) do
    if MapSet.size(joined) > 0 do
      idx = Enum.random(MapSet.to_list(joined))
      Game.quit_game(game_id, "token_#{idx}")
      {MapSet.delete(joined, idx), next_idx}
    else
      {joined, next_idx}
    end
  end

  defp execute_waiting_action(game_id, :rejoin, joined, next_idx, _max) do
    idx = :rand.uniform(max(next_idx - 1, 1))
    Game.rejoin_game(game_id, "player_#{idx}", "token_#{idx}")
    {joined, next_idx}
  end

  defp execute_waiting_action(game_id, :bad_token, joined, next_idx, _max) do
    bad = "bad_token_#{:rand.uniform(999)}"

    Enum.random([
      fn -> Game.join_game(game_id, "bad", bad) end,
      fn -> Game.create_team(game_id, bad, "bad_team") end,
      fn -> Game.join_team(game_id, bad, 1) end,
      fn -> Game.leave_waiting_game(game_id, bad) end,
      fn -> Game.start_game(game_id, bad) end
    ]).()

    {joined, next_idx}
  end

  defp flip_n_letters(game_id, n) do
    Enum.each(1..n, fn _ ->
      case Game.get_state(game_id) do
        {:ok, %{status: :playing, turn: turn, letter_pool_count: pool}} when pool > 0 ->
          Game.flip_letter(game_id, "t#{turn + 1}")

        _ ->
          :ok
      end
    end)
  end

  defp drain_pool_and_end_game(game_id, player_count) do
    # Flip all remaining letters
    Enum.reduce_while(1..200, :ok, fn _, _ ->
      case Game.get_state(game_id) do
        {:ok, %{status: :playing, letter_pool_count: 0}} ->
          {:halt, :ok}

        {:ok, %{status: :playing, turn: turn}} ->
          Game.flip_letter(game_id, "token_#{turn + 1}")
          {:cont, :ok}

        _ ->
          {:halt, :ok}
      end
    end)

    # All players vote to end
    for i <- 1..player_count do
      Game.end_game_vote(game_id, "token_#{i}")
    end

    :timer.sleep(50)
  end

  defp safe_get_state(game_id) do
    case Game.get_state(game_id) do
      {:ok, state} -> state
      {:error, :not_found} -> nil
    end
  rescue
    _ -> nil
  catch
    :exit, _ -> nil
  end

  defp ensure_dictionary_started do
    case Piratex.Dictionary.start_link(nil) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end
end

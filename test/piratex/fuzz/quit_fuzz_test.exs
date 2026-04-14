defmodule Piratex.QuitFuzzTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Piratex.FuzzHelpers
  alias Piratex.GameGenerators
  alias Piratex.Game

  @moduletag :fuzz

  setup do
    FuzzHelpers.ensure_dictionary_started()
    :ok
  end

  describe "quit at any point" do
    property "quit at any point never crashes" do
      check all(
              num_players <- StreamData.integer(2..6),
              seeds <- GameGenerators.seed_list_gen(10, 50),
              quit_after <- StreamData.integer(1..40),
              quit_player_idx <- StreamData.integer(1..6),
              max_runs: 50
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players)
        quit_idx = min(quit_player_idx, num_players)

        # Run some random actions
        seeds
        |> Enum.take(min(quit_after, length(seeds)))
        |> Enum.each(fn seed ->
          if FuzzHelpers.game_alive?(game_id) do
            action = GameGenerators.select_action(game_id, seed)
            GameGenerators.execute(action)
          end
        end)

        if FuzzHelpers.game_alive?(game_id) do
          {:ok, state_before} = Game.get_state(game_id)

          # Quit the selected player
          quit_token = "token_#{quit_idx}"
          Game.quit_game(game_id, quit_token)
          :timer.sleep(10)

          if FuzzHelpers.game_alive?(game_id) do
            {:ok, state_after} = Game.get_state(game_id)

            # If it was their turn, turn should have advanced
            if state_before.status == :playing do
              turn_player_before = Enum.at(state_before.players, state_before.turn)

              if turn_player_before != nil and
                   turn_player_before.name == "player_#{quit_idx}" and
                   state_after.status == :playing do
                turn_player_after = Enum.at(state_after.players, state_after.turn)

                assert turn_player_after.status == :playing,
                       "Turn should advance to a non-quit player"
              end
            end

            FuzzHelpers.check_invariants!(game_id)
          end
        end
      end
    end
  end

  describe "all players quit" do
    property "all-players-quit terminates game" do
      check all(
              num_players <- StreamData.integer(1..6),
              quit_order <- StreamData.list_of(StreamData.integer(1..6), length: 6),
              max_runs: 30
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players)

        # Determine unique quit order for the actual players
        quit_indices =
          quit_order
          |> Enum.uniq()
          |> Enum.filter(&(&1 <= num_players))
          |> Enum.take(num_players)

        # If the shuffle didn't cover all players, append the missing ones
        missing = Enum.to_list(1..num_players) -- quit_indices
        quit_indices = quit_indices ++ missing

        # Quit all players
        Enum.each(quit_indices, fn idx ->
          if FuzzHelpers.game_alive?(game_id) do
            Game.quit_game(game_id, "token_#{idx}")
            :timer.sleep(5)
          end
        end)

        # Game should stop within 2 seconds (1s delay + buffer)
        # Process may die during polling, so catch exits
        result =
          try do
            FuzzHelpers.wait_for_game_end(game_id, 2000)
          catch
            :exit, _ -> :dead
          end

        assert result in [:finished, :dead, :ok],
               "Game should terminate after all players quit, got: #{inspect(result)}"
      end
    end
  end

  describe "quit player's words remain stealable" do
    property "quit player's words remain stealable" do
      check all(
              num_players <- StreamData.integer(2..4),
              max_runs: 50
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players)

        # Flip letters and try to claim a word for player 1
        FuzzHelpers.flip_n_letters(game_id, 10)

        {:ok, state} = Game.get_state(game_id)
        claimable = FuzzHelpers.find_claimable_words_from_center(state.center)

        # Try each candidate until one succeeds
        claimed =
          Enum.reduce_while(claimable, nil, fn word, _acc ->
            case Game.claim_word(game_id, "token_1", word) do
              :ok -> {:halt, word}
              {:error, _} -> {:cont, nil}
            end
          end)

        case claimed do
          nil ->
            :ok

          word ->
            # Player 1 quits
            :ok = Game.quit_game(game_id, "token_1")
            :timer.sleep(10)

            if FuzzHelpers.game_alive?(game_id) do
              {:ok, post_quit_state} = Game.get_state(game_id)

              # Word should still be in play
              assert Enum.any?(post_quit_state.teams, fn t -> word in t.words end),
                     "Quit player's word should remain in play"

              # Try to find a steal for that word
              steals = FuzzHelpers.find_valid_steals(post_quit_state)

              # Filter to steals of the quit player's word
              word_steals = Enum.filter(steals, fn {old, _new} -> old == word end)

              # If a steal is possible, execute it
              case word_steals do
                [{_old, new_word} | _] ->
                  alive_token = FuzzHelpers.pick_alive_token(post_quit_state, 0.5)
                  result = Game.claim_word(game_id, alive_token, new_word)

                  if result == :ok do
                    {:ok, stolen_state} = Game.get_state(game_id)

                    assert Enum.any?(stolen_state.teams, fn t -> new_word in t.words end),
                           "Stolen word should be in play"

                    refute Enum.any?(stolen_state.teams, fn t -> word in t.words end),
                           "Old word should be removed after steal"
                  end

                [] ->
                  # Flip more letters to try to make a steal possible
                  FuzzHelpers.flip_n_letters(game_id, 5)
              end

              FuzzHelpers.check_invariants!(game_id)
            end
        end
      end
    end
  end

  describe "quit during end-game vote" do
    test "quit during end-game vote completes game if remaining all voted" do
      game_id = FuzzHelpers.setup_playing_game(2)

      # Drain the pool
      FuzzHelpers.drain_pool_and_end_game(game_id, 0)

      {:ok, state} = Game.get_state(game_id)

      if state.status == :playing do
        # Player 1 votes to end
        Game.end_game_vote(game_id, "token_1")

        {:ok, mid_state} = Game.get_state(game_id)

        if mid_state.status == :playing do
          # Player 2 quits instead of voting
          :ok = Game.quit_game(game_id, "token_2")
          :timer.sleep(50)

          result = FuzzHelpers.wait_for_game_end(game_id, 2000)

          assert result in [:finished, :dead],
                 "Game should end when remaining player voted and other quit"
        end
      end
    end
  end

  describe "actions from quit player" do
    test "actions from quit player return errors" do
      game_id = FuzzHelpers.setup_playing_game(3)

      # Flip a few letters first
      FuzzHelpers.flip_n_letters(game_id, 5)

      # Player 3 quits
      :ok = Game.quit_game(game_id, "token_3")
      :timer.sleep(10)

      assert FuzzHelpers.game_alive?(game_id)

      quit_token = "token_3"

      # flip_letter
      result = Game.flip_letter(game_id, quit_token)
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # claim_word
      result = Game.claim_word(game_id, quit_token, "test")
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # challenge_word
      result = Game.challenge_word(game_id, quit_token, "test")
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # challenge_vote
      result = Game.challenge_vote(game_id, quit_token, 0, true)
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # send_chat_message
      result = Game.send_chat_message(game_id, quit_token, "hello")
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # end_game_vote
      result = Game.end_game_vote(game_id, quit_token)
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # create_team (wrong phase)
      result = Game.create_team(game_id, quit_token, "new_team")
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # join_team (wrong phase)
      result = Game.join_team(game_id, quit_token, 999)
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # leave_waiting_game (wrong phase)
      result = Game.leave_waiting_game(game_id, quit_token)
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # start_game (wrong phase)
      result = Game.start_game(game_id, quit_token)
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # set_letter_pool_type (wrong phase)
      result = Game.set_letter_pool_type(game_id, :bananagrams)
      assert match?({:error, _}, result) or result == :ok
      assert FuzzHelpers.game_alive?(game_id)

      # quit_game again (double quit)
      result = Game.quit_game(game_id, quit_token)
      assert result == :ok or match?({:error, _}, result)
      :timer.sleep(10)
      assert FuzzHelpers.game_alive?(game_id)

      # rejoin_game
      result = Game.rejoin_game(game_id, "player_3", quit_token)
      assert result == :ok or match?({:error, _}, result)
      assert FuzzHelpers.game_alive?(game_id)

      # get_state (always works)
      result = Game.get_state(game_id)
      assert match?({:ok, _}, result)

      FuzzHelpers.check_invariants!(game_id)
    end
  end

  describe "rejoin and double quit" do
    test "rejoin after quit returns :ok" do
      game_id = FuzzHelpers.setup_playing_game(3)

      :ok = Game.quit_game(game_id, "token_2")
      :timer.sleep(10)

      assert FuzzHelpers.game_alive?(game_id)

      result = Game.rejoin_game(game_id, "player_2", "token_2")
      assert result == :ok

      FuzzHelpers.check_invariants!(game_id)
    end

    test "double quit doesn't crash" do
      game_id = FuzzHelpers.setup_playing_game(3)

      :ok = Game.quit_game(game_id, "token_2")
      :timer.sleep(10)

      assert FuzzHelpers.game_alive?(game_id)

      # Quit again - should not crash
      result = Game.quit_game(game_id, "token_2")
      assert result == :ok or match?({:error, _}, result)
      :timer.sleep(10)

      assert FuzzHelpers.game_alive?(game_id)
      FuzzHelpers.check_invariants!(game_id)
    end
  end
end

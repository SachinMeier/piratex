defmodule Piratex.ChallengeFuzzTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Piratex.FuzzHelpers
  alias Piratex.Game

  @moduletag :fuzz

  setup do
    FuzzHelpers.ensure_dictionary_started()
    :ok
  end

  # Helper: set up a game with a claim ready to challenge.
  # Returns {game_id, claimed_word, state} where claimed_word is on team 1.
  defp setup_game_with_claim(num_players) do
    game_id = FuzzHelpers.setup_playing_game(num_players)
    flip_until_claimable(game_id, num_players, 50)
  end

  defp flip_until_claimable(game_id, num_players, attempts_left) when attempts_left > 0 do
    FuzzHelpers.flip_n_letters(game_id, 3)
    {:ok, state} = Game.get_state(game_id)

    if state.status != :playing do
      :no_claimable_word
    else
      claimable = FuzzHelpers.find_claimable_words_from_center(state.center)
      words_in_play = Enum.flat_map(state.teams, & &1.words)
      claimable = Enum.reject(claimable, &(&1 in words_in_play))
      token = FuzzHelpers.pick_alive_token(state, 0.0)

      case try_claim_any(game_id, token, claimable) do
        {:ok, word} ->
          {:ok, new_state} = Game.get_state(game_id)
          {game_id, word, new_state}

        :none ->
          flip_until_claimable(game_id, num_players, attempts_left - 1)
      end
    end
  end

  defp flip_until_claimable(_game_id, _num_players, 0) do
    :no_claimable_word
  end

  defp try_claim_any(_game_id, _token, []), do: :none

  defp try_claim_any(game_id, token, [word | rest]) do
    case Game.claim_word(game_id, token, word) do
      :ok -> {:ok, word}
      {:error, _} -> try_claim_any(game_id, token, rest)
    end
  end

  defp get_game_pid(game_id) do
    [{pid, _}] = Registry.lookup(Piratex.Game.Registry, game_id)
    pid
  end

  describe "challenge vote outcomes" do
    property "challenge vote outcomes are correct" do
      check all(
              num_players <- StreamData.integer(2..6),
              vote_pattern <- StreamData.list_of(StreamData.boolean(), length: 6),
              max_runs: 50
            ) do
        case setup_game_with_claim(num_players) do
          :no_claimable_word ->
            :ok

          {game_id, word, _state} ->
            # Open challenge
            challenger_token = "token_2"

            case Game.challenge_word(game_id, challenger_token, word) do
              :ok ->
                {:ok, state} = Game.get_state(game_id)
                [challenge | _] = state.challenges
                challenge_id = challenge.id

                # Player 2 already voted false (challenger auto-votes against)
                # Cast remaining votes
                votes = Enum.take(vote_pattern, num_players)

                remaining_votes =
                  votes
                  |> Enum.with_index(1)
                  |> Enum.reject(fn {_vote, idx} -> idx == 2 end)

                Enum.each(remaining_votes, fn {vote, idx} ->
                  Game.challenge_vote(game_id, "token_#{idx}", challenge_id, vote)
                end)

                {:ok, final_state} = Game.get_state(game_id)

                # If challenge resolved, verify outcome
                if final_state.challenges == [] do
                  # Count expected votes: player 2 voted false, rest per pattern
                  all_votes =
                    votes
                    |> Enum.with_index(1)
                    |> Enum.map(fn {vote, idx} ->
                      if idx == 2, do: false, else: vote
                    end)
                    |> Enum.take(num_players)

                  valid_ct = Enum.count(all_votes, & &1)
                  invalid_ct = Enum.count(all_votes, &(!&1))
                  threshold = ceil(num_players / 2.0)

                  expected_valid =
                    cond do
                      valid_ct > threshold -> true
                      invalid_ct > threshold -> false
                      # tie goes to thief (word valid)
                      valid_ct >= threshold -> true
                      invalid_ct >= threshold -> false
                      true -> nil
                    end

                  if expected_valid != nil do
                    word_still_in_play =
                      Enum.any?(final_state.teams, fn t -> word in t.words end)

                    if expected_valid do
                      assert word_still_in_play,
                             "Word should remain (valid) but was removed"
                    else
                      refute word_still_in_play,
                             "Word should be removed (invalid) but remained"
                    end
                  end
                end

                FuzzHelpers.check_invariants!(game_id)

              {:error, _} ->
                :ok
            end
        end
      end
    end
  end

  describe "quit during challenge" do
    property "quit during challenge resolves correctly" do
      check all(
              num_players <- StreamData.integer(3..6),
              num_voters <- StreamData.integer(0..3),
              num_quitters <- StreamData.integer(1..2),
              max_runs: 50
            ) do
        case setup_game_with_claim(num_players) do
          :no_claimable_word ->
            :ok

          {game_id, word, _state} ->
            case Game.challenge_word(game_id, "token_2", word) do
              :ok ->
                {:ok, state} = Game.get_state(game_id)
                [challenge | _] = state.challenges
                challenge_id = challenge.id

                # Cast some votes (skip player 2 who already voted)
                voters =
                  Enum.to_list(1..num_players)
                  |> Enum.reject(&(&1 == 2))
                  |> Enum.take(num_voters)

                Enum.each(voters, fn idx ->
                  Game.challenge_vote(game_id, "token_#{idx}", challenge_id, true)
                end)

                # Quit some players who haven't voted
                non_voters =
                  Enum.to_list(1..num_players)
                  |> Enum.reject(&(&1 == 2))
                  |> Enum.reject(&(&1 in voters))
                  |> Enum.take(num_quitters)

                Enum.each(non_voters, fn idx ->
                  Game.quit_game(game_id, "token_#{idx}")
                end)

                :timer.sleep(10)

                if FuzzHelpers.game_alive?(game_id) do
                  {:ok, post_state} = Game.get_state(game_id)

                  # Verify quit players' votes were removed from any open challenges
                  Enum.each(post_state.challenges, fn c ->
                    quit_names =
                      Enum.map(non_voters, fn idx -> "player_#{idx}" end)

                    Enum.each(quit_names, fn name ->
                      refute Map.has_key?(c.votes, name),
                             "Quit player #{name} still has vote in challenge"
                    end)
                  end)

                  # Verify threshold recalculated
                  alive = FuzzHelpers.alive_player_count(post_state)

                  if alive > 0 do
                    assert post_state.active_player_count == alive
                  end

                  FuzzHelpers.check_invariants!(game_id)
                end

              {:error, _} ->
                :ok
            end
        end
      end
    end

    test "vote then quit removes vote" do
      case setup_game_with_claim(3) do
        :no_claimable_word ->
          :ok

        {game_id, word, _state} ->
          :ok = Game.challenge_word(game_id, "token_2", word)
          {:ok, state} = Game.get_state(game_id)
          [challenge | _] = state.challenges
          challenge_id = challenge.id

          # Player 1 votes
          :ok = Game.challenge_vote(game_id, "token_1", challenge_id, true)

          {:ok, mid_state} = Game.get_state(game_id)
          [mid_challenge | _] = mid_state.challenges
          assert Map.has_key?(mid_challenge.votes, "player_1")

          # Player 1 quits
          :ok = Game.quit_game(game_id, "token_1")
          :timer.sleep(10)

          if FuzzHelpers.game_alive?(game_id) do
            {:ok, post_state} = Game.get_state(game_id)

            # If challenge is still open, player_1's vote should be removed
            Enum.each(post_state.challenges, fn c ->
              refute Map.has_key?(c.votes, "player_1"),
                     "Quit player's vote should be removed"
            end)

            FuzzHelpers.check_invariants!(game_id)
          end
      end
    end

    test "quit then vote returns error" do
      case setup_game_with_claim(3) do
        :no_claimable_word ->
          :ok

        {game_id, word, _state} ->
          :ok = Game.challenge_word(game_id, "token_2", word)
          {:ok, state} = Game.get_state(game_id)
          [challenge | _] = state.challenges
          challenge_id = challenge.id

          # Player 3 quits first
          :ok = Game.quit_game(game_id, "token_3")
          :timer.sleep(10)

          if FuzzHelpers.game_alive?(game_id) do
            # Player 3 tries to vote after quitting
            result = Game.challenge_vote(game_id, "token_3", challenge_id, true)
            assert result == {:error, :player_not_found}

            # Challenge should be unchanged by the failed vote
            {:ok, post_state} = Game.get_state(game_id)

            Enum.each(post_state.challenges, fn c ->
              refute Map.has_key?(c.votes, "player_3"),
                     "Quit player should not have a vote"
            end)

            FuzzHelpers.check_invariants!(game_id)
          end
      end
    end
  end

  describe "challenge timeout" do
    test "challenge timeout resolves by plurality" do
      case setup_game_with_claim(4) do
        :no_claimable_word ->
          :ok

        {game_id, word, _state} ->
          :ok = Game.challenge_word(game_id, "token_2", word)
          {:ok, state} = Game.get_state(game_id)
          [challenge | _] = state.challenges
          challenge_id = challenge.id

          # Player 2 auto-voted false. Cast partial votes:
          # Player 1 votes valid (true), player 3 votes valid (true)
          # Player 4 does NOT vote
          # Score: valid=2, invalid=1 -> plurality = valid -> word stays
          :ok = Game.challenge_vote(game_id, "token_1", challenge_id, true)
          :ok = Game.challenge_vote(game_id, "token_3", challenge_id, true)

          # Manually send the challenge timeout
          pid = get_game_pid(game_id)
          send(pid, {:challenge_timeout, challenge_id})
          :timer.sleep(20)

          {:ok, post_state} = Game.get_state(game_id)

          # Challenge should be resolved
          assert post_state.challenges == [],
                 "Challenge should be resolved after timeout"

          # Word should still be in play (plurality says valid)
          assert Enum.any?(post_state.teams, fn t -> word in t.words end),
                 "Word should remain in play when plurality votes valid"

          FuzzHelpers.check_invariants!(game_id)
      end
    end

    test "challenge timeout with tie goes to thief" do
      case setup_game_with_claim(4) do
        :no_claimable_word ->
          :ok

        {game_id, word, _state} ->
          :ok = Game.challenge_word(game_id, "token_2", word)
          {:ok, state} = Game.get_state(game_id)
          [challenge | _] = state.challenges
          challenge_id = challenge.id

          # Player 2 auto-voted false. Player 1 votes valid.
          # Players 3,4 don't vote.
          # Score: valid=1, invalid=1 -> tie -> thief wins -> word stays
          :ok = Game.challenge_vote(game_id, "token_1", challenge_id, true)

          pid = get_game_pid(game_id)
          send(pid, {:challenge_timeout, challenge_id})
          :timer.sleep(20)

          {:ok, post_state} = Game.get_state(game_id)
          assert post_state.challenges == []

          assert Enum.any?(post_state.teams, fn t -> word in t.words end),
                 "Tie on timeout should go to thief (word valid)"

          FuzzHelpers.check_invariants!(game_id)
      end
    end
  end

  describe "challenge undo mechanics" do
    test "successful challenge undoes word steal completely" do
      # Use 5 players so challenge doesn't auto-resolve with just 2 votes
      case setup_game_with_claim(5) do
        :no_claimable_word ->
          :ok

        {game_id, word, _state_before_challenge} ->
          # Record letter counts before challenge
          raw_before = FuzzHelpers.get_raw_state(game_id)
          center_before = length(raw_before.center)
          pool_before = length(raw_before.letter_pool)

          words_letters_before =
            raw_before.teams
            |> Enum.flat_map(& &1.words)
            |> Enum.map(&String.length/1)
            |> Enum.sum()

          total_before = center_before + words_letters_before + pool_before

          # Challenge the word (player_2 auto-votes false)
          :ok = Game.challenge_word(game_id, "token_2", word)
          {:ok, state} = Game.get_state(game_id)
          [challenge | _] = state.challenges
          challenge_id = challenge.id

          # Vote to reject: need > ceil(5/2.0) = 3 invalid votes
          # Player 2 already voted false. Add players 1, 3, 4 voting false.
          :ok = Game.challenge_vote(game_id, "token_1", challenge_id, false)
          :ok = Game.challenge_vote(game_id, "token_3", challenge_id, false)
          # At 3 invalid votes (> threshold 3? No, > 3 is 4). threshold = ceil(5/2.0) = 3.
          # 3 invalid votes == threshold for odd player count -> succeeds.
          :timer.sleep(10)

          {:ok, post_state} = Game.get_state(game_id)

          # Word should be removed from thief
          refute Enum.any?(post_state.teams, fn t -> word in t.words end),
                 "Successfully challenged word should be removed"

          # Letter conservation: total letters should be unchanged
          raw_after = FuzzHelpers.get_raw_state(game_id)

          if raw_after != nil do
            center_after = length(raw_after.center)
            pool_after = length(raw_after.letter_pool)

            words_letters_after =
              raw_after.teams
              |> Enum.flat_map(& &1.words)
              |> Enum.map(&String.length/1)
              |> Enum.sum()

            total_after = center_after + words_letters_after + pool_after

            assert total_before == total_after,
                   "Letter conservation violated: #{total_before} != #{total_after}"

            # Center letters should have been restored
            assert center_after >= center_before,
                   "Center should have at least as many letters after successful challenge"
          end

          FuzzHelpers.check_invariants!(game_id)
      end
    end
  end

  describe "re-challenge and recidivist" do
    test "challenged word cannot be re-challenged" do
      case setup_game_with_claim(3) do
        :no_claimable_word ->
          :ok

        {game_id, word, _state} ->
          # First challenge
          :ok = Game.challenge_word(game_id, "token_2", word)
          {:ok, state} = Game.get_state(game_id)
          [challenge | _] = state.challenges
          challenge_id = challenge.id

          # Resolve: all vote valid (word stays)
          :ok = Game.challenge_vote(game_id, "token_1", challenge_id, true)
          :ok = Game.challenge_vote(game_id, "token_3", challenge_id, true)
          :timer.sleep(10)

          {:ok, mid_state} = Game.get_state(game_id)
          assert mid_state.challenges == []

          # Word should still be in play
          assert Enum.any?(mid_state.teams, fn t -> word in t.words end)

          # Try to challenge again
          result = Game.challenge_word(game_id, "token_2", word)
          assert result == {:error, :already_challenged}

          FuzzHelpers.check_invariants!(game_id)
      end
    end

    test "recidivist claim blocked after successful challenge" do
      # Use 5 players so challenge doesn't auto-resolve before all votes
      case setup_game_with_claim(5) do
        :no_claimable_word ->
          :ok

        {game_id, word, _state} ->
          # Challenge the word (player_2 auto-votes false)
          :ok = Game.challenge_word(game_id, "token_2", word)
          {:ok, state} = Game.get_state(game_id)
          [challenge | _] = state.challenges
          challenge_id = challenge.id

          # Vote invalid to reach threshold: ceil(5/2.0)=3, need 3 invalid
          # Player 2 auto-voted false. Add 1 and 3 for total of 3.
          :ok = Game.challenge_vote(game_id, "token_1", challenge_id, false)
          :ok = Game.challenge_vote(game_id, "token_3", challenge_id, false)
          :timer.sleep(10)

          {:ok, mid_state} = Game.get_state(game_id)

          # Word should be removed
          refute Enum.any?(mid_state.teams, fn t -> word in t.words end),
                 "Word should be removed after successful challenge"

          # Now flip enough letters so the word could be formed again
          FuzzHelpers.flip_n_letters(game_id, 10)

          # Try to re-claim the same word (recidivist)
          {:ok, current_state} = Game.get_state(game_id)
          token = FuzzHelpers.pick_alive_token(current_state, 0.0)
          result = Game.claim_word(game_id, token, word)

          # Should be rejected as invalid
          assert result == {:error, :invalid_word},
                 "Recidivist claim should be blocked, got: #{inspect(result)}"

          FuzzHelpers.check_invariants!(game_id)
      end
    end
  end
end

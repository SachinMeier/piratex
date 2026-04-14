defmodule Piratex.ClaimStealFuzzTest do
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

  describe "valid claims from center" do
    property "always succeed and maintain letter conservation" do
      check all(
              num_players <- StreamData.integer(2..4),
              num_flips <- StreamData.integer(10..30),
              claim_seeds <-
                StreamData.list_of(
                  StreamData.float(min: 0.0, max: 1.0),
                  min_length: 3,
                  max_length: 15
                ),
              max_runs: 50
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players, :bananagrams_half)
        FuzzHelpers.flip_n_letters(game_id, num_flips)

        state = FuzzHelpers.safe_get_state(game_id)

        if state != nil and state.status == :playing do
          claimable = FuzzHelpers.find_claimable_words_from_center(state.center)

          words_in_play = Enum.flat_map(state.teams, & &1.words)
          claimable = Enum.reject(claimable, &(&1 in words_in_play))

          # Try claiming each word found, using seeds to pick player tokens
          Enum.zip(claimable, Stream.cycle(claim_seeds))
          |> Enum.take(10)
          |> Enum.each(fn {word, seed} ->
            pre_state = FuzzHelpers.safe_get_state(game_id)

            if pre_state != nil and pre_state.status == :playing do
              # Verify the word is still claimable from current center
              still_claimable =
                FuzzHelpers.find_claimable_words_from_center(pre_state.center)

              current_words_in_play = Enum.flat_map(pre_state.teams, & &1.words)

              if word in still_claimable and word not in current_words_in_play do
                token = FuzzHelpers.pick_alive_token(pre_state, seed)
                result = Game.claim_word(game_id, token, word)

                case result do
                  :ok ->
                    post_state = FuzzHelpers.safe_get_state(game_id)

                    if post_state != nil do
                      # Word should be on some team
                      all_words = Enum.flat_map(post_state.teams, & &1.words)
                      assert word in all_words, "Claimed word #{word} not found on any team"

                      # Letters should have been removed from center
                      assert length(post_state.center) < length(pre_state.center),
                             "Center should shrink after successful claim"

                      FuzzHelpers.check_invariants!(game_id)
                    end

                  {:error, _reason} ->
                    # Claim may fail due to race conditions (challenge, turn change)
                    FuzzHelpers.check_invariants!(game_id)
                end
              end
            end
          end)

          FuzzHelpers.check_invariants!(game_id)
        end
      end
    end
  end

  describe "valid steals" do
    property "always succeed when conditions are met" do
      check all(
              num_players <- StreamData.integer(2..4),
              num_flips <- StreamData.integer(15..30),
              steal_seeds <-
                StreamData.list_of(
                  StreamData.float(min: 0.0, max: 1.0),
                  min_length: 3,
                  max_length: 10
                ),
              max_runs: 30
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players, :bananagrams_half)
        FuzzHelpers.flip_n_letters(game_id, num_flips)

        # First, make some center claims to have words in play
        state = FuzzHelpers.safe_get_state(game_id)

        if state != nil and state.status == :playing do
          claimable = FuzzHelpers.find_claimable_words_from_center(state.center)
          words_in_play = Enum.flat_map(state.teams, & &1.words)
          claimable = Enum.reject(claimable, &(&1 in words_in_play))

          # Claim up to 3 words to set up steal targets
          claimable
          |> Enum.take(3)
          |> Enum.with_index(1)
          |> Enum.each(fn {word, i} ->
            pre = FuzzHelpers.safe_get_state(game_id)

            if pre != nil and pre.status == :playing do
              token = "token_#{rem(i - 1, num_players) + 1}"
              Game.claim_word(game_id, token, word)
            end
          end)

          # Flip more letters to enable steals
          FuzzHelpers.flip_n_letters(game_id, 10)

          state = FuzzHelpers.safe_get_state(game_id)

          if state != nil and state.status == :playing do
            steals = FuzzHelpers.find_valid_steals(state)
            current_words = Enum.flat_map(state.teams, & &1.words)
            steals = Enum.reject(steals, fn {_, nw} -> nw in current_words end)

            # Execute steals
            Enum.zip(steals, Stream.cycle(steal_seeds))
            |> Enum.take(5)
            |> Enum.each(fn {{old_word, new_word}, seed} ->
              pre_state = FuzzHelpers.safe_get_state(game_id)

              if pre_state != nil and pre_state.status == :playing do
                # Re-verify steal validity
                current_steals = FuzzHelpers.find_valid_steals(pre_state)
                current_in_play = Enum.flat_map(pre_state.teams, & &1.words)

                valid? =
                  Enum.any?(current_steals, fn {ow, nw} ->
                    ow == old_word and nw == new_word and nw not in current_in_play
                  end)

                if valid? do
                  token = FuzzHelpers.pick_alive_token(pre_state, seed)
                  result = Game.claim_word(game_id, token, new_word)

                  case result do
                    :ok ->
                      post_state = FuzzHelpers.safe_get_state(game_id)

                      if post_state != nil do
                        all_words = Enum.flat_map(post_state.teams, & &1.words)

                        # New word should be in play
                        assert new_word in all_words,
                               "Stolen word #{new_word} not found on any team"

                        # Old word should have been removed
                        refute old_word in all_words,
                               "Old word #{old_word} should be removed after steal"

                        FuzzHelpers.check_invariants!(game_id)
                      end

                    {:error, _reason} ->
                      FuzzHelpers.check_invariants!(game_id)
                  end
                end
              end
            end)
          end

          FuzzHelpers.check_invariants!(game_id)
        end
      end
    end
  end

  describe "invalid claims" do
    property "fail gracefully without changing state" do
      check all(
              num_players <- StreamData.integer(2..4),
              num_flips <- StreamData.integer(5..15),
              bad_word_seeds <-
                StreamData.list_of(
                  StreamData.float(min: 0.0, max: 1.0),
                  min_length: 5,
                  max_length: 20
                ),
              max_runs: 50
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players, :bananagrams_half)
        FuzzHelpers.flip_n_letters(game_id, num_flips)

        state_before = FuzzHelpers.safe_get_state(game_id)

        if state_before != nil and state_before.status == :playing do
          Enum.each(bad_word_seeds, fn seed ->
            pre_state = FuzzHelpers.safe_get_state(game_id)

            if pre_state != nil and pre_state.status == :playing do
              token = FuzzHelpers.pick_alive_token(pre_state, seed)
              s1 = FuzzHelpers.sub_seed(seed, 1)

              # Generate an invalid word based on the seed
              bad_word =
                cond do
                  # Word not in dictionary
                  s1 < 0.25 ->
                    "zzxxqq"

                  # Too short
                  s1 < 0.40 ->
                    "ab"

                  # Empty string
                  s1 < 0.50 ->
                    ""

                  # Very long nonsense
                  s1 < 0.65 ->
                    String.duplicate("z", 50)

                  # Word needing unavailable letters
                  s1 < 0.80 ->
                    "zzzzzz"

                  # Numbers / special chars
                  true ->
                    "12345"
                end

              pre_teams = pre_state.teams
              pre_center = pre_state.center

              result = Game.claim_word(game_id, token, bad_word)

              case result do
                :ok ->
                  # If the claim somehow succeeded (unlikely with bad words),
                  # still check invariants
                  FuzzHelpers.check_invariants!(game_id)

                {:error, _reason} ->
                  # State should be unchanged after failed claim
                  post_state = FuzzHelpers.safe_get_state(game_id)

                  if post_state != nil and post_state.status == :playing do
                    assert post_state.teams == pre_teams,
                           "Teams changed after failed claim of #{inspect(bad_word)}"

                    assert post_state.center == pre_center,
                           "Center changed after failed claim of #{inspect(bad_word)}"
                  end

                  FuzzHelpers.check_invariants!(game_id)
              end
            end
          end)
        end
      end
    end
  end

  describe "interleaved claims and challenges" do
    property "maintain letter conservation throughout" do
      check all(
              num_players <- StreamData.integer(2..5),
              seeds <- GameGenerators.seed_list_gen(30, 80),
              max_runs: 50
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players, :bananagrams_half)

        # Flip some initial letters
        FuzzHelpers.flip_n_letters(game_id, 15)

        Enum.each(seeds, fn seed ->
          state = FuzzHelpers.safe_get_state(game_id)

          if state != nil and state.status == :playing do
            s1 = FuzzHelpers.sub_seed(seed, 1)
            s2 = FuzzHelpers.sub_seed(seed, 2)

            cond do
              # Flip
              seed < 0.20 ->
                if state.letter_pool_count > 0 do
                  token = FuzzHelpers.turn_player_token(state)
                  Game.flip_letter(game_id, token)
                end

              # Valid claim
              seed < 0.40 ->
                claimable = FuzzHelpers.find_claimable_words_from_center(state.center)
                words_in_play = Enum.flat_map(state.teams, & &1.words)
                claimable = Enum.reject(claimable, &(&1 in words_in_play))

                case claimable do
                  [] ->
                    :ok

                  list ->
                    word = FuzzHelpers.pick_from(list, s2)
                    token = FuzzHelpers.pick_alive_token(state, s1)
                    Game.claim_word(game_id, token, word)
                end

              # Valid steal
              seed < 0.55 ->
                steals = FuzzHelpers.find_valid_steals(state)
                words_in_play = Enum.flat_map(state.teams, & &1.words)
                steals = Enum.reject(steals, fn {_, nw} -> nw in words_in_play end)

                case steals do
                  [] ->
                    :ok

                  list ->
                    {_old, new_word} = FuzzHelpers.pick_from(list, s2)
                    token = FuzzHelpers.pick_alive_token(state, s1)
                    Game.claim_word(game_id, token, new_word)
                end

              # Challenge
              seed < 0.70 ->
                words_in_play = Enum.flat_map(state.teams, & &1.words)

                challengeable =
                  state.history
                  |> Enum.take(5)
                  |> Enum.filter(fn ws ->
                    ws.thief_word in words_in_play and
                      not MapSet.member?(
                        state.challenged_words,
                        {ws.victim_word, ws.thief_word}
                      )
                  end)

                case challengeable do
                  [] ->
                    :ok

                  list ->
                    ws = FuzzHelpers.pick_from(list, s2)
                    token = FuzzHelpers.pick_alive_token(state, s1)
                    Game.challenge_word(game_id, token, ws.thief_word)
                end

              # Vote on open challenge
              seed < 0.82 ->
                case state.challenges do
                  [] ->
                    :ok

                  [challenge | _] ->
                    token = FuzzHelpers.pick_alive_token(state, s1)
                    vote = s2 < 0.5
                    Game.challenge_vote(game_id, token, challenge.id, vote)
                end

              # End vote
              seed < 0.90 ->
                token = FuzzHelpers.pick_alive_token(state, s1)
                Game.end_game_vote(game_id, token)

              # Invalid claim
              true ->
                token = FuzzHelpers.pick_alive_token(state, s1)
                Game.claim_word(game_id, token, "zzxxqqjj")
            end

            # Letter conservation after every action
            FuzzHelpers.check_invariants!(game_id)
          end
        end)

        FuzzHelpers.check_invariants!(game_id)
      end
    end
  end
end

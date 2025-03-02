defmodule Piratex.Services.ChallengeTest do
  use ExUnit.Case, async: true

  import Piratex.TestHelpers

  alias Piratex.GameHelpers
  alias Piratex.WordSteal
  alias Piratex.Services.ChallengeService
  alias Piratex.Services.ChallengeService.Challenge
  alias Piratex.Services.WordClaimService

  setup do
    case Piratex.Dictionary.start_link(nil) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} -> raise "Failed to start dictionary: #{inspect(reason)}"
    end

    :ok
  end

  describe "Handle Word Challenge" do
    setup :new_game_state

    test "word is not in play", %{state: state, p1: p1} do
      assert {:error, :word_not_in_play} =
               ChallengeService.handle_word_challenge(state, p1, "nonword")

      assert state.challenges == []
      assert state.past_challenges == []

      state = default_new_game(1)

      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      %{players: [%{name: _p1_name, token: p1_token, words: _p1_words} = p1]} = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      state = GameHelpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "beat")

      assert state.center == []
      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p1_token, "beat")

      # ensure a word that was previously in play cannot be challenged
      assert {:error, :word_not_in_play} =
               ChallengeService.handle_word_challenge(state, p1, "eat")
    end

    test "word is already challenged - word from center", %{state: state, p1: p1, p2: p2} do
      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      %{name: _p1_name, token: p1_token, words: _p1_words} = p1
      %{name: p2_name, token: p2_token, words: _p2_words} = p2

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: %WordSteal{
                 thief_idx: 0,
                 thief_word: "eat",
                 victim_idx: nil,
                 victim_word: nil
               },
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      assert {:error, :already_challenged} =
               ChallengeService.handle_word_challenge(state, p2_token, "eat")

      # have p1 vote
      # testing results of votes is handled in a different test group
      assert new_state =
               ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)

      assert new_state.challenges == []
      assert length(new_state.past_challenges) == 1

      # ensure that past_challenges are also checked
      assert {:error, :already_challenged} =
               ChallengeService.handle_word_challenge(state, p2_token, "eat")
    end

    test "word is already challenged - word stolen from player", %{state: state, p1: p1, p2: p2} do
      state = GameHelpers.add_letters_to_center(state, ["e", "d"])

      %{name: _p1_name, token: p1_token, words: _p1_words} = p1
      %{name: p2_name, token: p2_token, words: _p2_words} = p2

      # p1 steals bond -> bonded (derivative)
      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "bonded")
      assert state.center == []
      assert player_has_word(state, p1_token, "bonded")

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "bonded")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: %WordSteal{
                 thief_idx: 0,
                 thief_word: "bonded",
                 victim_idx: 0,
                 victim_word: "bond"
               },
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      assert {:error, :already_challenged} =
               ChallengeService.handle_word_challenge(state, p2_token, "bonded")

      # have p1 vote
      # testing results of votes is handled in a different test group
      assert new_state =
               ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)

      assert new_state.challenges == []
      assert length(new_state.past_challenges) == 1

      # ensure that past_challenges are also checked
      assert {:error, :already_challenged} =
               ChallengeService.handle_word_challenge(state, p2_token, "bonded")
    end

    test "handle word challenge 2 players", %{state: state, p1: p1, p2: p2} do
      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      %{name: _p1_name, token: p1_token, words: _p1_words} = p1
      %{name: p2_name, token: p2_token, words: _p2_words} = p2

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: %WordSteal{
                 thief_idx: 0,
                 thief_word: "eat",
                 victim_idx: nil,
                 victim_word: nil
               },
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # ensure player still has the challenged word
      assert player_has_word(state, p1_token, "eat")

      # attempt to have p2 vote again.
      assert {:error, :already_voted} =
               ChallengeService.handle_challenge_vote(state, p2_token, challenge_id, false)

      # have p1 vote
      # testing results of votes is handled in a different test group
      assert new_state =
               ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)

      assert new_state.challenges == []
      assert length(new_state.past_challenges) == 1
    end
  end

  describe "Handle Election Votes" do
    test "handle word challegne 1 player (immediately votes and resolves)" do
      state = default_new_game(1)

      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      %{players: [%{name: _p1_name, token: p1_token, words: _p1_words} = p1]} = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p1_token, "eat")

      # in a 1player game, the challenge is resolved immediately
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      refute player_has_word(state, p1_token, "eat")
      assert match_center?(state, ["e", "a", "t"])
    end

    test "handle election - 2 players - no victim - success" do
      state =
        default_new_game(2)
        |> GameHelpers.add_letters_to_center(["e", "a", "t"])

      [
        %{name: p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2
      ] = state.players

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      word_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "eat",
        victim_idx: nil,
        victim_word: nil
      }

      assert [^word_steal] = state.history

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")

      assert length(state.challenges) == 1

      # p2 (challenger) automatically votes false
      assert %Challenge{
               id: challenge_id,
               word_steal: ^word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # have p1 vote true (valid)
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert %Challenge{
               id: ^challenge_id,
               word_steal: %WordSteal{
                 thief_idx: 0,
                 thief_word: "eat",
                 victim_idx: nil,
                 victim_word: nil
               },
               votes: %{^p2_name => false, ^p1_name => true}
             } = Enum.at(state.past_challenges, 0)

      # p1 should still have the word
      assert player_has_word(state, p1_token, "eat")
      # letters should be returned to the center
      assert match_center?(state, [])
    end

    test "handle election - 2 players - self steal - success" do
      state =
        default_new_game(2)
        |> GameHelpers.add_letters_to_center(["b", "o", "n", "d"])

      [
        %{name: p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2
      ] = state.players

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "bond")
      assert state.center == []
      assert player_has_word(state, p1_token, "bond")

      word_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "bond",
        victim_idx: nil,
        victim_word: nil
      }

      assert [^word_steal] = state.history

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "bond")

      assert length(state.challenges) == 1

      # p2 (challenger) automatically votes false
      assert %Challenge{
               id: challenge_id,
               word_steal: ^word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # have p1 vote true (valid)
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert %Challenge{
               id: ^challenge_id,
               word_steal: %WordSteal{
                 thief_idx: 0,
                 thief_word: "bond",
                 victim_idx: nil,
                 victim_word: nil
               },
               votes: %{^p2_name => false, ^p1_name => true}
             } = Enum.at(state.past_challenges, 0)

      # p1 should still have the word
      assert player_has_word(state, p1_token, "bond")
      # letters should be returned to the center
      assert match_center?(state, [])
    end

    test "handle election - 2 players - no victim - fail" do
      state =
        default_new_game(2)
        |> GameHelpers.add_letters_to_center(["e", "a", "t"])

      [
        %{name: p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2
      ] = state.players

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      word_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "eat",
        victim_idx: nil,
        victim_word: nil
      }

      assert [^word_steal] = state.history

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")

      assert length(state.challenges) == 1

      # p2 (challenger) automatically votes false
      assert %Challenge{
               id: challenge_id,
               word_steal: ^word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # have p1 vote false (invalid)
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, false)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert %Challenge{
               id: ^challenge_id,
               word_steal: %WordSteal{
                 thief_idx: 0,
                 thief_word: "eat",
                 victim_idx: nil,
                 victim_word: nil
               },
               votes: %{^p2_name => false, ^p1_name => false}
             } = Enum.at(state.past_challenges, 0)

      # p1 should still have the word
      refute player_has_word(state, p1_token, "eat")
      # letters should be returned to the center
      assert match_center?(state, ["e", "a", "t"])
    end

    test "handle election - 2 players - self steal - fail" do
      state =
        default_new_game(2)
        |> GameHelpers.add_letters_to_center(["b", "o", "n", "d", "e", "d"])

      [
        %{name: p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2
      ] = state.players

      # p1 takes bond
      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "bond")
      assert match_center?(state, ["e", "d"])
      assert player_has_word(state, p1_token, "bond")

      bond_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "bond",
        victim_idx: nil,
        victim_word: nil
      }

      # p1 turns bond into bonded (should be disallowed)
      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "bonded")
      assert match_center?(state, [])
      assert player_has_word(state, p1_token, "bonded")

      bonded_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "bonded",
        victim_idx: 0,
        victim_word: "bond"
      }

      assert [^bonded_steal, ^bond_steal] = state.history

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "bonded")

      assert length(state.challenges) == 1

      # p2 (challenger) automatically votes false
      assert %Challenge{
               id: challenge_id,
               word_steal: ^bonded_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # have p1 vote false (invalid)
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, false)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert %Challenge{
               id: ^challenge_id,
               word_steal: %WordSteal{
                 thief_idx: 0,
                 thief_word: "bonded",
                 victim_idx: 0,
                 victim_word: "bond"
               },
               votes: %{^p2_name => false, ^p1_name => false}
             } = Enum.at(state.past_challenges, 0)

      # p1 should still have the word
      refute player_has_word(state, p1_token, "bonded")
      # ensure player got old word back
      assert player_has_word(state, p1_token, "bond")
      # letters should be returned to the center
      assert match_center?(state, ["e", "d"])
    end

    test "handle election - 3 players - success" do
      state = default_new_game(3)

      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      [
        %{name: p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2,
        %{name: p3_name, token: p3_token, words: _p3_words} = p3
      ] = state.players

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      eat_word_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "eat",
        victim_idx: nil,
        victim_word: nil
      }

      state = GameHelpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p3, "beat")

      beat_word_steal = %WordSteal{
        thief_idx: 2,
        thief_word: "beat",
        victim_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")

      assert [^beat_word_steal, ^eat_word_steal] = state.history

      # p2 challenges beat
      state = ChallengeService.handle_word_challenge(state, p2_token, "beat")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: ^beat_word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # p1 votes true (valid), challenge is incomplete, waiting 3rd vote from p3
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")

      # p3 votes true (valid), challenge fails and word stays
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, true)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert %Challenge{
               id: ^challenge_id,
               word_steal: ^beat_word_steal,
               votes: %{^p2_name => false, ^p1_name => true, ^p3_name => true}
             } = Enum.at(state.past_challenges, 0)

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")
      assert match_center?(state, [])
    end

    test "handle election - 3 players - fail" do
      state = default_new_game(3)

      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      [
        %{name: _p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2,
        %{name: _p3_name, token: p3_token, words: _p3_words} = p3
      ] = state.players

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      eat_word_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "eat",
        victim_idx: nil,
        victim_word: nil
      }

      state = GameHelpers.add_letters_to_center(state, ["s"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p3, "eats")

      eats_word_steal = %WordSteal{
        thief_idx: 2,
        thief_word: "eats",
        victim_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "eats")

      assert [^eats_word_steal, ^eat_word_steal] = state.history

      # p2 challenges eats (derivative)
      state = ChallengeService.handle_word_challenge(state, p2_token, "eats")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: ^eats_word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # p1 votes false (invalid), so challenge succeeds and eats is reverted to eat
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, false)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      # p1 gets eat back, p3 loses eats
      assert player_has_word(state, p1_token, "eat")
      refute player_has_word(state, p3_token, "eats")
      # s goes back to center
      assert match_center?(state, ["s"])
    end

    test "handle election - 4 players - success" do
      state = default_new_game(4)

      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      [
        %{name: p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2,
        %{name: p3_name, token: p3_token, words: _p3_words} = p3,
        %{name: _p4_name, token: _p4_token, words: _p4_words} = _p4
      ] = state.players

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      eat_word_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "eat",
        victim_idx: nil,
        victim_word: nil
      }

      state = GameHelpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p3, "beat")

      beat_word_steal = %WordSteal{
        thief_idx: 2,
        thief_word: "beat",
        victim_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")

      assert [^beat_word_steal, ^eat_word_steal] = state.history

      # p2 challenges beat
      state = ChallengeService.handle_word_challenge(state, p2_token, "beat")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: ^beat_word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # p1 votes true (valid), challenge is incomplete, waiting for more votes
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")

      # p3 votes true (valid), challenge fails and word stays (2-1, valid wins tie breakers)
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, true)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert %Challenge{
               id: ^challenge_id,
               word_steal: ^beat_word_steal,
               votes: %{^p2_name => false, ^p1_name => true, ^p3_name => true}
             } = Enum.at(state.past_challenges, 0)

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")
      assert match_center?(state, [])
    end

    test "handle election - 4 players - fail" do
      state = default_new_game(4)

      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      [
        %{name: p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2,
        %{name: p3_name, token: p3_token, words: _p3_words} = p3,
        %{name: p4_name, token: p4_token, words: _p4_words} = _p4
      ] = state.players

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      eat_word_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "eat",
        victim_idx: nil,
        victim_word: nil
      }

      state = GameHelpers.add_letters_to_center(state, ["s"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p3, "eats")

      beat_word_steal = %WordSteal{
        thief_idx: 2,
        thief_word: "eats",
        victim_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "eats")

      assert [^beat_word_steal, ^eat_word_steal] = state.history

      # p2 challenges beat
      state = ChallengeService.handle_word_challenge(state, p2_token, "eats")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: ^beat_word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # p1 votes true (valid), challenge is incomplete, waiting for more votes
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "eats")

      # p3 votes false (invalid), challenge is now 1-2, so we wait for p4's vote
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, false)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "eats")
      assert match_center?(state, [])

      # p4 also votes false (invalid), challenge is settled (1-3)
      assert state = ChallengeService.handle_challenge_vote(state, p4_token, challenge_id, false)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert %Challenge{
               id: ^challenge_id,
               word_steal: ^beat_word_steal,
               votes: %{^p1_name => true, ^p2_name => false, ^p3_name => false, ^p4_name => false}
             } = Enum.at(state.past_challenges, 0)

      assert player_has_word(state, p1_token, "eat")
      refute player_has_word(state, p3_token, "eats")
      assert match_center?(state, ["s"])
    end

    test "handle election - 5 players - success" do
      state = default_new_game(5)

      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      [
        %{name: p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2,
        %{name: p3_name, token: p3_token, words: _p3_words} = p3,
        %{name: p4_name, token: p4_token, words: _p4_words} = _p4,
        %{name: p5_name, token: p5_token, words: _p5_words} = _p5
      ] = state.players

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      _eat_word_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "eat",
        victim_idx: nil,
        victim_word: nil
      }

      state = GameHelpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p3, "beat")

      beat_word_steal = %WordSteal{
        thief_idx: 2,
        thief_word: "beat",
        victim_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")

      # p2 challenges beat
      state = ChallengeService.handle_word_challenge(state, p2_token, "beat")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: ^beat_word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # p1 votes true (valid), challenge is incomplete, waiting for more votes
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")

      # p3 votes false (invalid), challenge is now 1-2, so we wait for p4's vote
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, false)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")
      assert match_center?(state, [])

      # p4 votes true (valid), challenge is 2-2, waiting for last vote
      assert state = ChallengeService.handle_challenge_vote(state, p4_token, challenge_id, true)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id

      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false, ^p4_name => true} =
               challenge.votes

      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")

      # p4 votes true (valid), challenge is 2-2, waiting for last vote
      assert state = ChallengeService.handle_challenge_vote(state, p5_token, challenge_id, true)
      assert state.challenges == []
      assert [completed_challenge] = state.past_challenges

      assert %{
               ^p1_name => true,
               ^p2_name => false,
               ^p3_name => false,
               ^p4_name => true,
               ^p5_name => true
             } = completed_challenge.votes

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "beat")
    end

    test "handle election - 5 players - fail" do
      state = default_new_game(5)

      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])

      [
        %{name: p1_name, token: p1_token, words: _p1_words} = p1,
        %{name: p2_name, token: p2_token, words: _p2_words} = _p2,
        %{name: p3_name, token: p3_token, words: _p3_words} = p3,
        %{name: p4_name, token: p4_token, words: _p4_words} = _p4,
        %{name: _p5_name, token: p5_token, words: _p5_words} = _p5
      ] = state.players

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      _eat_word_steal = %WordSteal{
        thief_idx: 0,
        thief_word: "eat",
        victim_idx: nil,
        victim_word: nil
      }

      state = GameHelpers.add_letters_to_center(state, ["s"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, p3, "eats")

      eats_word_steal = %WordSteal{
        thief_idx: 2,
        thief_word: "eats",
        victim_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "eats")
      assert [] = state.challenges

      # p2 challenges eats
      state = ChallengeService.handle_word_challenge(state, p2_token, "eats")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: ^eats_word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # p1 votes true (valid), challenge is incomplete, waiting for more votes
      assert state = ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "eats")

      # p3 votes false (invalid), challenge is now 1-2, so we wait for p4's vote
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, false)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "eats")
      assert match_center?(state, [])

      # p4 votes true (valid), challenge is 2-2, waiting for last vote
      assert state = ChallengeService.handle_challenge_vote(state, p4_token, challenge_id, true)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id

      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false, ^p4_name => true} =
               challenge.votes

      assert length(state.past_challenges) == 0

      refute player_has_word(state, p1_token, "eat")
      assert player_has_word(state, p3_token, "eats")

      # p5 votes false (invalid), challenge is settled (2-3)
      assert state = ChallengeService.handle_challenge_vote(state, p5_token, challenge_id, false)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert player_has_word(state, p1_token, "eat")
      refute player_has_word(state, p3_token, "eats")
      assert match_center?(state, ["s"])
    end
  end
end

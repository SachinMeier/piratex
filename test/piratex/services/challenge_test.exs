defmodule Piratex.ChallengeTest do
  use ExUnit.Case, async: true

  import Piratex.TestHelpers

  alias Piratex.Game
  alias Piratex.Helpers
  alias Piratex.WordSteal
  alias Piratex.ChallengeService
  alias Piratex.ChallengeService.Challenge
  alias Piratex.WordClaimService

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

    test "word is not in play" do
      state = default_new_game(1)

      assert state.challenges == []
      assert state.past_challenges == []

      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{players: [%{name: _p1_name, token: _p1_token} = p1], teams: [t1 | _]} = state

      assert {:error, :word_not_in_play} =
               ChallengeService.handle_word_challenge(state, p1, "nonword")

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      state = Helpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "beat")

      assert state.center == []
      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t1.id, "beat")

      # ensure a word that was previously in play cannot be challenged
      assert {:error, :word_not_in_play} =
               ChallengeService.handle_word_challenge(state, p1, "eat")
    end

    test "word is already challenged - word from center", %{state: state, t1: t1, t2: _t2, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{name: _p1_name, token: p1_token} = p1
      %{name: p2_name, token: p2_token} = p2

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: %WordSteal{
                 thief_team_idx: 0,
                 thief_player_idx: 0,
                 thief_word: "eat",
                 victim_team_idx: nil,
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

    test "word is already challenged - word stolen from player", %{state: state, t1: t1, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e", "d"])

      %{name: _p1_name, token: p1_token} = p1
      %{name: p2_name, token: p2_token} = p2

      # p1 steals bond -> bonded (derivative)
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "bonded")
      assert state.center == []
      assert team_has_word(state, t1.id, "bonded")

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "bonded")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: %WordSteal{
                 thief_team_idx: 0,
                 thief_player_idx: 0,
                 thief_word: "bonded",
                 victim_team_idx: 0,
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

    test "handle word challenge 2 players", %{state: state, t1: t1, t2: _t2, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{name: _p1_name, token: p1_token} = p1
      %{name: p2_name, token: p2_token} = p2

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")

      assert length(state.challenges) == 1

      assert %Challenge{
               id: challenge_id,
               word_steal: %WordSteal{
                 thief_team_idx: 0,
                 thief_player_idx: 0,
                 thief_word: "eat",
                 victim_team_idx: nil,
                 victim_word: nil
               },
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      # ensure player still has the challenged word
      assert team_has_word(state, t1.id, "eat")

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
    test "disallow double voting" do
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "s"],
        center_sorted: ["e", "s", "s", "t"]
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      {p1_name, p1_token} = {"player1", "token1"}
      {p2_name, p2_token} = {"player2", "token2"}

      :ok = Game.join_game(game_id, p1_name, p1_token)
      :ok = Game.join_game(game_id, p2_name, p2_token)

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token2", "set")

      # now challenge the word
      :ok = Game.challenge_word(game_id, p2_token, "set")

      assert {:ok, state} = Game.get_state(game_id)

      assert length(state.challenges) == 1

      # p2 (challenger) automatically votes false
      assert %Challenge{
               id: challenge_id,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      {:error, :already_voted} = Game.challenge_vote(game_id, p2_token, challenge_id, false)
      {:error, :already_voted} = Game.challenge_vote(game_id, p2_token, challenge_id, true)
    end

    test "handle word challenge 1 player (immediately votes and resolves)" do
      state = default_new_game(1)

      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{
        players: [%{name: _p1_name, token: p1_token} = p1],
        teams: [t1]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p1_token, "eat")

      # in a 1player game, the challenge is resolved immediately
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      refute team_has_word(state, t1.id, "eat")
      assert match_center?(state, ["e", "a", "t"])
    end

    test "handle election - 2 players - no victim - success" do
      state =
        default_new_game(2)
        |> Helpers.add_letters_to_center(["e", "a", "t"])

      %{
        players: [
          %{name: p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2
        ],
        teams: [t1, _t2]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
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
                 thief_team_idx: 0,
                 thief_player_idx:  0,
                 thief_word: "eat",
                 victim_team_idx: nil,
                 victim_word: nil
               },
               votes: %{^p2_name => false, ^p1_name => true}
             } = Enum.at(state.past_challenges, 0)

      # p1 should still have the word
      assert team_has_word(state, t1.id, "eat")
      # letters should be returned to the center
      assert match_center?(state, [])
    end

    test "handle election - 2 players - self steal - success" do
      state =
        default_new_game(2)
        |> Helpers.add_letters_to_center(["b", "o", "n", "d"])

      %{
        players: [
          %{name: p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2
        ],
        teams: [t1, _t2]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "bond")
      assert state.center == []
      assert team_has_word(state, t1.id, "bond")

      word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bond",
        victim_team_idx: nil,
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
                 thief_team_idx: 0,
                 thief_player_idx:  0,
                 thief_word: "bond",
                 victim_team_idx: nil,
                 victim_word: nil
               },
               votes: %{^p2_name => false, ^p1_name => true}
             } = Enum.at(state.past_challenges, 0)

      # p1 should still have the word
      assert team_has_word(state, t1.id, "bond")
      # letters should be returned to the center
      assert match_center?(state, [])
    end

    test "handle election - 2 players - no victim - fail" do
      state =
        default_new_game(2)
        |> Helpers.add_letters_to_center(["e", "a", "t"])

      %{
        players: [
          %{name: p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2
        ],
        teams: [t1, _t2]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
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
                 thief_team_idx: 0,
                 thief_player_idx:  0,
                 thief_word: "eat",
                 victim_team_idx: nil,
                 victim_word: nil
               },
               votes: %{^p2_name => false, ^p1_name => false}
             } = Enum.at(state.past_challenges, 0)

      # p1 should still have the word
      refute team_has_word(state, t1.id, "eat")
      # letters should be returned to the center
      assert match_center?(state, ["e", "a", "t"])
    end

    test "handle election - 2 players - self steal - fail" do
      state =
        default_new_game(2)
        |> Helpers.add_letters_to_center(["b", "o", "n", "d", "e", "d"])

      %{
        players: [
          %{name: p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2
        ],
        teams: [t1, _t2]
      } = state

      # p1 takes bond
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "bond")
      assert match_center?(state, ["e", "d"])
      assert team_has_word(state, t1.id, "bond")

      bond_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bond",
        victim_team_idx: nil,
        victim_word: nil
      }

      # p1 turns bond into bonded (should be disallowed)
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "bonded")
      assert match_center?(state, [])
      assert team_has_word(state, t1.id, "bonded")

      bonded_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bonded",
        victim_team_idx: 0,
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
                 thief_team_idx: 0,
                 thief_player_idx:  0,
                 thief_word: "bonded",
                 victim_team_idx: 0,
                 victim_word: "bond"
               },
               votes: %{^p2_name => false, ^p1_name => false}
             } = Enum.at(state.past_challenges, 0)

      # p1 should still have the word
      refute team_has_word(state, t1.id, "bonded")
      # ensure player got old word back
      assert team_has_word(state, t1.id, "bond")
      # letters should be returned to the center
      assert match_center?(state, ["e", "d"])
    end

    test "handle election - 3 players - success" do
      state = default_new_game(3)

      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{
        players: [
          %{name: p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2,
          %{name: p3_name, token: p3_token} = p3
        ],
        teams: [t1, _t2, t3]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      eat_word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil
      }

      state = Helpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "beat")

      beat_word_steal = %WordSteal{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "beat",
        victim_team_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")

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

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")

      # p3 votes true (valid), challenge fails and word stays
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, true)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert %Challenge{
               id: ^challenge_id,
               word_steal: ^beat_word_steal,
               votes: %{^p2_name => false, ^p1_name => true, ^p3_name => true}
             } = Enum.at(state.past_challenges, 0)

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")
      assert match_center?(state, [])
    end

    test "handle election - 3 players - fail" do
      state = default_new_game(3)

      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{
        players: [
          %{name: _p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2,
          %{name: _p3_name, token: _p3_token} = p3
        ],
        teams: [t1, _t2, t3]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      eat_word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil
      }

      state = Helpers.add_letters_to_center(state, ["s"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "eats")

      eats_word_steal = %WordSteal{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "eats",
        victim_team_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "eats")

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
      assert team_has_word(state, t1.id, "eat")
      refute team_has_word(state, t3.id, "eats")
      # s goes back to center
      assert match_center?(state, ["s"])
    end

    test "handle election - 4 players - success" do
      state = default_new_game(4)

      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{
        players: [
          %{name: p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2,
          %{name: p3_name, token: p3_token} = p3,
          %{name: _p4_name, token: _p4_token} = _p4
        ],
        teams: [t1, _t2, t3, _t4]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      eat_word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil
      }

      state = Helpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "beat")

      beat_word_steal = %WordSteal{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "beat",
        victim_team_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")

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

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")

      # p3 votes true (valid), challenge fails and word stays (2-1, valid wins tie breakers)
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, true)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert %Challenge{
               id: ^challenge_id,
               word_steal: ^beat_word_steal,
               votes: %{^p2_name => false, ^p1_name => true, ^p3_name => true}
             } = Enum.at(state.past_challenges, 0)

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")
      assert match_center?(state, [])
    end

    test "handle election - 4 players - fail" do
      state = default_new_game(4)

      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{
        players: [
          %{name: p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2,
          %{name: p3_name, token: p3_token} = p3,
          %{name: p4_name, token: p4_token} = _p4
        ],
        teams: [t1, _t2, t3, _t4]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      eat_word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil
      }

      state = Helpers.add_letters_to_center(state, ["s"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "eats")

      beat_word_steal = %WordSteal{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "eats",
        victim_team_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "eats")

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

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "eats")

      # p3 votes false (invalid), challenge is now 1-2, so we wait for p4's vote
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, false)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "eats")
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

      assert team_has_word(state, t1.id, "eat")
      refute team_has_word(state, t3.id, "eats")
      assert match_center?(state, ["s"])
    end

    test "handle election - 5 players - success" do
      state = default_new_game(5)

      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{
        players: [
          %{name: p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2,
          %{name: p3_name, token: p3_token} = p3,
          %{name: p4_name, token: p4_token} = _p4,
          %{name: p5_name, token: p5_token} = _p5
        ],
        teams: [t1, _t2, t3, _t4, _t5]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      _eat_word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil
      }

      state = Helpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "beat")

      beat_word_steal = %WordSteal{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "beat",
        victim_team_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")

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

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")

      # p3 votes false (invalid), challenge is now 1-2, so we wait for p4's vote
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, false)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")
      assert match_center?(state, [])

      # p4 votes true (valid), challenge is 2-2, waiting for last vote
      assert state = ChallengeService.handle_challenge_vote(state, p4_token, challenge_id, true)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id

      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false, ^p4_name => true} =
               challenge.votes

      assert length(state.past_challenges) == 0

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")

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

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "beat")
    end

    test "handle election - 5 players - fail" do
      state = default_new_game(5)

      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      %{
        players: [
          %{name: p1_name, token: p1_token} = p1,
          %{name: p2_name, token: p2_token} = _p2,
          %{name: p3_name, token: p3_token} = p3,
          %{name: p4_name, token: p4_token} = _p4,
          %{name: _p5_name, token: p5_token} = _p5
        ],
        teams: [t1, _t2, t3, _t4, _t5]
      } = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      _eat_word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil
      }

      state = Helpers.add_letters_to_center(state, ["s"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "eats")

      eats_word_steal = %WordSteal{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "eats",
        victim_team_idx: 0,
        victim_word: "eat"
      }

      assert state.center == []
      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "eats")
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

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "eats")

      # p3 votes false (invalid), challenge is now 1-2, so we wait for p4's vote
      assert state = ChallengeService.handle_challenge_vote(state, p3_token, challenge_id, false)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id
      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false} = challenge.votes
      assert length(state.past_challenges) == 0

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "eats")
      assert match_center?(state, [])

      # p4 votes true (valid), challenge is 2-2, waiting for last vote
      assert state = ChallengeService.handle_challenge_vote(state, p4_token, challenge_id, true)
      assert [challenge] = state.challenges
      assert challenge.id == challenge_id

      assert %{^p1_name => true, ^p2_name => false, ^p3_name => false, ^p4_name => true} =
               challenge.votes

      assert length(state.past_challenges) == 0

      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t3.id, "eats")

      # p5 votes false (invalid), challenge is settled (2-3)
      assert state = ChallengeService.handle_challenge_vote(state, p5_token, challenge_id, false)
      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert team_has_word(state, t1.id, "eat")
      refute team_has_word(state, t3.id, "eats")
      assert match_center?(state, ["s"])
    end
  end

  test "open_challenge?/1" do
    refute ChallengeService.open_challenge?(%{challenges: []})
    assert ChallengeService.open_challenge?(%{challenges: [%{id: 1}]})
  end

  describe "word_already_challenged?/2" do
    setup :new_game_state

    test "", %{state: state, t1: t1, t2: _t2, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e", "d"])

      %{name: _p1_name, token: p1_token} = p1
      %{name: p2_name, token: p2_token} = p2

      # p1 steals bond -> bonded (derivative)
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "bonded")
      assert state.center == []
      assert team_has_word(state, t1.id, "bonded")

      word_steal = %WordSteal{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bonded",
        victim_team_idx: 0,
        victim_word: "bond"
      }

      refute ChallengeService.word_already_challenged?(state, word_steal)

      # now challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "bonded")

      assert length(state.challenges) == 1

      assert ChallengeService.word_already_challenged?(state, word_steal)

      assert %Challenge{
               id: challenge_id,
               word_steal: word_steal,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      assert {:error, :already_challenged} =
               ChallengeService.handle_word_challenge(state, p2_token, "bonded")

      # have p1 vote
      # testing results of votes is handled in a different test group
      assert state =
               ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)

      assert state.challenges == []
      assert length(state.past_challenges) == 1

      assert ChallengeService.word_already_challenged?(state, word_steal)
    end
  end

  describe "remove_quitter_vote/2" do
    test "2 players, 1 votes then quits" do
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "s"],
        center_sorted: ["e", "s", "s", "t"]
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      {p1_name, p1_token} = {"player1", "token1"}
      {p2_name, p2_token} = {"player2", "token2"}

      :ok = Game.join_game(game_id, p1_name, p1_token)
      :ok = Game.join_game(game_id, p2_name, p2_token)

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token2", "set")

      # now challenge the word
      :ok = Game.challenge_word(game_id, p2_token, "set")

      assert {:ok, state} = Game.get_state(game_id)

      assert length(state.challenges) == 1

      # p2 (challenger) automatically votes false
      assert %Challenge{
               id: challenge_id,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      :ok = Game.quit_game(game_id, p2_token)

      # ensure quit player cannot vote
      {:error, :player_not_found} = Game.challenge_vote(game_id, p2_token, challenge_id, false)
      :ok = Game.challenge_vote(game_id, p1_token, challenge_id, true)

      # assert the vote ended the challenge.
      assert {:ok, %{challenges: [], past_challenges: [%Challenge{id: ^challenge_id, result: true}]}} = Game.get_state(game_id)
    end

    test "2 players, 1 votes then other quits. Challenge is resolved" do
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "s"],
        center_sorted: ["e", "s", "s", "t"]
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      {p1_name, p1_token} = {"player1", "token1"}
      {p2_name, p2_token} = {"player2", "token2"}

      :ok = Game.join_game(game_id, p1_name, p1_token)
      :ok = Game.join_game(game_id, p2_name, p2_token)

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, "token2", "set")

      # now challenge the word
      :ok = Game.challenge_word(game_id, p2_token, "set")

      assert {:ok, state} = Game.get_state(game_id)

      assert length(state.challenges) == 1

      # p2 (challenger) automatically votes false
      assert %Challenge{
               id: challenge_id,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      :ok = Game.quit_game(game_id, p1_token)

      # ensure quit player cannot vote
      {:error, :challenge_not_found} = Game.challenge_vote(game_id, p1_token, challenge_id, false)

      # assert the quit ended the challenge.
      assert {:ok, %{challenges: [], past_challenges: [%Challenge{id: ^challenge_id, result: false}]}} = Game.get_state(game_id)
    end

    test "3 players, 1 votes yes, third quits, Challenge is resolved" do
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "s"],
        center_sorted: ["e", "s", "s", "t"]
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      {p1_name, p1_token} = {"player1", "token1"}
      {p2_name, p2_token} = {"player2", "token2"}
      {p3_name, p3_token} = {"player3", "token3"}

      :ok = Game.join_game(game_id, p1_name, p1_token)
      :ok = Game.join_game(game_id, p2_name, p2_token)
      :ok = Game.join_game(game_id, p3_name, p3_token)

      :ok = Game.start_game(game_id, "token1")

      :ok = Game.claim_word(game_id, p2_token, "set")

      # now challenge the word
      :ok = Game.challenge_word(game_id, p2_token, "set")

      assert {:ok, state} = Game.get_state(game_id)

      assert length(state.challenges) == 1

      # p2 (challenger) automatically votes false
      assert %Challenge{
               id: challenge_id,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      :ok = Game.challenge_vote(game_id, p1_token, challenge_id, true)

      :ok = Game.quit_game(game_id, p3_token)

      # ensure quit player cannot vote
      {:error, :challenge_not_found} = Game.challenge_vote(game_id, p1_token, challenge_id, false)
      # ensure playing player cannot vote
      {:error, :challenge_not_found} = Game.challenge_vote(game_id, p3_token, challenge_id, false)

      # assert the quit ended the challenge. (tie goes to thief)
      assert {:ok, %{challenges: [], past_challenges: [%Challenge{id: ^challenge_id, result: true}]}} = Game.get_state(game_id)
    end

    test "4 players, 2 votes no, third quits, Challenge is resolved" do
      state = Piratex.TestHelpers.default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "s"],
        center_sorted: ["e", "s", "s", "t"]
      })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      {p1_name, p1_token} = {"player1", "token1"}
      {p2_name, p2_token} = {"player2", "token2"}
      {p3_name, p3_token} = {"player3", "token3"}
      {p4_name, p4_token} = {"player4", "token4"}

      :ok = Game.join_game(game_id, p1_name, p1_token)
      :ok = Game.join_game(game_id, p2_name, p2_token)
      :ok = Game.join_game(game_id, p3_name, p3_token)
      :ok = Game.join_game(game_id, p4_name, p4_token)

      :ok = Game.start_game(game_id, p1_token)

      :ok = Game.claim_word(game_id, p2_token, "set")

      # now challenge the word
      :ok = Game.challenge_word(game_id, p2_token, "set")

      assert {:ok, state} = Game.get_state(game_id)

      assert length(state.challenges) == 1

      # p2 (challenger) automatically votes false
      assert %Challenge{
               id: challenge_id,
               votes: %{^p2_name => false}
             } = Enum.at(state.challenges, 0)

      :ok = Game.challenge_vote(game_id, p1_token, challenge_id, false)

      :ok = Game.quit_game(game_id, p3_token)

      # ensure quit player cannot vote
      {:error, :challenge_not_found} = Game.challenge_vote(game_id, p1_token, challenge_id, false)
      # ensure playing player cannot vote
      {:error, :challenge_not_found} = Game.challenge_vote(game_id, p3_token, challenge_id, false)

      # assert the quit ended the challenge. (tie goes to thief)
      assert {:ok, %{challenges: [], past_challenges: [%Challenge{id: ^challenge_id, result: false}]}} = Game.get_state(game_id)
    end
  end
end

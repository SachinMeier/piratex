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
               ChallengeService.handle_word_challenge(state, p1.token, "nonword")

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
               ChallengeService.handle_word_challenge(state, p1.token, "eat")
    end

    test "player not found returns error", %{state: state, t1: t1, p1: p1} do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      invalid_token = "invalid_token_xyz"
      assert {:error, :player_not_found} =
               ChallengeService.handle_word_challenge(state, invalid_token, "eat")
    end

    test "word steal not found returns error when word exists but no history", %{state: state} do
      state = Map.put(state, :history, [])
      state = Map.put(state, :teams, [
        Map.put(Enum.at(state.teams, 0), :words, ["testword"])
      ])

      assert {:error, :word_steal_not_found} =
               ChallengeService.handle_word_challenge(state, "token", "testword")
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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      assert %Challenge{
               id: challenge_id,
               word_steal: ^word_steal,
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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "bonded",
        victim_team_idx: 0,
        victim_word: "bond",
        letter_count: 0
      })

      assert %Challenge{
               id: challenge_id,
               word_steal: ^word_steal,
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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      assert %Challenge{
               id: challenge_id,
               word_steal: ^word_steal,
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

    test "returns error when challenge not found" do
      state = default_new_game(2)
      %{players: [p1, _p2]} = state

      non_existent_challenge_id = 999_999
      assert {:error, :challenge_not_found} =
               ChallengeService.handle_challenge_vote(state, p1.token, non_existent_challenge_id, true)
    end

    test "returns error when player not found" do
      state = default_new_game(2)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2], teams: [t1 | _]} = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      state = ChallengeService.handle_word_challenge(state, p2.token, "eat")
      assert [%Challenge{id: challenge_id}] = state.challenges

      invalid_token = "invalid_token_xyz"
      assert {:error, :player_not_found} =
               ChallengeService.handle_challenge_vote(state, invalid_token, challenge_id, true)
    end

    test "returns error when player has quit status" do
      state = default_new_game(2)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2], teams: [t1 | _]} = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      state = ChallengeService.handle_word_challenge(state, p2.token, "eat")
      assert [%Challenge{id: challenge_id}] = state.challenges

      quit_player = Piratex.Player.quit(p1)
      state = Map.put(state, :players, [quit_player, p2])

      assert {:error, :player_not_found} =
               ChallengeService.handle_challenge_vote(state, p1.token, challenge_id, true)
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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      assert %Challenge{
               id: ^challenge_id,
               word_steal: ^word_steal,
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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bond",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bond",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      assert %Challenge{
               id: ^challenge_id,
               word_steal: ^word_steal,
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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      assert %Challenge{
               id: ^challenge_id,
               word_steal: ^word_steal,
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

      bond_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bond",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      # p1 turns bond into bonded (should be disallowed)
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "bonded")
      assert match_center?(state, [])
      assert team_has_word(state, t1.id, "bonded")

      bonded_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bonded",
        victim_team_idx: 0,
        victim_word: "bond",
        letter_count: 0
      })

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

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bonded",
        victim_team_idx: 0,
        victim_word: "bond",
        letter_count: 0
      })

      assert %Challenge{
               id: ^challenge_id,
               word_steal: ^word_steal,
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

      eat_word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      state = Helpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "beat")

      beat_word_steal = WordSteal.new(%{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "beat",
        victim_team_idx: 0,
        victim_word: "eat",
        letter_count: 0
      })

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

      eat_word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      state = Helpers.add_letters_to_center(state, ["s"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "eats")

      eats_word_steal = WordSteal.new(%{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "eats",
        victim_team_idx: 0,
        victim_word: "eat",
        letter_count: 0
      })

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

      eat_word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      state = Helpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "beat")

      beat_word_steal = WordSteal.new(%{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "beat",
        victim_team_idx: 0,
        victim_word: "eat",
        letter_count: 0
      })

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

      eat_word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      state = Helpers.add_letters_to_center(state, ["s"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "eats")

      beat_word_steal = WordSteal.new(%{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "eats",
        victim_team_idx: 0,
        victim_word: "eat",
        letter_count: 0
      })

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

      _eat_word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      }
)
      state = Helpers.add_letters_to_center(state, ["b"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "beat")

      beat_word_steal = WordSteal.new(%{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "beat",
        victim_team_idx: 0,
        victim_word: "eat",
        letter_count: 0
      })

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

      _eat_word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      state = Helpers.add_letters_to_center(state, ["s"])

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t3, p3, "eats")

      eats_word_steal = WordSteal.new(%{
        thief_team_idx: 2,
        thief_player_idx:  2,
        thief_word: "eats",
        victim_team_idx: 0,
        victim_word: "eat",
        letter_count: 0
      })

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

  describe "multiple challenges" do
    test "can have multiple challenges at once" do
      state = default_new_game(3)
      state = Helpers.add_letters_to_center(state, ["c", "a", "t"])
      %{players: [p1, _p2, p3], teams: [t1 | _]} = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "cat")

      state = Helpers.add_letters_to_center(state, ["b", "a", "t"])
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "bat")

      state = ChallengeService.handle_word_challenge(state, p3.token, "cat")
      assert length(state.challenges) == 1

      state = ChallengeService.handle_word_challenge(state, p3.token, "bat")
      assert length(state.challenges) == 2

      [c1, c2] = state.challenges
      assert c1.word_steal.thief_word == "cat"
      assert c2.word_steal.thief_word == "bat"
    end

    test "challenges can be resolved independently" do
      state = default_new_game(3)
      state = Helpers.add_letters_to_center(state, ["c", "a", "t"])
      %{players: [p1, p2, p3], teams: [t1 | _]} = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "cat")

      state = Helpers.add_letters_to_center(state, ["b", "a", "t"])
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "bat")

      state = ChallengeService.handle_word_challenge(state, p3.token, "cat")
      state = ChallengeService.handle_word_challenge(state, p3.token, "bat")
      [c1, c2] = state.challenges

      state = ChallengeService.handle_challenge_vote(state, p2.token, c1.id, true)
      assert length(state.challenges) == 2
      assert length(state.past_challenges) == 0

      state = ChallengeService.handle_challenge_vote(state, p1.token, c1.id, true)
      assert length(state.challenges) == 1
      assert length(state.past_challenges) == 1
      assert Enum.at(state.challenges, 0).id == c2.id

      state = ChallengeService.handle_challenge_vote(state, p2.token, c2.id, true)
      assert length(state.challenges) == 1

      state = ChallengeService.handle_challenge_vote(state, p1.token, c2.id, true)
      assert state.challenges == []
      assert length(state.past_challenges) == 2
    end
  end

  test "open_challenge?/1" do
    refute ChallengeService.open_challenge?(%{challenges: []})
    assert ChallengeService.open_challenge?(%{challenges: [%{id: 1}]})
    assert ChallengeService.open_challenge?(%{challenges: [%{id: 1}, %{id: 2}]})
  end

  describe "word_already_challenged?/2" do
    setup :new_game_state

    test "returns false when no challenges exist" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "test",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      state = %{challenges: [], past_challenges: []}
      refute ChallengeService.word_already_challenged?(state, word_steal)
    end

    test "returns true when challenge exists in challenges list" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "test",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      challenge = Challenge.new(word_steal)
      state = %{challenges: [challenge], past_challenges: []}

      assert ChallengeService.word_already_challenged?(state, word_steal)
    end

    test "returns true when challenge exists in past_challenges list" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "test",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      challenge = Challenge.new(word_steal)
      state = %{challenges: [], past_challenges: [challenge]}

      assert ChallengeService.word_already_challenged?(state, word_steal)
    end

    test "returns false when word_steal has different words", %{state: state, t1: t1, t2: _t2, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e", "d"])

      %{name: _p1_name, token: p1_token} = p1
      %{name: p2_name, token: p2_token} = p2

      # p1 steals bond -> bonded (derivative)
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "bonded")
      assert state.center == []
      assert team_has_word(state, t1.id, "bonded")

      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx:  0,
        thief_word: "bonded",
        victim_team_idx: 0,
        victim_word: "bond",
        letter_count: 0
      })

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
    test "returns error when player not found" do
      state = default_new_game(2)
      invalid_token = "invalid_token_xyz"

      assert {:error, :player_not_found} =
               ChallengeService.remove_quitter_vote(state, invalid_token)
    end

    test "returns error when player has not quit" do
      state = default_new_game(2)
      %{players: [p1, _p2]} = state

      assert {:error, :player_has_not_quit} =
               ChallengeService.remove_quitter_vote(state, p1.token)
    end

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

  describe "Challenge struct" do
    test "Challenge.new/2 creates a challenge with id, word_steal, votes, and nil result" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      challenge = Challenge.new(word_steal)

      assert is_integer(challenge.id)
      assert challenge.word_steal == word_steal
      assert challenge.votes == %{}
      assert challenge.result == nil
      assert challenge.timeout_ref == nil
    end

    test "Challenge.new_with_timeout/2 creates a challenge with a timeout_ref" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      challenge = Challenge.new_with_timeout(word_steal)

      assert is_integer(challenge.id)
      assert challenge.word_steal == word_steal
      assert challenge.votes == %{}
      assert challenge.result == nil
      assert is_reference(challenge.timeout_ref)
    end

    test "Challenge.new_with_timeout/2 accepts initial votes" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      votes = %{"player1" => false}
      challenge = Challenge.new_with_timeout(word_steal, votes)

      assert challenge.votes == votes
      assert is_reference(challenge.timeout_ref)
    end

    test "Challenge.start_challenge_timeout/1 returns a reference" do
      challenge_id = 123
      ref = Challenge.start_challenge_timeout(challenge_id)

      assert is_reference(ref)
    end

    test "Challenge.new/2 accepts initial votes" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      votes = %{"player1" => false, "player2" => true}
      challenge = Challenge.new(word_steal, votes)

      assert challenge.votes == votes
      assert challenge.result == nil
    end

    test "Challenge.player_already_voted?/2 returns true when player has voted" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      player = Piratex.Player.new("alice", "token_alice")
      challenge = Challenge.new(word_steal, %{"alice" => false})

      assert Challenge.player_already_voted?(challenge, player)
    end

    test "Challenge.player_already_voted?/2 returns false when player has not voted" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      player = Piratex.Player.new("bob", "token_bob")
      challenge = Challenge.new(word_steal, %{"alice" => false})

      refute Challenge.player_already_voted?(challenge, player)
    end

    test "Challenge.add_vote/3 adds a vote to the challenge" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      player = Piratex.Player.new("alice", "token_alice")
      challenge = Challenge.new(word_steal)

      updated = Challenge.add_vote(challenge, player, false)
      assert updated.votes == %{"alice" => false}

      player2 = Piratex.Player.new("bob", "token_bob")
      updated = Challenge.add_vote(updated, player2, true)
      assert updated.votes == %{"alice" => false, "bob" => true}
    end

    test "Challenge.remove_vote/2 removes a player's vote" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      player = Piratex.Player.new("alice", "token_alice")
      challenge = Challenge.new(word_steal, %{"alice" => false, "bob" => true})

      updated = Challenge.remove_vote(challenge, player)
      assert updated.votes == %{"bob" => true}
    end

    test "Challenge.remove_vote/2 is a no-op when player has no vote" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      player = Piratex.Player.new("charlie", "token_charlie")
      challenge = Challenge.new(word_steal, %{"alice" => false})

      updated = Challenge.remove_vote(challenge, player)
      assert updated.votes == %{"alice" => false}
    end

    test "Challenge.count_votes/1 counts valid and invalid votes" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      # empty votes
      challenge = Challenge.new(word_steal)
      assert Challenge.count_votes(challenge) == {0, 0}

      # all valid
      challenge = Challenge.new(word_steal, %{"a" => true, "b" => true, "c" => true})
      assert Challenge.count_votes(challenge) == {3, 0}

      # all invalid
      challenge = Challenge.new(word_steal, %{"a" => false, "b" => false})
      assert Challenge.count_votes(challenge) == {0, 2}

      # mixed votes
      challenge = Challenge.new(word_steal, %{"a" => true, "b" => false, "c" => true, "d" => false, "e" => false})
      assert Challenge.count_votes(challenge) == {2, 3}
    end
  end

  describe "find_word_steal/2" do
    setup :new_game_state

    test "finds word steal by thief_word in history", %{state: state, t1: t1, p1: p1} do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      result = ChallengeService.find_word_steal(state, "eat")
      assert %WordSteal{thief_word: "eat"} = result
    end

    test "returns nil when word not found in history", %{state: state} do
      assert ChallengeService.find_word_steal(state, "nonexistent") == nil
    end

    test "returns nil when history is empty" do
      state = %{history: []}
      assert ChallengeService.find_word_steal(state, "anyword") == nil
    end

    test "finds the correct word steal when multiple exist", %{state: state, t1: t1, p1: p1} do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t", "s"])
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = Helpers.add_letters_to_center(state, ["b"])
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "beat")

      result = ChallengeService.find_word_steal(state, "beat")
      assert %WordSteal{thief_word: "beat", victim_word: "eat"} = result

      # "eat" is no longer in history as a thief_word after being stolen into "beat"
      # but the original word steal for "eat" still exists in history
      eat_steal = ChallengeService.find_word_steal(state, "eat")
      assert %WordSteal{thief_word: "eat", victim_word: nil} = eat_steal
    end

    test "finds first matching word steal when duplicates exist in history", %{state: state} do
      word_steal1 = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "test",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      word_steal2 = WordSteal.new(%{
        thief_team_idx: 1,
        thief_player_idx: 1,
        thief_word: "test",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      state = Map.put(state, :history, [word_steal2, word_steal1])
      result = ChallengeService.find_word_steal(state, "test")

      assert result == word_steal2
    end
  end

  describe "Challenge timeout_ref behavior" do
    test "timeout_ref can be cancelled" do
      word_steal = WordSteal.new(%{
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "eat",
        victim_team_idx: nil,
        victim_word: nil,
        letter_count: 0
      })

      challenge = Challenge.new_with_timeout(word_steal)
      assert is_reference(challenge.timeout_ref)

      result = Process.cancel_timer(challenge.timeout_ref)
      assert is_integer(result) or result == false
    end

    test "challenge timeout message structure is correct" do
      challenge_id = 123
      ref = Challenge.start_challenge_timeout(challenge_id)
      assert is_reference(ref)
    end
  end

  describe "timeout_challenge/2" do
    setup :new_game_state

    test "more invalid votes than valid -> succeed challenge (word overturned)", %{state: state, t1: t1, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert team_has_word(state, t1.id, "eat")

      %{token: p2_token} = p2

      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")
      assert [%Challenge{id: challenge_id}] = state.challenges

      # p2 already voted false (invalid). Timeout with 0 valid, 1 invalid -> succeed
      state = ChallengeService.timeout_challenge(state, challenge_id)

      assert state.challenges == []
      assert length(state.past_challenges) == 1
      assert %Challenge{result: false} = Enum.at(state.past_challenges, 0)
      refute team_has_word(state, t1.id, "eat")
      assert match_center?(state, ["e", "a", "t"])
    end

    test "more valid votes than invalid -> fail challenge (word upheld)", %{state: _state, t1: _t1, p1: _p1, p2: _p2} do
      # Use a 3 player game so vote stays open after 2 votes
      state = default_new_game(3)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2, _p3], teams: [t1 | _]} = state
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = ChallengeService.handle_word_challenge(state, p1.token, "eat")
      assert [%Challenge{id: cid}] = state.challenges

      # p1 voted false (auto). Add p2 voting true.
      state = ChallengeService.handle_challenge_vote(state, p2.token, cid, true)
      # Now 1 valid, 1 invalid, waiting for p3. Timeout it.
      state = ChallengeService.timeout_challenge(state, cid)

      # tie goes to thief (valid), so challenge fails
      assert state.challenges == []
      assert [%Challenge{result: true}] = state.past_challenges
      assert team_has_word(state, t1.id, "eat")
    end

    test "tie -> fail challenge (word upheld, tie goes to thief)", %{state: _state, t1: _t1, p1: _p1, p2: _p2} do
      # Use a 4-player game to have room for a tie at timeout
      state = default_new_game(4)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2, p3, _p4], teams: [t1 | _]} = state
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = ChallengeService.handle_word_challenge(state, p2.token, "eat")
      assert [%Challenge{id: cid}] = state.challenges

      # p2 voted false (auto). Add p3 voting true.
      state = ChallengeService.handle_challenge_vote(state, p3.token, cid, true)
      # Now 1 valid, 1 invalid (tied, 2 votes outstanding). Timeout it.
      state = ChallengeService.timeout_challenge(state, cid)

      # tie -> fail challenge (word upheld)
      assert state.challenges == []
      assert [%Challenge{result: true}] = state.past_challenges
      assert team_has_word(state, t1.id, "eat")
    end

    test "challenge not found -> returns state unchanged", %{state: state} do
      non_existent_id = 999_999
      result = ChallengeService.timeout_challenge(state, non_existent_id)
      assert result == state
    end
  end

  describe "word steal undo scenarios" do
    test "undoing word steal from center returns letters to center" do
      state = default_new_game(2)
      state = Helpers.add_letters_to_center(state, ["c", "a", "t"])
      %{players: [p1, p2], teams: [t1 | _]} = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "cat")
      assert match_center?(state, [])
      assert team_has_word(state, t1.id, "cat")

      state = ChallengeService.handle_word_challenge(state, p2.token, "cat")
      assert [%Challenge{id: cid}] = state.challenges

      state = ChallengeService.handle_challenge_vote(state, p1.token, cid, false)

      assert state.challenges == []
      assert [%Challenge{result: false}] = state.past_challenges
      refute team_has_word(state, t1.id, "cat")
      assert match_center?(state, ["c", "a", "t"])
    end

    test "undoing word steal returns victim word to victim team" do
      state = default_new_game(2)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2], teams: [t1, t2 | _]} = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert team_has_word(state, t1.id, "eat")

      state = Helpers.add_letters_to_center(state, ["b"])
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t2, p2, "beat")
      refute team_has_word(state, t1.id, "eat")
      assert team_has_word(state, t2.id, "beat")

      state = ChallengeService.handle_word_challenge(state, p1.token, "beat")
      assert [%Challenge{id: cid}] = state.challenges

      state = ChallengeService.handle_challenge_vote(state, p2.token, cid, false)

      assert state.challenges == []
      assert [%Challenge{result: false}] = state.past_challenges
      assert team_has_word(state, t1.id, "eat")
      refute team_has_word(state, t2.id, "beat")
      assert match_center?(state, ["b"])
    end

    test "challenge removes word steal from history" do
      state = default_new_game(2)
      state = Helpers.add_letters_to_center(state, ["c", "a", "t"])
      %{players: [p1, p2], teams: [t1 | _]} = state

      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "cat")
      assert length(state.history) == 1

      state = ChallengeService.handle_word_challenge(state, p2.token, "cat")
      assert [%Challenge{id: cid}] = state.challenges

      state = ChallengeService.handle_challenge_vote(state, p1.token, cid, false)

      assert state.history == []
    end
  end

  describe "evaluate_challenge/3" do
    test "2 players (even) - valid reaches threshold (1), challenge fails" do
      state = default_new_game(2)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2], teams: [t1 | _]} = state
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = ChallengeService.handle_word_challenge(state, p2.token, "eat")
      assert [%Challenge{id: cid}] = state.challenges

      # p2 voted false. p1 votes true -> 1 valid, 1 invalid. Threshold = 1.
      # Tie goes to thief so valid == threshold settles as fail.
      state = ChallengeService.handle_challenge_vote(state, p1.token, cid, true)
      assert state.challenges == []
      assert [%Challenge{result: true}] = state.past_challenges
      assert team_has_word(state, t1.id, "eat")
    end

    test "3 players (odd) - invalid reaches threshold (2), challenge succeeds" do
      state = default_new_game(3)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2, _p3], teams: [t1 | _]} = state
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = ChallengeService.handle_word_challenge(state, p2.token, "eat")
      assert [%Challenge{id: cid}] = state.challenges

      # p2 voted false. p1 also votes false -> 0 valid, 2 invalid.
      # threshold = ceil(3/2) = 2. invalid == threshold -> succeed
      state = ChallengeService.handle_challenge_vote(state, p1.token, cid, false)
      assert state.challenges == []
      assert [%Challenge{result: false}] = state.past_challenges
      refute team_has_word(state, t1.id, "eat")
    end

    test "3 players (odd) - valid reaches threshold (2), challenge fails" do
      state = default_new_game(3)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2, p3], teams: [t1 | _]} = state
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = ChallengeService.handle_word_challenge(state, p2.token, "eat")
      assert [%Challenge{id: cid}] = state.challenges

      # p2 voted false. p1 votes true -> 1 valid, 1 invalid. Not settled yet.
      state = ChallengeService.handle_challenge_vote(state, p1.token, cid, true)
      assert length(state.challenges) == 1

      # p3 votes true -> 2 valid, 1 invalid. threshold = 2. valid == threshold -> fail
      state = ChallengeService.handle_challenge_vote(state, p3.token, cid, true)
      assert state.challenges == []
      assert [%Challenge{result: true}] = state.past_challenges
      assert team_has_word(state, t1.id, "eat")
    end

    test "4 players (even) - tie at threshold (2) goes to thief" do
      state = default_new_game(4)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2, p3, _p4], teams: [t1 | _]} = state
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = ChallengeService.handle_word_challenge(state, p2.token, "eat")
      assert [%Challenge{id: cid}] = state.challenges

      # p2 voted false. p1 votes true -> 1-1. Not settled.
      state = ChallengeService.handle_challenge_vote(state, p1.token, cid, true)
      assert length(state.challenges) == 1

      # p3 votes true -> 2-1. threshold = ceil(4/2) = 2.
      # valid == threshold with even player count -> fail (tie goes to thief)
      state = ChallengeService.handle_challenge_vote(state, p3.token, cid, true)
      assert state.challenges == []
      assert [%Challenge{result: true}] = state.past_challenges
      assert team_has_word(state, t1.id, "eat")
    end

    test "4 players (even) - invalid exceeds threshold, challenge succeeds" do
      state = default_new_game(4)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2, p3, _p4], teams: [t1 | _]} = state
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = ChallengeService.handle_word_challenge(state, p2.token, "eat")
      assert [%Challenge{id: cid}] = state.challenges

      # p2 voted false. p1 votes false -> 0-2. Not yet settled (threshold=2, need > threshold).
      state = ChallengeService.handle_challenge_vote(state, p1.token, cid, false)
      assert length(state.challenges) == 1

      # p3 votes false -> 0-3. invalid > threshold -> succeed
      state = ChallengeService.handle_challenge_vote(state, p3.token, cid, false)
      assert state.challenges == []
      assert [%Challenge{result: false}] = state.past_challenges
      refute team_has_word(state, t1.id, "eat")
    end

    test "5 players (odd) - vote remains incomplete until threshold reached" do
      state = default_new_game(5)
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{players: [p1, p2, p3, p4, _p5], teams: [t1 | _]} = state
      assert {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")

      state = ChallengeService.handle_word_challenge(state, p2.token, "eat")
      assert [%Challenge{id: cid}] = state.challenges

      # p2 voted false. p1 votes true -> 1-1. threshold = ceil(5/2) = 3.
      state = ChallengeService.handle_challenge_vote(state, p1.token, cid, true)
      assert length(state.challenges) == 1

      # p3 votes true -> 2-1. Still not settled.
      state = ChallengeService.handle_challenge_vote(state, p3.token, cid, true)
      assert length(state.challenges) == 1

      # p4 votes true -> 3-1. valid == threshold (odd) -> fail
      state = ChallengeService.handle_challenge_vote(state, p4.token, cid, true)
      assert state.challenges == []
      assert [%Challenge{result: true}] = state.past_challenges
      assert team_has_word(state, t1.id, "eat")
    end
  end
end

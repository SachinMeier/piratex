defmodule Piratex.WordClaimServiceTest do
  use ExUnit.Case, async: true

  alias Piratex.WordClaimService

  import Piratex.TestHelpers

  alias Piratex.Helpers
  alias Piratex.Player
  alias Piratex.Team
  alias Piratex.WordClaimService
  alias Piratex.ChallengeService

  setup do
    case Piratex.Dictionary.start_link(nil) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} -> raise "Failed to start dictionary: #{inspect(reason)}"
    end

    :ok
  end

  test "calculate_word_product" do
    assert WordClaimService.calculate_word_product("a") == 2
    assert WordClaimService.calculate_word_product("ab") == 6
    assert WordClaimService.calculate_word_product("abc") == 30
  end

  test "add_letter_to_word_product" do
    # multiplies the current product by the prime number associated with the letter
    assert WordClaimService.add_letter_to_word_product(2, "a") == 4
    assert WordClaimService.add_letter_to_word_product(2, "b") == 6
    assert WordClaimService.add_letter_to_word_product(2, "c") == 10
  end

  describe "handle_word_claim/3" do
    # from TestHelpers
    setup :new_game_state

    # tests:
    # - SUCCESS: word is valid and can be built from center entirely
    test "take valid word entirely from center", %{
      state: state,
      players: _players,
      t1: t1,
      t2: t2,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{words: t1_words} = t1
      %{words: t2_words} = t2

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert new_state.center == []
      assert team_has_word(new_state, t1.id, "eat")

      # ensure that t1 still has all their old words
      for word <- t1_words do
        assert team_has_word(new_state, t1.id, word)
      end

      # ensure that t2 still has all their words
      for word <- t2_words do
        assert team_has_word(new_state, t2.id, word)
      end
    end

    # - SUCCESS: steal from self
    test "take valid word from self", %{state: state, players: _players, t1: t1, t2: t2, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e"])
      %{words: t1_words} = t1
      %{words: t2_words} = t2

      # p2 has "bing"
      {:ok, new_state} = WordClaimService.handle_word_claim(state, t2, p2, "binge")
      assert new_state.center == []
      assert team_has_word(new_state, t2.id, "binge")

      # ensure that p1 still has all their old words
      for word <- t1_words do
        assert team_has_word(new_state, t1.id, word)
      end

      # ensure that p2 still has all their old words except the one they turned into "binge"
      for word <- t2_words -- ["bing"] do
        assert team_has_word(new_state, t2.id, word)
      end
    end

    # - SUCCESS: steal from another player
    test "steal from another player", %{state: state, players: _players, t1: t1, t2: t2, p1: p1, p2: _p2} do
      state = Helpers.add_letters_to_center(state, ["e"])
      %{words: t1_words} = t1
      %{words: t2_words} = t2

      # p2 has "bing"
      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "binge")
      assert new_state.center == []
      assert team_has_word(new_state, t1.id, "binge")

      # ensure that p1 still has all their old words
      for word <- t1_words do
        assert team_has_word(new_state, t1.id, word)
      end

      # ensure that p2 still has all their old words except the one they lost to "binge"
      for word <- t2_words -- ["bing"] do
        assert team_has_word(new_state, t2.id, word)
      end
    end

    # - FAIL: word is invalid
    test "word is invalid", %{state: state, players: _players, t1: t1, p1: p1, p2: _p2} do
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "napalmer")
      # ensure nothing has changed
      assert new_state == state
    end

    # - FAIL: word already in play
    test "word is already in play", %{state: state, players: _players, t1: t1, p1: p1, p2: _p2} do
      {:word_in_play, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "bang")
      # ensure nothing has changed
      assert new_state == state
    end

    # - FAIL: word is valid but cannot be built from center
    test "word is valid but cannot be built from center", %{
      state: state,
      players: _players,
      t1: t1,
      p1: p1,
      p2: _p2
    } do
      {:cannot_make_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "binged")
      # ensure nothing has changed
      assert new_state == state

      state = Helpers.add_letters_to_center(state, ["e"])
      # still no "d"
      {:cannot_make_word, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "binged")
      # ensure nothing has changed
      assert new_state == state
    end

    test "imply -> simply", %{state: state, players: _players, t1: t1, t2: t2, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["i", "m", "p", "l", "y"])
      {:ok, new_state} = WordClaimService.handle_word_claim(state, t1, p1, "imply")
      assert new_state.center == []
      assert team_has_word(new_state, t1.id, "imply")

      state = Helpers.add_letters_to_center(state, ["s"])

      {:ok, new_state} = WordClaimService.handle_word_claim(state, t2, p2, "simply")
      assert new_state.center == []
      assert team_has_word(new_state, t2.id, "simply")
      refute team_has_word(new_state, t1.id, "imply")
    end
  end

  # somewhat redundant with handle_word_claim/3, but useful for testing
  describe "update_state_for_word_steal" do
    setup do
      p1 = Player.new("token1", "name1")
      p2 = Player.new("token2", "name2")

      t1 = Team.new("team1", ["cop", "cap", "cup"])
      t2 = Team.new("team2", ["bot", "bat", "but"])

      state =
        default_new_game(2, %{
          players: [p1, p2],
          teams: [t1, t2],
          players_teams: %{
            p1.token => t1.id,
            p2.token => t2.id
          },
          center: ["a", "b", "c", "e"],
          center_sorted: ["a", "b", "c", "e"]
        })

      {:ok, state: state, t1: t1, t2: t2, p1: p1, p2: p2}
    end

    test "player2 steals cope from player1's cop", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: p1,
      p2: p2
    } do
      new_state =
        WordClaimService.update_state_for_word_steal(
          state, %{
            letters_used: ["e"],
            thief_team: t2,
            thief_player: p2,
            new_word: "cope",
            victim_team: t1,
            old_word: "cop"
          }
        )

      assert new_state.center == ["a", "b", "c"]

      assert new_state.players == [
               Player.new(p1.name, p1.token, ["cap", "cup"]),
               Player.new(p2.name, p2.token, ["cope", "bot", "bat", "but"])
             ]
    end

    test "player1 steals cope from his own cop", %{
      state: state,
      t1: t1,
      t2: _t2,
      p1: p1,
      p2: p2
    } do
      new_state =
        WordClaimService.update_state_for_word_steal(
          state, %{
            letters_used: ["e"],
            thief_team: t1,
            thief_player: p1,
            new_word: "cope",
            victim_team: t1,
            old_word: "cop"
          }
        )

      assert new_state.center == ["a", "b", "c"]

      assert new_state.players == [
               Player.new(p1.name, p1.token, ["cope", "cap", "cup"]),
               Player.new(p2.name, p2.token, ["bot", "bat", "but"])
             ]
    end

    test "player1 steals cab from center", %{state: state, t1: t1, t2: t2, p1: p1, p2: p2} do
      new_state =
        WordClaimService.update_state_for_word_steal(
          state, %{
            letters_used: ["c", "a", "b"],
            thief_team: t1,
            thief_player: p1,
            new_word: "cab",
            victim_team: nil,
            old_word: nil
          }
        )

      assert new_state.center == ["e"]

      assert new_state.players == [
               Team.new(t1.name, ["cab", "cop", "cap", "cup"]),
               Team.new(t2.name, ["bot", "bat", "but"])
             ]
    end
  end

  describe "is_recidivist_word_claim?" do
    # from TestHelpers
    setup :new_game_state

    test "returns true if the word has been previously challenged and rejected (victimless)", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      # the word is not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")
      challenge_id = Enum.at(state.challenges, 0).id

      # while the challenge is open, the word is not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # p1 concurs, word is invalid
      assert state =
               ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, false)

      refute team_has_word(state, t1.id, "eat")
      assert match_center?(state, ["e", "a", "t"])

      # from now on, <nil> -> "eat" is recidivist
      assert WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # try to claim eat again
      {:invalid_word, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      {:invalid_word, _state} = WordClaimService.handle_word_claim(state, t2, p2, "eat")
    end

    test "returns true if the word has been previously challenged and rejected (victim word)", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2,
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      state = Helpers.add_letters_to_center(state, ["s"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t2, p2, "eats")
      assert team_has_word(state, t2.id, "eats")
      refute team_has_word(state, t1.id, "eat")

      # not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", "eats")

       # challenge eat->eats
       state = ChallengeService.handle_word_challenge(state, p1_token, "eats")
       challenge_id = Enum.at(state.challenges, 0).id
       # p2 concurs, word is invalid
       assert state =
                ChallengeService.handle_challenge_vote(state, p2_token, challenge_id, false)

       assert team_has_word(state, t1.id, "eat")
       refute team_has_word(state, t2.id, "eats")

       # from now on, "eat" -> "eats" is recidivist
       assert WordClaimService.is_recidivist_word_claim?(state, "eats", "eat")

       {:invalid_word, state} = WordClaimService.handle_word_claim(state, t1, p1, "eats")
       {:invalid_word, state} = WordClaimService.handle_word_claim(state, t2, p2, "eats")

       assert team_has_word(state, t1.id, "eat")
       refute team_has_word(state, t2.id, "eats")
       assert match_center?(state, ["s"])
    end

    test "returns false if the word has not been previously challenged", %{
      state: state,
      t1: t1,
      p1: p1
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)
    end

    test "returns false if the word has been previously challenged and accepted", %{
      state: state,
      t1: t1,
      t2: t2,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2,
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      {:ok, state} = WordClaimService.handle_word_claim(state, t1, p1, "eat")
      assert state.center == []
      assert team_has_word(state, t1.id, "eat")

      # the word is not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # challenge the word
      state = ChallengeService.handle_word_challenge(state, p2_token, "eat")
      challenge_id = Enum.at(state.challenges, 0).id

      # while the challenge is open, the word is not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # p1 disagrees, word is valid
      assert state =
               ChallengeService.handle_challenge_vote(state, p1_token, challenge_id, true)

      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      state = Helpers.add_letters_to_center(state, ["s"])
      {:ok, state} = WordClaimService.handle_word_claim(state, t2, p2, "east")
      assert team_has_word(state, t2.id, "east")
      refute team_has_word(state, t1.id, "eat")

      refute WordClaimService.is_recidivist_word_claim?(state, "east", "eat")

      # challenge east->eat
      state = ChallengeService.handle_word_challenge(state, p1_token, "east")
      challenge_id = Enum.at(state.challenges, 0).id

      # p2 disagrees, word is valid
      assert state =
               ChallengeService.handle_challenge_vote(state, p2_token, challenge_id, true)

      refute WordClaimService.is_recidivist_word_claim?(state, "east", "eat")
    end
  end
end

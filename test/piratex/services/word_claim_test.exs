defmodule Piratex.WordClaimServiceTest do
  use ExUnit.Case, async: true

  alias Piratex.WordClaimService

  import Piratex.TestHelpers

  alias Piratex.Helpers
  alias Piratex.Player
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
      p1: p1,
      p2: p2
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])
      %{token: p1_token, words: p1_words} = p1
      %{token: p2_token, words: p2_words} = p2

      {:ok, new_state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert new_state.center == []
      assert player_has_word(new_state, p1_token, "eat")

      # ensure that p1 still has all their old words
      for word <- p1_words do
        assert player_has_word(new_state, p1_token, word)
      end

      # ensure that p2 still has all their words
      for word <- p2_words do
        assert player_has_word(new_state, p2_token, word)
      end
    end

    # - SUCCESS: steal from self
    test "take valid word from self", %{state: state, players: _players, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e"])
      %{token: p1_token, words: p1_words} = p1
      %{token: p2_token, words: p2_words} = p2

      # p2 has "bing"
      {:ok, new_state} = WordClaimService.handle_word_claim(state, p2, "binge")
      assert new_state.center == []
      assert player_has_word(new_state, p2_token, "binge")

      # ensure that p1 still has all their old words
      for word <- p1_words do
        assert player_has_word(new_state, p1_token, word)
      end

      # ensure that p2 still has all their old words except the one they turned into "binge"
      for word <- p2_words -- ["bing"] do
        assert player_has_word(new_state, p2_token, word)
      end
    end

    # - SUCCESS: steal from another player
    test "steal from another player", %{state: state, players: _players, p1: p1, p2: p2} do
      state = Helpers.add_letters_to_center(state, ["e"])
      %{token: p1_token, words: p1_words} = p1
      %{token: p2_token, words: p2_words} = p2

      # p2 has "bing"
      {:ok, new_state} = WordClaimService.handle_word_claim(state, p1, "binge")
      assert new_state.center == []
      assert player_has_word(new_state, p1_token, "binge")

      # ensure that p1 still has all their old words
      for word <- p1_words do
        assert player_has_word(new_state, p1_token, word)
      end

      # ensure that p2 still has all their old words except the one they lost to "binge"
      for word <- p2_words -- ["bing"] do
        assert player_has_word(new_state, p2_token, word)
      end
    end

    # - FAIL: word is invalid
    test "word is invalid", %{state: state, players: _players, p1: p1, p2: _p2} do
      {:invalid_word, new_state} = WordClaimService.handle_word_claim(state, p1, "napalmer")
      # ensure nothing has changed
      assert new_state == state
    end

    # - FAIL: word already in play
    test "word is already in play", %{state: state, players: _players, p1: p1, p2: _p2} do
      {:word_in_play, new_state} = WordClaimService.handle_word_claim(state, p1, "bang")
      # ensure nothing has changed
      assert new_state == state
    end

    # - FAIL: word is valid but cannot be built from center
    test "word is valid but cannot be built from center", %{
      state: state,
      players: _players,
      p1: p1,
      p2: _p2
    } do
      {:cannot_make_word, new_state} = WordClaimService.handle_word_claim(state, p1, "binged")
      # ensure nothing has changed
      assert new_state == state

      state = Helpers.add_letters_to_center(state, ["e"])
      # still no "d"
      {:cannot_make_word, new_state} = WordClaimService.handle_word_claim(state, p1, "binged")
      # ensure nothing has changed
      assert new_state == state
    end

    test "imply -> simply", %{state: state, players: _players, p1: p1, p2: p2} do
      %{token: p1_token, words: _p1_words} = p1
      %{token: p2_token, words: _p2_words} = p2
      state = Helpers.add_letters_to_center(state, ["i", "m", "p", "l", "y"])
      {:ok, new_state} = WordClaimService.handle_word_claim(state, p1, "imply")
      assert new_state.center == []
      assert player_has_word(new_state, p1_token, "imply")

      state = Helpers.add_letters_to_center(state, ["s"])

      {:ok, new_state} = WordClaimService.handle_word_claim(state, p2, "simply")
      assert new_state.center == []
      assert player_has_word(new_state, p2_token, "simply")
      refute player_has_word(new_state, p1_token, "imply")
    end
  end

  # somewhat redundant with handle_word_claim/3, but useful for testing
  describe "update_state_for_word_steal" do
    setup do
      player1 = Player.new("token1", "name1", ["cop", "cap", "cup"])
      player2 = Player.new("token2", "name2", ["bot", "bat", "but"])

      state =
        default_new_game(2, %{
          players: [player1, player2],
          center: ["a", "b", "c", "e"],
          center_sorted: ["a", "b", "c", "e"]
        })

      {:ok, state: state, player1: player1, player2: player2}
    end

    test "player2 steals cope from player1's cop", %{
      state: state,
      player1: player1,
      player2: player2
    } do
      new_state =
        WordClaimService.update_state_for_word_steal(
          state,
          ["e"],
          player2,
          "cope",
          player1,
          "cop"
        )

      assert new_state.center == ["a", "b", "c"]

      assert new_state.players == [
               Player.new(player1.name, player1.token, ["cap", "cup"]),
               Player.new(player2.name, player2.token, ["cope", "bot", "bat", "but"])
             ]
    end

    test "player1 steals cope from his own cop", %{
      state: state,
      player1: player1,
      player2: player2
    } do
      new_state =
        WordClaimService.update_state_for_word_steal(
          state,
          ["e"],
          player1,
          "cope",
          player1,
          "cop"
        )

      assert new_state.center == ["a", "b", "c"]

      assert new_state.players == [
               Player.new(player1.name, player1.token, ["cope", "cap", "cup"]),
               Player.new(player2.name, player2.token, ["bot", "bat", "but"])
             ]
    end

    test "player1 steals cab from center", %{state: state, player1: player1, player2: player2} do
      new_state =
        WordClaimService.update_state_for_word_steal(
          state,
          ["c", "a", "b"],
          player1,
          "cab",
          nil,
          nil
        )

      assert new_state.center == ["e"]

      assert new_state.players == [
               Player.new(player1.name, player1.token, ["cab", "cop", "cap", "cup"]),
               Player.new(player2.name, player2.token, ["bot", "bat", "but"])
             ]
    end
  end

  describe "is_recidivist_word_claim?" do
    # from TestHelpers
    setup :new_game_state

    test "returns true if the word has been previously challenged and rejected (victimless)", %{
      state: state,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

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

      refute player_has_word(state, p1_token, "eat")
      assert match_center?(state, ["e", "a", "t"])

      # from now on, <nil> -> "eat" is recidivist
      assert WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      # try to claim eat again
      {:invalid_word, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      {:invalid_word, _state} = WordClaimService.handle_word_claim(state, p2, "eat")
    end

    test "returns true if the word has been previously challenged and rejected (victim word)", %{
      state: state,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2,
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      state = Helpers.add_letters_to_center(state, ["s"])
      {:ok, state} = WordClaimService.handle_word_claim(state, p2, "eats")
      assert player_has_word(state, p2_token, "eats")
      refute player_has_word(state, p1_token, "eat")

      # not yet recidivist
      refute WordClaimService.is_recidivist_word_claim?(state, "eat", "eats")

       # challenge eat->eats
       state = ChallengeService.handle_word_challenge(state, p1_token, "eats")
       challenge_id = Enum.at(state.challenges, 0).id
       # p2 concurs, word is invalid
       assert state =
                ChallengeService.handle_challenge_vote(state, p2_token, challenge_id, false)

       assert player_has_word(state, p1_token, "eat")
       refute player_has_word(state, p2_token, "eats")

       # from now on, "eat" -> "eats" is recidivist
       assert WordClaimService.is_recidivist_word_claim?(state, "eats", "eat")

       {:invalid_word, state} = WordClaimService.handle_word_claim(state, p1, "eats")
       {:invalid_word, state} = WordClaimService.handle_word_claim(state, p2, "eats")

       assert player_has_word(state, p1_token, "eat")
       refute player_has_word(state, p2_token, "eats")
       assert match_center?(state, ["s"])
    end

    test "returns false if the word has not been previously challenged", %{
      state: state,
      p1: %{token: p1_token} = p1
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)

      {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

      refute WordClaimService.is_recidivist_word_claim?(state, "eat", nil)
    end

    test "returns false if the word has been previously challenged and accepted", %{
      state: state,
      p1: %{token: p1_token} = p1,
      p2: %{token: p2_token} = p2,
    } do
      state = Helpers.add_letters_to_center(state, ["e", "a", "t"])

      {:ok, state} = WordClaimService.handle_word_claim(state, p1, "eat")
      assert state.center == []
      assert player_has_word(state, p1_token, "eat")

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
      {:ok, state} = WordClaimService.handle_word_claim(state, p2, "east")
      assert player_has_word(state, p2_token, "east")
      refute player_has_word(state, p1_token, "eat")

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

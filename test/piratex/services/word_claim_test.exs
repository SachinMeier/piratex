defmodule Piratex.Services.WordClaimServiceTest do
  use ExUnit.Case, async: true

  alias Piratex.Services.WordClaimService

  import Piratex.TestHelpers

  alias Piratex.GameHelpers
  alias Piratex.Player
  alias Piratex.Services.WordClaimService

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
      state = GameHelpers.add_letters_to_center(state, ["e", "a", "t"])
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
      state = GameHelpers.add_letters_to_center(state, ["e"])
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
      state = GameHelpers.add_letters_to_center(state, ["e"])
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

      state = GameHelpers.add_letters_to_center(state, ["e"])
      # still no "d"
      {:cannot_make_word, new_state} = WordClaimService.handle_word_claim(state, p1, "binged")
      # ensure nothing has changed
      assert new_state == state
    end

    test "imply -> simply", %{state: state, players: _players, p1: p1, p2: p2} do
      %{token: p1_token, words: _p1_words} = p1
      %{token: p2_token, words: _p2_words} = p2
      state = GameHelpers.add_letters_to_center(state, ["i", "m", "p", "l", "y"])
      {:ok, new_state} = WordClaimService.handle_word_claim(state, p1, "imply")
      assert new_state.center == []
      assert player_has_word(new_state, p1_token, "imply")

      state = GameHelpers.add_letters_to_center(state, ["s"])

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
end

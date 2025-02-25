defmodule Piratex.GameHelpersTest do
  use ExUnit.Case

  import Piratex.TestHelpers

  alias Piratex.GameHelpers
  alias Piratex.Player
  setup do
    case Piratex.Dictionary.start_link(nil) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} -> raise "Failed to start dictionary: #{inspect(reason)}"
    end
    :ok
  end

  test "word_in_play?" do
    players = [
      Player.new("token", "name1", ["bind", "band", "bond"]),
      Player.new("token2", "name2", ["bing", "bang", "bong"])
    ]
    assert GameHelpers.word_in_play?(%{players: players}, "bind")
    assert GameHelpers.word_in_play?(%{players: players}, "band")
    assert GameHelpers.word_in_play?(%{players: players}, "bond")
    assert GameHelpers.word_in_play?(%{players: players}, "bing")
    assert GameHelpers.word_in_play?(%{players: players}, "bang")
    assert GameHelpers.word_in_play?(%{players: players}, "bong")

    refute GameHelpers.word_in_play?(%{players: players}, "nonword")
    refute GameHelpers.word_in_play?(%{players: players}, "")
  end

  # tests flipping letters into the center
  describe "update_state_flip_letter" do
    setup :new_game_state

    test "flip letter into center", %{state: state} do
      new_state =
        state
        # flip 3 letters into center
        |> GameHelpers.update_state_flip_letter()
        |> GameHelpers.update_state_flip_letter()
        |> GameHelpers.update_state_flip_letter()

      assert length(new_state.center) == 3
      assert length(new_state.letter_pool) == length(state.letter_pool) - 3
      # 2 players, turn=1 means p2's turn.
      assert new_state.turn == 1
    end

    test "ensure turn cycles" do
      player1 = Player.new("token1", "name1", ["cop", "cap", "cup"])
      player2 = Player.new("token2", "name2", ["bot", "bat", "but"])
      player3 = Player.new("token3", "name3", ["net", "not", "nut"])
      player4 = Player.new("token4", "name4", ["tin", "ton", "tan"])

      state = default_new_game(4, %{
        players: [player1, player2, player3, player4]
      })

      letters = length(state.letter_pool)

      state = GameHelpers.update_state_flip_letter(state)
      assert state.turn == 1
      assert length(state.center) == 1
      assert length(state.letter_pool) == letters - 1

      state = GameHelpers.update_state_flip_letter(state)
      assert state.turn == 2
      assert length(state.center) == 2
      assert length(state.letter_pool) == letters - 2

      state = GameHelpers.update_state_flip_letter(state)
      assert state.turn == 3
      assert length(state.center) == 3
      assert length(state.letter_pool) == letters - 3

      state = GameHelpers.update_state_flip_letter(state)
      assert state.turn == 0
      assert length(state.center) == 4
      assert length(state.letter_pool) == letters - 4

      state = GameHelpers.update_state_flip_letter(state)
      assert state.turn == 1
      assert length(state.center) == 5
      assert length(state.letter_pool) == letters - 5

      state = GameHelpers.update_state_flip_letter(state)
      assert state.turn == 2
      assert length(state.center) == 6
      assert length(state.letter_pool) == letters - 6

      state = GameHelpers.update_state_flip_letter(state)
      assert state.turn == 3
      assert length(state.center) == 7
      assert length(state.letter_pool) == letters - 7

      state = GameHelpers.update_state_flip_letter(state)
      assert state.turn == 0
      assert length(state.center) == 8
      assert length(state.letter_pool) == letters - 8
    end

    test "letter pool is empty" do
      state = %{
        letter_pool: [],
        center: [],
        players: []
      }

      # should return the state unchanged
      new_state = GameHelpers.update_state_flip_letter(state)
      assert new_state == state
    end
  end
end

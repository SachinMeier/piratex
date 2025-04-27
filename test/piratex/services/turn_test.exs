defmodule Piratex.TurnTest do
  use ExUnit.Case

  import Piratex.TestHelpers

  alias Piratex.TurnService
  alias Piratex.Player

  # tests flipping letters into the center
  describe "update_state_flip_letter" do
    setup :new_game_state

    test "flip letter into center", %{state: state} do
      new_state =
        state
        # flip 3 letters into center
        |> TurnService.update_state_flip_letter()
        |> TurnService.update_state_flip_letter()
        |> TurnService.update_state_flip_letter()

      assert length(new_state.center) == 3
      assert length(new_state.letter_pool) == length(state.letter_pool) - 3
      # 2 players, turn=1 means p2's turn.
      assert new_state.turn == 1
    end

    test "ensure turn cycles" do
      players = [
        _player1 = Player.new("token1", "name1", ["cop", "cap", "cup"]),
        _player2 = Player.new("token2", "name2", ["bot", "bat", "but"]),
        _player3 = Player.new("token3", "name3", ["net", "not", "nut"]),
        _player4 = Player.new("token4", "name4", ["tin", "ton", "tan"])
      ]

      state =
        default_new_game(4, %{
          players: players
        })

      letters = length(state.letter_pool)

      assert match_turn?(state, 0, 0)

      state = TurnService.update_state_flip_letter(state)
      assert match_turn?(state, 1, 1)
      assert length(state.center) == 1
      assert length(state.letter_pool) == letters - 1

      state = TurnService.update_state_flip_letter(state)
      assert match_turn?(state, 2, 2)
      assert length(state.center) == 2
      assert length(state.letter_pool) == letters - 2

      state = TurnService.update_state_flip_letter(state)
      assert match_turn?(state, 3, 3)
      assert length(state.center) == 3
      assert length(state.letter_pool) == letters - 3

      state = TurnService.update_state_flip_letter(state)
      assert match_turn?(state, 0, 4)
      assert length(state.center) == 4
      assert length(state.letter_pool) == letters - 4

      state = TurnService.update_state_flip_letter(state)
      assert match_turn?(state, 1, 5)
      assert length(state.center) == 5
      assert length(state.letter_pool) == letters - 5

      state = TurnService.update_state_flip_letter(state)
      assert match_turn?(state, 2, 6)
      assert length(state.center) == 6
      assert length(state.letter_pool) == letters - 6

      state = TurnService.update_state_flip_letter(state)
      assert match_turn?(state, 3, 7)
      assert length(state.center) == 7
      assert length(state.letter_pool) == letters - 7

      state = TurnService.update_state_flip_letter(state)
      assert match_turn?(state, 0, 8)
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
      new_state = TurnService.update_state_flip_letter(state)
      assert new_state == state
    end
  end
end

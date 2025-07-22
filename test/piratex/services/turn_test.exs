defmodule Piratex.TurnTest do
  use ExUnit.Case

  import Piratex.TestHelpers

  alias Piratex.TurnService
  alias Piratex.Player
  alias Piratex.Team

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
        p1 = Player.new("token1", "name1", ["cop", "cap", "cup"]),
        p2 = Player.new("token2", "name2", ["bot", "bat", "but"]),
        p3 = Player.new("token3", "name3", ["net", "not", "nut"]),
        p4 = Player.new("token4", "name4", ["tin", "ton", "tan"])
      ]

      teams = [
        t1 = Team.new("t1"),
        t2 = Team.new("t2"),
        t3 = Team.new("t3"),
        t4 = Team.new("t4"),
      ]

      players_teams = %{
        p1.token => t1.id,
        p2.token => t2.id,
        p3.token => t3.id,
        p4.token => t4.id
      }

      state =
        default_new_game(0, %{
          players: players,
          teams: teams,
          players_teams: players_teams
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

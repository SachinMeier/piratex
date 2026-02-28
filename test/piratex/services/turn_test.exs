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
        t4 = Team.new("t4")
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

  describe "is_player_turn?/2" do
    test "returns true when it is the player's turn" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")

      state = default_new_game(0, %{players: [p1, p2], turn: 0})

      assert TurnService.is_player_turn?(state, "token_1")
      refute TurnService.is_player_turn?(state, "token_2")
    end

    test "returns true for second player when turn is 1" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")

      state = default_new_game(0, %{players: [p1, p2], turn: 1})

      refute TurnService.is_player_turn?(state, "token_1")
      assert TurnService.is_player_turn?(state, "token_2")
    end

    test "works with multiple players" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")
      p3 = Player.new("Charlie", "token_3")
      p4 = Player.new("Diana", "token_4")

      players = [p1, p2, p3, p4]

      Enum.each(0..3, fn turn ->
        state = default_new_game(0, %{players: players, turn: turn})
        current_player = Enum.at(players, turn)

        assert TurnService.is_player_turn?(state, current_player.token)

        players
        |> Enum.reject(fn p -> p.token == current_player.token end)
        |> Enum.each(fn p ->
          refute TurnService.is_player_turn?(state, p.token)
        end)
      end)
    end

    test "returns false for a token not in the player list" do
      p1 = Player.new("Alice", "token_1")
      state = default_new_game(0, %{players: [p1], turn: 0})

      refute TurnService.is_player_turn?(state, "nonexistent_token")
    end
  end

  describe "next_turn/1" do
    test "advances turn to the next player" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")
      p3 = Player.new("Charlie", "token_3")

      state = default_new_game(0, %{players: [p1, p2, p3]})

      assert state.turn == 0
      assert state.total_turn == 0

      state = TurnService.next_turn(state)
      assert state.turn == 1
      assert state.total_turn == 1

      state = TurnService.next_turn(state)
      assert state.turn == 2
      assert state.total_turn == 2
    end

    test "cycles back to the first player after the last" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")
      p3 = Player.new("Charlie", "token_3")

      state = default_new_game(0, %{players: [p1, p2, p3], turn: 0, total_turn: 0})

      state = TurnService.next_turn(state)
      assert state.turn == 1

      state = TurnService.next_turn(state)
      assert state.turn == 2

      state = TurnService.next_turn(state)
      assert state.turn == 0
      assert state.total_turn == 3

      state = TurnService.next_turn(state)
      assert state.turn == 1
      assert state.total_turn == 4
    end

    test "skips quit players" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2") |> Player.quit()
      p3 = Player.new("Charlie", "token_3")

      state = default_new_game(0, %{players: [p1, p2, p3], turn: 0, total_turn: 0})

      # from p1 (index 0), next should skip p2 (quit) and land on p3 (index 2)
      state = TurnService.next_turn(state)
      assert state.turn == 2
      assert state.total_turn == 2
    end

    test "skips multiple consecutive quit players" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2") |> Player.quit()
      p3 = Player.new("Charlie", "token_3") |> Player.quit()
      p4 = Player.new("Diana", "token_4")

      state = default_new_game(0, %{players: [p1, p2, p3, p4], turn: 0, total_turn: 0})

      # from p1, should skip p2 and p3, land on p4
      state = TurnService.next_turn(state)
      assert state.turn == 3
      assert state.total_turn == 3
    end

    test "skips quit players when cycling past end of list" do
      p1 = Player.new("Alice", "token_1") |> Player.quit()
      p2 = Player.new("Bob", "token_2")
      p3 = Player.new("Charlie", "token_3")

      state = default_new_game(0, %{players: [p1, p2, p3], turn: 2, total_turn: 2})

      # from p3 (index 2), next wraps to p1 (quit), skips to p2
      state = TurnService.next_turn(state)
      assert state.turn == 1
      assert state.total_turn == 4
    end

    test "handles only one active player remaining" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2") |> Player.quit()
      p3 = Player.new("Charlie", "token_3") |> Player.quit()

      state = default_new_game(0, %{players: [p1, p2, p3], turn: 0, total_turn: 0})

      # should cycle through all quit players and come back to p1
      state = TurnService.next_turn(state)
      assert state.turn == 0
      assert state.total_turn == 3
    end
  end

  describe "start_turn_timeout/1" do
    @tag timeout: 70_000
    test "sends turn_timeout message after configured timeout" do
      total_turn = 5
      TurnService.start_turn_timeout(total_turn)

      refute_receive {:turn_timeout, ^total_turn}, 100

      assert_receive {:turn_timeout, ^total_turn}, 65_000
    end

    @tag timeout: 70_000
    test "sends correct total_turn in timeout message" do
      total_turn = 42
      TurnService.start_turn_timeout(total_turn)

      assert_receive {:turn_timeout, ^total_turn}, 65_000
    end

    test "returns timer reference" do
      total_turn = 1
      result = TurnService.start_turn_timeout(total_turn)

      assert is_reference(result)
    end
  end

  describe "next_turn/1 with turn timeout behavior" do
    @tag timeout: 70_000
    test "starts turn timeout when more than one player is active" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")
      p3 = Player.new("Charlie", "token_3")

      state = default_new_game(0, %{players: [p1, p2, p3], turn: 0, total_turn: 0})

      TurnService.next_turn(state)

      assert_receive {:turn_timeout, 1}, 65_000
    end

    test "does not start turn timeout when only one player is active" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2") |> Player.quit()
      p3 = Player.new("Charlie", "token_3") |> Player.quit()

      state = default_new_game(0, %{players: [p1, p2, p3], turn: 0, total_turn: 0})

      TurnService.next_turn(state)

      refute_receive {:turn_timeout, _}, 100
    end

    @tag timeout: 70_000
    test "starts turn timeout after skipping quit players" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2") |> Player.quit()
      p3 = Player.new("Charlie", "token_3")

      state = default_new_game(0, %{players: [p1, p2, p3], turn: 0, total_turn: 0})

      TurnService.next_turn(state)

      assert_receive {:turn_timeout, 2}, 65_000
    end

    @tag timeout: 70_000
    test "starts turn timeout with correct total_turn after multiple advances" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")

      state = default_new_game(0, %{players: [p1, p2], turn: 0, total_turn: 5})

      TurnService.next_turn(state)

      assert_receive {:turn_timeout, 6}, 65_000
    end
  end

  describe "update_state_flip_letter/1 edge cases" do
    test "flips last letter from pool" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")

      state =
        default_new_game(0, %{
          players: [p1, p2],
          letter_pool: ["Z"],
          center: ["A", "B", "C"],
          turn: 0,
          total_turn: 0
        })

      new_state = TurnService.update_state_flip_letter(state)

      assert new_state.letter_pool == []
      assert length(new_state.center) == 4
      assert "Z" in new_state.center
      assert new_state.turn == 1
      assert new_state.total_turn == 1
    end

    test "advances turn correctly after flipping letter" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")
      p3 = Player.new("Charlie", "token_3")

      state =
        default_new_game(0, %{
          players: [p1, p2, p3],
          letter_pool: ["X", "Y", "Z"],
          center: [],
          turn: 1,
          total_turn: 1
        })

      new_state = TurnService.update_state_flip_letter(state)

      assert new_state.turn == 2
      assert new_state.total_turn == 2
      assert length(new_state.letter_pool) == 2
      assert length(new_state.center) == 1
    end

    test "skips quit players when flipping letter" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2") |> Player.quit()
      p3 = Player.new("Charlie", "token_3")

      state =
        default_new_game(0, %{
          players: [p1, p2, p3],
          letter_pool: ["X", "Y", "Z"],
          center: [],
          turn: 0,
          total_turn: 0
        })

      new_state = TurnService.update_state_flip_letter(state)

      assert new_state.turn == 2
      assert new_state.total_turn == 2
    end

    test "picks random letter from pool" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")

      state =
        default_new_game(0, %{
          players: [p1, p2],
          letter_pool: ["A", "B", "C", "D", "E"],
          center: [],
          turn: 0,
          total_turn: 0
        })

      new_state = TurnService.update_state_flip_letter(state)

      assert length(new_state.letter_pool) == 4
      assert length(new_state.center) == 1

      flipped_letter = hd(new_state.center)
      assert flipped_letter in ["A", "B", "C", "D", "E"]
      refute flipped_letter in new_state.letter_pool
    end

    test "maintains center_sorted when flipping letter" do
      p1 = Player.new("Alice", "token_1")
      p2 = Player.new("Bob", "token_2")

      state =
        default_new_game(0, %{
          players: [p1, p2],
          letter_pool: ["Z"],
          center: ["B", "A"],
          center_sorted: ["A", "B"],
          turn: 0,
          total_turn: 0
        })

      new_state = TurnService.update_state_flip_letter(state)

      assert length(new_state.center_sorted) == 3
      assert new_state.center_sorted == Enum.sort(new_state.center)
      assert "Z" in new_state.center_sorted
    end
  end
end

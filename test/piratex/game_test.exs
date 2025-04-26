defmodule Piratex.GameTest do
  use ExUnit.Case

  alias Piratex.Game

  describe "Join Game" do
    test "game not found" do
      assert {:error, :not_found} = Game.join_game("game_id", "player1", "token1")
    end

    test "new game, 2 players join" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      {:ok, %{status: :waiting}} = Game.get_state(game_id)

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.join_game(game_id, "player2", "token2")

      {:ok, %{status: :waiting, players: [_, _]}} = Game.get_state(game_id)

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing, players: [_, _]}} = Game.get_state(game_id)
    end

    test "new game max_players join and next player rejected" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()
      max_players = Piratex.Config.max_players()

      for i <- 1..max_players do
        :ok = Game.join_game(game_id, "player#{i}", "token#{i}")
      end

      assert {:error, :game_full} = Game.join_game(game_id, "player#{max_players + 1}", "token#{max_players + 1}")
    end

    test "new game player name too short" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      assert {:error, :player_name_too_short} =
        Game.join_game(game_id, String.duplicate("a", Piratex.Config.min_player_name() - 1), "token1")
    end

    test "new game player name too long" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      assert {:error, :player_name_too_long} =
        Game.join_game(game_id, String.duplicate("a", Piratex.Config.max_player_name() + 1), "token1")
    end

    test "unique player name and token" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :duplicate_player} = Game.join_game(game_id, "player1", "token1")
      assert {:error, :duplicate_player} = Game.join_game(game_id, "player1", "token2")
      assert {:error, :duplicate_player} = Game.join_game(game_id, "player2", "token1")
    end

    test "player tries to join late" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.join_game(game_id, "player3", "token3")

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)

      {:error, :game_already_started} = Game.join_game(game_id, "player4", "token4")
    end
  end

  describe "Rejoin Game" do
    test "player not found" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      assert {:error, :not_found} = Game.rejoin_game(game_id, "player1", "token1")
    end

    test "success" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      assert :ok = Game.rejoin_game(game_id, "player1", "token1")
      assert :ok = Game.rejoin_game(game_id, "player1", "token1")

      assert :ok = Game.rejoin_game(game_id, "player2", "token2")
      assert :ok = Game.rejoin_game(game_id, "player2", "token2")

      assert {:error, :not_found} = Game.rejoin_game(game_id, "player3", "token3")
    end
  end

  describe "Leave Waiting Game" do
    test "game is not waiting" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.start_game(game_id, "token1")

      assert {:error, :game_already_started} = Game.leave_waiting_game(game_id, "token1")
    end

    test "success" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      {:ok, %{players: [_, _], status: :waiting}} = Game.get_state(game_id)

      assert :ok = Game.leave_waiting_game(game_id, "token1")

      {:ok, %{players: [_player2], status: :waiting}} = Game.get_state(game_id)

      # game should terminate when last player leaves during waiting state
      assert :ok = Game.leave_waiting_game(game_id, "token2")
      # TODO: find a better way to ensure stop is processed before the Registry lookup below
      :timer.sleep(100)

      assert [] = Registry.lookup(Piratex.Game.Registry, game_id)
    end
  end

  describe "Start Game" do
    test "game not found" do
      assert {:error, :not_found} = Game.start_game("game_id", "token1")
    end

    test "start a 1 player game" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)
    end

    test "start a 2 player game" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)

      :game_already_started = Game.start_game(game_id, "token1")
      :game_already_started = Game.start_game(game_id, "token2")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)
    end

    test "start a 2 player game - non-first player starts" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token2")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)

      :game_already_started = Game.start_game(game_id, "token1")
      :game_already_started = Game.start_game(game_id, "token2")

      {:ok, %{status: :playing} = _state} = Game.get_state(game_id)
    end
  end

  describe "Flip Letter" do
    test "game not found" do
      assert {:error, :not_found} = Game.flip_letter("game_id", "token1")
    end

    test "one player" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")

      assert {:error, :game_not_playing} = Game.flip_letter(game_id, "token1")

      :ok = Game.start_game(game_id, "token1")

      assert {:ok, %{status: :playing}} = Game.get_state(game_id)

      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{center: [_letter]}} = Game.get_state(game_id)

      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{center: [_, _]}} = Game.get_state(game_id)
    end


    test "two players" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      assert {:error, :game_not_playing} = Game.flip_letter(game_id, "token1")

      :ok = Game.start_game(game_id, "token1")

      assert {:ok, %{status: :playing}} = Game.get_state(game_id)

      # NOT p2's turn
      assert {:error, :not_your_turn} = Game.flip_letter(game_id, "token2")
      assert {:ok, %{center: []}} = Game.get_state(game_id)

      # p1's turn
      assert :ok = Game.flip_letter(game_id, "token1")
      assert {:ok, %{center: [_letter]}} = Game.get_state(game_id)

      # NOT p1's turn
      assert {:error, :not_your_turn} = Game.flip_letter(game_id, "token1")
      assert {:ok, %{center: [_]}} = Game.get_state(game_id)

      # p2's turn
      assert :ok = Game.flip_letter(game_id, "token2")
      assert {:ok, %{center: [_, _]}} = Game.get_state(game_id)

      # NOT p2's turn
      assert {:error, :not_your_turn} = Game.flip_letter(game_id, "token2")
      assert {:ok, %{center: [_, _]}} = Game.get_state(game_id)
    end

    test "no flip with open challenge" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")

      :ok = Game.start_game(game_id, "token1")

      # TODO: add challenge and try to flip
    end
  end

  describe "Claim Word" do
    # TODO: test claim word
  end

  describe "Challenge Word" do
    # TODO: test challenge word
  end
end

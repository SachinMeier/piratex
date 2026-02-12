defmodule Piratex.PlayerTest do
  use ExUnit.Case

  alias Piratex.Player
  alias Piratex.PlayerService

  # Player Tests

  describe "Player.new/3" do
    test "creates a player with default team_id nil" do
      player = Player.new("alice", "tok123")
      assert player.name == "alice"
      assert player.token == "tok123"
      assert player.status == :playing
      assert player.team_id == nil
    end

    test "creates a player with a team_id" do
      player = Player.new("bob", "tok456", 2)
      assert player.name == "bob"
      assert player.token == "tok456"
      assert player.status == :playing
      assert player.team_id == 2
    end
  end

  describe "Player.is_playing?/1" do
    test "returns true for a playing player" do
      assert Player.is_playing?(%Player{status: :playing})
    end

    test "returns false for a quit player" do
      refute Player.is_playing?(%Player{status: :quit})
    end
  end

  describe "Player.quit/1" do
    test "marks a player as quit" do
      player = Player.new("name", "token") |> Player.quit()
      refute Player.is_playing?(player)
      assert player.status == :quit
    end
  end

  describe "Player.set_team/2" do
    test "sets the team_id on a player" do
      player = Player.new("name", "token")
      assert player.team_id == nil

      player = Player.set_team(player, 3)
      assert player.team_id == 3
    end

    test "overwrites an existing team_id" do
      player = Player.new("name", "token", 1)
      assert player.team_id == 1

      player = Player.set_team(player, 5)
      assert player.team_id == 5
    end
  end

  describe "Player.drop_internal_state/1" do
    test "removes token from player map" do
      player = Player.new("name", "token", 1)
      result = Player.drop_internal_state(player)
      assert Map.get(result, :token, nil) == nil
    end

    test "retains name, status, and team_id" do
      player = Player.new("name", "token", 2)
      result = Player.drop_internal_state(player)
      assert result[:name] == "name"
      assert result[:status] == :playing
      assert result[:team_id] == 2
    end
  end

  # Service Tests

  describe "PlayerService.new_player_token/0" do
    test "returns a base64-encoded string" do
      token = PlayerService.new_player_token()
      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "returns unique tokens on successive calls" do
      token1 = PlayerService.new_player_token()
      token2 = PlayerService.new_player_token()
      refute token1 == token2
    end

    test "token can be decoded back to 16 bytes" do
      token = PlayerService.new_player_token()
      {:ok, decoded} = Base.decode64(token, padding: false)
      assert byte_size(decoded) == 16
    end
  end

  describe "PlayerService.add_player/2" do
    test "adds players up to the max" do
      max_players = Piratex.Config.max_players()
      state = %{players: []}

      state =
        Enum.reduce(1..max_players, state, fn i, state ->
          player = Player.new("name#{i}", "token#{i}")
          state = PlayerService.add_player(state, player)
          assert length(state.players) == i
          state
        end)

      assert length(state.players) == max_players
    end

    test "returns error when game is full" do
      max_players = Piratex.Config.max_players()

      state =
        Enum.reduce(1..max_players, %{players: []}, fn i, state ->
          PlayerService.add_player(state, Player.new("name#{i}", "token#{i}"))
        end)

      assert {:error, :game_full} =
               PlayerService.add_player(state, Player.new("extra", "token_extra"))
    end
  end

  describe "PlayerService.remove_player/2" do
    test "removes a player from the players list" do
      p1 = Player.new("alice", "tok1")
      p2 = Player.new("bob", "tok2")

      state = %{
        players: [p1, p2],
        players_teams: %{"tok1" => 1, "tok2" => 2}
      }

      result = PlayerService.remove_player(state, "tok1")
      assert length(result.players) == 1
      assert hd(result.players).token == "tok2"
    end

    test "removes the player from players_teams map" do
      p1 = Player.new("alice", "tok1")

      state = %{
        players: [p1],
        players_teams: %{"tok1" => 1}
      }

      result = PlayerService.remove_player(state, "tok1")
      assert result.players_teams == %{}
    end

    test "does nothing when token is not found" do
      p1 = Player.new("alice", "tok1")

      state = %{
        players: [p1],
        players_teams: %{"tok1" => 1}
      }

      result = PlayerService.remove_player(state, "nonexistent")
      assert length(result.players) == 1
      assert result.players_teams == %{"tok1" => 1}
    end
  end

  describe "PlayerService.find_player/2" do
    test "finds players by token" do
      p1 = Player.new("name1", "token1")
      p2 = Player.new("name2", "token2")
      p3 = Player.new("name3", "token3")
      players = [p1, p2, p3]

      assert PlayerService.find_player(%{players: players}, "token1") == p1
      assert PlayerService.find_player(%{players: players}, "token2") == p2
      assert PlayerService.find_player(%{players: players}, "token3") == p3
    end

    test "returns nil when token is not found" do
      players = [Player.new("name1", "token1")]
      assert PlayerService.find_player(%{players: players}, "token4") == nil
    end
  end

  describe "PlayerService.find_unassigned_player/2" do
    test "finds a player by token" do
      p1 = Player.new("alice", "tok1")
      p2 = Player.new("bob", "tok2")
      state = %{players: [p1, p2]}

      assert PlayerService.find_unassigned_player(state, "tok1") == p1
      assert PlayerService.find_unassigned_player(state, "tok2") == p2
    end

    test "returns nil when token is not found" do
      state = %{players: [Player.new("alice", "tok1")]}
      assert PlayerService.find_unassigned_player(state, "nonexistent") == nil
    end
  end

  describe "PlayerService.find_unassigned_player_with_index/2" do
    test "returns index and player when found" do
      p1 = Player.new("alice", "tok1")
      p2 = Player.new("bob", "tok2")
      p3 = Player.new("carol", "tok3")
      state = %{players: [p1, p2, p3]}

      assert {0, ^p1} = PlayerService.find_unassigned_player_with_index(state, "tok1")
      assert {1, ^p2} = PlayerService.find_unassigned_player_with_index(state, "tok2")
      assert {2, ^p3} = PlayerService.find_unassigned_player_with_index(state, "tok3")
    end

    test "returns error tuple when token is not found" do
      state = %{players: [Player.new("alice", "tok1")]}

      assert {:error, :not_found} =
               PlayerService.find_unassigned_player_with_index(state, "nonexistent")
    end
  end

  describe "PlayerService.player_is_unique?/3" do
    setup do
      players = [
        Player.new("name1", "token1"),
        Player.new("name2", "token2")
      ]

      %{players: players, state: %{players: players}}
    end

    test "returns false when both name and token match", %{state: state} do
      refute PlayerService.player_is_unique?(state, "name1", "token1")
      refute PlayerService.player_is_unique?(state, "name2", "token2")
    end

    test "returns false when name matches but token differs", %{state: state} do
      refute PlayerService.player_is_unique?(state, "name1", "token3")
    end

    test "returns false when token matches but name differs", %{state: state} do
      refute PlayerService.player_is_unique?(state, "name3", "token2")
    end

    test "returns true when both name and token are new", %{state: state} do
      assert PlayerService.player_is_unique?(state, "name3", "token3")
    end
  end

  describe "PlayerService.count_unquit_players/1" do
    test "counts all playing players" do
      players = [
        Player.new("name1", "token1"),
        Player.new("name2", "token2"),
        Player.new("name3", "token3"),
        Player.new("name4", "token4")
      ]

      assert PlayerService.count_unquit_players(%{players: players}) == 4
      assert PlayerService.count_unquit_players(%{players: Enum.take(players, 3)}) == 3
      assert PlayerService.count_unquit_players(%{players: Enum.take(players, 2)}) == 2
      assert PlayerService.count_unquit_players(%{players: Enum.take(players, 1)}) == 1
      assert PlayerService.count_unquit_players(%{players: []}) == 0
    end

    test "excludes quit players" do
      p1 = Player.new("name1", "token1")
      p2 = Player.new("name2", "token2")
      p3 = Player.new("name3", "token3")
      p4 = Player.new("name4", "token4")

      qp1 = Player.quit(p1)
      qp2 = Player.quit(p2)
      qp3 = Player.quit(p3)
      qp4 = Player.quit(p4)

      assert PlayerService.count_unquit_players(%{players: [qp1, qp2, qp3, qp4]}) == 0
      assert PlayerService.count_unquit_players(%{players: [qp1, qp2, qp3, p4]}) == 1
      assert PlayerService.count_unquit_players(%{players: [qp1, qp2, p3, p4]}) == 2
      assert PlayerService.count_unquit_players(%{players: [qp1, p2, p3, p4]}) == 3
    end
  end
end

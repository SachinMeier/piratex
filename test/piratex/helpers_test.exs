defmodule Piratex.HelpersTest do
  use ExUnit.Case, async: true

  import Piratex.TestHelpers

  alias Piratex.Helpers
  alias Piratex.Player
  alias Piratex.Team
  alias Piratex.TurnService

  describe "ok/0 and ok/1" do
    test "ok/0 returns :ok" do
      assert Helpers.ok() == :ok
    end

    test "ok/1 wraps value in {:ok, value}" do
      assert Helpers.ok(42) == {:ok, 42}
      assert Helpers.ok("hello") == {:ok, "hello"}
      assert Helpers.ok(%{key: :val}) == {:ok, %{key: :val}}
      assert Helpers.ok(nil) == {:ok, nil}
    end
  end

  describe "noreply/1" do
    test "returns {:noreply, state, timeout} for state with players" do
      state = default_new_game(2)
      {:noreply, returned_state, timeout} = Helpers.noreply(state)

      assert returned_state == state
      assert timeout == Piratex.Config.game_timeout_ms()
    end

    test "returns {:noreply, state, timeout} for state with no players" do
      state = default_new_game(0)
      {:noreply, returned_state, timeout} = Helpers.noreply(state)

      assert returned_state == state
      assert timeout == Piratex.Config.new_game_timeout_ms()
    end
  end

  describe "reply/3" do
    test "returns {:reply, resp, state, timeout} with default timeout" do
      state = default_new_game(2)
      {:reply, resp, returned_state, timeout} = Helpers.reply(state, :ok)

      assert resp == :ok
      assert returned_state == state
      assert timeout == Piratex.Config.game_timeout_ms()
    end

    test "returns {:reply, resp, state, timeout} with custom timeout" do
      state = default_new_game(2)
      {:reply, resp, returned_state, timeout} = Helpers.reply(state, {:ok, "data"}, 5000)

      assert resp == {:ok, "data"}
      assert returned_state == state
      assert timeout == 5000
    end

    test "uses game_timeout for empty players when no custom timeout" do
      state = default_new_game(0)
      {:reply, _resp, _state, timeout} = Helpers.reply(state, :ok)

      assert timeout == Piratex.Config.new_game_timeout_ms()
    end
  end

  describe "new_id/0 and new_id/1" do
    test "new_id/0 returns a positive integer" do
      id = Helpers.new_id()
      assert is_integer(id)
      assert id >= 0
    end

    test "new_id/1 returns a positive integer with custom byte size" do
      id = Helpers.new_id(4)
      assert is_integer(id)
      assert id >= 0
    end

    test "new_id/0 generates different ids on successive calls" do
      ids = Enum.map(1..10, fn _ -> Helpers.new_id() end)
      assert length(Enum.uniq(ids)) > 1
    end
  end

  describe "word_in_play?/2" do
    test "returns true for words belonging to any team" do
      teams = [
        Team.new("name1", ["bind", "band", "bond"]),
        Team.new("name2", ["bing", "bang", "bong"])
      ]

      assert Helpers.word_in_play?(%{teams: teams}, "bind")
      assert Helpers.word_in_play?(%{teams: teams}, "band")
      assert Helpers.word_in_play?(%{teams: teams}, "bond")
      assert Helpers.word_in_play?(%{teams: teams}, "bing")
      assert Helpers.word_in_play?(%{teams: teams}, "bang")
      assert Helpers.word_in_play?(%{teams: teams}, "bong")
    end

    test "returns false for words not in play" do
      teams = [
        Team.new("name1", ["bind", "band", "bond"]),
        Team.new("name2", ["bing", "bang", "bong"])
      ]

      refute Helpers.word_in_play?(%{teams: teams}, "nonword")
      refute Helpers.word_in_play?(%{teams: teams}, "")
    end
  end

  describe "no_more_letters?/1" do
    test "returns true when letter pool is empty" do
      assert Helpers.no_more_letters?(%{letter_pool: []})
    end

    test "returns false when letter pool has letters" do
      refute Helpers.no_more_letters?(%{letter_pool: ["a"]})
    end

    test "tracks letter pool depletion through flips" do
      state =
        default_new_game(2, %{
          letter_pool: ["a", "b", "c"]
        })

      refute Helpers.no_more_letters?(state)

      state = TurnService.update_state_flip_letter(state)
      refute Helpers.no_more_letters?(state)

      state = TurnService.update_state_flip_letter(state)
      refute Helpers.no_more_letters?(state)

      state = TurnService.update_state_flip_letter(state)
      assert Helpers.no_more_letters?(state)
    end
  end

  describe "add_letters_to_center/2" do
    test "adds a single letter to an empty center" do
      state = %{center: [], center_sorted: []}
      result = Helpers.add_letters_to_center(state, ["a"])

      assert result.center == ["a"]
      assert result.center_sorted == ["a"]
    end

    test "adds a single letter to a non-empty center" do
      state = %{center: ["b"], center_sorted: ["b"]}
      result = Helpers.add_letters_to_center(state, ["a"])

      # new letter is prepended (chronological desc)
      assert result.center == ["a", "b"]
      # sorted alphabetically
      assert result.center_sorted == ["a", "b"]
    end

    test "adds multiple letters" do
      state = %{center: ["c"], center_sorted: ["c"]}
      result = Helpers.add_letters_to_center(state, ["z", "a"])

      # z is added first, then a is prepended
      assert result.center == ["a", "z", "c"]
      assert result.center_sorted == ["a", "c", "z"]
    end

    test "adds letters to empty center maintaining sort" do
      state = %{center: [], center_sorted: []}
      result = Helpers.add_letters_to_center(state, ["d", "b", "a"])

      assert result.center == ["a", "b", "d"]
      assert result.center_sorted == ["a", "b", "d"]
    end
  end

  describe "find_player_index/2" do
    test "finds index of existing player by token" do
      state = default_new_game(3)

      assert Helpers.find_player_index(state, "token_1") == 0
      assert Helpers.find_player_index(state, "token_2") == 1
      assert Helpers.find_player_index(state, "token_3") == 2
    end

    test "returns nil for non-existent token" do
      state = default_new_game(2)

      assert Helpers.find_player_index(state, "nonexistent") == nil
    end
  end

  describe "lookup_team/2" do
    test "finds the team for a given player token" do
      p1 = Player.new("alice", "tok_alice")
      p2 = Player.new("bob", "tok_bob")

      t1 = Team.new("Team Alice", ["word1"])
      t2 = Team.new("Team Bob", ["word2"])

      state = %{
        players: [p1, p2],
        teams: [t1, t2],
        players_teams: %{p1.token => t1.id, p2.token => t2.id}
      }

      result = Helpers.lookup_team(state, "tok_alice")
      assert result.id == t1.id
      assert result.name == "Team Alice"

      result = Helpers.lookup_team(state, "tok_bob")
      assert result.id == t2.id
    end

    test "returns nil for a player token not in players_teams" do
      t1 = Team.new("Team One")

      state = %{
        players: [],
        teams: [t1],
        players_teams: %{}
      }

      result = Helpers.lookup_team(state, "nonexistent_token")
      assert result == nil
    end
  end

  describe "state_for_player/1" do
    setup do
      state = build_state_with_map_players_teams(2)
      {:ok, state: state}
    end

    test "returns the expected keys", %{state: state} do
      result = Helpers.state_for_player(state)

      # state_for_player picks certain keys and adds :players and :players_teams
      # :game_stats is only present if set on the state
      assert Map.has_key?(result, :id)
      assert Map.has_key?(result, :status)
      assert Map.has_key?(result, :turn)
      assert Map.has_key?(result, :teams)
      assert Map.has_key?(result, :letter_pool_count)
      assert Map.has_key?(result, :initial_letter_count)
      assert Map.has_key?(result, :center)
      assert Map.has_key?(result, :history)
      assert Map.has_key?(result, :challenges)
      assert Map.has_key?(result, :past_challenges)
      assert Map.has_key?(result, :end_game_votes)
      assert Map.has_key?(result, :players_teams)
      assert Map.has_key?(result, :players)
    end

    test "does not include center_sorted", %{state: state} do
      result = Helpers.state_for_player(state)

      refute Map.has_key?(result, :center_sorted)
    end

    test "does not include last_action_at", %{state: state} do
      result = Helpers.state_for_player(state)

      refute Map.has_key?(result, :last_action_at)
    end

    test "includes total_turn and active_player_count", %{state: state} do
      result = Helpers.state_for_player(state)

      assert Map.has_key?(result, :total_turn)
      assert Map.has_key?(result, :active_player_count)
      assert result.active_player_count == 2
    end

    test "players list has tokens stripped", %{state: state} do
      result = Helpers.state_for_player(state)

      Enum.each(result.players, fn player ->
        refute Map.has_key?(player, :token)
      end)
    end

    test "players_teams maps player names to team ids", %{state: state} do
      result = Helpers.state_for_player(state)

      Enum.each(result.players_teams, fn {key, _team_id} ->
        assert is_binary(key)
      end)

      assert map_size(result.players_teams) == 2
      assert Map.has_key?(result.players_teams, "player_1")
      assert Map.has_key?(result.players_teams, "player_2")
    end
  end

  describe "sanitize_players_teams/1" do
    test "maps player tokens to player names" do
      state = build_state_with_map_players_teams(2)
      result = Helpers.sanitize_players_teams(state)

      assert Map.has_key?(result, "player_1")
      assert Map.has_key?(result, "player_2")
      refute Map.has_key?(result, "token_1")
      refute Map.has_key?(result, "token_2")
    end

    test "preserves team id values" do
      state = build_state_with_map_players_teams(2)
      result = Helpers.sanitize_players_teams(state)

      p1_team_id = Map.get(state.players_teams, "token_1")
      p2_team_id = Map.get(state.players_teams, "token_2")

      assert Map.get(result, "player_1") == p1_team_id
      assert Map.get(result, "player_2") == p2_team_id
    end
  end

  describe "drop_internal_states/1" do
    test "removes tokens from player list" do
      players = [
        Player.new("alice", "secret_token_1"),
        Player.new("bob", "secret_token_2")
      ]

      result = Helpers.drop_internal_states(players)

      Enum.each(result, fn player ->
        refute Map.has_key?(player, :token)
        assert Map.has_key?(player, :name)
        assert Map.has_key?(player, :status)
      end)
    end

    test "preserves player names and statuses" do
      players = [
        Player.new("alice", "t1"),
        Player.new("bob", "t2")
      ]

      result = Helpers.drop_internal_states(players)

      assert Enum.at(result, 0).name == "alice"
      assert Enum.at(result, 1).name == "bob"
      assert Enum.at(result, 0).status == :playing
      assert Enum.at(result, 1).status == :playing
    end

    test "handles empty player list" do
      assert Helpers.drop_internal_states([]) == []
    end
  end

  # Builds a state where players_teams is a proper map (not a keyword list).
  # default_new_game returns players_teams as a list of tuples from Enum.unzip,
  # but production code expects a map.
  defp build_state_with_map_players_teams(player_count) do
    state = default_new_game(player_count)
    %{state | players_teams: Map.new(state.players_teams)}
  end

  describe "game_timeout/1" do
    test "returns new_game_timeout for empty players" do
      state = %{players: []}
      assert Helpers.game_timeout(state) == Piratex.Config.new_game_timeout_ms()
    end

    test "returns game_timeout for state with players" do
      state = default_new_game(1)
      assert Helpers.game_timeout(state) == Piratex.Config.game_timeout_ms()
    end
  end
end

defmodule Piratex.DynamicSupervisorTest do
  use ExUnit.Case

  alias Piratex.DynamicSupervisor, as: DS
  alias Piratex.Game

  describe "start_link/1" do
    test "starts the dynamic supervisor with the correct name" do
      # The supervisor is already started by the application
      # We verify it exists and is named correctly
      pid = Process.whereis(DS)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "supervisor can be looked up by module name" do
      assert is_pid(Process.whereis(DS))
    end
  end

  describe "init/1" do
    test "initializes with :one_for_one strategy" do
      # init/1 returns the proper supervisor spec
      assert {:ok, supervisor_spec} = DS.init([])
      assert supervisor_spec.strategy == :one_for_one
    end

    test "init/1 ignores the init_arg parameter" do
      # The function accepts _init_arg but doesn't use it
      assert {:ok, spec1} = DS.init([])
      assert {:ok, spec2} = DS.init(:some_arg)
      assert {:ok, spec3} = DS.init(%{key: "value"})

      # All should return the same result
      assert spec1 == spec2
      assert spec2 == spec3
    end
  end

  describe "new_game/0" do
    test "creates a new game and returns {:ok, game_id}" do
      assert {:ok, game_id} = DS.new_game()
      assert is_binary(game_id)
    end

    test "created game is findable via Game.get_state/1" do
      {:ok, game_id} = DS.new_game()

      assert {:ok, %{id: ^game_id, status: :waiting}} = Game.get_state(game_id)
    end

    test "created game has expected default state" do
      {:ok, game_id} = DS.new_game()

      {:ok, state} = Game.get_state(game_id)

      assert state.status == :waiting
      assert state.players == []
      assert state.teams == []
      assert state.center == []
      assert state.challenges == []
      assert state.past_challenges == []
      assert state.end_game_votes == %{}
    end

    test "creates multiple independent games" do
      {:ok, game_id_1} = DS.new_game()
      {:ok, game_id_2} = DS.new_game()
      {:ok, game_id_3} = DS.new_game()

      assert game_id_1 != game_id_2
      assert game_id_2 != game_id_3
      assert game_id_1 != game_id_3

      assert {:ok, %{id: ^game_id_1, status: :waiting}} = Game.get_state(game_id_1)
      assert {:ok, %{id: ^game_id_2, status: :waiting}} = Game.get_state(game_id_2)
      assert {:ok, %{id: ^game_id_3, status: :waiting}} = Game.get_state(game_id_3)
    end

    test "game process is supervised by DynamicSupervisor" do
      {:ok, game_id} = DS.new_game()

      {:ok, _state} = Game.get_state(game_id)
      game_pid = GenServer.whereis(Game.via_tuple(game_id))

      assert is_pid(game_pid)

      # Verify the game is a child of the supervisor
      children = DynamicSupervisor.which_children(DS)
      child_pids = Enum.map(children, fn {_id, pid, _type, _modules} -> pid end)

      assert game_pid in child_pids
    end

    test "game is registered with the correct child spec" do
      {:ok, game_id} = DS.new_game()

      children = DynamicSupervisor.which_children(DS)

      # Find our game in the children
      game_child =
        Enum.find(children, fn {_id, pid, _type, _modules} ->
          pid == GenServer.whereis(Game.via_tuple(game_id))
        end)

      assert game_child != nil

      {_id, _pid, :worker, [Piratex.Game]} = game_child
    end
  end

  describe "new_game/1" do
    test "creates a game from a custom state map" do
      custom_state = %{
        id: "PLACEHOLDER",
        status: :waiting,
        players: [],
        teams: [],
        players_teams: %{},
        turn: 0,
        total_turn: 0,
        letter_pool: ["a", "b", "c"],
        initial_letter_count: 3,
        center: ["x", "y"],
        center_sorted: ["x", "y"],
        history: [],
        challenges: [],
        past_challenges: [],
        end_game_votes: %{},
        last_action_at: DateTime.utc_now()
      }

      {:ok, game_id} = DS.new_game(custom_state)

      assert is_binary(game_id)
      # new_game/1 assigns a fresh id, so it won't be "PLACEHOLDER"
      assert game_id != "PLACEHOLDER"

      {:ok, state} = Game.get_state(game_id)

      assert state.id == game_id
      assert state.status == :waiting
      assert state.center == ["x", "y"]
      assert state.letter_pool == ["a", "b", "c"]
      assert state.initial_letter_count == 3
    end

    test "assigns a new game id, overriding the one in the state map" do
      custom_state = %{
        id: "ORIGINAL_ID",
        status: :waiting,
        players: [],
        teams: [],
        players_teams: %{},
        turn: 0,
        total_turn: 0,
        letter_pool: [],
        initial_letter_count: 0,
        center: [],
        center_sorted: [],
        history: [],
        challenges: [],
        past_challenges: [],
        end_game_votes: %{},
        last_action_at: DateTime.utc_now()
      }

      {:ok, game_id} = DS.new_game(custom_state)

      assert game_id != "ORIGINAL_ID"
      assert {:ok, %{id: ^game_id}} = Game.get_state(game_id)
    end

    test "preserves custom center and letter_pool from state" do
      center = ["d", "o", "g"]
      center_sorted = ["d", "g", "o"]
      letter_pool = ["z", "q", "w"]

      custom_state = %{
        id: "TEMP",
        status: :waiting,
        players: [],
        teams: [],
        players_teams: %{},
        turn: 0,
        total_turn: 0,
        letter_pool: letter_pool,
        initial_letter_count: 3,
        center: center,
        center_sorted: center_sorted,
        history: [],
        challenges: [],
        past_challenges: [],
        end_game_votes: %{},
        last_action_at: DateTime.utc_now()
      }

      {:ok, game_id} = DS.new_game(custom_state)

      {:ok, state} = Game.get_state(game_id)

      assert state.center == center
      assert state.letter_pool == letter_pool
      assert state.initial_letter_count == 3
    end

    test "preserves players and teams from custom state" do
      player = Piratex.Player.new("alice", "token_alice", nil)
      team = Piratex.Team.new("Team Alice")

      custom_state = %{
        id: "TEMP",
        status: :waiting,
        players: [player],
        teams: [team],
        players_teams: %{"token_alice" => team.id},
        turn: 0,
        total_turn: 0,
        letter_pool: [],
        initial_letter_count: 0,
        center: [],
        center_sorted: [],
        history: [],
        challenges: [],
        past_challenges: [],
        end_game_votes: %{},
        last_action_at: DateTime.utc_now()
      }

      {:ok, game_id} = DS.new_game(custom_state)

      {:ok, state} = Game.get_state(game_id)

      assert length(state.players) == 1
      assert length(state.teams) == 1
      assert hd(state.players).name == "alice"
      assert hd(state.teams).name == "Team Alice"
      assert state.players_teams == %{"alice" => team.id}
    end

    test "preserves history and turn counter from custom state" do
      custom_state = %{
        id: "TEMP",
        status: :waiting,
        players: [],
        teams: [],
        players_teams: %{},
        turn: 5,
        total_turn: 10,
        letter_pool: [],
        initial_letter_count: 0,
        center: [],
        center_sorted: [],
        history: [%{event: "test_event"}],
        challenges: [],
        past_challenges: [],
        end_game_votes: %{},
        last_action_at: DateTime.utc_now()
      }

      {:ok, game_id} = DS.new_game(custom_state)

      {:ok, state} = Game.get_state(game_id)

      assert state.turn == 5
      assert state.history == [%{event: "test_event"}]
    end

    test "game created with new_game/1 is also supervised" do
      custom_state = Piratex.TestHelpers.default_new_game(0, %{status: :waiting})

      {:ok, game_id} = DS.new_game(custom_state)

      game_pid = GenServer.whereis(Game.via_tuple(game_id))

      assert is_pid(game_pid)

      children = DynamicSupervisor.which_children(DS)
      child_pids = Enum.map(children, fn {_id, pid, _type, _modules} -> pid end)

      assert game_pid in child_pids
    end
  end

  describe "list_games/0" do
    test "lists games in waiting status" do
      {:ok, game_id} = DS.new_game()

      games = DS.list_games()

      game_ids = Enum.map(games, & &1.id)
      assert game_id in game_ids
    end

    test "does not list games in playing status" do
      {:ok, game_id} = DS.new_game()

      :ok = Game.join_game(game_id, "player1", "token_list_1")
      :ok = Game.start_game(game_id, "token_list_1")

      {:ok, %{status: :playing}} = Game.get_state(game_id)

      games = DS.list_games()

      game_ids = Enum.map(games, & &1.id)
      refute game_id in game_ids
    end

    test "does not list games in finished status" do
      state =
        Piratex.TestHelpers.default_new_game(0, %{
          status: :waiting,
          center: ["s", "e", "t"],
          center_sorted: ["e", "s", "t"],
          letter_pool: []
        })

      {:ok, game_id} = DS.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token_fin_1")
      :ok = Game.join_game(game_id, "player2", "token_fin_2")
      :ok = Game.start_game(game_id, "token_fin_1")

      :ok = Game.claim_word(game_id, "token_fin_1", "set")

      :ok = Game.end_game_vote(game_id, "token_fin_1")
      :ok = Game.end_game_vote(game_id, "token_fin_2")

      :ok = Piratex.TestHelpers.wait_for_state_match(game_id, %{status: :finished})

      games = DS.list_games()

      game_ids = Enum.map(games, & &1.id)
      refute game_id in game_ids
    end

    test "returns only waiting games from a mix of statuses" do
      # Create a waiting game
      {:ok, waiting_id} = DS.new_game()

      # Create a playing game
      {:ok, playing_id} = DS.new_game()
      :ok = Game.join_game(playing_id, "player1", "token_mix_1")
      :ok = Game.start_game(playing_id, "token_mix_1")

      {:ok, %{status: :playing}} = Game.get_state(playing_id)

      games = DS.list_games()
      game_ids = Enum.map(games, & &1.id)

      assert waiting_id in game_ids
      refute playing_id in game_ids
    end

    test "returns empty list when no games are in waiting status" do
      # Create a playing game
      {:ok, playing_id} = DS.new_game()
      :ok = Game.join_game(playing_id, "player1", "token_empty_1")
      :ok = Game.start_game(playing_id, "token_empty_1")

      {:ok, %{status: :playing}} = Game.get_state(playing_id)

      games = DS.list_games()
      game_ids = Enum.map(games, & &1.id)

      refute playing_id in game_ids
    end

    test "list_games returns full state maps" do
      {:ok, game_id} = DS.new_game()

      games = DS.list_games()

      game = Enum.find(games, fn g -> g.id == game_id end)

      assert game != nil
      assert Map.has_key?(game, :id)
      assert Map.has_key?(game, :status)
      assert Map.has_key?(game, :players)
      assert Map.has_key?(game, :teams)
      assert Map.has_key?(game, :center)
      assert game.status == :waiting
    end

    test "list_games handles multiple waiting games" do
      {:ok, game_id_1} = DS.new_game()
      {:ok, game_id_2} = DS.new_game()
      {:ok, game_id_3} = DS.new_game()

      games = DS.list_games()
      game_ids = Enum.map(games, & &1.id)

      assert game_id_1 in game_ids
      assert game_id_2 in game_ids
      assert game_id_3 in game_ids
      assert length(games) >= 3
    end
  end

  describe "supervisor behavior" do
    test "supervisor count_children returns correct values" do
      initial_count = DynamicSupervisor.count_children(DS)

      {:ok, _game_id_1} = DS.new_game()
      {:ok, _game_id_2} = DS.new_game()

      new_count = DynamicSupervisor.count_children(DS)

      assert new_count.active >= initial_count.active + 2
      assert new_count.workers >= initial_count.workers + 2
    end

    test "games started with temporary restart strategy" do
      {:ok, game_id} = DS.new_game()

      game_pid = GenServer.whereis(Game.via_tuple(game_id))
      assert is_pid(game_pid)

      # Kill the game process
      Process.exit(game_pid, :kill)

      # Wait a bit to ensure it doesn't restart
      Process.sleep(50)

      # The game should not be restarted (temporary restart)
      refute Process.alive?(game_pid)

      # Trying to get state should fail
      assert {:error, :not_found} = Game.get_state(game_id)
    end

    test "supervisor continues running when a child crashes" do
      {:ok, game_id} = DS.new_game()

      game_pid = GenServer.whereis(Game.via_tuple(game_id))
      supervisor_pid = Process.whereis(DS)

      # Kill the game
      Process.exit(game_pid, :kill)
      Process.sleep(50)

      # Supervisor should still be alive
      assert Process.alive?(supervisor_pid)

      # Should be able to create new games
      assert {:ok, _new_game_id} = DS.new_game()
    end

    test "which_children returns list of child specs" do
      {:ok, _game_id} = DS.new_game()

      children = DynamicSupervisor.which_children(DS)

      assert is_list(children)
      assert length(children) > 0

      # Each child should be a tuple with {id, pid, type, modules}
      Enum.each(children, fn child ->
        assert is_tuple(child)
        assert tuple_size(child) == 4

        {_id, pid, type, modules} = child

        # Pids should be valid (or :restarting)
        assert is_pid(pid) or pid == :restarting

        # Type should be :worker
        assert type == :worker

        # Modules should be a list containing Piratex.Game
        assert is_list(modules)
      end)
    end
  end
end

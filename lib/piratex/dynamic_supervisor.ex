defmodule Piratex.DynamicSupervisor do
  @moduledoc """
  DynamicSupervisor for managing all game processes.
  It spawns a new game process for each new game.
  """
  use DynamicSupervisor

  @doc """
  Starts the dynamic supervisor. This is called by the supervisor in the main application.
  """
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Initializes the dynamic supervisor.
  """
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new game and returns the game ID.
  """
  @spec new_game() :: {:ok, String.t()} | {:error, any()}
  def new_game() do
    id = Piratex.Game.new_game_id()

    spec = %{
      id: id,
      start: {Piratex.Game, :start_link, [id]},
      restart: :temporary
    }

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, _pid} -> {:ok, id}
      {:error, {:already_started, _pid}} -> {:ok, id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Starts a game from a given state and returns the game ID.
  """
  @spec new_game(map()) :: {:ok, String.t()} | {:error, any()}
  def new_game(state) do
    state = %{state | id: Piratex.Game.new_game_id()}

    spec = %{
      id: state.id,
      start: {Piratex.Game, :start_link, [state.id, state]},
      restart: :temporary
    }

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, _pid} -> {:ok, state.id}
      {:error, {:already_started, _pid}} -> {:ok, state.id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all running games. Currently unused
  """
  @spec list_games() :: list(map())
  def list_games() do
    # TODO: maybe call count_children first and if there are too many children,
    # don't call which_children. IDK how else we will return a list of games in this case.
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_id_undef, pid, _type, modules}
                   when pid != :restarting and modules == [Piratex.Game] ->
      GenServer.call(pid, :get_state)
    end)
    |> Enum.filter(fn state -> state.status == :waiting end)
  end
end

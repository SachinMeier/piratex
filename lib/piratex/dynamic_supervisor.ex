defmodule Piratex.DynamicSupervisor do
  @moduledoc """
  DynamicSupervisor for managing all game processes.
  It spawns a new game process for each new game.
  """
  use DynamicSupervisor

  @default_page_size 10

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
    registered_games()
    |> Enum.reduce([], fn {game_id, pid}, games ->
      case safe_get_state(pid) do
        %{status: :waiting} = state -> [Map.put(state, :id, game_id) | games]
        _ -> games
      end
    end)
    |> Enum.reverse()
  end

  @spec list_games_page(keyword()) :: %{
          games: list(map()),
          has_next: boolean(),
          page: pos_integer(),
          page_size: pos_integer()
        }
  def list_games_page(opts \\ []) do
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = max(Keyword.get(opts, :page_size, @default_page_size), 1)
    waiting_offset = (page - 1) * page_size

    {games, overflow?} =
      registered_games()
      |> Enum.reduce_while({[], waiting_offset, false}, fn {game_id, pid},
                                                           {games, remaining_offset, overflow?} ->
        case safe_get_state(pid) do
          %{status: :waiting} = _state when remaining_offset > 0 ->
            {:cont, {games, remaining_offset - 1, overflow?}}

          %{status: :waiting} = state when length(games) < page_size ->
            {:cont, {[Map.put(state, :id, game_id) | games], remaining_offset, overflow?}}

          %{status: :waiting} ->
            {:halt, {Enum.reverse(games), remaining_offset, true}}

          _ ->
            {:cont, {games, remaining_offset, overflow?}}
        end
      end)
      |> case do
        {games, _remaining_offset, true} ->
          {games, true}

        {games, _remaining_offset, false} ->
          {Enum.reverse(games), false}
      end

    %{
      games: games,
      has_next: overflow? or length(games) > page_size,
      page: page,
      page_size: page_size
    }
  end

  defp registered_games() do
    Registry.select(Piratex.Game.Registry, [
      {
        {:"$1", :"$2", :_},
        [{:is_pid, :"$2"}],
        [{{:"$1", :"$2"}}]
      }
    ])
    |> Enum.sort_by(fn {game_id, _pid} -> game_id end)
  end

  defp safe_get_state(pid) do
    GenServer.call(pid, :get_state)
  catch
    :exit, _ -> nil
  end
end

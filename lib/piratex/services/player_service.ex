defmodule Piratex.PlayerService do
  @moduledoc """
  Handles the logic for player management.
  """

  alias Piratex.Config
  alias Piratex.Player

  @doc """
  Generates a new player token.
  """
  @spec new_player_token() :: String.t()
  def new_player_token() do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64(padding: false)
  end

  @doc """
  Adds a player to the game.
  """
  @spec add_player(map(), Player.t()) :: {:ok, map()} | {:error, atom()}
  def add_player(%{players: players} = state, player) do
    if length(players) >= Config.max_players() do
      {:error, :game_full}
    else
      Map.put(state, :players, players ++ [player])
    end
  end

  @doc """
  Removes a player from the game. If the player is on a team, they are removed from the team.
  If the player is not on a team, they are removed from the waiting players list.
  """
  @spec remove_player(map(), String.t()) :: map()
  def remove_player(%{players_teams: players_teams, players: players} = state, player_token) do
    new_players = Enum.filter(players, fn %{token: token} -> token != player_token end)
    new_players_teams = Map.delete(players_teams, player_token)

    state
    |> Map.put(:players_teams, new_players_teams)
    |> Map.put(:players, new_players)
  end

  @doc """
  Unquits a player by name.
  """
  @spec unquit_player(map(), String.t()) :: map()
  def unquit_player(%{players: players} = state, player_name) do
    new_players = Enum.map(players, fn %{name: name} = player ->
      if name == player_name do
        Player.unquit(player)
      else
        player
      end
    end)

    Map.put(state, :players, new_players)
  end

  @doc """
  Finds the player with the given token.
  """
  @spec find_player(map(), String.t()) :: Player.t() | nil
  def find_player(%{players: players}, player_token) do
    Enum.find(players, fn %{token: token} = _player -> token == player_token end)
  end

  @doc """
  Finds the player with the given name.
  """
  @spec find_player_by_name(map(), String.t()) :: Player.t() | nil
  def find_player_by_name(%{players: players}, player_name) do
    Enum.find(players, fn %{name: name} = _player -> name == player_name end)
  end

  @doc """
  Finds the player with the given token.
  """
  @spec find_unassigned_player(map(), String.t()) :: {String.t(), any()} | nil
  def find_unassigned_player(%{players: players}, player_token) do
    Enum.find(players, fn %{token: token} = _player -> token == player_token end)
  end

  def find_unassigned_player_with_index(%{players: players}, player_token) do
    idx = Enum.find_index(players, fn %{token: token} = _player -> token == player_token end)
    if idx != nil do
      {idx, Enum.at(players, idx)}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Checks if the player name and token are unique.
  """
  @spec player_is_unique?(map(), String.t(), String.t()) :: boolean()
  def player_is_unique?(%{players: players}, player_name, player_token) do
    Enum.all?(players, fn %{token: token, name: name} = _player ->
      token != player_token && name != player_name
    end)
  end

  @doc """
  Counts the number of players that have not quit.
  """
  @spec count_unquit_players(map()) :: integer()
  def count_unquit_players(%{players: players}) do
    Enum.count(players, fn %{status: status} -> status != :quit end)
  end
end

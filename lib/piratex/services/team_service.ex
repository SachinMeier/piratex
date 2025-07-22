defmodule Piratex.TeamService do
  @moduledoc """
  Logic related to creating, joining, leaving teams.
  """

  alias Piratex.Team
  alias Piratex.Player
  alias Piratex.Game

  import Piratex.Helpers, only: [ok: 1]

  def create_team(state, player_token, team_name) do
    team = Team.new(team_name)

    state
    |> Map.put(:teams, state.teams ++ [team])
    |> add_player_to_team(player_token, team.id)
  end

  def join_team(state, team_id, player_token) do
    with {_, %Team{}} <- {:find_team, Enum.find(state.teams, fn team -> team.id == team_id end)} do
      state
      |> add_player_to_team(player_token, team_id)
      |> ok()
    else
      {:find_team, _} -> {:error, :team_not_found}
    end
  end

  def delete_team(state, team_id) do
    teams = Enum.filter(state.teams, fn %{id: id} -> id != team_id end)
    Map.put(state, :teams, teams)
  end

  # game's total player count
  def player_count(%{teams: teams} = _state) do
    length(Enum.flat_map(teams, & &1.players))
  end

  def team_count(%{teams: teams} = _state) do
    length(teams)
  end


  # used for setting players_teams, which is a map of player tokens to team ids
  def add_player_to_team(state, player_token, team_id) do
    players_teams = Map.merge(state.players_teams,
    %{player_token => team_id})

    state
    |> Map.put(:players_teams, players_teams)
    |> remove_empty_teams()
  end

  def remove_empty_teams(state) do
    populated_team_ids = Map.values(state.players_teams)
    teams =
      Enum.filter(state.teams, fn team ->
        Enum.member?(populated_team_ids, team.id)
      end)
    Map.put(state, :teams, teams)
  end

  # used to permanently assign players to teams when the game starts
  def assign_players_to_teams(%{players_teams: players_teams} = state) do
    players =
      Enum.map(state.players, fn player ->
        team_id = Map.get(players_teams, player.token)
        Player.set_team(player, team_id)
      end)

    state
    |> Map.put(:players, players)
  end

  def find_player_team(state, player_token) do
    %Player{team_id: team_id} =
      Enum.find(state.players, fn player ->
        player.token == player_token
      end)

    Enum.find(state.teams, fn team ->
      team.id == team_id
    end)
  end

  def find_team_index(%{teams: teams} = _state, team_id) do
    Enum.find_index(teams, fn team -> team.id == team_id end)
  end

  def find_team_with_index(%{teams: teams} = state, team_id) do
    idx = find_team_index(state, team_id)
    if idx != nil do
      {idx, Enum.at(teams, idx)}
    else
      {:error, :not_found}
    end
  end

  @doc """
  adds a word to a team's words. This may be a noop in the case of undoing a
  word steal after a successful challenge where the word was built exclusively from the middle.
  """
  @spec add_word_to_team(Game.t(), Team.t() | nil, String.t() | nil) :: map()
  def add_word_to_team(state, nil, nil), do: state

  def add_word_to_team(%{teams: teams} = state, team_id, word) do
    new_teams =
      Enum.map(teams, fn team ->
        if team.id == team_id do
          Team.add_word(team, word)
        else
          team
        end
      end)

    state
    |> Map.put(:teams, new_teams)
  end

  @doc """
  removes a word from a team's words.
  new words don't require removing a word from anyone if they only use the center.
  This case is handled by the first clause.
  """
  @spec remove_word_from_team(Game.t(), Team.t() | nil, String.t() | nil) :: map()
  def remove_word_from_team(state, nil, nil), do: state

  def remove_word_from_team(%{teams: teams} = state, victim_team, word) do
    new_teams =
      Enum.map(teams, fn team ->
        if victim_team.id == team.id do
          Team.remove_word(team, word)
        else
          team
        end
      end)

    state
    |> Map.put(:teams, new_teams)
  end

  def team_name_unique?(state, team_name) do
    Enum.all?(state.teams, fn team -> team.name != team_name end)
  end
end

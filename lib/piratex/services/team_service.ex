defmodule Piratex.TeamService do
  @moduledoc """
  Logic related to creating, joining, leaving teams.
  """

  alias Piratex.Team
  alias Piratex.Player
  alias Piratex.PlayerService
  alias Piratex.Game

  import Piratex.Helpers, only: [ok: 1, ok: 0]

  def create_team(state, player_token, team_name) do
    team = Team.new(team_name)

    state
    |> Map.put(:teams, state.teams ++ [team])
    |> add_player_to_team(player_token, team.id)
  end

  def join_team(state, team_id, player_token) do
    with {_, team = %Team{}} <- {:find_team, Enum.find(state.teams, fn team -> team.id == team_id end)} do
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

  # team's player count
  def player_count(%{players: players} = _state) do
    length(players)
  end

  # used for setting players_teams, which is a map of player tokens to team ids
  def add_player_to_team(state, player_token, team_id) do
    players_teams = Map.put(state.players_teams, player_token, team_id)

    state
    |> Map.put(:players_teams, players_teams)
    |> remove_empty_teams()
  end

  def remove_empty_teams(state) do
    populated_team_ids = Map.values(state.players_teams)
    teams = Enum.filter(state.teams, fn team ->
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

  def find_team_with_index(%{teams: teams} = state, team_id) do
    idx = Enum.find_index(teams, fn team -> team.id == team_id end)
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
    # TODO: update to use PlayerService.find_player_with_index
    case find_team_with_index(state, team_id) do
      # this case handles the case where a word was created from the center
      # and is then challenged and invalidated.
      {:error, :not_found} ->
        state

      {team_idx, team} ->
        new_teams = List.replace_at(state.teams, team_idx, Team.add_word(team, word))

        state
        |> Map.put(:team, new_teams)
    end
  end

  # @doc """
  # removes a word from a team's words.
  # new words don't require removing a word from anyone if they only use the center.
  # This case is handled by the first clause.
  # """
  # @spec remove_word_from_team(Game.t(), Team.t() | nil, String.t() | nil) :: map()
  # def remove_word_from_team(state, nil, nil), do: state

  # def remove_word_from_team(%{teams: teams} = state, %{token: player_token} = _player, word) do
  #   team =
  #     find_player_team(state, player_token)
  #     |> Team.remove_word(word)

  #   new_teams = List.replace_at(teams, team_idx, team)

  #   state
  #   |> Map.put(:teams, new_teams)
  # end

  def team_name_unique?(state, team_name) do
    Enum.all?(state.teams, fn team -> team.name != team_name end)
  end


end

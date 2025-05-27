defmodule Piratex.TeamService do
  @moduledoc """
  Logic related to creating, joining, leaving teams.
  """

  def create_team(state, team_name, player_token) do
    team = Team.new(team_name)

    state
    |> Map.put(:teams, state.teams ++ [team])
    |> assign_player_to_team(team.id, player_token)
    |> ok()
  end

  def delete_team(state, team_id) do
    teams = Enum.filter(state.teams, fn %{id: id} -> id != team_id end)
    Map.put(state, :teams, teams)
  end

  defp assign_player_to_team(state, team_id, player_token) do
    # assign the creating player to this team
    case PlayerService.find_player_with_index(state, player_token) do
      {:error, error} -> state

      {player_idx, player} ->
        old_team_id = player.team_id
        new_player = PlayerService.assign_team(player, team.id)
        state
        # first, check if the player was previously on another team
        # if so, if the old team is empty, delete that team
        |> delete_empty_old_team(old_team_id, team_id)
        # update the player
        |> Map.put(:players,
          List.replace_at(state.players, player_idx, new_player)
        )
    end
  end

  defp delete_empty_old_team(state, old_team_id, new_team_id) do
    # if player was on an old team and is moving to a new team,
    # check the team is not empty. If it is, delete it.
    if team_id != nil and old_team_id != new_team_id do
      if team_has_members?(state, team_id) do
        state
      else
        delete_team(state, team_id)
      end
    end
  end

  defp team_has_members?(%{players: players} = state, team_id) do
    Enum.reduce_while(players, false, fn %{team_id: player_team_id} = _player, _acc ->
      if player_team_id == team_id do
        {:halt, true}
      else
        {:cont, false}
      end
    end)
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
    idx = Enum.find_index(teams, fn team -> team.id == team_id)
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
  @spec add_word_to_team(Game.t(), Player.t() | nil, String.t() | nil) :: map()
  def add_word_to_team(state, nil, nil), do: state

  def add_word_to_team(%{players: players} = state, team_id, word) do
    # TODO: update to use PlayerService.find_player_with_index
    case find_team_with_index(state, team_id) do
      # this case handles the case where a word was created from the center
      # and is then challenged and invalidated.
      {:error, :not_found} ->
        state

      {team_idx, team} ->
        new_teams = List.replace_at(teams, team_idx, Team.add_word(team, word))

        state
        |> Map.put(:team, new_teams)
    end
  end

  @doc """
  removes a word from a team's words.
  new words don't require removing a word from anyone if they only use the center.
  This case is handled by the first clause.
  """
  @spec remove_word_from_team(Game.t(), Team.t() | nil, String.t() | nil) :: map()
  def remove_word_from_team(state, nil, nil), do: state

  def remove_word_from_team(%{teams: teams} = state, %{token: player_token} = _player, word) do
    team =
      find_player_team(state, player_token)
      |> Team.remove_word(word)

    new_teams = List.replace_at(teams, team_idx, team)

    state
    |> Map.put(:teams, new_teams)
  end


end

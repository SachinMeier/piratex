defmodule Piratex.Helpers do
  @moduledoc """
  Helper functions for the game.
  """

  alias Piratex.Game
  alias Piratex.Player
  alias Piratex.PlayerService
  alias Piratex.Config

  @spec ok(term()) :: {:ok, term()} | :ok
  def ok(v), do: {:ok, v}
  def ok(), do: :ok

  def noreply(state) do
    {:noreply, state, game_timeout(state)}
  end

  def reply(state, resp, timeout \\ nil) do
    timeout = timeout || game_timeout(state)
    {:reply, resp, state, timeout}
  end

  @spec new_id() :: non_neg_integer()
  def new_id(bytes \\ 2) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> :binary.decode_unsigned()
  end

  ##### Word Management Functions #####

  @doc """
  Checks if a word is in play.
  assumes all words are lowercase
  """
  @spec word_in_play?(map(), String.t()) :: boolean()
  def word_in_play?(%{teams: teams} = _state, word) do
    Enum.any?(teams, fn %{words: words} = _team -> word in words end)
  end

  @doc """
  Checks if there are no more letters in the letter pool.
  """
  @spec no_more_letters?(Game.t() | map()) :: boolean()
  def no_more_letters?(%{letter_pool: []}), do: true
  def no_more_letters?(%{letter_pool_count: 0}), do: true
  def no_more_letters?(_), do: false

  @doc """
  This function is used by multiple functions to add letters to the center
  in the case of flipping a new letter or returning letters after a successful challenge
  """
  def add_letters_to_center(state, letters) do
    Enum.reduce(letters, state, fn letter, acc ->
      acc
      |> Map.update!(:center, &[letter | &1])
      |> Map.update!(:center_sorted, &insert_sorted_letter(&1, letter))
    end)
  end

  defp insert_sorted_letter([], letter), do: [letter]

  defp insert_sorted_letter([current | rest] = letters, letter) do
    if letter <= current do
      [letter | letters]
    else
      [current | insert_sorted_letter(rest, letter)]
    end
  end

  @doc """
  Finds the index of the player with the given token.
  """
  @spec find_player_index(map(), String.t()) :: integer()
  def find_player_index(%{players: players}, player_token) do
    Enum.find_index(players, fn %{token: token} = _player -> token == player_token end)
  end

  def lookup_team(state, player_token) do
    team_id = Map.get(state.players_teams, player_token)
    Enum.find(state.teams, fn %{id: id} = _team -> id == team_id end)
  end

  ##### PubSub #####

  @doc """
  Returns the state for a player.
  """
  @spec state_for_player(Game.t()) :: map()
  def state_for_player(state) do
    Map.take(state, [
      # id will be used by clients to make calls to the correct game process
      :id,
      :status,
      # whose turn it is
      :turn,
      # monotonically increasing turn counter, used by client to reset countdown timer
      :total_turn,
      :teams,
      :initial_letter_count,
      # only give the chronologically sorted center to the player
      :center,
      :history,
      :challenges,
      # clients use this to show/hide the challenge button on past
      :past_challenges,
      :end_game_votes,
      :game_stats
    ])
    |> Map.put(:players_teams, sanitize_players_teams(state))
    # we strip the tokens from the state to avoid leaking tokens
    |> Map.put(:players, drop_internal_states(state.players))
    |> Map.put(:active_player_count, Enum.count(state.players, &Player.is_playing?/1))
    # send count instead of full list — clients only need to know how many remain
    |> Map.put(:letter_pool_count, length(state.letter_pool))
  end

  # map the player_token to player_name to avoid exposing tokens
  def sanitize_players_teams(%{players_teams: players_teams} = state) do
    Map.new(players_teams, fn {player_token, team_id} ->
      {PlayerService.find_player(state, player_token).name, team_id}
    end)
  end

  @doc """
  Removes the player tokens and status from the state. We only send the player
  name, words, and score to the client not the tokens of all players (for obvious reasons)
  """
  @spec drop_internal_states(list(Player.t())) :: list(map())
  def drop_internal_states(players) do
    Enum.map(players, &Player.drop_internal_state/1)
  end

  ##### Game Timeout #####

  # Games with no players timeout after 1 minute of inactivity
  # Games with players timeout after 1 hour of inactivity
  @spec game_timeout(Game.t()) :: non_neg_integer()
  def game_timeout(%{players: []}), do: Config.new_game_timeout_ms()
  def game_timeout(_), do: Config.game_timeout_ms()
end

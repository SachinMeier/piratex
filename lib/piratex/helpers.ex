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
  @spec no_more_letters?(Game.t()) :: boolean()
  def no_more_letters?(%{letter_pool: []}), do: true
  def no_more_letters?(_), do: false

  @doc """
  This function is used by multiple functions to add letters to the center
  in the case of flipping a new letter or returning letters after a successful challenge
  """
  def add_letters_to_center(state, letters) do
    # TODO: not the most efficient, but its only done on lists with >1 letter in
    # the case of a successful challenge
    Enum.reduce(letters, state, fn letter, acc ->
      {new_center, new_center_sorted} = add_new_letter_to_center(acc.center, letter)

      acc
      |> Map.put(:center, new_center)
      |> Map.put(:center_sorted, new_center_sorted)
    end)
  end

  # Adds a new letter to the center and returns the new center sorted chronologically and alphabetically.
  @spec add_new_letter_to_center(list(String.t()), String.t()) ::
          {list(String.t()), list(String.t())}
  defp add_new_letter_to_center(center, new_letter) do
    # center is sorted chronologically (desc) for player clarity
    center = [new_letter | center]

    # center_sorted is sorted alphabetically (asc) for efficient word building
    # TODO: make this more efficient since rest of list is already sorted
    {center, Enum.sort(center)}
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
      :teams,
      # clients check this to disable the Flip button when game is over.
      :letter_pool,
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

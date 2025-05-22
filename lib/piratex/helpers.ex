defmodule Piratex.Helpers do
  @moduledoc """
  Helper functions for the game.
  """

  alias Piratex.Game
  alias Piratex.Player

  ##### Word Management Functions #####

  @doc """
  Checks if a word is in play.
  assumes all words are lowercase
  """
  @spec word_in_play?(map(), String.t()) :: boolean()
  def word_in_play?(%{players: players} = _state, word) do
    Enum.any?(players, fn %{words: words} = _player -> word in words end)
  end

  @doc """
  removes a word from a player's words.
  new words don't require removing a word from anyone if they only use the center.
  This case is handled by the first clause.
  """
  @spec remove_word_from_player(Game.t(), Player.t() | nil, String.t() | nil) :: map()
  def remove_word_from_player(state, nil, nil), do: state

  def remove_word_from_player(%{players: players} = state, %{token: player_token} = _player, word) do
    player_idx = find_player_index(state, player_token)

    player =
      players
      |> Enum.at(player_idx)
      |> Player.remove_word(word)

    new_players = List.replace_at(players, player_idx, player)

    state
    |> Map.put(:players, new_players)
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
end

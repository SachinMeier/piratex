defmodule Piratex.Helpers do
  @moduledoc """
  Helper functions for the game.
  """

  alias Piratex.Game
  # alias Piratex.Player

  @spec ok(term()) :: {:ok, term()} | :ok
  def ok(v), do: {:ok, v}
  def ok(), do: :ok

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
    Enum.any?(teams, fn %{words: words} = _player -> word in words end)
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

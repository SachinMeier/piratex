defmodule Piratex.Helpers do
  @moduledoc """
  Helper functions for the game.
  """

  alias Piratex.Game
  alias Piratex.Player

  @letter_pool [
    # 13 As
    "a",
    "a",
    "a",
    "a",
    "a",
    "a",
    "a",
    "a",
    "a",
    "a",
    "a",
    "a",
    "a",
    # 3 Bs
    "b",
    "b",
    "b",
    # 3 Cs
    "c",
    "c",
    "c",
    # 6 Ds
    "d",
    "d",
    "d",
    "d",
    "d",
    "d",
    # 18 Es
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    "e",
    # 3 Fs
    "f",
    "f",
    "f",
    # 4 Gs
    "g",
    "g",
    "g",
    "g",
    # 3 Hs
    "h",
    "h",
    "h",
    # 12 Is
    "i",
    "i",
    "i",
    "i",
    "i",
    "i",
    "i",
    "i",
    "i",
    "i",
    "i",
    "i",
    # 2 Js
    "j",
    "j",
    # 2 Ks
    "k",
    "k",
    # 5 Ls
    "l",
    "l",
    "l",
    "l",
    "l",
    # 3 Ms
    "m",
    "m",
    "m",
    # 8 Ns
    "n",
    "n",
    "n",
    "n",
    "n",
    "n",
    "n",
    "n",
    # 11 Os
    "o",
    "o",
    "o",
    "o",
    "o",
    "o",
    "o",
    "o",
    "o",
    "o",
    "o",
    # 3 Ps
    "p",
    "p",
    "p",
    # 2 Qs
    "q",
    "q",
    # 9 Rs
    "r",
    "r",
    "r",
    "r",
    "r",
    "r",
    "r",
    "r",
    "r",
    # 6 Ss
    "s",
    "s",
    "s",
    "s",
    "s",
    "s",
    # 9 Ts
    "t",
    "t",
    "t",
    "t",
    "t",
    "t",
    "t",
    "t",
    "t",
    # 6 Us
    "u",
    "u",
    "u",
    "u",
    "u",
    "u",
    # 3 Vs
    "v",
    "v",
    "v",
    # 3 Ws
    "w",
    "w",
    "w",
    # 2 Xs
    "x",
    "x",
    # 3 Ys
    "y",
    "y",
    "y",
    # 2 Zs
    "z",
    "z"
  ]
  @doc """
  Uses the bananagrams letter distribution. 144 letters in total.
  A: 13
  B: 3
  C: 3
  D: 6
  E: 18
  F: 3
  G: 4
  H: 3
  I: 12
  J: 2
  K: 2
  L: 5
  M: 3
  N: 8
  O: 11
  P: 3
  Q: 2
  R: 9
  S: 6
  T: 9
  U: 6
  V: 3
  W: 3
  X: 2
  Y: 3
  Z: 2
  """
  @spec letter_pool() :: list(String.t())
  def letter_pool(), do: @letter_pool

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

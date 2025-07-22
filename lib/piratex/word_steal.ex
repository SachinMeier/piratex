defmodule Piratex.WordSteal do
  @moduledoc """
  A word steal is a record of a word being stolen from one player to another.

  Victim word & idx can both be nil if the word was stolen from the center.
  """

  @type t :: %__MODULE__{
          victim_team_idx: non_neg_integer() | nil,
          victim_word: String.t() | nil,
          thief_team_idx: non_neg_integer(),
          thief_player_idx: non_neg_integer(),
          thief_word: String.t()
        }

  defstruct [
    :victim_team_idx,
    :victim_word,
    :thief_team_idx,
    :thief_player_idx,
    :thief_word
  ]

  @doc """
  creates a new WordSteal
  """
  @spec new(%{
          victim_team_idx: non_neg_integer(),
          victim_word: String.t(),
          thief_team_idx: non_neg_integer(),
          thief_player_idx: non_neg_integer(),
          thief_word: String.t()
        }) :: t()
  def new(%{
        victim_team_idx: victim_team_idx,
        victim_word: victim_word,
        thief_team_idx: thief_team_idx,
        thief_player_idx: thief_player_idx,
        thief_word: thief_word
      }) do
    %__MODULE__{
      victim_team_idx: victim_team_idx,
      victim_word: victim_word,
      thief_team_idx: thief_team_idx,
      thief_player_idx: thief_player_idx,
      thief_word: thief_word
    }
  end

  @doc """
  word steals are considered equivalent if
  the old and new word match, regardless of
  which players are thief and victim
  """
  @spec match?(t(), t()) :: boolean()
  def match?(word_steal1, word_steal2) do
    # this allows for victim_word to be nil
    word_steal1.thief_word == word_steal2.thief_word &&
      word_steal1.victim_word == word_steal2.victim_word
  end
end

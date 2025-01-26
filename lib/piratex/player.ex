defmodule Piratex.Player do
  @moduledoc """
  Represents a Player with a token, a name, and a list of words.
  Score is nil and uncalculated until the game is over.
  """

  @type status :: :playing | :quit

  @type t :: %__MODULE__{
    name: String.t(),
    status: status(),
    token: String.t(),
    words: list(String.t()),
    score: non_neg_integer() | nil,
  }

  defstruct [
    :name,
    :status,
    :token,
    :words,
    :score,
  ]

  @doc """
  creates a new player from a name and token
  """
  @spec new(String.t(), String.t(), list(String.t())) :: %__MODULE__{}
  def new(name, token, words \\ []) do
    %__MODULE__{
      name: name,
      status: :playing,
      token: token,
      words: words,
      score: 0,
    }
  end

  @doc """
  marks a player as quit. This allows Game to skip
  this player when incrementing the turn
  """
  @spec quit(t()) :: t()
  def quit(player) do
    Map.put(player, :status, :quit)
  end

  @doc """
  adds a word to the player's list of words
  """
  @spec add_word(t(), String.t()) :: t()
  def add_word(player, word) do
    Map.put(player, :words, [word | player.words])
  end

  @doc """
  removes a word from the player's list of words
  """
  @spec remove_word(t(), String.t()) :: t()
  def remove_word(player, word) do
    Map.put(player, :words, List.delete(player.words, word))
  end

  @doc """
  calculates score for the player. Score is:
  count(letters) - count(words)

  This favors longer words over many short words.
  """
  @spec calculate_score(t()) :: t()
  def calculate_score(%{words: words} =player) do
    letter_ct = Enum.reduce(words, 0, fn word, acc -> acc + String.length(word) end)
    score = letter_ct - length(words)

    Map.put(player, :score, score)
  end

  @doc """
  drop_internal_state returns the Player's state without the token or status.
  status is not needed, but token must not be included when broadcasting state
  to all players.
  """
  @spec drop_internal_state(t()) :: %{
    name: String.t(),
    words: list(String.t()),
    score: non_neg_integer(),
  }
  def drop_internal_state(player = %__MODULE__{}) do
    Map.take(player, [:name, :words, :score, :status])
  end
end

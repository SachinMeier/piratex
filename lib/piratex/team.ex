defmodule Piratex.Team do
  @moduledoc """
  Represents a Team, which has a name and a list of words.
  Players can join a team. A Player's team is indicated by
  their team_idx field
  """

  alias Piratex.Player

  @type t :: %__MODULE__{
    id: non_neg_integer(),
    name: String.t(),
    players: list(Player.t()),
    words: list(String.t()),
    score: non_neg_integer()
  }

  defstruct [
    :id,
    :name,
    :players,
    :words,
    :score
  ]

  @doc """
  Creates a new team with the given name.
  Optionally accepts initial words.
  """
  @spec new(String.t(), list(String.t())) :: t()
  def new(name, words \\ []) do
    %__MODULE__{
      id: Piratex.Helpers.new_id(),
      name: name,
      players: [],
      words: words,
      score: 0
    }
  end

  def default_name(player_name) do
    "Team-" <> player_name
  end

  @doc """
  adds a word to the team's list of words
  """
  @spec add_word(t(), String.t()) :: t()
  def add_word(team, word) do
    Map.put(team, :words, [word | team.words])
  end

  @doc """
  removes a word from the team's list of words
  """
  @spec remove_word(t(), String.t()) :: t()
  def remove_word(team, word) do
    Map.put(team, :words, List.delete(team.words, word))
  end

  @doc """
  adds a player to the team
  """
  @spec add_player(t(), Player.t()) :: t()
  def add_player(team, player) do
    Map.put(team, :players, team.players ++ [player])
  end

  @doc """
  calculates score for the Team. Score is:
  count(letters) - count(words)

  This favors longer words over many short words.
  """
  @spec calculate_score(t()) :: t()
  def calculate_score(%{words: words} = team) do
    letter_ct = Enum.reduce(words, 0, fn word, acc -> acc + String.length(word) end)
    score = letter_ct - length(words)

    Map.put(team, :score, score)
  end

end

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
          team_id: non_neg_integer()
        }

  defstruct [
    :name,
    :status,
    :token,
    :team_id
  ]

  @doc """
  creates a new player from a name and token
  """
  @spec new(String.t(), String.t(), non_neg_integer()) :: t()
  def new(name, token, team_id \\ nil) do
    %__MODULE__{
      name: name,
      status: :playing,
      token: token,
      team_id: team_id
    }
  end

  @doc """
  checks if a player is playing
  """
  @spec is_playing?(t()) :: boolean()
  def is_playing?(player) do
    player.status == :playing
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
  assigns the players to a team
  """
  @spec set_team(t(), non_neg_integer()) :: t()
  def set_team(player, team_id) do
    Map.put(player, :team_id, team_id)
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
          status: status()
        }
  def drop_internal_state(player = %__MODULE__{}) do
    Map.take(player, [:name, :status, :team_id])
  end
end

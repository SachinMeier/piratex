defmodule Piratex.ScoreService do
  @moduledoc """
  Handles the logic for scoring the game.
  """

  alias Piratex.Player

  @doc """
  Calculates the scores for each player.
  Score is calculated as the number of letters in all words minus the number of words.
  Put another way, drop one letter from each word and count the remaining letters.
  """
  @spec calculate_scores(map()) :: map()
  def calculate_scores(%{players: players} = state) do
    players_with_scores = Enum.map(players, &Player.calculate_score/1)
    Map.put(state, :players, players_with_scores)
  end

end

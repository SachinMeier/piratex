defmodule Piratex.ScoreService do
  @moduledoc """
  Handles the logic for scoring the game.
  """

  alias Piratex.Team

  @doc """
  Calculates the scores for each Team.
  Score is calculated as the number of letters in all words minus the number of words.
  Put another way, drop one letter from each word and count the remaining letters.
  """
  def calculate_team_scores(%{teams: teams} = state) do
    teams_with_scores = Enum.map(teams, &Team.calculate_score/1)
    Map.put(state, :teams, teams_with_scores)
  end

end

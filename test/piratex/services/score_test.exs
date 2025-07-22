defmodule Piratex.ScoreServiceTest do
  use ExUnit.Case

  alias Piratex.Team
  alias Piratex.ScoreService

  test "calculate_scores" do
    scores = [
      {0, []},
      {2, ["bot"]},
      {3, ["boat"]},
      {4, ["boast"]},
      {5, ["aborts"]},
      {6, ["boaters"]},
      {7, ["boasters"]},
      {8, ["saboteurs"]},
      {9, ["zoo", "ooze", "ozone"]},
      {10, ["the", "haters", "hate"]},
      {12, ["ooze", "ozone", "snooze"]},
      {15, ["doozies", "snooze", "ozone"]},
      {51, ["potteries", "advancer", "analogue", "plowing", "renown",
            "juicy", "golfs", "need", "joey", "axe", "him"]},
      {62, ["flittering", "tolerates", "dousers", "thanked", "biome",
            "brims", "quark", "vapid", "quiz", "cave", "iota", "afar",
            "doth", "web"
          ]}
    ]

    Enum.each(scores, fn {score, words} ->
      team = Team.new("name", words)
      state = ScoreService.calculate_team_scores(%{teams: [team]})

      assert %{teams: [%{score: ^score}]} = state
    end)

  end
end

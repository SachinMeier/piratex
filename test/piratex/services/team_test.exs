defmodule Piratex.TeamTest do
  use ExUnit.Case

  import Piratex.TestHelpers

  alias Piratex.Team
  alias Piratex.TeamService

  @scores [
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

  # Team Tests

  describe "Team.add_word/2" do
    test "add word to wordless team" do
      t = Team.new("me")
      t = Team.add_word(t, "test")

      assert t.words == ["test"]
    end

    test "add word to worded team, preserves chronological order" do
      t = Team.new("me", ["bet"])
      t = Team.add_word(t, "ate")

      assert t.words == ["ate", "bet"]

      t = Team.add_word(t, "tea")

      assert t.words == ["tea", "ate", "bet"]
    end
  end

  describe "calculate_score/1" do
    test "examples" do
      Enum.each(@scores, fn {score, words} ->
        team = Team.new("name", words) |> Team.calculate_score()
        assert team.score == score
      end)
    end
  end

  # Service Tests

  describe "Team.remove_word/2" do
    test "remove non-existent word fails safely" do
      t = Team.new("me")
      t = Team.remove_word(t, "these")

      assert t.words == []
    end

    test "remove word from team" do
      t = Team.new("me", ["bet"])
      t = Team.remove_word(t, "bet")

      assert t.words == []
    end

    test "remove multiple words one by one" do
      t = Team.new("me", ["ace", "ate", "bet"])
      t = Team.remove_word(t, "ate")

      assert t.words == ["ace", "bet"]

      t = Team.remove_word(t, "ace")

      assert t.words == ["bet"]

      t = Team.remove_word(t, "bet")

      assert t.words == []
    end
  end

  describe "TeamService.create_team/3" do
    test "auto-create team on join" do

    end
  end

  describe "TeamService.join_team/3" do

  end

  describe "TeamService.delete_team/2" do

  end

  describe "TeamService.add_word_to_team/3" do

  end

  describe "TeamService.remove_word_from_team/3" do
    setup :new_game_state

    test "no victim", %{state: state} do
      new_state = TeamService.remove_word_from_team(state, nil, nil)

      assert new_state == state
    end

    test "remove word", %{state: state, t1: t1} do
      state = TeamService.remove_word_from_team(state, t1, "bind")

      assert team_has_word(state, t1.id, "band")
      assert team_has_word(state, t1.id, "bond")
      refute team_has_word(state, t1.id, "bind")
    end
  end

  describe "TeamService.team_name_unique?/2" do

  end
end

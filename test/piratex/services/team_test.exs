defmodule Piratex.TeamTest do
  use ExUnit.Case

  alias Piratex.Team

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

  end

  describe "TeamService.join_team/3" do

  end

  describe "TeamService.delete_team/2" do

  end

  describe "TeamService.add_word_to_team/3" do

  end

  describe "TeamService.remove_word_from_team/3" do

  end

  describe "TeamService.team_name_unique?/2" do

  end
end

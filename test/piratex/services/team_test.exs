defmodule Piratex.TeamTest do
  use ExUnit.Case

  import Piratex.TestHelpers

  alias Piratex.Team
  alias Piratex.Player
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

  describe "Team.new/2" do
    test "creates a team with name and default empty words" do
      team = Team.new("pirates")

      assert team.name == "pirates"
      assert team.words == []
      assert team.score == 0
      assert team.players == []
      assert is_integer(team.id)
    end

    test "creates a team with name and initial words" do
      team = Team.new("pirates", ["ahoy", "matey"])

      assert team.name == "pirates"
      assert team.words == ["ahoy", "matey"]
      assert team.score == 0
      assert team.players == []
      assert is_integer(team.id)
    end

    test "each team gets a unique id" do
      t1 = Team.new("team1")
      t2 = Team.new("team2")

      assert t1.id != t2.id
    end
  end

  describe "Team.default_name/1" do
    test "returns Team-{name}" do
      assert Team.default_name("Alice") == "Team-Alice"
    end

    test "works with any string" do
      assert Team.default_name("player_1") == "Team-player_1"
    end
  end

  describe "Team.add_player/2" do
    test "adds a player to an empty team" do
      team = Team.new("crew")
      player = Player.new("Jack", "token_jack")

      team = Team.add_player(team, player)

      assert length(team.players) == 1
      assert hd(team.players).name == "Jack"
    end

    test "adds a player to a team that already has players" do
      team = Team.new("crew")
      p1 = Player.new("Jack", "token_jack")
      p2 = Player.new("Jill", "token_jill")

      team = team |> Team.add_player(p1) |> Team.add_player(p2)

      assert length(team.players) == 2
      assert Enum.at(team.players, 0).name == "Jack"
      assert Enum.at(team.players, 1).name == "Jill"
    end
  end

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

  describe "Team.calculate_score/1" do
    test "examples" do
      Enum.each(@scores, fn {score, words} ->
        team = Team.new("name", words) |> Team.calculate_score()
        assert team.score == score
      end)
    end
  end

  # Service Tests

  describe "TeamService.create_team/3" do
    setup :new_game_state

    test "creates a new team and assigns player to it", %{state: state, p1: p1} do
      new_state = TeamService.create_team(state, p1.token, "NewCrew")

      new_team = Enum.find(new_state.teams, fn t -> t.name == "NewCrew" end)
      assert new_team != nil
      assert Map.get(new_state.players_teams, p1.token) == new_team.id
    end

    test "player's old team is removed if empty after switching", %{state: state, p1: p1, t1: t1} do
      # p1 is the only player on t1. Creating a new team reassigns p1,
      # which triggers remove_empty_teams and should remove t1.
      new_state = TeamService.create_team(state, p1.token, "Solo")

      team_ids = Enum.map(new_state.teams, & &1.id)
      refute t1.id in team_ids
    end
  end

  describe "TeamService.join_team/3" do
    setup :new_game_state

    test "joins an existing team", %{state: state, p1: p1, t2: t2} do
      {:ok, new_state} = TeamService.join_team(state, t2.id, p1.token)

      assert Map.get(new_state.players_teams, p1.token) == t2.id
    end

    test "returns error for non-existent team", %{state: state, p1: p1} do
      assert {:error, :team_not_found} = TeamService.join_team(state, -1, p1.token)
    end
  end

  describe "TeamService.delete_team/2" do
    setup :new_game_state

    test "removes a team from state", %{state: state, t1: t1} do
      new_state = TeamService.delete_team(state, t1.id)

      team_ids = Enum.map(new_state.teams, & &1.id)
      refute t1.id in team_ids
    end

    test "does not affect other teams", %{state: state, t1: t1, t2: t2} do
      new_state = TeamService.delete_team(state, t1.id)

      team_ids = Enum.map(new_state.teams, & &1.id)
      assert t2.id in team_ids
    end

    test "deleting non-existent team is a no-op", %{state: state} do
      new_state = TeamService.delete_team(state, -999)

      assert length(new_state.teams) == length(state.teams)
    end
  end

  describe "TeamService.player_count/1" do
    setup :new_game_state

    test "counts players across all teams", %{state: state} do
      # new_game_state sets up 2 players with 1 player each on 2 teams.
      # player_count counts players on teams by flattening team.players lists,
      # which are empty in the setup (players_teams tracks assignment, not team.players).
      assert TeamService.player_count(state) == 0
    end

    test "counts players on teams with players added" do
      t1 = Team.new("A") |> Team.add_player(Player.new("p1", "t1"))
      t2 = Team.new("B") |> Team.add_player(Player.new("p2", "t2")) |> Team.add_player(Player.new("p3", "t3"))

      state = %{teams: [t1, t2]}

      assert TeamService.player_count(state) == 3
    end

    test "returns 0 with no teams" do
      state = %{teams: []}

      assert TeamService.player_count(state) == 0
    end
  end

  describe "TeamService.team_count/1" do
    setup :new_game_state

    test "counts teams in state", %{state: state} do
      assert TeamService.team_count(state) == 2
    end

    test "returns 0 with no teams" do
      state = %{teams: []}

      assert TeamService.team_count(state) == 0
    end
  end

  describe "TeamService.add_player_to_team/3" do
    setup :new_game_state

    test "assigns player to team in players_teams map", %{state: state, t1: t1} do
      new_state = TeamService.add_player_to_team(state, "new_token", t1.id)

      assert Map.get(new_state.players_teams, "new_token") == t1.id
    end

    test "reassigning a player removes their old empty team", %{state: state, p1: p1, t1: t1, t2: t2} do
      # p1 is only member of t1. Reassign p1 to t2 -> t1 should be removed.
      new_state = TeamService.add_player_to_team(state, p1.token, t2.id)

      team_ids = Enum.map(new_state.teams, & &1.id)
      refute t1.id in team_ids
      assert t2.id in team_ids
    end
  end

  describe "TeamService.remove_empty_teams/1" do
    setup :new_game_state

    test "keeps teams that have players assigned", %{state: state} do
      new_state = TeamService.remove_empty_teams(state)

      assert length(new_state.teams) == 2
    end

    test "removes teams with no players assigned" do
      t1 = Team.new("occupied")
      t2 = Team.new("empty")

      state = %{
        teams: [t1, t2],
        players_teams: %{"player_token" => t1.id}
      }

      new_state = TeamService.remove_empty_teams(state)

      assert length(new_state.teams) == 1
      assert hd(new_state.teams).id == t1.id
    end

    test "removes all teams when no players assigned" do
      t1 = Team.new("ghost1")
      t2 = Team.new("ghost2")

      state = %{teams: [t1, t2], players_teams: %{}}

      new_state = TeamService.remove_empty_teams(state)

      assert new_state.teams == []
    end
  end

  describe "TeamService.assign_players_to_teams/1" do
    setup :new_game_state

    test "sets team_id on each player struct", %{state: state, p1: p1, p2: p2, t1: t1, t2: t2} do
      new_state = TeamService.assign_players_to_teams(state)

      assigned_p1 = Enum.find(new_state.players, fn p -> p.token == p1.token end)
      assigned_p2 = Enum.find(new_state.players, fn p -> p.token == p2.token end)

      assert assigned_p1.team_id == t1.id
      assert assigned_p2.team_id == t2.id
    end

    test "players without team mapping get nil team_id" do
      player = Player.new("orphan", "orphan_token")
      team = Team.new("lonely")

      state = %{
        players: [player],
        players_teams: %{},
        teams: [team]
      }

      new_state = TeamService.assign_players_to_teams(state)

      assert hd(new_state.players).team_id == nil
    end
  end

  describe "TeamService.find_player_team/2" do
    setup :new_game_state

    test "finds the team for a player", %{state: state, p1: p1, t1: t1, p2: p2, t2: t2} do
      # assign_players_to_teams sets team_id on player structs
      state = TeamService.assign_players_to_teams(state)

      team = TeamService.find_player_team(state, p1.token)
      assert team.id == t1.id

      team = TeamService.find_player_team(state, p2.token)
      assert team.id == t2.id
    end
  end

  describe "TeamService.find_team_index/2" do
    setup :new_game_state

    test "returns the index of a team", %{state: state, t1: t1, t2: t2} do
      assert TeamService.find_team_index(state, t1.id) == 0
      assert TeamService.find_team_index(state, t2.id) == 1
    end

    test "returns nil for non-existent team", %{state: state} do
      assert TeamService.find_team_index(state, -1) == nil
    end
  end

  describe "TeamService.find_team_with_index/2" do
    setup :new_game_state

    test "returns {index, team} for existing team", %{state: state, t1: t1, t2: t2} do
      {idx, team} = TeamService.find_team_with_index(state, t1.id)
      assert idx == 0
      assert team.id == t1.id

      {idx, team} = TeamService.find_team_with_index(state, t2.id)
      assert idx == 1
      assert team.id == t2.id
    end

    test "returns {:error, :not_found} for non-existent team", %{state: state} do
      assert {:error, :not_found} = TeamService.find_team_with_index(state, -1)
    end
  end

  describe "TeamService.add_word_to_team/3" do
    setup :new_game_state

    test "adds a word to the correct team", %{state: state, t1: t1} do
      new_state = TeamService.add_word_to_team(state, t1.id, "plunder")

      assert team_has_word(new_state, t1.id, "plunder")
    end

    test "does not affect other teams", %{state: state, t1: t1, t2: t2} do
      new_state = TeamService.add_word_to_team(state, t1.id, "plunder")

      refute team_has_word(new_state, t2.id, "plunder")
    end

    test "nil team and nil word is a no-op", %{state: state} do
      new_state = TeamService.add_word_to_team(state, nil, nil)

      assert new_state == state
    end
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

    test "does not affect other teams", %{state: state, t1: t1, t2: t2} do
      new_state = TeamService.remove_word_from_team(state, t1, "bind")

      # t2 should be unchanged
      assert team_has_word(new_state, t2.id, "bing")
      assert team_has_word(new_state, t2.id, "bang")
      assert team_has_word(new_state, t2.id, "bong")
    end
  end

  describe "TeamService.team_name_unique?/2" do
    setup :new_game_state

    test "returns true for a unique name", %{state: state} do
      assert TeamService.team_name_unique?(state, "UniqueCrew")
    end

    test "returns false for a duplicate name", %{state: state} do
      refute TeamService.team_name_unique?(state, "team1")
    end

    test "is case-sensitive", %{state: state} do
      # "Team1" != "team1"
      assert TeamService.team_name_unique?(state, "Team1")
    end
  end
end

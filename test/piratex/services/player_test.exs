defmodule Piratex.PlayerTest do
  use ExUnit.Case

  alias Piratex.Player
  alias Piratex.PlayerService

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

  # Player Tests

  test "is_player?/1" do
    assert Player.is_playing?(%Player{status: :playing})
    refute Player.is_playing?(%Player{status: :quit})
  end

  test "quit/1" do
    player = Player.new("name", "token", []) |> Player.quit()
    refute Player.is_playing?(player)
  end

  test "add_word/2" do
    player = Player.new("name", "token", []) |> Player.add_word("word")
    assert player.words == ["word"]
    player = Player.add_word(player, "another")
    assert player.words == ["another", "word"]
  end

  test "remove_word/2" do
    player = Player.new("name", "token", ["another", "word"])
    player = Player.remove_word(player, "word")
    assert player.words == ["another"]

    player = Player.new("name", "token", ["another", "word"])
    player = Player.remove_word(player, "another")
    assert player.words == ["word"]
  end

  test "calculate_score/1" do
    Enum.each(@scores, fn {score, words} ->
      player = Player.new("name", "token", words) |> Player.calculate_score()
      assert player.score == score
    end)
  end

  test "drop_internal_state/1" do
    player = Player.new("name", "token", ["word"])
    player = Player.drop_internal_state(player)
    assert Map.get(player, :token, nil) == nil
  end

  # Service Tests

  test "add_player/2" do
    max_players = Piratex.Config.max_players()
    state = %{players: []}

    state =
      Enum.reduce(1..max_players, state, fn i, state ->
        player = Player.new("name#{i}", "token#{i}", [])
        state = PlayerService.add_player(state, player)
        assert length(state.players) == i
        state
      end)

    assert length(state.players) == max_players

    {:error, :game_full} = PlayerService.add_player(state, Player.new("extra", "token", []))
  end

  test "find_player/2" do
    players = [
      p1 = Player.new("name1", "token1", []),
      p2 = Player.new("name2", "token2", []),
      p3 = Player.new("name3", "token3", [])
    ]

    assert PlayerService.find_player(%{players: players}, "token1") == p1
    assert PlayerService.find_player(%{players: players}, "token2") == p2
    assert PlayerService.find_player(%{players: players}, "token3") == p3
    assert PlayerService.find_player(%{players: players}, "token4") == nil
  end

  test "player_is_unique?/3" do
    players = [
      p1 = Player.new("name1", "token1", []),
      p2 = Player.new("name2", "token2", [])
    ]

    refute PlayerService.player_is_unique?(%{players: players}, p1.name, p1.token)
    refute PlayerService.player_is_unique?(%{players: players}, p2.name, p2.token)
    refute PlayerService.player_is_unique?(%{players: players}, p1.name, "token3")
    refute PlayerService.player_is_unique?(%{players: players}, "name3", p2.token)
    assert PlayerService.player_is_unique?(%{players: players}, "name3", "token3")
  end

  test "count_unquit_players/1" do
    players = [
      p1 = Player.new("name1", "token1", []),
      p2 = Player.new("name2", "token2", []),
      p3 = Player.new("name3", "token3", []),
      p4 = Player.new("name4", "token4", [])
    ]

    quit_players = [
      qp1 = Player.quit(p1),
      qp2 = Player.quit(p2),
      qp3 = Player.quit(p3),
      qp4 = Player.quit(p4)
    ]

    assert PlayerService.count_unquit_players(%{players: players}) == 4
    assert PlayerService.count_unquit_players(%{players: [p1, p2, p3]}) == 3
    assert PlayerService.count_unquit_players(%{players: [p1, p2]}) == 2
    assert PlayerService.count_unquit_players(%{players: [p1]}) == 1
    assert PlayerService.count_unquit_players(%{players: []}) == 0

    assert PlayerService.count_unquit_players(%{players: quit_players}) == 0
    assert PlayerService.count_unquit_players(%{players: [qp1, qp2, qp3, qp4]}) == 0
    assert PlayerService.count_unquit_players(%{players: [qp1, qp2, qp3, p4]}) == 1
    assert PlayerService.count_unquit_players(%{players: [qp1, qp2, p3, p4]}) == 2
    assert PlayerService.count_unquit_players(%{players: [qp1, p2, p3, p4]}) == 3
  end
end

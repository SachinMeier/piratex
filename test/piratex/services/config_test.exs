defmodule Piratex.ConfigTest do
  use ExUnit.Case

  alias Piratex.Config

  describe "timeouts" do
    test "turn_timeout_ms/0 returns a positive integer" do
      result = Config.turn_timeout_ms()
      assert is_integer(result)
      assert result > 0
    end

    test "challenge_timeout_ms/0 returns a positive integer" do
      result = Config.challenge_timeout_ms()
      assert is_integer(result)
      assert result > 0
    end

    test "new_game_timeout_ms/0 returns a positive integer" do
      result = Config.new_game_timeout_ms()
      assert is_integer(result)
      assert result > 0
    end

    test "game_timeout_ms/0 returns a positive integer" do
      result = Config.game_timeout_ms()
      assert is_integer(result)
      assert result > 0
    end

    test "end_game_time_ms/0 returns a positive integer" do
      result = Config.end_game_time_ms()
      assert is_integer(result)
      assert result > 0
    end

    test "challenge_timeout_ms >= turn_timeout_ms" do
      assert Config.challenge_timeout_ms() >= Config.turn_timeout_ms()
    end

    test "game_timeout_ms is the longest timeout" do
      assert Config.game_timeout_ms() >= Config.turn_timeout_ms()
      assert Config.game_timeout_ms() >= Config.challenge_timeout_ms()
      assert Config.game_timeout_ms() >= Config.new_game_timeout_ms()
      assert Config.game_timeout_ms() >= Config.end_game_time_ms()
    end
  end

  describe "player name limits" do
    test "min_player_name/0 returns a positive integer" do
      result = Config.min_player_name()
      assert is_integer(result)
      assert result > 0
    end

    test "max_player_name/0 returns a positive integer" do
      result = Config.max_player_name()
      assert is_integer(result)
      assert result > 0
    end

    test "max_player_name >= min_player_name" do
      assert Config.max_player_name() >= Config.min_player_name()
    end
  end

  describe "team name limits" do
    test "min_team_name/0 returns a positive integer" do
      result = Config.min_team_name()
      assert is_integer(result)
      assert result > 0
    end

    test "max_team_name/0 returns a positive integer" do
      result = Config.max_team_name()
      assert is_integer(result)
      assert result > 0
    end

    test "max_team_name >= min_team_name" do
      assert Config.max_team_name() >= Config.min_team_name()
    end
  end

  describe "game limits" do
    test "min_word_length/0 returns a positive integer" do
      result = Config.min_word_length()
      assert is_integer(result)
      assert result > 0
    end

    test "max_players/0 returns a positive integer" do
      result = Config.max_players()
      assert is_integer(result)
      assert result > 0
    end

    test "max_teams/0 returns a positive integer" do
      result = Config.max_teams()
      assert is_integer(result)
      assert result > 0
    end

    test "max_players >= max_teams" do
      assert Config.max_players() >= Config.max_teams()
    end

    test "letter_pool_size/0 returns a positive integer" do
      result = Config.letter_pool_size()
      assert is_integer(result)
      assert result > 0
    end

    test "letter_pool_size is large enough relative to min_word_length" do
      assert Config.letter_pool_size() > Config.min_word_length()
    end
  end

  describe "dictionary" do
    test "dictionary_file_name/0 returns a non-empty string" do
      result = Config.dictionary_file_name()
      assert is_binary(result)
      assert String.length(result) > 0
    end

    test "dictionary_file_name/0 returns a .txt file" do
      assert String.ends_with?(Config.dictionary_file_name(), ".txt")
    end
  end
end

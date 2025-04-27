defmodule Piratex.Config do
  @moduledoc """
  This module provides a centralized way to access configuration values for the Piratex application.
  """

  # time for each player to flip a letter
  @spec turn_timeout_ms :: non_neg_integer()
  def turn_timeout_ms, do: Application.get_env(:piratex, :turn_timeout_ms)

  # time for players to vote on a challenge
  @spec challenge_timeout_ms :: non_neg_integer()
  def challenge_timeout_ms, do: Application.get_env(:piratex, :challenge_timeout_ms)

  # time for the first player to join
  @spec new_game_timeout_ms :: non_neg_integer()
  def new_game_timeout_ms, do: Application.get_env(:piratex, :new_game_timeout_ms)

  # games timeout after inactivity
  @spec game_timeout_ms :: non_neg_integer()
  def game_timeout_ms, do: Application.get_env(:piratex, :game_timeout_ms)

  # time for the last player to claim a word
  @spec end_game_time_ms :: non_neg_integer()
  def end_game_time_ms, do: Application.get_env(:piratex, :end_game_time_ms)

  # min and max player name length
  @spec min_player_name :: non_neg_integer()
  def min_player_name, do: Application.get_env(:piratex, :min_player_name)

  @spec max_player_name :: non_neg_integer()
  def max_player_name, do: Application.get_env(:piratex, :max_player_name)

  # min word length
  @spec min_word_length :: non_neg_integer()
  def min_word_length, do: Application.get_env(:piratex, :min_word_length)

  # max number of players
  @spec max_players :: non_neg_integer()
  def max_players, do: Application.get_env(:piratex, :max_players)

  # size of the letter pool
  @spec letter_pool_size :: non_neg_integer()
  def letter_pool_size, do: Application.get_env(:piratex, :letter_pool_size)

  # name of the dictionary file. Mainly to reduce testing resource usage
  # but could be used to change/choose the dictionary for the game
  @spec dictionary_file_name :: String.t()
  def dictionary_file_name, do: Application.get_env(:piratex, :dictionary_file_name)
end

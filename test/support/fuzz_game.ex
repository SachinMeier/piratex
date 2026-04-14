defmodule Piratex.FuzzGame do
  @moduledoc """
  Drop-in replacement for Piratex.Game that monitors the GenServer process
  during every call. Raises if the GenServer crashes instead of silently
  returning {:error, :not_found}. Use in fuzz tests via:

      alias Piratex.FuzzGame, as: Game
  """
  alias Piratex.Game
  alias Piratex.FuzzHelpers

  # Read-only — delegate directly
  defdelegate get_state(game_id), to: Game
  defdelegate max_chat_message_length(), to: Game

  # Mutating calls — monitored for crashes
  def flip_letter(game_id, token),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.flip_letter(game_id, token) end)

  def claim_word(game_id, token, word),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.claim_word(game_id, token, word) end)

  def challenge_word(game_id, token, word),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.challenge_word(game_id, token, word) end)

  def challenge_vote(game_id, token, challenge_id, vote),
    do:
      FuzzHelpers.monitored_call!(game_id, fn ->
        Game.challenge_vote(game_id, token, challenge_id, vote)
      end)

  def quit_game(game_id, token),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.quit_game(game_id, token) end)

  def end_game_vote(game_id, token),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.end_game_vote(game_id, token) end)

  def join_game(game_id, name, token),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.join_game(game_id, name, token) end)

  def leave_waiting_game(game_id, token),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.leave_waiting_game(game_id, token) end)

  def create_team(game_id, token, name),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.create_team(game_id, token, name) end)

  def join_team(game_id, token, team_id),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.join_team(game_id, token, team_id) end)

  def start_game(game_id, token),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.start_game(game_id, token) end)

  def set_letter_pool_type(game_id, pool_type),
    do:
      FuzzHelpers.monitored_call!(game_id, fn ->
        Game.set_letter_pool_type(game_id, pool_type)
      end)

  def send_chat_message(game_id, token, message),
    do:
      FuzzHelpers.monitored_call!(game_id, fn ->
        Game.send_chat_message(game_id, token, message)
      end)

  def rejoin_game(game_id, name, token),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.rejoin_game(game_id, name, token) end)

  def get_players_teams(game_id),
    do: FuzzHelpers.monitored_call!(game_id, fn -> Game.get_players_teams(game_id) end)
end

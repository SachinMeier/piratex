defmodule Piratex.TurnService do
  @moduledoc """
  Handles the logic for turn management and letter flipping
  """

  alias Piratex.Helpers
  alias Piratex.Player
  alias Piratex.Config
  @doc """
  Checks if it is the given player's turn.
  """
  @spec is_player_turn?(map(), String.t()) :: boolean()
  def is_player_turn?(%{players: players, turn: turn}, player_token) do
    %{token: token} = Enum.at(players, turn)
    player_token == token
  end


  @doc """
  Updates the state to add a new letter to the center and remove it from the letter pool.
  If the letter pool is empty, it returns the state unchanged.
  """
  @spec update_state_flip_letter(map()) :: map()
  def update_state_flip_letter(%{letter_pool: []} = state), do: state

  def update_state_flip_letter(%{letter_pool: letter_pool} = state) do
    rand_idx = :rand.uniform(length(letter_pool)) - 1
    new_letter = Enum.at(letter_pool, rand_idx)
    new_letter_pool = List.delete_at(letter_pool, rand_idx)

    state
    |> Helpers.add_letters_to_center([new_letter])
    |> next_turn()
    |> Map.put(:letter_pool, new_letter_pool)
  end

  @doc """
  next_turn is recursive and sets the turn to the next player that has not quit.
  """
  def next_turn(%{players: players, total_turn: total_turn} = state) do
    total_turn = total_turn + 1
    turn = rem(total_turn, length(players))

    state =
      state
      |> Map.put(:total_turn, total_turn)
      |> Map.put(:turn, turn)

    case Enum.at(players, turn) do
      %Player{status: :quit} ->
        next_turn(state)

      _ ->
        # we only start the turn timeout if there are more than 1 player still playing
        if Enum.count(players, fn player -> Player.is_playing?(player) end) > 1 do
          start_turn_timeout(total_turn)
        end

        state
    end
  end

  # TODO: consider using cancel_timer to cancel the timeout for a specific turn or challenge
  # if it ended before the timeout

  def start_turn_timeout(total_turn) do
    Process.send_after(self(), {:turn_timeout, total_turn}, Config.turn_timeout_ms())
  end
end

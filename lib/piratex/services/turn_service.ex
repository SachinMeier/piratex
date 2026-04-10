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

  def update_state_flip_letter(%{letter_pool: [new_letter | rest]} = state) do
    state
    |> Helpers.add_letters_to_center([new_letter])
    |> next_turn()
    |> Map.put(:letter_pool, rest)
  end

  @doc """
  next_turn is recursive and sets the turn to the next player that has not quit.
  """
  def next_turn(%{players: players, total_turn: total_turn} = state) do
    total_turn = total_turn + 1
    turn = rem(total_turn, length(players))

    state =
      state
      |> cancel_turn_timer()
      |> Map.put(:total_turn, total_turn)
      |> Map.put(:turn, turn)

    case Enum.at(players, turn) do
      %Player{status: :quit} ->
        next_turn(state)

      _ ->
        if Enum.count(players, fn player -> Player.is_playing?(player) end) > 1 do
          timer_ref = start_turn_timeout(total_turn)
          Map.put(state, :turn_timer_ref, timer_ref)
        else
          state
        end
    end
  end

  def cancel_turn_timer(%{turn_timer_ref: ref} = state) when is_reference(ref) do
    Process.cancel_timer(ref)
    Map.put(state, :turn_timer_ref, nil)
  end

  def cancel_turn_timer(state), do: state

  def start_turn_timeout(total_turn) do
    Process.send_after(self(), {:turn_timeout, total_turn}, Config.turn_timeout_ms())
  end
end

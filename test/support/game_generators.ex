defmodule Piratex.GameGenerators do
  @moduledoc """
  StreamData generators for fuzz testing the Game GenServer.
  """
  import StreamData

  @dictionary Path.join([__DIR__, "../../priv/data/test.txt"])
              |> File.read!()
              |> String.split("\n", trim: true)

  def dictionary, do: @dictionary

  def valid_word do
    member_of(@dictionary)
  end

  def action_slot_gen do
    frequency([
      {4, constant(:flip)},
      {3, constant(:claim)},
      {1, constant(:challenge)},
      {1, constant(:vote)},
      {1, constant(:quit)},
      {1, constant(:end_vote)},
      {1, constant(:chat)},
      {1, constant(:bad_token)},
      {1, constant(:quit_player_action)},
      {1, constant(:rejoin)},
      {1, constant(:cross_phase)},
      {1, constant(:degenerate_input)}
    ])
  end

  def waiting_action_slot_gen do
    frequency([
      {3, constant(:join)},
      {2, constant(:create_team)},
      {2, constant(:join_team)},
      {1, constant(:leave)},
      {1, constant(:quit)},
      {1, constant(:rejoin)},
      {1, constant(:bad_token)}
    ])
  end
end

defmodule Piratex.WordStealTest do
  use ExUnit.Case

  alias Piratex.WordSteal

  describe "WordSteal.new/1" do
    test "creates a WordSteal struct with all fields" do
      ws =
        WordSteal.new(%{
          victim_team_idx: 0,
          victim_word: "CAT",
          thief_team_idx: 1,
          thief_player_idx: 0,
          thief_word: "CATS",
          letter_count: 1
        })

      assert %WordSteal{} = ws
      assert ws.victim_team_idx == 0
      assert ws.victim_word == "CAT"
      assert ws.thief_team_idx == 1
      assert ws.thief_player_idx == 0
      assert ws.thief_word == "CATS"
      assert ws.letter_count == 1
    end

    test "creates a WordSteal with nil victim fields for center steal" do
      ws =
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 1,
          thief_word: "DOG",
          letter_count: 3
        })

      assert %WordSteal{} = ws
      assert ws.victim_team_idx == nil
      assert ws.victim_word == nil
      assert ws.thief_word == "DOG"
      assert ws.letter_count == 3
    end
  end

  describe "WordSteal.match?/2" do
    test "returns true for exact same thief_word and victim_word" do
      ws1 =
        WordSteal.new(%{
          victim_team_idx: 0,
          victim_word: "CAT",
          thief_team_idx: 1,
          thief_player_idx: 0,
          thief_word: "CATS",
          letter_count: 1
        })

      ws2 =
        WordSteal.new(%{
          victim_team_idx: 0,
          victim_word: "CAT",
          thief_team_idx: 1,
          thief_player_idx: 0,
          thief_word: "CATS",
          letter_count: 1
        })

      assert WordSteal.match?(ws1, ws2)
    end

    test "returns true when words match but players differ" do
      ws1 =
        WordSteal.new(%{
          victim_team_idx: 0,
          victim_word: "CAT",
          thief_team_idx: 1,
          thief_player_idx: 0,
          thief_word: "CATS",
          letter_count: 1
        })

      ws2 =
        WordSteal.new(%{
          victim_team_idx: 2,
          victim_word: "CAT",
          thief_team_idx: 3,
          thief_player_idx: 1,
          thief_word: "CATS",
          letter_count: 5
        })

      assert WordSteal.match?(ws1, ws2)
    end

    test "returns true when both victim_words are nil" do
      ws1 =
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "DOG",
          letter_count: 3
        })

      ws2 =
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 1,
          thief_player_idx: 1,
          thief_word: "DOG",
          letter_count: 3
        })

      assert WordSteal.match?(ws1, ws2)
    end

    test "returns false when thief_words differ" do
      ws1 =
        WordSteal.new(%{
          victim_team_idx: 0,
          victim_word: "CAT",
          thief_team_idx: 1,
          thief_player_idx: 0,
          thief_word: "CATS",
          letter_count: 1
        })

      ws2 =
        WordSteal.new(%{
          victim_team_idx: 0,
          victim_word: "CAT",
          thief_team_idx: 1,
          thief_player_idx: 0,
          thief_word: "CART",
          letter_count: 1
        })

      refute WordSteal.match?(ws1, ws2)
    end

    test "returns false when victim_words differ" do
      ws1 =
        WordSteal.new(%{
          victim_team_idx: 0,
          victim_word: "CAT",
          thief_team_idx: 1,
          thief_player_idx: 0,
          thief_word: "CATS",
          letter_count: 1
        })

      ws2 =
        WordSteal.new(%{
          victim_team_idx: 0,
          victim_word: "BAT",
          thief_team_idx: 1,
          thief_player_idx: 0,
          thief_word: "CATS",
          letter_count: 1
        })

      refute WordSteal.match?(ws1, ws2)
    end

    test "returns false when one victim_word is nil and the other is not" do
      ws1 =
        WordSteal.new(%{
          victim_team_idx: nil,
          victim_word: nil,
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "DOG",
          letter_count: 3
        })

      ws2 =
        WordSteal.new(%{
          victim_team_idx: 1,
          victim_word: "DO",
          thief_team_idx: 0,
          thief_player_idx: 0,
          thief_word: "DOG",
          letter_count: 1
        })

      refute WordSteal.match?(ws1, ws2)
    end
  end
end

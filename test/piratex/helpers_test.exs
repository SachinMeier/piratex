defmodule Piratex.HelpersTest do
  use ExUnit.Case

  import Piratex.TestHelpers

  alias Piratex.Helpers
  alias Piratex.Team
  alias Piratex.TurnService

  test "word_in_play?/1" do
    teams = [
      Team.new("name1", ["bind", "band", "bond"]),
      Team.new("name2", ["bing", "bang", "bong"])
    ]

    assert Helpers.word_in_play?(%{teams: teams}, "bind")
    assert Helpers.word_in_play?(%{teams: teams}, "band")
    assert Helpers.word_in_play?(%{teams: teams}, "bond")
    assert Helpers.word_in_play?(%{teams: teams}, "bing")
    assert Helpers.word_in_play?(%{teams: teams}, "bang")
    assert Helpers.word_in_play?(%{teams: teams}, "bong")

    refute Helpers.word_in_play?(%{teams: teams}, "nonword")
    refute Helpers.word_in_play?(%{teams: teams}, "")
  end

  test "no_more_letters?/1" do
    assert Helpers.no_more_letters?(%{letter_pool: []})
    refute Helpers.no_more_letters?(%{letter_pool: ["a"]})

    state =
      default_new_game(2, %{
        letter_pool: ["a", "b", "c"]
      })

    refute Helpers.no_more_letters?(state)

    state = TurnService.update_state_flip_letter(state)
    refute Helpers.no_more_letters?(state)

    state = TurnService.update_state_flip_letter(state)
    refute Helpers.no_more_letters?(state)

    state = TurnService.update_state_flip_letter(state)
    assert Helpers.no_more_letters?(state)
  end

  # TODO: test remove_word_from_player
  # TODO: test add_letters_to_center
  # TODO: test find_player_index
end

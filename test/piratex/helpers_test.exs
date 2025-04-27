defmodule Piratex.HelpersTest do
  use ExUnit.Case

  import Piratex.TestHelpers

  alias Piratex.Helpers
  alias Piratex.Player
  alias Piratex.TurnService

  test "word_in_play?/1" do
    players = [
      Player.new("token", "name1", ["bind", "band", "bond"]),
      Player.new("token2", "name2", ["bing", "bang", "bong"])
    ]

    assert Helpers.word_in_play?(%{players: players}, "bind")
    assert Helpers.word_in_play?(%{players: players}, "band")
    assert Helpers.word_in_play?(%{players: players}, "bond")
    assert Helpers.word_in_play?(%{players: players}, "bing")
    assert Helpers.word_in_play?(%{players: players}, "bang")
    assert Helpers.word_in_play?(%{players: players}, "bong")

    refute Helpers.word_in_play?(%{players: players}, "nonword")
    refute Helpers.word_in_play?(%{players: players}, "")
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

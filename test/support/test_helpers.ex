defmodule Piratex.TestHelpers do
  @moduledoc """
  Helper functions for testing
  """
  alias Piratex.Player


  # if :players is passed to attrs, it overrides the default players
  def default_new_game(player_count, attrs \\ %{}) do
    players = Enum.map(1..player_count, fn i ->
      Player.new("player_#{i}", "token_#{i}", [])
    end)

    %{
      id: "ASDF",
      status: :playing,
      players: players,
      turn: 0,
      total_turn: 0,
      letter_pool: Piratex.GameHelpers.letter_pool(),
      center: [],
      center_sorted: [],
      scores: [],
      history: [],
      challenges: [],
      past_challenges: [],
      last_action_at: DateTime.utc_now()
    }
    |> Map.merge(attrs)
  end

  def new_game_state(_ctx) do
    players = [
      Player.new("name1", "token", ["bind", "band", "bond"]),
      Player.new("name2", "token2", ["bing", "bang", "bong"])
    ]

    state = %{
      id: "ASDF",
      status: :playing,
      players: players,
      turn: 0,
      total_turn: 0,
      letter_pool: Piratex.GameHelpers.letter_pool(),
      center: [],
      center_sorted: [],
      scores: [],
      history: [],
      challenges: [],
      past_challenges: [],
      last_action_at: DateTime.utc_now()
    }

    {:ok, state: state, players: state.players, p1: Enum.at(state.players, 0), p2: Enum.at(state.players, 1)}
  end

  def player_has_word(state, player_token, word) do
    Enum.any?(state.players, fn %{token: token, words: player_words} ->
      token == player_token && word in player_words
    end)
  end

  def match_center?(state, letters) do
    Piratex.Services.WordClaimService.calculate_word_product(letters) == Piratex.Services.WordClaimService.calculate_word_product(state.center)
  end
end

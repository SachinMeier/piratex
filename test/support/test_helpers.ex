defmodule Piratex.TestHelpers do
  @moduledoc """
  Helper functions for testing
  """
  alias Piratex.Player
  alias Piratex.Team

  # if :players is passed to attrs, it overrides the default players
  def default_new_game(player_count, attrs \\ %{}) do
    {players, teams, players_teams} =
      if player_count > 0 do
        players = Enum.map(1..player_count, fn i ->
          Player.new("player_#{i}", "token_#{i}", [])
        end)

        {teams, players_teams} =
          Enum.map(players, fn player ->
            team = Team.new("Team-" <> player.name)
            {team, {player.token, team.id}}
          end)
          |> Enum.unzip()

        {players, teams, players_teams}
      else
        {[], [], %{}}
      end

    {letter_count, letter_pool} = Piratex.LetterPoolService.load_letter_pool(:bananagrams)

    %{
      id: "ASDF",
      status: :playing,
      players: players,
      players_teams: players_teams,
      teams: teams,
      turn: 0,
      total_turn: 0,
      letter_pool: letter_pool,
      initial_letter_count: letter_count,
      center: [],
      center_sorted: [],
      history: [],
      challenges: [],
      past_challenges: [],
      end_game_votes: %{},
      last_action_at: DateTime.utc_now()
    }
    |> Map.merge(attrs)
  end

  def new_game_state(_ctx) do
    players = [
      p1 = Player.new("name1", "token"),
      p2 = Player.new("name2", "token2")
    ]

    teams = [
      t1 = Team.new("team1", ["bind", "band", "bond"]),
      t2 = Team.new("team2", ["bing", "bang", "bong"])
    ]

    players_teams = %{
      p1.token => t1.id,
      p2.token => t2.id
    }

    {letter_count, letter_pool} = Piratex.LetterPoolService.load_letter_pool(:bananagrams)

    state = %{
      id: "ASDF",
      status: :playing,
      players: players,
      players_teams: players_teams,
      teams: teams,
      turn: 0,
      total_turn: 0,
      letter_pool: letter_pool,
      initial_letter_count: letter_count,
      center: [],
      center_sorted: [],
      history: [],
      challenges: [],
      past_challenges: [],
      end_game_votes: %{},
      last_action_at: DateTime.utc_now()
    }

    {:ok,
     state: state,
     players: state.players,
     t1: Enum.at(teams, 0),
     t2: Enum.at(teams, 1),
     p1: p1,
     p2: p2
    }
  end

  def team_has_word(state, team_id, word) do
    Enum.any?(state.teams, fn %{id: id, words: words} = _team ->
      id == team_id && word in words
    end)
  end

  def match_center?(state, letters) do
    Piratex.WordClaimService.calculate_word_product(letters) ==
      Piratex.WordClaimService.calculate_word_product(state.center)
  end

  def match_turn?(state, turn, total_turn \\ nil) do
    cond do
      state.turn != turn -> false
      !is_nil(total_turn) and state.total_turn != total_turn -> false
      true -> true
    end
  end

  def wait_for_state_match(game_id, match_term) do
    Enum.reduce_while(1..10, :incorrect_state, fn _, _ ->
      {:ok, state} = Piratex.Game.get_state(game_id)
      if Enum.all?(match_term, fn {key, value} ->
        Map.get(state, key) == value
      end) do
        {:halt, :ok}
      else
        :timer.sleep(10)
        {:cont, {:incorrect_state, state}}
      end
    end)
  end
end

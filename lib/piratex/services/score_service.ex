defmodule Piratex.ScoreService do
  @moduledoc """
  Handles the logic for scoring the game.
  """

  alias Piratex.Team
  alias Piratex.WordSteal

  @doc """
  Calculates the scores for each Team.
  Score is calculated as the number of letters in all words minus the number of words.
  Put another way, drop one letter from each word and count the remaining letters.
  """
  def calculate_team_scores(%{teams: teams} = state) do
    teams_with_scores = Enum.map(teams, &Team.calculate_score/1)

    state
    |> Map.put(:teams, teams_with_scores)
  end

  defp calculate_word_length_distribution(word_length_distribution, words) do
    Enum.reduce(words, word_length_distribution, fn word, distribution ->
      Map.update(distribution, String.length(word), 1, &(&1 + 1))
    end)
  end

  def calculate_game_stats(state) do
    game_stats = do_calculate_game_stats(state)

    Map.put(state, :game_stats, game_stats)
  end

  @spec calculate_game_stats(map()) :: %{
    total_score: non_neg_integer(),
    total_steals: non_neg_integer(),
    best_steal: WordSteal.t() | nil,
    best_steal_score: non_neg_integer(),
    raw_player_stats: map()
  }
  defp do_calculate_game_stats(state) do
    game_duration =
      if state.end_time != nil and state.start_time != nil do
        DateTime.diff(state.end_time, state.start_time, :second)
      else
        0
      end

    team_stats = calculate_team_stats(state.teams)

    challenge_stats =
      calculate_challenge_stats(state.past_challenges)

    total_score =
      Enum.reduce(state.teams, 0, fn team, total_score ->
        total_score + team.score
      end)

    # first, remove all successful challenges from the word history
    # This technically eliminates word steals that were allowed at the time but
    # in a different instance, disallowed. This is quite rare and ok.
    invalid_words = Enum.map(challenge_stats.invalid_word_steals, fn word_steal -> word_steal.thief_word end)
    history = Enum.filter(state.history, fn word_steal ->
      !Enum.member?(invalid_words, word_steal.thief_word)
    end)

    game_stats = calculate_history_stats(state.players, history)

    {raw_mvp_idx, raw_mvp} =
      case Enum.max_by(game_stats.raw_player_stats, fn {_player_idx, %{points: points}} -> points end, fn -> nil end) do
        # If there is no MVP, use the first player
        nil ->
          Enum.at(game_stats.raw_player_stats, 0)

        {raw_mvp_idx, raw_mvp} ->
          {raw_mvp_idx, raw_mvp}
      end

    game_stats
    |> Map.put(:team_stats, team_stats)
    |> Map.put(:game_duration, game_duration)
    |> Map.put(:total_score, total_score)
    |> Map.put(:challenge_stats, challenge_stats)
    |> Map.put(:raw_mvp, Map.put(raw_mvp, :player_idx, raw_mvp_idx))
  end

  defp new_raw_player_stats() do
    %{
      points: 0,
      words: [],
      steals: 0
    }
  end

  defp update_raw_player_stats(raw_player_stats, word_steal, word_steal_points) do
    Map.update(raw_player_stats, word_steal.thief_player_idx, %{
      points: word_steal_points,
      words: [word_steal.thief_word],
      steals: 1
    }, fn player_stats ->
      %{
        points: player_stats.points + word_steal_points,
        words: [word_steal.thief_word | player_stats.words],
        steals: player_stats.steals + 1
      }
    end)
  end

  defp calculate_history_stats(players, history) do
    raw_player_stats =
      players
      |> Enum.with_index()
      |> Map.new(fn {_, idx} ->
        {idx, new_raw_player_stats()}
      end)

    Enum.reduce(history, %{total_steals: 0, raw_player_stats: raw_player_stats}, fn word_steal, stats ->
      word_steal_letters_added = word_steal_letters_added(word_steal)

      word_steal_points =
        # if its a self-steal, we only count the letters added
        if word_steal.thief_team_idx == word_steal.victim_team_idx do
          word_steal_letters_added
        else
          # if its a team-steal, we count the full word points
          word_points(word_steal.thief_word)
        end

      raw_player_stats = update_raw_player_stats(stats.raw_player_stats, word_steal, word_steal_points)

      best_steal_score = calculate_best_steal_score(word_steal.victim_word, word_steal.thief_word)

      {new_best_steal, new_best_steal_score} =
        if stats[:best_steal] == nil or (best_steal_score > stats.best_steal_score) do
          {word_steal, best_steal_score}
        else
          {stats.best_steal, stats.best_steal_score}
        end

      {new_longest_word, new_longest_word_length} =
        if stats[:longest_word] == nil or (String.length(word_steal.thief_word) > stats.longest_word_length) do
          {word_steal.thief_word, String.length(word_steal.thief_word)}
        else
          {stats.longest_word, stats.longest_word_length}
        end

      %{
        total_steals: stats.total_steals + 1,
        best_steal: new_best_steal,
        best_steal_score: new_best_steal_score,
        raw_player_stats: raw_player_stats,
        longest_word: new_longest_word,
        longest_word_length: new_longest_word_length
      }
    end)
    |> Map.update(:raw_player_stats, %{}, fn rps ->
      Map.new(rps, fn {player_idx, player_stats} ->
        points_per_steal =
          if player_stats.steals > 0 do
            player_stats.points / player_stats.steals
          else
            0
          end

        {player_idx, Map.put(player_stats, :points_per_steal, points_per_steal)}
      end)
    end)
  end

  def calculate_team_stats(teams) do
    Enum.reduce(teams, %{
      total_letters: 0,
      total_score: 0,
      word_count: 0,
      word_length_distribution: %{}
    }, fn team, stats ->
      %{
        total_score: stats.total_score + team.score,
        word_count: stats.word_count + length(team.words),
        word_length_distribution: calculate_word_length_distribution(stats.word_length_distribution, team.words)
      }
    end)
    |> Map.put(:avg_points_per_word, calculate_avg_points_per_word(teams))
    |> Map.put(:margin_of_victory, calculate_margin_of_victory(teams))
    |> then(&Map.put(&1, :avg_word_length, calculate_avg_word_length(&1)))
  end

  defp calculate_avg_points_per_word(teams) do
    teams
    |> Enum.with_index()
    |> Map.new(fn {team, idx} ->
      word_count = length(team.words)
      if word_count > 0 do
        {idx, team.score / word_count}
      else
        {idx, 0}
      end
    end)
  end

  defp calculate_avg_word_length(team_stats) do
    if team_stats.word_count > 0 do
      (team_stats.total_score + team_stats.word_count) / team_stats.word_count
    else
      0
    end
  end

  defp calculate_margin_of_victory(teams) do
    teams
    |> Enum.sort_by(& &1.score, :desc)
    |> case do
      [first_team, second_team | _] ->
        first_team.score - second_team.score
      _ ->
        0
    end
  end

  def calculate_challenge_stats(past_challenges) do
    challenge_stats =
      %{count: 0, valid_ct: 0, player_stats: %{}, invalid_word_steals: []}
    Enum.reduce(past_challenges, challenge_stats, fn challenge, stats ->
      %{
        count: stats.count + 1,
        valid_ct: stats.valid_ct + if(challenge.result, do: 1, else: 0),
        player_stats: update_player_challenge_stats(stats.player_stats, challenge),
        invalid_word_steals: if(!challenge.result, do: [challenge.word_steal | stats.invalid_word_steals], else: stats.invalid_word_steals)
      }
    end)
  end

  defp update_player_challenge_stats(player_stats, challenge) do
    Map.update(player_stats, challenge.word_steal.thief_player_idx, %{
      count: 1,
      valid_ct: if(challenge.result, do: 1, else: 0)
    }, fn player_stats ->
      %{
        count: player_stats.count + 1,
        valid_ct: player_stats.valid_ct + if(challenge.result, do: 1, else: 0)
      }
    end)
  end

  defp word_points(nil), do: 0
  defp word_points(word) do
    String.length(word) - 1
  end

  # from the center
  defp word_steal_letters_added(%{
    thief_word: thief_word,
    victim_word: nil
  }) do
    String.length(thief_word)
  end

  # from another word
  defp word_steal_letters_added(%{
    thief_word: thief_word,
    victim_word: victim_word,
  }) do
    String.length(thief_word) - String.length(victim_word)
  end

  def calculate_best_steal_score(victim_word, thief_word) do
    victim_letter_pairs = get_letter_pairs(victim_word)

    thief_letter_pairs = get_letter_pairs(thief_word)

    num_new_pairs =
      Enum.count(thief_letter_pairs, fn pair ->
        pair not in victim_letter_pairs
      end)

    String.length(thief_word || "") + String.length(victim_word || "") + num_new_pairs
  end

  def get_letter_pairs(nil), do: []
  def get_letter_pairs(word) do
    word
    |> String.graphemes()
    |> do_get_letter_pairs([])
  end

  def do_get_letter_pairs([], pairs), do: pairs

  def do_get_letter_pairs([_], pairs), do: pairs

  def do_get_letter_pairs([letter1, letter2 | rest], pairs) do
    do_get_letter_pairs([letter2 | rest], [{letter1, letter2} | pairs])
  end
end

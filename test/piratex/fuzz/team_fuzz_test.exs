defmodule Piratex.TeamFuzzTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Piratex.FuzzHelpers
  alias Piratex.GameGenerators
  alias Piratex.FuzzGame, as: Game
  alias Piratex.Config

  @moduletag :fuzz

  setup do
    FuzzHelpers.ensure_dictionary_started()
    :ok
  end

  defp run_random_actions(game_id, seeds) do
    Enum.each(seeds, fn seed ->
      if FuzzHelpers.game_alive?(game_id) do
        action = GameGenerators.select_action(game_id, seed)
        GameGenerators.execute(action)
      end
    end)
  end

  defp finish_game(game_id, num_players) do
    case FuzzHelpers.safe_get_state(game_id) do
      %{status: :playing} ->
        FuzzHelpers.drain_pool_and_end_game(game_id, num_players)
        FuzzHelpers.wait_for_game_end(game_id, 3000)

      _ ->
        :ok
    end
  end

  describe "all players on one team" do
    property "all players on one team - game plays correctly" do
      check all(
              num_players <- StreamData.integer(2..6),
              seeds <- GameGenerators.seed_list_gen(20, 80),
              max_runs: 50
            ) do
        {:ok, game_id} = Piratex.DynamicSupervisor.new_game()
        :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)

        # First player joins and creates a team
        :ok = Game.join_game(game_id, "player_1", "token_1")
        :ok = Game.create_team(game_id, "token_1", "pirates")

        # Get the team id
        {:ok, state} = Game.get_state(game_id)
        team = Enum.find(state.teams, fn t -> t.name == "pirates" end)

        # Remaining players join the same team
        for i <- 2..num_players do
          :ok = Game.join_game(game_id, "player_#{i}", "token_#{i}")
          :ok = Game.join_team(game_id, "token_#{i}", team.id)
        end

        :ok = Game.start_game(game_id, "token_1")

        {:ok, playing_state} = Game.get_state(game_id)
        assert playing_state.status == :playing
        assert length(playing_state.teams) == 1

        # Run random actions
        run_random_actions(game_id, seeds)

        if FuzzHelpers.game_alive?(game_id) do
          {:ok, mid_state} = Game.get_state(game_id)

          if mid_state.status == :playing do
            # All words should be on the single team
            assert length(mid_state.teams) == 1
            [only_team] = mid_state.teams

            all_words = Enum.flat_map(mid_state.teams, & &1.words)
            assert all_words == only_team.words

            FuzzHelpers.check_invariants!(game_id)
          end

          # Finish the game
          finish_game(game_id, num_players)

          final = FuzzHelpers.safe_get_state(game_id)

          if final != nil and final.status == :finished do
            assert length(final.teams) == 1
            [team] = final.teams
            assert is_integer(team.score)

            # Score = sum of letters - number of words
            expected_score =
              Enum.reduce(team.words, 0, fn w, acc -> acc + String.length(w) end) -
                length(team.words)

            assert team.score == expected_score
          end
        end
      end
    end
  end

  describe "every player on own team" do
    property "every player on own team - game plays correctly" do
      check all(
              num_players <- StreamData.integer(2..6),
              seeds <- GameGenerators.seed_list_gen(20, 80),
              max_runs: 50
            ) do
        # Default behavior: each player auto-gets their own team
        game_id = FuzzHelpers.setup_playing_game(num_players)

        {:ok, playing_state} = Game.get_state(game_id)
        assert playing_state.status == :playing
        assert length(playing_state.teams) == num_players

        # Run random actions
        run_random_actions(game_id, seeds)

        if FuzzHelpers.game_alive?(game_id) do
          {:ok, mid_state} = Game.get_state(game_id)

          if mid_state.status == :playing do
            # Verify steals are tracked correctly across teams
            all_words = Enum.flat_map(mid_state.teams, & &1.words)
            unique_words = Enum.uniq(all_words)
            assert length(all_words) == length(unique_words), "No word should appear on two teams"

            FuzzHelpers.check_invariants!(game_id)
          end

          # Finish the game
          finish_game(game_id, num_players)

          final = FuzzHelpers.safe_get_state(game_id)

          if final != nil and final.status == :finished do
            # Each team should have independent scores
            Enum.each(final.teams, fn team ->
              expected_score =
                Enum.reduce(team.words, 0, fn w, acc -> acc + String.length(w) end) -
                  length(team.words)

              assert team.score == expected_score,
                     "Team #{team.name}: expected score #{expected_score}, got #{team.score}"
            end)
          end
        end
      end
    end
  end

  describe "team churn in waiting room" do
    property "team churn in waiting room" do
      check all(
              num_players <- StreamData.integer(2..8),
              churn_seeds <- GameGenerators.seed_list_gen(10, 40),
              max_runs: 50
            ) do
        game_id = FuzzHelpers.setup_waiting_game(num_players)

        # Run churn actions
        Enum.each(churn_seeds, fn seed ->
          if FuzzHelpers.game_alive?(game_id) do
            {:ok, state} = Game.get_state(game_id)

            if state.status == :waiting do
              s1 = FuzzHelpers.sub_seed(seed, 1)
              s2 = FuzzHelpers.sub_seed(seed, 2)
              player_idx = trunc(s1 * length(state.players)) + 1
              player_idx = min(player_idx, length(state.players))

              cond do
                seed < 0.2 and length(state.teams) < Config.max_teams() ->
                  Game.create_team(
                    game_id,
                    "token_#{player_idx}",
                    "team_#{trunc(s2 * 999)}"
                  )

                seed < 0.4 and length(state.teams) > 0 ->
                  team = FuzzHelpers.pick_from(state.teams, s2)

                  if team do
                    Game.join_team(game_id, "token_#{player_idx}", team.id)
                  end

                seed < 0.55 ->
                  Game.leave_waiting_game(game_id, "token_#{player_idx}")

                seed < 0.65 ->
                  Game.quit_game(game_id, "token_#{player_idx}")

                seed < 0.80 ->
                  # Rejoin a player who left
                  new_idx = length(state.players) + 1
                  Game.join_game(game_id, "player_#{new_idx}", "token_#{new_idx}")

                true ->
                  :noop
              end
            end
          end
        end)

        if FuzzHelpers.game_alive?(game_id) do
          {:ok, state} = Game.get_state(game_id)

          if state.status == :waiting do
            # No orphan teams (teams without players assigned)
            team_ids_with_players =
              state.players_teams
              |> Map.values()
              |> MapSet.new()

            Enum.each(state.teams, fn team ->
              assert MapSet.member?(team_ids_with_players, team.id),
                     "Orphan team found: #{team.name} (id: #{team.id})"
            end)

            # Team count within limits
            assert length(state.teams) <= Config.max_teams()

            # No duplicate team names
            team_names = Enum.map(state.teams, & &1.name)
            assert length(team_names) == length(Enum.uniq(team_names))

            # Try to start game if we have players
            if length(state.players) > 0 do
              result = Game.start_game(game_id, "token_1")

              if result == :ok do
                {:ok, playing_state} = Game.get_state(game_id)
                assert playing_state.status == :playing
                FuzzHelpers.check_invariants!(game_id)
              end
            end
          end
        end
      end
    end
  end

  describe "max_teams boundary" do
    test "max_teams boundary" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      max_teams = Config.max_teams()

      # Join players one at a time. Each auto-creates their own team.
      # After max_teams players, every new player auto-assigns to first team.
      for i <- 1..max_teams do
        :ok = Game.join_game(game_id, "player_#{i}", "token_#{i}")
      end

      {:ok, state} = Game.get_state(game_id)
      assert length(state.teams) == max_teams

      # Join one more player - should be auto-assigned to first team since max reached
      overflow_idx = max_teams + 1
      :ok = Game.join_game(game_id, "player_#{overflow_idx}", "token_#{overflow_idx}")

      {:ok, mid_state} = Game.get_state(game_id)
      # Team count should still be max_teams (overflow player joined existing team)
      assert length(mid_state.teams) == max_teams

      # Try to create a new team - should fail since max already reached
      result = Game.create_team(game_id, "token_#{overflow_idx}", "team_overflow")
      assert result == {:error, :no_more_teams_allowed}

      {:ok, final_state} = Game.get_state(game_id)
      assert length(final_state.teams) == max_teams

      # The overflow player should be assigned to a team
      overflow_team = Map.get(final_state.players_teams, "player_#{overflow_idx}")
      assert overflow_team != nil, "Overflow player should be assigned to a team"

      FuzzHelpers.check_invariants!(game_id)
    end
  end

  describe "team name collisions" do
    test "team name collisions" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player_1", "token_1")
      :ok = Game.join_game(game_id, "player_2", "token_2")
      :ok = Game.join_game(game_id, "player_3", "token_3")

      # Create team "Alpha"
      :ok = Game.create_team(game_id, "token_1", "Alpha")

      # Try to create another team with same name
      result = Game.create_team(game_id, "token_2", "Alpha")
      assert result == {:error, :team_name_taken}

      # Player named "Alpha" can't exist because join auto-creates a team with the player's name
      # But we can test that a player's name-based team prevents creating a team with that name
      # Player_1's default team was "player_1" before they created "Alpha"
      # Let's test: creating a team with a player's name
      result = Game.create_team(game_id, "token_3", "player_2")
      assert result == {:error, :team_name_taken}

      {:ok, state} = Game.get_state(game_id)

      team_names = Enum.map(state.teams, & &1.name)

      assert length(team_names) == length(Enum.uniq(team_names)),
             "Team names should be unique"

      FuzzHelpers.check_invariants!(game_id)
    end
  end

  describe "balanced 2v2 game" do
    test "balanced 2v2 game plays correctly" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()
      :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)

      # Join 4 players
      for i <- 1..4 do
        :ok = Game.join_game(game_id, "player_#{i}", "token_#{i}")
      end

      # Create two teams
      :ok = Game.create_team(game_id, "token_1", "team_a")
      {:ok, state} = Game.get_state(game_id)
      team_a = Enum.find(state.teams, fn t -> t.name == "team_a" end)

      :ok = Game.join_team(game_id, "token_2", team_a.id)

      :ok = Game.create_team(game_id, "token_3", "team_b")
      {:ok, state} = Game.get_state(game_id)
      team_b = Enum.find(state.teams, fn t -> t.name == "team_b" end)

      :ok = Game.join_team(game_id, "token_4", team_b.id)

      :ok = Game.start_game(game_id, "token_1")

      {:ok, playing_state} = Game.get_state(game_id)
      assert playing_state.status == :playing
      assert length(playing_state.teams) == 2

      # Play through: flip, claim, try steals
      FuzzHelpers.flip_n_letters(game_id, 15)

      {:ok, state} = Game.get_state(game_id)

      # Try claims for both teams
      claimable = FuzzHelpers.find_claimable_words_from_center(state.center)

      claimed_words =
        claimable
        |> Enum.take(4)
        |> Enum.with_index()
        |> Enum.reduce([], fn {word, idx}, acc ->
          # Alternate between teams
          token = if rem(idx, 2) == 0, do: "token_1", else: "token_3"

          case Game.claim_word(game_id, token, word) do
            :ok -> [word | acc]
            {:error, _} -> acc
          end
        end)

      if length(claimed_words) > 0 do
        {:ok, mid_state} = Game.get_state(game_id)

        # Words should be distributed across teams
        all_words = Enum.flat_map(mid_state.teams, & &1.words)
        assert length(all_words) == length(Enum.uniq(all_words))

        # Try steals between teams
        steals = FuzzHelpers.find_valid_steals(mid_state)

        case steals do
          [{_old, new_word} | _] ->
            Game.claim_word(game_id, "token_1", new_word)

          [] ->
            :ok
        end
      end

      # Finish game
      FuzzHelpers.drain_pool_and_end_game(game_id, 4)
      FuzzHelpers.wait_for_game_end(game_id, 3000)

      final = FuzzHelpers.safe_get_state(game_id)

      if final != nil and final.status == :finished do
        assert length(final.teams) == 2

        Enum.each(final.teams, fn team ->
          assert is_integer(team.score)

          expected_score =
            Enum.reduce(team.words, 0, fn w, acc -> acc + String.length(w) end) -
              length(team.words)

          assert team.score == expected_score
        end)

        FuzzHelpers.check_invariants!(game_id)
      end
    end
  end

  describe "self-steal within same team" do
    test "self-steal within same team works" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()
      :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)

      # 2 players, same team
      :ok = Game.join_game(game_id, "player_1", "token_1")
      :ok = Game.join_game(game_id, "player_2", "token_2")

      :ok = Game.create_team(game_id, "token_1", "solo_team")
      {:ok, state} = Game.get_state(game_id)
      team = Enum.find(state.teams, fn t -> t.name == "solo_team" end)
      :ok = Game.join_team(game_id, "token_2", team.id)

      :ok = Game.start_game(game_id, "token_1")

      # Flip lots of letters
      FuzzHelpers.flip_n_letters(game_id, 20)

      {:ok, state} = Game.get_state(game_id)
      claimable = FuzzHelpers.find_claimable_words_from_center(state.center)

      # Try each candidate until one succeeds
      claimed =
        Enum.reduce_while(claimable, nil, fn word, _acc ->
          case Game.claim_word(game_id, "token_1", word) do
            :ok -> {:halt, word}
            {:error, _} -> {:cont, nil}
          end
        end)

      case claimed do
        nil ->
          :ok

        word ->
          {:ok, post_claim} = Game.get_state(game_id)
          [team] = post_claim.teams
          assert word in team.words

          # Try to find a self-steal (same team steals own word)
          FuzzHelpers.flip_n_letters(game_id, 10)

          {:ok, state2} = Game.get_state(game_id)
          steals = FuzzHelpers.find_valid_steals(state2)

          # Filter for steals of our word
          self_steals = Enum.filter(steals, fn {old, _new} -> old == word end)

          case self_steals do
            [{_old_word, new_word} | _] ->
              result = Game.claim_word(game_id, "token_1", new_word)

              if result == :ok do
                {:ok, post_steal} = Game.get_state(game_id)

                # Should still be 1 team
                assert length(post_steal.teams) == 1
                [team] = post_steal.teams

                # Old word removed, new word added
                refute word in team.words,
                       "Old word should be removed after self-steal"

                assert new_word in team.words,
                       "New word should be on the same team"
              end

            [] ->
              :ok
          end

          FuzzHelpers.check_invariants!(game_id)
      end
    end
  end
end

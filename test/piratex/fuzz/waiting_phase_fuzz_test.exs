defmodule Piratex.WaitingPhaseFuzzTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Piratex.FuzzHelpers
  alias Piratex.GameGenerators
  alias Piratex.Game
  alias Piratex.Config

  @moduletag :fuzz

  setup do
    FuzzHelpers.ensure_dictionary_started()
    :ok
  end

  describe "waiting phase churn" do
    property "never crashes regardless of join/leave/team/quit churn" do
      check all(
              num_initial_players <- StreamData.integer(2..10),
              seeds <- GameGenerators.seed_list_gen(30, 80),
              max_runs: 50
            ) do
        {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

        # Join initial players
        for i <- 1..num_initial_players do
          Game.join_game(game_id, "player_#{i}", "token_#{i}")
        end

        next_player_idx = num_initial_players + 1

        {_next_idx, _} =
          Enum.reduce(seeds, {next_player_idx, :ok}, fn seed, {next_idx, _} ->
            s1 = FuzzHelpers.sub_seed(seed, 1)
            s2 = FuzzHelpers.sub_seed(seed, 2)

            state = FuzzHelpers.safe_get_state(game_id)

            unless state == nil or state.status != :waiting do
              player_count = length(state.players)

              cond do
                # Join new player
                seed < 0.15 and player_count < 20 ->
                  Game.join_game(game_id, "player_#{next_idx}", "token_#{next_idx}")
                  {next_idx + 1, :ok}

                # Create team
                seed < 0.30 and player_count > 0 ->
                  idx = trunc(s1 * player_count) + 1
                  Game.create_team(game_id, "token_#{idx}", "team_#{trunc(s2 * 999)}")
                  {next_idx, :ok}

                # Join team
                seed < 0.45 and length(state.teams) > 0 and player_count > 0 ->
                  player_idx = trunc(s1 * player_count) + 1
                  team = FuzzHelpers.pick_from(state.teams, s2)

                  if team do
                    Game.join_team(game_id, "token_#{player_idx}", team.id)
                  end

                  {next_idx, :ok}

                # Leave
                seed < 0.55 and player_count > 1 ->
                  idx = trunc(s1 * player_count) + 1
                  Game.leave_waiting_game(game_id, "token_#{idx}")
                  {next_idx, :ok}

                # Quit
                seed < 0.65 and player_count > 0 ->
                  idx = trunc(s1 * player_count) + 1
                  Game.quit_game(game_id, "token_#{idx}")
                  {next_idx, :ok}

                # Rejoin
                seed < 0.75 and player_count > 0 ->
                  idx = trunc(s1 * player_count) + 1
                  Game.rejoin_game(game_id, "player_#{idx}", "token_#{idx}")
                  {next_idx, :ok}

                # Bad token
                seed < 0.90 ->
                  bad_token = "bad_token_#{trunc(s1 * 999)}"

                  cond do
                    s2 < 0.25 -> Game.join_game(game_id, "bad_name", bad_token)
                    s2 < 0.50 -> Game.create_team(game_id, bad_token, "bad_team")
                    s2 < 0.75 -> Game.leave_waiting_game(game_id, bad_token)
                    true -> Game.start_game(game_id, bad_token)
                  end

                  {next_idx, :ok}

                # Noop
                true ->
                  {next_idx, :ok}
              end
            else
              {next_idx, :ok}
            end
          end)

        # Check invariants after all churn
        FuzzHelpers.check_invariants!(game_id)

        # Try to start the game if enough players remain
        state = FuzzHelpers.safe_get_state(game_id)

        if state != nil and state.status == :waiting do
          alive = FuzzHelpers.alive_player_count(state)

          if alive >= 1 do
            # Find a playing player to start
            playing_idx =
              state.players
              |> Enum.with_index(1)
              |> Enum.find(fn {p, _} -> p.status == :playing end)

            case playing_idx do
              {_, idx} ->
                result = Game.start_game(game_id, "token_#{idx}")

                case result do
                  :ok ->
                    new_state = FuzzHelpers.safe_get_state(game_id)

                    if new_state do
                      assert new_state.status == :playing
                    end

                  {:error, _} ->
                    :ok
                end

              nil ->
                :ok
            end
          end

          FuzzHelpers.check_invariants!(game_id)
        end
      end
    end

    property "team assignment consistent through churn" do
      check all(
              num_players <- StreamData.integer(3..8),
              seeds <- GameGenerators.seed_list_gen(20, 60),
              max_runs: 50
            ) do
        {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

        for i <- 1..num_players do
          Game.join_game(game_id, "player_#{i}", "token_#{i}")
        end

        next_idx = num_players + 1

        Enum.reduce(seeds, next_idx, fn seed, nidx ->
          s1 = FuzzHelpers.sub_seed(seed, 1)
          s2 = FuzzHelpers.sub_seed(seed, 2)

          state = FuzzHelpers.safe_get_state(game_id)

          unless state == nil or state.status != :waiting do
            player_count = length(state.players)

            new_nidx =
              cond do
                seed < 0.20 and player_count < 15 ->
                  Game.join_game(game_id, "player_#{nidx}", "token_#{nidx}")
                  nidx + 1

                seed < 0.40 and player_count > 0 ->
                  idx = trunc(s1 * player_count) + 1
                  Game.create_team(game_id, "token_#{idx}", "fteam_#{trunc(s2 * 999)}")
                  nidx

                seed < 0.60 and length(state.teams) > 0 and player_count > 0 ->
                  pidx = trunc(s1 * player_count) + 1
                  team = FuzzHelpers.pick_from(state.teams, s2)
                  if team, do: Game.join_team(game_id, "token_#{pidx}", team.id)
                  nidx

                seed < 0.75 and player_count > 1 ->
                  idx = trunc(s1 * player_count) + 1
                  Game.leave_waiting_game(game_id, "token_#{idx}")
                  nidx

                seed < 0.85 and player_count > 0 ->
                  idx = trunc(s1 * player_count) + 1
                  Game.quit_game(game_id, "token_#{idx}")
                  nidx

                true ->
                  nidx
              end

            # Check team assignment consistency after every action
            updated_state = FuzzHelpers.safe_get_state(game_id)

            if updated_state != nil and updated_state.status == :waiting do
              team_ids = MapSet.new(updated_state.teams, & &1.id)

              # Every player in players_teams points to an existing team
              Enum.each(updated_state.players_teams, fn {_name, tid} ->
                assert MapSet.member?(team_ids, tid),
                       "players_teams references nonexistent team #{tid}"
              end)

              # Team count within limits
              assert length(updated_state.teams) <= Config.max_teams(),
                     "Team count #{length(updated_state.teams)} exceeds max #{Config.max_teams()}"
            end

            new_nidx
          else
            nidx
          end
        end)

        FuzzHelpers.check_invariants!(game_id)
      end
    end

    property "max_teams boundary is respected" do
      check all(
              extra_seeds <-
                StreamData.list_of(
                  StreamData.float(min: 0.0, max: 1.0),
                  min_length: 5,
                  max_length: 20
                ),
              max_runs: 30
            ) do
        {:ok, game_id} = Piratex.DynamicSupervisor.new_game()
        max_teams = Config.max_teams()

        # Join 1 player first — auto-creates 1 team
        :ok = Game.join_game(game_id, "player_1", "token_1")

        # Now create custom teams up to the max (player_1 already has 1 auto-team,
        # so each new create_team replaces player_1's membership but net adds a team)
        # Join more players to be team creators
        for i <- 2..(max_teams + 2) do
          Game.join_game(game_id, "player_#{i}", "token_#{i}")
        end

        # Auto-join already created max_teams worth of teams (one per player, up to max).
        # Verify we're at the limit.
        state = FuzzHelpers.safe_get_state(game_id)
        current_teams = length(state.teams)
        assert current_teams <= max_teams

        # If we're not yet at max, create teams until we reach it
        if current_teams < max_teams do
          for i <- 1..(max_teams - current_teams) do
            Game.create_team(game_id, "token_#{i}", "custom_team_#{i}")
          end
        end

        state = FuzzHelpers.safe_get_state(game_id)
        assert length(state.teams) <= max_teams

        # Attempting to create one more team should fail
        overflow_idx = max_teams + 1
        result = Game.create_team(game_id, "token_#{overflow_idx}", "overflow_team")
        assert match?({:error, _}, result)

        # Team count must not exceed max
        state = FuzzHelpers.safe_get_state(game_id)
        assert length(state.teams) <= max_teams

        # Additional random churn should not breach the limit
        Enum.each(extra_seeds, fn seed ->
          s1 = FuzzHelpers.sub_seed(seed, 1)
          idx = trunc(s1 * (max_teams + 2)) + 1

          cond do
            seed < 0.4 ->
              Game.create_team(game_id, "token_#{idx}", "extra_team_#{trunc(seed * 999)}")

            seed < 0.7 and state.teams != [] ->
              team = FuzzHelpers.pick_from(state.teams, s1)
              if team, do: Game.join_team(game_id, "token_#{idx}", team.id)

            true ->
              :ok
          end
        end)

        state = FuzzHelpers.safe_get_state(game_id)
        assert length(state.teams) <= max_teams
        FuzzHelpers.check_invariants!(game_id)
      end
    end
  end
end

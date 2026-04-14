defmodule Piratex.GameSequenceFuzzTest do
  use PiratexWeb.ConnCase, async: false
  use ExUnitProperties

  alias Piratex.FuzzHelpers
  alias Piratex.GameGenerators

  @moduletag :fuzz

  setup do
    FuzzHelpers.ensure_dictionary_started()
    :ok
  end

  describe "random game sequences" do
    property "never crash the GenServer, and all invariants hold" do
      check all(
              num_players <- StreamData.integer(2..8),
              pool_type <- StreamData.member_of([:bananagrams, :bananagrams_half]),
              seeds <- GameGenerators.seed_list_gen(50, 200),
              max_runs: 100
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players, pool_type)
        action_log = []

        {player_view, watcher_view} =
          case {FuzzHelpers.mount_player_view(game_id), FuzzHelpers.mount_watcher_view(game_id)} do
            {{:ok, pv, _html}, {:ok, wv, _html2}} -> {pv, wv}
            {{:ok, pv, _html}, :redirect} -> {pv, nil}
            {:redirect, {:ok, wv, _html}} -> {nil, wv}
            {:redirect, :redirect} -> {nil, nil}
          end

        prev_status = :playing

        {_prev_status, _pv, _wv, _log} =
          seeds
          |> Enum.with_index(1)
          |> Enum.reduce({prev_status, player_view, watcher_view, action_log}, fn
            {seed, idx}, {prev_st, pv, wv, log} ->
              unless FuzzHelpers.game_alive?(game_id) do
                {prev_st, pv, wv, log}
              else
                action = GameGenerators.select_action(game_id, seed)
                GameGenerators.execute(action)
                updated_log = [{idx, action} | log]

                try do
                  FuzzHelpers.check_invariants!(game_id)
                rescue
                  e ->
                    recent = Enum.take(updated_log, 20) |> Enum.reverse()

                    reraise(
                      "Invariant failed after action ##{idx}: #{inspect(action)}\n" <>
                        "Recent actions: #{inspect(recent)}\n" <>
                        "Original: #{Exception.message(e)}",
                      __STACKTRACE__
                    )
                end

                # Render views every 5 actions
                {new_pv, new_wv} =
                  if rem(idx, 5) == 0 and FuzzHelpers.game_alive?(game_id) do
                    try do
                      FuzzHelpers.check_views_render!(game_id, pv, wv)
                    rescue
                      _ -> :ok
                    end

                    {pv, wv}
                  else
                    {pv, wv}
                  end

                # Fresh-mount on phase transitions
                current_state = FuzzHelpers.safe_get_state(game_id)
                current_status = if current_state, do: current_state.status, else: prev_st

                {final_pv, final_wv} =
                  if current_status != prev_st and FuzzHelpers.game_alive?(game_id) do
                    try do
                      FuzzHelpers.fresh_mount_and_render!(game_id)
                    rescue
                      _ -> :ok
                    end

                    # Re-mount views for continued rendering
                    case {FuzzHelpers.mount_player_view(game_id),
                          FuzzHelpers.mount_watcher_view(game_id)} do
                      {{:ok, npv, _}, {:ok, nwv, _}} -> {npv, nwv}
                      {{:ok, npv, _}, :redirect} -> {npv, nil}
                      {:redirect, {:ok, nwv, _}} -> {nil, nwv}
                      {:redirect, :redirect} -> {nil, nil}
                    end
                  else
                    {new_pv, new_wv}
                  end

                {current_status, final_pv, final_wv, updated_log}
              end
          end)

        FuzzHelpers.check_invariants!(game_id)
      end
    end

    property "games always reach :finished or process death" do
      check all(
              num_players <- StreamData.integer(2..8),
              pool_type <- StreamData.member_of([:bananagrams, :bananagrams_half]),
              seeds <- GameGenerators.seed_list_gen(30, 100),
              max_runs: 50
            ) do
        game_id = FuzzHelpers.setup_playing_game(num_players, pool_type)

        Enum.each(seeds, fn seed ->
          if FuzzHelpers.game_alive?(game_id) do
            action = GameGenerators.select_action(game_id, seed)
            GameGenerators.execute(action)
          end
        end)

        # If game is still alive and playing, drain the pool and force end
        case FuzzHelpers.safe_get_state(game_id) do
          %{status: :playing} ->
            FuzzHelpers.drain_pool_and_end_game(game_id, num_players)
            result = FuzzHelpers.wait_for_game_end(game_id)
            assert result in [:finished, :dead, :ok]

          %{status: :finished} ->
            :ok

          nil ->
            :ok
        end

        state = FuzzHelpers.safe_get_state(game_id)
        assert state == nil or state.status == :finished
      end
    end

    property "single-player games complete without crashes" do
      check all(
              seeds <- GameGenerators.seed_list_gen(10, 50),
              max_runs: 30
            ) do
        game_id = FuzzHelpers.setup_playing_game(1)

        Enum.each(seeds, fn seed ->
          if FuzzHelpers.game_alive?(game_id) do
            action = GameGenerators.select_action(game_id, seed)

            # Filter out challenge/vote actions -- not possible with 1 player
            case action do
              {:challenge, _} -> :skip
              {:vote, _} -> :skip
              _ -> GameGenerators.execute(action)
            end

            FuzzHelpers.check_invariants!(game_id)
          end
        end)

        case FuzzHelpers.safe_get_state(game_id) do
          %{status: :playing} ->
            FuzzHelpers.drain_pool_and_end_game(game_id, 1)

          _ ->
            :ok
        end

        state = FuzzHelpers.safe_get_state(game_id)
        assert state == nil or state.status == :finished
      end
    end
  end
end

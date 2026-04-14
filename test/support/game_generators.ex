defmodule Piratex.GameGenerators do
  @moduledoc """
  State-aware action generators for fuzz testing the Game GenServer.

  Uses a seed-based approach: StreamData generates a list of float seeds,
  then at execution time each seed + current game state deterministically
  selects an action with full parameters. This preserves StreamData's
  shrinking capability while enabling state-aware generation.
  """

  alias Piratex.FuzzHelpers
  alias Piratex.Game
  alias Piratex.ChallengeService

  # ──────────────────────────────────────────────
  # Main action selection
  # ──────────────────────────────────────────────

  @doc """
  Given the current game state and a seed (0.0..1.0), deterministically
  selects and returns an {action, params} tuple.
  """
  def select_action(game_id, seed) do
    case FuzzHelpers.safe_get_state(game_id) do
      nil ->
        {:noop, %{}}

      state ->
        select_action_for_state(game_id, state, seed)
    end
  end

  defp select_action_for_state(game_id, state, seed) do
    s1 = FuzzHelpers.sub_seed(seed, 1)
    s2 = FuzzHelpers.sub_seed(seed, 2)
    s3 = FuzzHelpers.sub_seed(seed, 3)

    case state.status do
      :waiting ->
        select_waiting_action(game_id, state, seed, s1, s2)

      :playing ->
        if ChallengeService.open_challenge?(state) do
          select_challenge_open_action(game_id, state, seed, s1, s2, s3)
        else
          if state.letter_pool_count == 0 do
            select_pool_empty_action(game_id, state, seed, s1, s2, s3)
          else
            select_normal_playing_action(game_id, state, seed, s1, s2, s3)
          end
        end

      :finished ->
        select_finished_action(game_id, state, seed, s1)

      _ ->
        {:noop, %{}}
    end
  end

  # ──────────────────────────────────────────────
  # Waiting phase actions
  # ──────────────────────────────────────────────

  defp select_waiting_action(game_id, state, seed, s1, s2) do
    player_count = length(state.players)

    cond do
      seed < 0.15 and player_count < 20 ->
        idx = player_count + 1
        {:join, %{game_id: game_id, name: "player_#{idx}", token: "token_#{idx}"}}

      seed < 0.30 and player_count > 0 ->
        idx = trunc(s1 * player_count) + 1

        {:create_team,
         %{game_id: game_id, token: "token_#{idx}", name: "team_#{trunc(s2 * 999)}"}}

      seed < 0.45 and length(state.teams) > 0 and player_count > 0 ->
        player_idx = trunc(s1 * player_count) + 1
        team = FuzzHelpers.pick_from(state.teams, s2)
        {:join_team, %{game_id: game_id, token: "token_#{player_idx}", team_id: team.id}}

      seed < 0.55 and player_count > 1 ->
        idx = trunc(s1 * player_count) + 1
        {:leave, %{game_id: game_id, token: "token_#{idx}"}}

      seed < 0.65 and player_count > 0 ->
        idx = trunc(s1 * player_count) + 1
        {:quit, %{game_id: game_id, token: "token_#{idx}"}}

      seed < 0.75 ->
        {:bad_token, %{game_id: game_id, token: "bad_token_#{trunc(s1 * 999)}", sub_seed: s2}}

      seed < 0.85 and player_count > 0 ->
        idx = trunc(s1 * player_count) + 1
        {:rejoin, %{game_id: game_id, name: "player_#{idx}", token: "token_#{idx}"}}

      true ->
        {:cross_phase, %{game_id: game_id, sub_seed: s1, token: "token_1"}}
    end
  end

  # ──────────────────────────────────────────────
  # Normal playing actions (pool has letters, no challenge)
  # ──────────────────────────────────────────────

  defp select_normal_playing_action(game_id, state, seed, s1, s2, s3) do
    cond do
      seed < 0.25 ->
        build_flip(game_id, state, s1)

      seed < 0.40 ->
        build_claim(game_id, state, s1, s2)

      seed < 0.52 ->
        build_steal(game_id, state, s1, s2)

      seed < 0.62 ->
        build_challenge(game_id, state, s1, s2)

      seed < 0.68 ->
        token = FuzzHelpers.pick_alive_token(state, s1)
        {:end_vote, %{game_id: game_id, token: token}}

      seed < 0.74 ->
        build_quit(game_id, state, s1)

      seed < 0.80 ->
        build_chat(game_id, state, s1, s2)

      seed < 0.85 ->
        {:bad_token, %{game_id: game_id, token: "bad_#{trunc(s1 * 999)}", sub_seed: s2}}

      seed < 0.90 ->
        build_quit_player_action(game_id, state, s1, s2)

      seed < 0.95 ->
        {:cross_phase,
         %{game_id: game_id, sub_seed: s1, token: FuzzHelpers.pick_alive_token(state, s2)}}

      true ->
        build_degenerate(game_id, state, s1, s2, s3)
    end
  end

  # ──────────────────────────────────────────────
  # Challenge open actions
  # ──────────────────────────────────────────────

  defp select_challenge_open_action(game_id, state, seed, s1, s2, _s3) do
    cond do
      seed < 0.40 ->
        build_vote(game_id, state, s1, s2)

      seed < 0.55 ->
        build_quit(game_id, state, s1)

      seed < 0.65 ->
        build_claim(game_id, state, s1, s2)

      seed < 0.75 ->
        build_chat(game_id, state, s1, s2)

      seed < 0.85 ->
        {:bad_token, %{game_id: game_id, token: "bad_#{trunc(s1 * 999)}", sub_seed: s2}}

      seed < 0.92 ->
        build_quit_player_action(game_id, state, s1, s2)

      true ->
        {:cross_phase,
         %{game_id: game_id, sub_seed: s1, token: FuzzHelpers.pick_alive_token(state, s2)}}
    end
  end

  # ──────────────────────────────────────────────
  # Pool empty actions
  # ──────────────────────────────────────────────

  defp select_pool_empty_action(game_id, state, seed, s1, s2, s3) do
    cond do
      seed < 0.25 ->
        build_claim(game_id, state, s1, s2)

      seed < 0.40 ->
        build_steal(game_id, state, s1, s2)

      seed < 0.55 ->
        token = FuzzHelpers.pick_alive_token(state, s1)
        {:end_vote, %{game_id: game_id, token: token}}

      seed < 0.65 ->
        build_challenge(game_id, state, s1, s2)

      seed < 0.72 ->
        build_quit(game_id, state, s1)

      seed < 0.80 ->
        build_chat(game_id, state, s1, s2)

      seed < 0.88 ->
        build_flip(game_id, state, s1)

      seed < 0.94 ->
        {:bad_token, %{game_id: game_id, token: "bad_#{trunc(s1 * 999)}", sub_seed: s2}}

      true ->
        build_degenerate(game_id, state, s1, s2, s3)
    end
  end

  # ──────────────────────────────────────────────
  # Finished phase actions (all should error)
  # ──────────────────────────────────────────────

  defp select_finished_action(game_id, _state, _seed, s1) do
    {:cross_phase, %{game_id: game_id, sub_seed: s1, token: "token_1"}}
  end

  # ──────────────────────────────────────────────
  # Action builders
  # ──────────────────────────────────────────────

  defp build_flip(game_id, state, s1) do
    token =
      if s1 < 0.8 do
        FuzzHelpers.turn_player_token(state)
      else
        FuzzHelpers.pick_alive_token(state, s1)
      end

    {:flip, %{game_id: game_id, token: token}}
  end

  defp build_claim(game_id, state, s1, s2) do
    claimable = FuzzHelpers.find_claimable_words_from_center(state.center)
    words_in_play = Enum.flat_map(state.teams, & &1.words)

    claimable = Enum.reject(claimable, &(&1 in words_in_play))

    word =
      case claimable do
        [] -> FuzzHelpers.pick_from(FuzzHelpers.fuzz_dictionary(), s2) || "test"
        list -> FuzzHelpers.pick_from(list, s2)
      end

    token = FuzzHelpers.pick_alive_token(state, s1)
    {:claim, %{game_id: game_id, token: token, word: word}}
  end

  defp build_steal(game_id, state, s1, s2) do
    steals = FuzzHelpers.find_valid_steals(state)
    words_in_play = Enum.flat_map(state.teams, & &1.words)

    steals = Enum.reject(steals, fn {_, new_word} -> new_word in words_in_play end)

    case steals do
      [] ->
        build_claim(game_id, state, s1, s2)

      list ->
        {_old_word, new_word} = FuzzHelpers.pick_from(list, s2)
        token = FuzzHelpers.pick_alive_token(state, s1)
        {:claim, %{game_id: game_id, token: token, word: new_word}}
    end
  end

  defp build_challenge(game_id, state, s1, s2) do
    words_in_play = Enum.flat_map(state.teams, & &1.words)

    challengeable =
      state.history
      |> Enum.take(5)
      |> Enum.filter(fn ws ->
        ws.thief_word in words_in_play and
          not MapSet.member?(state.challenged_words, {ws.victim_word, ws.thief_word})
      end)

    case challengeable do
      [] ->
        token = FuzzHelpers.pick_alive_token(state, s1)
        {:challenge, %{game_id: game_id, token: token, word: "nonexistent_#{trunc(s2 * 999)}"}}

      list ->
        ws = FuzzHelpers.pick_from(list, s2)
        token = FuzzHelpers.pick_alive_token(state, s1)
        {:challenge, %{game_id: game_id, token: token, word: ws.thief_word}}
    end
  end

  defp build_vote(game_id, state, s1, s2) do
    case state.challenges do
      [] ->
        {:noop, %{}}

      [challenge | _] ->
        token = FuzzHelpers.pick_alive_token(state, s1)
        vote = s2 < 0.5
        {:vote, %{game_id: game_id, token: token, challenge_id: challenge.id, vote: vote}}
    end
  end

  defp build_quit(game_id, state, s1) do
    token = FuzzHelpers.pick_alive_token(state, s1)
    {:quit, %{game_id: game_id, token: token}}
  end

  defp build_chat(game_id, state, s1, s2) do
    token = FuzzHelpers.pick_alive_token(state, s1)
    msg = "fuzz_#{trunc(s2 * 9999)}"
    {:chat, %{game_id: game_id, token: token, message: msg}}
  end

  defp build_quit_player_action(game_id, state, s1, s2) do
    case FuzzHelpers.pick_quit_token(state, s1) do
      nil ->
        {:noop, %{}}

      token ->
        action_seed = s2

        cond do
          action_seed < 0.15 ->
            {:flip, %{game_id: game_id, token: token}}

          action_seed < 0.30 ->
            {:claim, %{game_id: game_id, token: token, word: "test"}}

          action_seed < 0.45 ->
            {:challenge, %{game_id: game_id, token: token, word: "test"}}

          action_seed < 0.60 ->
            {:vote, %{game_id: game_id, token: token, challenge_id: 0, vote: false}}

          action_seed < 0.75 ->
            {:chat, %{game_id: game_id, token: token, message: "hi"}}

          action_seed < 0.85 ->
            {:end_vote, %{game_id: game_id, token: token}}

          true ->
            {:quit, %{game_id: game_id, token: token}}
        end
    end
  end

  defp build_degenerate(game_id, state, s1, s2, _s3) do
    token = FuzzHelpers.pick_alive_token(state, s1)

    cond do
      s2 < 0.15 -> {:claim, %{game_id: game_id, token: token, word: ""}}
      s2 < 0.30 -> {:claim, %{game_id: game_id, token: token, word: String.duplicate("a", 500)}}
      s2 < 0.45 -> {:chat, %{game_id: game_id, token: token, message: ""}}
      s2 < 0.60 -> {:chat, %{game_id: game_id, token: token, message: String.duplicate("x", 500)}}
      s2 < 0.75 -> {:vote, %{game_id: game_id, token: token, challenge_id: -1, vote: false}}
      s2 < 0.85 -> {:vote, %{game_id: game_id, token: token, challenge_id: 999_999, vote: true}}
      true -> {:join_team, %{game_id: game_id, token: token, team_id: -1}}
    end
  end

  # ──────────────────────────────────────────────
  # Action execution
  # ──────────────────────────────────────────────

  @doc """
  Executes the given {action, params} tuple against the game.
  Returns :ok for expected outcomes (success or domain error).
  Raises if the Game GenServer crashes during the action.
  """
  def execute({:noop, _params}), do: :ok

  def execute({:flip, %{game_id: gid, token: token}}) do
    safe_call(gid, fn -> Game.flip_letter(gid, token) end)
  end

  def execute({:claim, %{game_id: gid, token: token, word: word}}) do
    safe_call(gid, fn -> Game.claim_word(gid, token, word) end)
  end

  def execute({:challenge, %{game_id: gid, token: token, word: word}}) do
    safe_call(gid, fn -> Game.challenge_word(gid, token, word) end)
  end

  def execute({:vote, %{game_id: gid, token: token, challenge_id: cid, vote: vote}}) do
    safe_call(gid, fn -> Game.challenge_vote(gid, token, cid, vote) end)
  end

  def execute({:end_vote, %{game_id: gid, token: token}}) do
    safe_call(gid, fn -> Game.end_game_vote(gid, token) end)
  end

  def execute({:quit, %{game_id: gid, token: token}}) do
    safe_call(gid, fn ->
      Game.quit_game(gid, token)
      :timer.sleep(5)
    end)
  end

  def execute({:chat, %{game_id: gid, token: token, message: msg}}) do
    safe_call(gid, fn -> Game.send_chat_message(gid, token, msg) end)
  end

  def execute({:join, %{game_id: gid, name: name, token: token}}) do
    safe_call(gid, fn -> Game.join_game(gid, name, token) end)
  end

  def execute({:leave, %{game_id: gid, token: token}}) do
    safe_call(gid, fn -> Game.leave_waiting_game(gid, token) end)
  end

  def execute({:create_team, %{game_id: gid, token: token, name: name}}) do
    safe_call(gid, fn -> Game.create_team(gid, token, name) end)
  end

  def execute({:join_team, %{game_id: gid, token: token, team_id: tid}}) do
    safe_call(gid, fn -> Game.join_team(gid, token, tid) end)
  end

  def execute({:rejoin, %{game_id: gid, name: name, token: token}}) do
    safe_call(gid, fn -> Game.rejoin_game(gid, name, token) end)
  end

  def execute({:bad_token, %{game_id: gid, token: token, sub_seed: s}}) do
    safe_call(gid, fn ->
      cond do
        s < 0.08 -> Game.join_game(gid, "bad_name", token)
        s < 0.16 -> Game.create_team(gid, token, "bad_team")
        s < 0.24 -> Game.join_team(gid, token, 1)
        s < 0.32 -> Game.leave_waiting_game(gid, token)
        s < 0.40 -> Game.start_game(gid, token)
        s < 0.48 -> Game.flip_letter(gid, token)
        s < 0.56 -> Game.claim_word(gid, token, "test")
        s < 0.64 -> Game.challenge_word(gid, token, "test")
        s < 0.72 -> Game.challenge_vote(gid, token, 0, false)
        s < 0.80 -> Game.send_chat_message(gid, token, "hi")
        s < 0.88 -> Game.end_game_vote(gid, token)
        s < 0.94 -> Game.quit_game(gid, token)
        true -> Game.rejoin_game(gid, "bad_name", token)
      end
    end)
  end

  def execute({:cross_phase, %{game_id: gid, sub_seed: s, token: token}}) do
    safe_call(gid, fn ->
      cond do
        s < 0.14 -> Game.create_team(gid, token, "fuzz_team")
        s < 0.28 -> Game.join_team(gid, token, 999)
        s < 0.42 -> Game.start_game(gid, token)
        s < 0.56 -> Game.set_letter_pool_type(gid, :bananagrams)
        s < 0.70 -> Game.join_game(gid, "fuzz_player", "fuzz_token")
        s < 0.84 -> Game.leave_waiting_game(gid, token)
        true -> Game.flip_letter(gid, token)
      end
    end)
  end

  # Monitors the game process during a call to detect GenServer crashes.
  # Expected shutdowns (normal, shutdown) are allowed. Crashes raise.
  defp safe_call(game_id, fun) do
    case Registry.lookup(Piratex.Game.Registry, game_id) do
      [{pid, _}] ->
        ref = Process.monitor(pid)
        fun.()

        receive do
          {:DOWN, ^ref, :process, ^pid, reason} ->
            unless expected_exit?(reason) do
              raise "Game GenServer (#{game_id}) crashed: #{inspect(reason)}"
            end
        after
          0 ->
            Process.demonitor(ref, [:flush])
        end

      [] ->
        fun.()
    end

    :ok
  end

  defp expected_exit?(:normal), do: true
  defp expected_exit?(:shutdown), do: true
  defp expected_exit?({:shutdown, _}), do: true
  defp expected_exit?(:noproc), do: true
  defp expected_exit?(_), do: false

  # ──────────────────────────────────────────────
  # StreamData helpers (for use in property tests)
  # ──────────────────────────────────────────────

  @doc """
  Generates a list of seeds for driving a fuzz test.
  """
  def seed_list_gen(min_length \\ 20, max_length \\ 200) do
    StreamData.list_of(
      StreamData.float(min: 0.0, max: 1.0),
      min_length: min_length,
      max_length: max_length
    )
  end
end

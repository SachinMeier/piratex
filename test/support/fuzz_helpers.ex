defmodule Piratex.FuzzHelpers do
  @moduledoc """
  Shared helpers for comprehensive fuzz testing of the Game GenServer.
  Provides invariant checks, word-finding utilities, render verification,
  and game setup/teardown helpers.
  """

  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Piratex.Game
  alias Piratex.Config
  alias Piratex.WordClaimService

  @endpoint PiratexWeb.Endpoint

  @fuzz_dictionary Path.join([__DIR__, "../../priv/data/fuzz_dictionary.txt"])
                   |> File.read!()
                   |> String.split("\n", trim: true)

  def fuzz_dictionary, do: @fuzz_dictionary


  # ──────────────────────────────────────────────
  # Game setup helpers
  # ──────────────────────────────────────────────

  def ensure_dictionary_started do
    case Piratex.Dictionary.start_link(nil) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end

  def setup_playing_game(num_players, pool_type \\ :bananagrams_half) do
    {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

    :ok = Game.set_letter_pool_type(game_id, pool_type)

    for i <- 1..num_players do
      :ok = Game.join_game(game_id, "player_#{i}", "token_#{i}")
    end

    :ok = Game.start_game(game_id, "token_1")
    game_id
  end

  def setup_waiting_game(num_players) do
    {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

    for i <- 1..num_players do
      :ok = Game.join_game(game_id, "player_#{i}", "token_#{i}")
    end

    game_id
  end

  def safe_get_state(game_id) do
    case Game.get_state(game_id) do
      {:ok, state} -> state
      {:error, :not_found} -> nil
    end
  rescue
    _ -> nil
  catch
    :exit, _ -> nil
  end

  def game_alive?(game_id) do
    safe_get_state(game_id) != nil
  end

  def get_raw_state(game_id) do
    [{pid, _}] = Registry.lookup(Piratex.Game.Registry, game_id)
    :sys.get_state(pid)
  rescue
    _ -> nil
  catch
    :exit, _ -> nil
  end

  # ──────────────────────────────────────────────
  # Player/token helpers
  # ──────────────────────────────────────────────

  def turn_player_token(state) do
    "token_#{state.turn + 1}"
  end

  def pick_alive_token(state, seed) do
    alive =
      state.players
      |> Enum.with_index(1)
      |> Enum.filter(fn {p, _} -> p.status == :playing end)
      |> Enum.map(fn {_, i} -> i end)

    case alive do
      [] -> "token_1"
      list -> "token_#{pick_from(list, seed)}"
    end
  end

  def pick_quit_token(state, seed) do
    quit =
      state.players
      |> Enum.with_index(1)
      |> Enum.filter(fn {p, _} -> p.status == :quit end)
      |> Enum.map(fn {_, i} -> i end)

    case quit do
      [] -> nil
      list -> "token_#{pick_from(list, seed)}"
    end
  end

  def alive_player_count(state) do
    Enum.count(state.players, fn p -> p.status == :playing end)
  end

  def quit_player_count(state) do
    Enum.count(state.players, fn p -> p.status == :quit end)
  end

  # ──────────────────────────────────────────────
  # Word-finding helpers (delegates to WordClaimService)
  # ──────────────────────────────────────────────

  def find_claimable_words_from_center(center_sorted) do
    center_product = WordClaimService.calculate_word_product(center_sorted)

    @fuzz_dictionary
    |> Enum.filter(fn word ->
      word_product = WordClaimService.calculate_word_product(word)

      String.length(word) >= Config.min_word_length() and
        word_product != 0 and
        rem(center_product, word_product) == 0 and
        match?({true, _}, WordClaimService.attempt_find_center_letters(center_sorted, word_product))
    end)
  end

  def find_valid_steals(state) do
    words_in_play =
      state.teams
      |> Enum.flat_map(& &1.words)

    center_sorted = state.center

    for old_word <- words_in_play,
        old_product = WordClaimService.calculate_word_product(old_word),
        new_word <- @fuzz_dictionary,
        new_word != old_word,
        String.length(new_word) > String.length(old_word),
        new_product = WordClaimService.calculate_word_product(new_word),
        rem(new_product, old_product) == 0,
        needed_product = div(new_product, old_product),
        needed_product > 1,
        center_product = WordClaimService.calculate_word_product(center_sorted),
        rem(center_product, needed_product) == 0,
        match?({true, _}, WordClaimService.attempt_find_center_letters(center_sorted, needed_product)) do
      {old_word, new_word}
    end
  end

  # ──────────────────────────────────────────────
  # Seed-based selection
  # ──────────────────────────────────────────────

  def pick_from(list, seed) when is_list(list) and list != [] do
    idx = trunc(seed * length(list)) |> min(length(list) - 1) |> max(0)
    Enum.at(list, idx)
  end

  def pick_from([], _seed), do: nil

  def sub_seed(seed, offset) do
    frac(seed * 1000 + offset)
  end

  defp frac(f), do: f - Float.floor(f)

  # ──────────────────────────────────────────────
  # Invariant checks
  # ──────────────────────────────────────────────

  def check_invariants!(game_id) do
    case safe_get_state(game_id) do
      nil ->
        :ok

      state ->
        raw = get_raw_state(game_id)
        check_status_valid!(state)
        check_turn_bounds!(state)
        check_letter_conservation!(state, raw)
        check_no_duplicate_names!(state)
        check_valid_team_refs!(state)
        check_challenged_words_type!(state)
        check_active_player_count!(state)
        check_scores_on_finish!(state)
        check_no_duplicate_words!(state)
        check_center_sorted!(raw)
        check_center_set_equal!(raw)
        check_turn_player_not_quit!(state)
        check_team_count!(state)
        check_no_duplicate_team_names!(state)
        check_team_words_disjoint!(state)
        check_activity_feed!(state)
        check_no_open_challenges_on_finish!(state)
        check_no_tokens_leaked!(state)
        :ok
    end
  end

  defp check_status_valid!(state) do
    assert state.status in [:waiting, :playing, :finished],
           "Invalid status: #{inspect(state.status)}"
  end

  defp check_turn_bounds!(state) do
    if state.status == :playing and length(state.players) > 0 do
      assert state.turn >= 0 and state.turn < length(state.players),
             "Turn #{state.turn} out of bounds for #{length(state.players)} players"
    end
  end

  defp check_letter_conservation!(state, raw) do
    if raw != nil and state.status in [:playing, :finished] do
      center_count = length(raw.center)

      words_letter_count =
        raw.teams
        |> Enum.flat_map(& &1.words)
        |> Enum.map(&String.length/1)
        |> Enum.sum()

      pool_count = length(raw.letter_pool)
      total = center_count + words_letter_count + pool_count

      assert total == raw.initial_letter_count,
             "Letter conservation: center=#{center_count} + words=#{words_letter_count} + pool=#{pool_count} = #{total}, expected #{raw.initial_letter_count}"
    end
  end

  defp check_no_duplicate_names!(state) do
    names = Enum.map(state.players, & &1.name)
    assert length(names) == length(Enum.uniq(names)), "Duplicate player names: #{inspect(names)}"
  end

  defp check_valid_team_refs!(state) do
    team_ids = MapSet.new(state.teams, & &1.id)

    Enum.each(state.players_teams, fn {_name, tid} ->
      assert MapSet.member?(team_ids, tid),
             "players_teams references nonexistent team #{tid}"
    end)
  end

  defp check_challenged_words_type!(state) do
    assert is_struct(state.challenged_words, MapSet),
           "challenged_words should be a MapSet, got: #{inspect(state.challenged_words)}"
  end

  defp check_active_player_count!(state) do
    expected = Enum.count(state.players, fn p -> p.status == :playing end)

    assert state.active_player_count == expected,
           "active_player_count #{state.active_player_count} != actual #{expected}"
  end

  defp check_scores_on_finish!(state) do
    if state.status == :finished do
      Enum.each(state.teams, fn team ->
        assert is_integer(team.score),
               "Team #{team.name} has no score after game finished"
      end)
    end
  end

  defp check_no_duplicate_words!(state) do
    all_words = Enum.flat_map(state.teams, & &1.words)
    assert length(all_words) == length(Enum.uniq(all_words)), "Duplicate words across teams"
  end

  defp check_center_sorted!(raw) do
    if raw != nil do
      assert raw.center_sorted == Enum.sort(raw.center_sorted),
             "center_sorted is not sorted: #{inspect(raw.center_sorted)}"
    end
  end

  defp check_center_set_equal!(raw) do
    if raw != nil do
      assert Enum.sort(raw.center) == Enum.sort(raw.center_sorted),
             "center and center_sorted are not set-equal"
    end
  end

  defp check_turn_player_not_quit!(state) do
    if state.status == :playing and length(state.players) > 0 do
      turn_player = Enum.at(state.players, state.turn)

      if alive_player_count(state) > 0 do
        assert turn_player.status == :playing,
               "Turn player (index #{state.turn}) has status #{turn_player.status}"
      end
    end
  end

  defp check_team_count!(state) do
    assert length(state.teams) <= Config.max_teams(),
           "Team count #{length(state.teams)} exceeds max #{Config.max_teams()}"
  end

  defp check_no_duplicate_team_names!(state) do
    names = Enum.map(state.teams, & &1.name)
    assert length(names) == length(Enum.uniq(names)), "Duplicate team names: #{inspect(names)}"
  end

  defp check_team_words_disjoint!(state) do
    all_words = Enum.flat_map(state.teams, fn t -> Enum.map(t.words, &{t.name, &1}) end)
    words_only = Enum.map(all_words, &elem(&1, 1))

    if length(words_only) != length(Enum.uniq(words_only)) do
      flunk("Words appear on multiple teams: #{inspect(all_words)}")
    end
  end

  defp check_activity_feed!(state) do
    feed = state.activity_feed

    if is_list(feed) do
      assert length(feed) <= 20, "Activity feed exceeds 20 entries: #{length(feed)}"

      Enum.each(feed, fn entry ->
        assert entry.type in [:player_message, :event],
               "Invalid feed entry type: #{inspect(entry.type)}"

        assert is_binary(entry.body), "Feed entry body is not a string"
      end)
    end
  end

  defp check_no_open_challenges_on_finish!(state) do
    if state.status == :finished do
      assert state.challenges == [],
             "Open challenges after game finished: #{inspect(state.challenges)}"
    end
  end

  defp check_no_tokens_leaked!(state) do
    serialized = inspect(state, limit: :infinity)

    for i <- 1..20 do
      refute String.contains?(serialized, "token_#{i}"),
             "Player token token_#{i} leaked in sanitized state"
    end
  end

  # ──────────────────────────────────────────────
  # LiveView render helpers
  # ──────────────────────────────────────────────

  def player_conn(game_id, player_idx \\ 1) do
    build_conn()
    |> Plug.Test.init_test_session(%{
      "game_id" => game_id,
      "player_name" => "player_#{player_idx}",
      "player_token" => "token_#{player_idx}"
    })
  end

  def mount_player_view(game_id, player_idx \\ 1) do
    conn = player_conn(game_id, player_idx)

    case live(conn, "/game/#{game_id}") do
      {:ok, view, html} -> {:ok, view, html}
      {:error, {:redirect, _}} -> :redirect
      {:error, {:live_redirect, _}} -> :redirect
    end
  end

  def mount_watcher_view(game_id) do
    conn = build_conn()

    case live(conn, "/watch/#{game_id}") do
      {:ok, view, html} -> {:ok, view, html}
      {:error, {:redirect, _}} -> :redirect
      {:error, {:live_redirect, _}} -> :redirect
    end
  end

  def check_views_render!(game_id, player_view, watcher_view) do
    state = safe_get_state(game_id)

    if state != nil do
      if player_view != nil do
        html = render(player_view)
        assert_render_invariants!(html, state.status)
      end

      if watcher_view != nil do
        html = render(watcher_view)
        assert_render_invariants!(html, state.status)
      end
    end
  end

  def fresh_mount_and_render!(game_id) do
    state = safe_get_state(game_id)
    if state == nil, do: :ok

    case mount_player_view(game_id) do
      {:ok, view, html} ->
        assert_render_invariants!(html, state.status)
        render(view)
        :ok

      :redirect ->
        :ok
    end

    case mount_watcher_view(game_id) do
      {:ok, view, html} ->
        assert_render_invariants!(html, state.status)
        render(view)
        :ok

      :redirect ->
        :ok
    end
  end

  def assert_render_invariants!(html, status) do
    assert html != "", "Rendered HTML is empty"

    refute String.contains?(html, "Internal Server Error"),
           "Error page rendered"

    refute String.contains?(html, "%Piratex."),
           "Raw Elixir struct leaked in HTML"

    case status do
      :waiting ->
        assert String.contains?(html, "teams") or String.contains?(html, "TEAMS") or
                 String.contains?(html, "START") or String.contains?(html, "JOIN"),
               "Waiting page missing expected content"

      :playing ->
        :ok

      :finished ->
        assert String.contains?(String.downcase(html), "game over") or
                 String.contains?(html, "Podium") or
                 String.contains?(html, "podium"),
               "Finished page missing expected content"
    end
  end

  # ──────────────────────────────────────────────
  # Monitored Game API calls
  # ──────────────────────────────────────────────

  @doc """
  Wraps a Game API call with process monitoring. If the GenServer crashes
  during the call, raises with the crash reason. Expected shutdowns
  (normal, shutdown) are allowed.
  """
  def monitored_call!(game_id, fun) do
    case Registry.lookup(Piratex.Game.Registry, game_id) do
      [{pid, _}] ->
        ref = Process.monitor(pid)
        result = fun.()

        receive do
          {:DOWN, ^ref, :process, ^pid, reason} ->
            unless expected_exit?(reason) do
              raise "Game GenServer (#{game_id}) crashed: #{inspect(reason)}"
            end
        after
          0 ->
            Process.demonitor(ref, [:flush])
        end

        result

      [] ->
        fun.()
    end
  end

  defp expected_exit?(:normal), do: true
  defp expected_exit?(:shutdown), do: true
  defp expected_exit?({:shutdown, _}), do: true
  defp expected_exit?(:noproc), do: true
  defp expected_exit?(_), do: false

  # ──────────────────────────────────────────────
  # Action execution helpers
  # ──────────────────────────────────────────────

  def flip_n_letters(game_id, n) do
    Enum.each(1..n, fn _ ->
      case Game.get_state(game_id) do
        {:ok, %{status: :playing, turn: turn, letter_pool_count: pool}} when pool > 0 ->
          monitored_call!(game_id, fn -> Game.flip_letter(game_id, "token_#{turn + 1}") end)

        _ ->
          :ok
      end
    end)
  end

  def drain_pool_and_end_game(game_id, player_count) do
    Enum.reduce_while(1..500, :ok, fn _, _ ->
      case Game.get_state(game_id) do
        {:ok, %{status: :playing, letter_pool_count: 0}} ->
          {:halt, :ok}

        {:ok, %{status: :playing, turn: turn}} ->
          monitored_call!(game_id, fn -> Game.flip_letter(game_id, "token_#{turn + 1}") end)
          {:cont, :ok}

        _ ->
          {:halt, :ok}
      end
    end)

    if player_count > 0 do
      for i <- 1..player_count do
        monitored_call!(game_id, fn -> Game.end_game_vote(game_id, "token_#{i}") end)
      end
    end

    :timer.sleep(50)
  end

  def wait_for_game_end(game_id, timeout_ms \\ 2000) do
    Enum.reduce_while(1..div(timeout_ms, 10), :ok, fn _, _ ->
      case Game.get_state(game_id) do
        {:ok, %{status: :finished}} ->
          {:halt, :finished}

        {:error, :not_found} ->
          {:halt, :dead}

        _ ->
          :timer.sleep(10)
          {:cont, :ok}
      end
    end)
  end

  # ──────────────────────────────────────────────
  # Real-flow game state builders
  # ──────────────────────────────────────────────

  @doc """
  Sets up a playing game and claims a word through real gameplay.
  Returns {game_id, claimed_word} or raises if no word can be claimed
  after max_attempts rounds of flipping.
  """
  def setup_game_with_claimed_word(num_players, pool_type \\ :bananagrams_half) do
    game_id = setup_playing_game(num_players, pool_type)
    {word, _token} = flip_and_claim!(game_id, "token_1")
    {game_id, word}
  end

  @doc """
  Sets up a playing game with an open challenge through real gameplay.
  Returns game_id. The game will have at least one open challenge.
  """
  def setup_game_with_challenge(num_players \\ 3, pool_type \\ :bananagrams_half) do
    game_id = setup_playing_game(num_players, pool_type)
    {word, _token} = flip_and_claim!(game_id, "token_1")

    challenger_idx = if num_players >= 2, do: 2, else: 1
    :ok = Game.challenge_word(game_id, "token_#{challenger_idx}", word)

    {:ok, state} = Game.get_state(game_id)
    assert length(state.challenges) > 0, "Challenge should be open"
    game_id
  end

  @doc """
  Sets up a playing game with words claimed on teams through real gameplay.
  Returns game_id. Tries to claim `target_claims` words, alternating between
  players so multiple teams have words.
  """
  def setup_playing_game_with_words(num_players \\ 2, pool_type \\ :bananagrams_half, target_claims \\ 2) do
    game_id = setup_playing_game(num_players, pool_type)

    if target_claims > 0 do
      Enum.reduce_while(1..target_claims, 0, fn i, claimed_count ->
        token = "token_#{rem(i - 1, num_players) + 1}"

        case flip_and_claim(game_id, token) do
          {:ok, _word} -> {:cont, claimed_count + 1}
          :no_claimable_word -> {:halt, claimed_count}
        end
      end)
    end

    game_id
  end

  @doc """
  Sets up a playing game with history entries (including a steal) through
  real gameplay. Returns game_id.
  """
  def setup_game_with_history(num_players \\ 2, pool_type \\ :bananagrams_half) do
    game_id = setup_playing_game(num_players, pool_type)

    # Claim a word first
    {_word, _token} = flip_and_claim!(game_id, "token_1")

    # Flip more and try a second claim (for a richer history)
    case flip_and_claim(game_id, "token_#{min(2, num_players)}") do
      {:ok, _} -> :ok
      :no_claimable_word -> :ok
    end

    # Try to find and execute a steal for even richer history
    flip_n_letters(game_id, 10)
    {:ok, state} = Game.get_state(game_id)

    if state.status == :playing do
      steals = find_valid_steals(state)
      words_in_play = Enum.flat_map(state.teams, & &1.words)
      steals = Enum.reject(steals, fn {_, nw} -> nw in words_in_play end)

      case steals do
        [{_old, new_word} | _] ->
          monitored_call!(game_id, fn -> Game.claim_word(game_id, "token_1", new_word) end)

        [] ->
          :ok
      end
    end

    game_id
  end

  @doc """
  Sets up a finished game through real gameplay.
  Claims `target_claims` words (alternating between players for multi-team
  distribution), then drains the pool and has all players vote to end.
  Returns game_id with status :finished.
  """
  def setup_finished_game(num_players \\ 2, pool_type \\ :bananagrams_half, target_claims \\ 2) do
    game_id = setup_playing_game_with_words(num_players, pool_type, target_claims)

    drain_pool_and_end_game(game_id, num_players)
    wait_for_game_end(game_id, 3000)

    {:ok, state} = Game.get_state(game_id)
    assert state.status == :finished, "Game should be finished"
    game_id
  end

  @doc """
  Flips letters and claims a word for the given token. Returns {:ok, word}
  or :no_claimable_word. Non-raising version.
  """
  def flip_and_claim(game_id, token, max_attempts \\ 50) do
    Enum.reduce_while(1..max_attempts, :no_claimable_word, fn _, _ ->
      flip_n_letters(game_id, 3)
      {:ok, state} = Game.get_state(game_id)

      if state.status != :playing do
        {:halt, :no_claimable_word}
      else
        claimable = find_claimable_words_from_center(state.center)
        words_in_play = Enum.flat_map(state.teams, & &1.words)
        claimable = Enum.reject(claimable, &(&1 in words_in_play))

        case try_claim_first(game_id, token, claimable) do
          {:ok, word} -> {:halt, {:ok, word}}
          :none -> {:cont, :no_claimable_word}
        end
      end
    end)
  end

  @doc """
  Like flip_and_claim/3 but raises if no word can be claimed.
  Returns {word, token}.
  """
  def flip_and_claim!(game_id, token, max_attempts \\ 50) do
    case flip_and_claim(game_id, token, max_attempts) do
      {:ok, word} -> {word, token}
      :no_claimable_word -> raise "Could not claim any word after #{max_attempts} attempts"
    end
  end

  defp try_claim_first(_game_id, _token, []), do: :none

  defp try_claim_first(game_id, token, [word | rest]) do
    case monitored_call!(game_id, fn -> Game.claim_word(game_id, token, word) end) do
      :ok -> {:ok, word}
      {:error, _} -> try_claim_first(game_id, token, rest)
    end
  end
end

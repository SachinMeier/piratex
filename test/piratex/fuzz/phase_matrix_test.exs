defmodule Piratex.PhaseMatrixTest do
  @moduledoc """
  Deterministic exhaustive test: every API call x every game phase.
  Verifies the exact error atom returned for each invalid-phase call.
  """
  use ExUnit.Case, async: false

  alias Piratex.FuzzHelpers
  alias Piratex.FuzzGame, as: Game

  @moduletag :fuzz

  @bad_token "nonexistent_token"

  setup do
    FuzzHelpers.ensure_dictionary_started()
    :ok
  end

  # ──────────────────────────────────────────────
  # Phase 1: :waiting (initial, with players joined)
  # ──────────────────────────────────────────────

  describe "waiting phase" do
    setup do
      game_id = FuzzHelpers.setup_waiting_game(3)
      state = FuzzHelpers.safe_get_state(game_id)
      assert state.status == :waiting
      %{game_id: game_id}
    end

    test "join_game succeeds with valid params", %{game_id: game_id} do
      assert :ok = Game.join_game(game_id, "new_player", "new_token")
    end

    test "join_game fails with bad token (duplicate name)", %{game_id: game_id} do
      assert {:error, :duplicate_player} = Game.join_game(game_id, "player_1", "different_token")
    end

    test "leave_waiting_game succeeds with valid token", %{game_id: game_id} do
      assert :ok = Game.leave_waiting_game(game_id, "token_1")
    end

    test "leave_waiting_game with bad token still returns ok (no-op)", %{game_id: game_id} do
      # remove_player is a no-op for unknown tokens
      result = Game.leave_waiting_game(game_id, @bad_token)
      assert result == :ok
    end

    test "create_team succeeds with valid params", %{game_id: game_id} do
      assert :ok = Game.create_team(game_id, "token_1", "MyNewTeam")
    end

    test "create_team fails with bad token", %{game_id: game_id} do
      assert {:error, :player_not_found} = Game.create_team(game_id, @bad_token, "BadTeam")
    end

    test "join_team succeeds with valid params", %{game_id: game_id} do
      state = FuzzHelpers.safe_get_state(game_id)
      team = List.first(state.teams)
      assert :ok = Game.join_team(game_id, "token_2", team.id)
    end

    test "join_team fails with invalid team_id", %{game_id: game_id} do
      assert {:error, _reason} = Game.join_team(game_id, "token_1", -999)
    end

    test "set_letter_pool_type succeeds", %{game_id: game_id} do
      assert :ok = Game.set_letter_pool_type(game_id, :bananagrams_half)
    end

    test "start_game succeeds", %{game_id: game_id} do
      assert :ok = Game.start_game(game_id, "token_1")
    end

    test "flip_letter fails in waiting", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.flip_letter(game_id, "token_1")
    end

    test "claim_word fails in waiting", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.claim_word(game_id, "token_1", "test")
    end

    test "challenge_word fails in waiting", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.challenge_word(game_id, "token_1", "test")
    end

    test "challenge_vote fails in waiting", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.challenge_vote(game_id, "token_1", 0, true)
    end

    test "end_game_vote fails in waiting", %{game_id: game_id} do
      assert {:error, :game_not_endable} = Game.end_game_vote(game_id, "token_1")
    end

    test "send_chat_message fails in waiting", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.send_chat_message(game_id, "token_1", "hello")
    end

    test "quit_game succeeds in waiting (behaves like leave)", %{game_id: game_id} do
      assert :ok = Game.quit_game(game_id, "token_1")
    end

    test "rejoin_game succeeds for existing player", %{game_id: game_id} do
      assert :ok = Game.rejoin_game(game_id, "player_1", "token_1")
    end

    test "rejoin_game fails for unknown token", %{game_id: game_id} do
      assert {:error, :not_found} = Game.rejoin_game(game_id, "nobody", @bad_token)
    end
  end

  # ──────────────────────────────────────────────
  # Phase 2: :playing (normal, pool has letters, no challenge)
  # ──────────────────────────────────────────────

  describe "playing phase (normal)" do
    setup do
      game_id = FuzzHelpers.setup_playing_game(3, :bananagrams_half)
      state = FuzzHelpers.safe_get_state(game_id)
      assert state.status == :playing
      assert state.letter_pool_count > 0
      %{game_id: game_id}
    end

    test "join_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} =
               Game.join_game(game_id, "new_player", "new_token")
    end

    test "leave_waiting_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.leave_waiting_game(game_id, "token_1")
    end

    test "create_team fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.create_team(game_id, "token_1", "NewTeam")
    end

    test "join_team fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.join_team(game_id, "token_1", 1)
    end

    test "set_letter_pool_type fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.set_letter_pool_type(game_id, :bananagrams)
    end

    test "start_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.start_game(game_id, "token_1")
    end

    test "flip_letter succeeds for turn player", %{game_id: game_id} do
      state = FuzzHelpers.safe_get_state(game_id)
      token = FuzzHelpers.turn_player_token(state)
      assert :ok = Game.flip_letter(game_id, token)
    end

    test "flip_letter fails for non-turn player", %{game_id: game_id} do
      state = FuzzHelpers.safe_get_state(game_id)
      non_turn_idx = rem(state.turn + 1, length(state.players))
      token = "token_#{non_turn_idx + 1}"
      assert {:error, :not_your_turn} = Game.flip_letter(game_id, token)
    end

    test "flip_letter fails with bad token", %{game_id: game_id} do
      assert {:error, :not_your_turn} = Game.flip_letter(game_id, @bad_token)
    end

    test "claim_word fails with invalid word", %{game_id: game_id} do
      assert {:error, _reason} = Game.claim_word(game_id, "token_1", "xyznotaword")
    end

    test "claim_word fails with bad token", %{game_id: game_id} do
      assert {:error, :player_not_found} = Game.claim_word(game_id, @bad_token, "test")
    end

    test "challenge_word fails when no words in play", %{game_id: game_id} do
      assert {:error, _reason} = Game.challenge_word(game_id, "token_1", "nonexistent")
    end

    test "challenge_vote fails with no open challenge", %{game_id: game_id} do
      assert {:error, :challenge_not_found} = Game.challenge_vote(game_id, "token_1", 0, true)
    end

    test "end_game_vote succeeds", %{game_id: game_id} do
      assert :ok = Game.end_game_vote(game_id, "token_1")
    end

    test "end_game_vote fails with bad token", %{game_id: game_id} do
      assert {:error, :not_found} = Game.end_game_vote(game_id, @bad_token)
    end

    test "send_chat_message succeeds", %{game_id: game_id} do
      assert :ok = Game.send_chat_message(game_id, "token_1", "hello")
    end

    test "send_chat_message fails with empty message", %{game_id: game_id} do
      assert {:error, :empty_message} = Game.send_chat_message(game_id, "token_1", "")
    end

    test "send_chat_message fails with bad token", %{game_id: game_id} do
      assert {:error, :player_not_found} = Game.send_chat_message(game_id, @bad_token, "hello")
    end

    test "quit_game succeeds", %{game_id: game_id} do
      assert :ok = Game.quit_game(game_id, "token_3")
    end

    test "rejoin_game succeeds for existing player", %{game_id: game_id} do
      assert :ok = Game.rejoin_game(game_id, "player_1", "token_1")
    end

    test "rejoin_game fails for unknown token", %{game_id: game_id} do
      assert {:error, :not_found} = Game.rejoin_game(game_id, "nobody", @bad_token)
    end
  end

  # ──────────────────────────────────────────────
  # Phase 3: :playing (challenge open)
  # ──────────────────────────────────────────────

  describe "playing phase (challenge open)" do
    setup do
      game_id = FuzzHelpers.setup_game_with_challenge(3)
      state = FuzzHelpers.safe_get_state(game_id)
      assert state.status == :playing
      assert length(state.challenges) > 0
      challenge = List.first(state.challenges)
      %{game_id: game_id, challenge_id: challenge.id}
    end

    test "join_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} =
               Game.join_game(game_id, "new_player", "new_token")
    end

    test "leave_waiting_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.leave_waiting_game(game_id, "token_1")
    end

    test "create_team fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.create_team(game_id, "token_1", "NewTeam")
    end

    test "join_team fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.join_team(game_id, "token_1", 1)
    end

    test "set_letter_pool_type fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.set_letter_pool_type(game_id, :bananagrams)
    end

    test "start_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.start_game(game_id, "token_1")
    end

    test "flip_letter fails (challenge open)", %{game_id: game_id} do
      state = FuzzHelpers.safe_get_state(game_id)
      token = FuzzHelpers.turn_player_token(state)
      assert {:error, :challenge_open} = Game.flip_letter(game_id, token)
    end

    test "claim_word fails with invalid word during challenge", %{game_id: game_id} do
      assert {:error, _reason} = Game.claim_word(game_id, "token_1", "xyznotaword")
    end

    test "challenge_word fails (word not challengeable during open challenge)", %{
      game_id: game_id
    } do
      # Trying to challenge a nonexistent word
      assert {:error, _reason} = Game.challenge_word(game_id, "token_1", "nonexistent")
    end

    test "challenge_vote succeeds with valid params", %{
      game_id: game_id,
      challenge_id: challenge_id
    } do
      # Find a player who hasn't voted yet (the challenger already auto-voted)
      state = FuzzHelpers.safe_get_state(game_id)
      challenge = List.first(state.challenges)
      voted_names = Map.keys(challenge.votes)

      non_voter =
        state.players
        |> Enum.with_index(1)
        |> Enum.find(fn {p, _idx} ->
          p.status == :playing and p.name not in voted_names
        end)

      case non_voter do
        {_player, idx} ->
          result = Game.challenge_vote(game_id, "token_#{idx}", challenge_id, true)
          assert result == :ok

        nil ->
          # All players already voted; this is fine
          :ok
      end
    end

    test "challenge_vote fails with bad challenge_id", %{game_id: game_id} do
      assert {:error, :challenge_not_found} =
               Game.challenge_vote(game_id, "token_1", -999, true)
    end

    test "challenge_vote fails with bad token", %{game_id: game_id, challenge_id: challenge_id} do
      assert {:error, :player_not_found} =
               Game.challenge_vote(game_id, @bad_token, challenge_id, true)
    end

    test "end_game_vote succeeds during challenge", %{game_id: game_id} do
      assert :ok = Game.end_game_vote(game_id, "token_1")
    end

    test "send_chat_message succeeds during challenge", %{game_id: game_id} do
      assert :ok = Game.send_chat_message(game_id, "token_1", "hello")
    end

    test "quit_game succeeds during challenge", %{game_id: game_id} do
      assert :ok = Game.quit_game(game_id, "token_3")
    end

    test "rejoin_game succeeds for existing player", %{game_id: game_id} do
      assert :ok = Game.rejoin_game(game_id, "player_1", "token_1")
    end

    test "rejoin_game fails for unknown token", %{game_id: game_id} do
      assert {:error, :not_found} = Game.rejoin_game(game_id, "nobody", @bad_token)
    end
  end

  # ──────────────────────────────────────────────
  # Phase 4: :playing (pool empty)
  # ──────────────────────────────────────────────

  describe "playing phase (pool empty)" do
    setup do
      game_id = FuzzHelpers.setup_playing_game(3, :bananagrams_half)
      FuzzHelpers.drain_pool_and_end_game(game_id, 0)
      state = FuzzHelpers.safe_get_state(game_id)
      assert state.status == :playing
      assert state.letter_pool_count == 0
      %{game_id: game_id}
    end

    test "join_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} =
               Game.join_game(game_id, "new_player", "new_token")
    end

    test "leave_waiting_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.leave_waiting_game(game_id, "token_1")
    end

    test "create_team fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.create_team(game_id, "token_1", "NewTeam")
    end

    test "join_team fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.join_team(game_id, "token_1", 1)
    end

    test "set_letter_pool_type fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.set_letter_pool_type(game_id, :bananagrams)
    end

    test "start_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.start_game(game_id, "token_1")
    end

    test "flip_letter fails (no more letters)", %{game_id: game_id} do
      state = FuzzHelpers.safe_get_state(game_id)
      token = FuzzHelpers.turn_player_token(state)
      assert {:error, :no_more_letters} = Game.flip_letter(game_id, token)
    end

    test "claim_word fails with invalid word", %{game_id: game_id} do
      assert {:error, _reason} = Game.claim_word(game_id, "token_1", "xyznotaword")
    end

    test "challenge_word fails when no words in play", %{game_id: game_id} do
      assert {:error, _reason} = Game.challenge_word(game_id, "token_1", "nonexistent")
    end

    test "challenge_vote fails with no open challenge", %{game_id: game_id} do
      assert {:error, :challenge_not_found} = Game.challenge_vote(game_id, "token_1", 0, true)
    end

    test "end_game_vote succeeds", %{game_id: game_id} do
      assert :ok = Game.end_game_vote(game_id, "token_1")
    end

    test "send_chat_message succeeds", %{game_id: game_id} do
      assert :ok = Game.send_chat_message(game_id, "token_1", "hello")
    end

    test "quit_game succeeds", %{game_id: game_id} do
      assert :ok = Game.quit_game(game_id, "token_3")
    end

    test "rejoin_game succeeds for existing player", %{game_id: game_id} do
      assert :ok = Game.rejoin_game(game_id, "player_1", "token_1")
    end

    test "rejoin_game fails for unknown token", %{game_id: game_id} do
      assert {:error, :not_found} = Game.rejoin_game(game_id, "nobody", @bad_token)
    end
  end

  # ──────────────────────────────────────────────
  # Phase 5: :finished
  # ──────────────────────────────────────────────

  describe "finished phase" do
    setup do
      game_id = FuzzHelpers.setup_finished_game(3)
      state = FuzzHelpers.safe_get_state(game_id)
      assert state.status == :finished
      %{game_id: game_id}
    end

    test "join_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} =
               Game.join_game(game_id, "new_player", "new_token")
    end

    test "leave_waiting_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.leave_waiting_game(game_id, "token_1")
    end

    test "create_team fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.create_team(game_id, "token_1", "NewTeam")
    end

    test "join_team fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.join_team(game_id, "token_1", 1)
    end

    test "set_letter_pool_type fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.set_letter_pool_type(game_id, :bananagrams)
    end

    test "start_game fails (game already started)", %{game_id: game_id} do
      assert {:error, :game_already_started} = Game.start_game(game_id, "token_1")
    end

    test "flip_letter fails (game not playing)", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.flip_letter(game_id, "token_1")
    end

    test "claim_word fails (game not playing)", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.claim_word(game_id, "token_1", "test")
    end

    test "challenge_word fails (game not playing)", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.challenge_word(game_id, "token_1", "test")
    end

    test "challenge_vote fails (game not playing)", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.challenge_vote(game_id, "token_1", 0, true)
    end

    test "end_game_vote fails (game not endable)", %{game_id: game_id} do
      assert {:error, :game_not_endable} = Game.end_game_vote(game_id, "token_1")
    end

    test "send_chat_message fails (game not playing)", %{game_id: game_id} do
      assert {:error, :game_not_playing} = Game.send_chat_message(game_id, "token_1", "hello")
    end

    test "quit_game succeeds (marks player as quit)", %{game_id: game_id} do
      assert :ok = Game.quit_game(game_id, "token_1")
    end

    test "rejoin_game succeeds for existing player", %{game_id: game_id} do
      assert :ok = Game.rejoin_game(game_id, "player_1", "token_1")
    end

    test "rejoin_game fails for unknown token", %{game_id: game_id} do
      assert {:error, :not_found} = Game.rejoin_game(game_id, "nobody", @bad_token)
    end
  end
end

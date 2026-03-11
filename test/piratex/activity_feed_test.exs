defmodule Piratex.ActivityFeedTest do
  use ExUnit.Case, async: true

  import Piratex.TestHelpers

  alias Piratex.ActivityFeed.Entry
  alias Piratex.Game

  describe "activity feed integration" do
    test "appends chat messages during play" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.start_game(game_id, "token1")

      assert :ok = Game.send_chat_message(game_id, "token1", "  Ahoy there  ")

      assert {:ok,
              %{
                activity_feed: [
                  %Entry{type: :player_message, player_name: "player1", body: "Ahoy there"}
                ]
              }} = Game.get_state(game_id)
    end

    test "adds a word stolen event but not a center-only claim event" do
      state =
        default_new_game(0, %{
          status: :waiting,
          center: ["t", "s", "e", "t"],
          center_sorted: ["e", "s", "t", "t"]
        })

      {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.start_game(game_id, "token1")

      assert :ok = Game.claim_word(game_id, "token1", "set")
      assert {:ok, %{activity_feed: []}} = Game.get_state(game_id)

      assert :ok = Game.claim_word(game_id, "token2", "test")

      assert {:ok,
              %{
                activity_feed: [
                  %Entry{
                    type: :event,
                    event_kind: :word_stolen,
                    body: "player2 stole SET to make TEST."
                  }
                ]
              }} = Game.get_state(game_id)
    end

    test "adds challenge resolution and invalidation events when a challenge succeeds" do
      game_id = start_steal_game!()

      assert :ok = Game.challenge_word(game_id, "token1", "test")
      {:ok, %{challenges: [%{id: challenge_id}]}} = Game.get_state(game_id)

      assert :ok = Game.challenge_vote(game_id, "token2", challenge_id, false)

      assert {:ok,
              %{
                activity_feed: [
                  %Entry{event_kind: :word_stolen},
                  %Entry{
                    event_kind: :challenge_resolved,
                    body: "Challenge resolved: TEST is invalid."
                  },
                  %Entry{
                    event_kind: :word_invalidated,
                    body: "TEST was invalidated and SET was restored."
                  }
                ]
              }} = Game.get_state(game_id)
    end

    test "adds a player quit event during play" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.join_game(game_id, "player2", "token2")
      :ok = Game.start_game(game_id, "token1")

      assert :ok = Game.quit_game(game_id, "token2")

      assert {:ok,
              %{
                activity_feed: [
                  %Entry{
                    type: :event,
                    event_kind: :player_quit,
                    body: "player2 quit the game."
                  }
                ]
              }} = Game.get_state(game_id)
    end
  end

  defp start_steal_game! do
    state =
      default_new_game(0, %{
        status: :waiting,
        center: ["t", "s", "e", "t"],
        center_sorted: ["e", "s", "t", "t"]
      })

    {:ok, game_id} = Piratex.DynamicSupervisor.new_game(state)

    :ok = Game.join_game(game_id, "player1", "token1")
    :ok = Game.join_game(game_id, "player2", "token2")
    :ok = Game.start_game(game_id, "token1")

    :ok = Game.claim_word(game_id, "token1", "set")
    :ok = Game.claim_word(game_id, "token2", "test")

    game_id
  end
end

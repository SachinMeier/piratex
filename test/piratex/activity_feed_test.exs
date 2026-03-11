defmodule Piratex.ActivityFeedTest do
  use ExUnit.Case, async: true

  import Piratex.TestHelpers

  alias Piratex.ActivityFeed
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

    test "adds a gameplay event for both center claims and steals" do
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
      assert {:ok,
              %{
                activity_feed: [
                  %Entry{
                    type: :event,
                    event_kind: :word_stolen,
                    body: "player1 made SET from the center."
                  }
                ]
              }} = Game.get_state(game_id)

      assert :ok = Game.claim_word(game_id, "token2", "test")

      assert {:ok,
              %{
                activity_feed: [
                  %Entry{
                    type: :event,
                    event_kind: :word_stolen,
                    body: "player1 made SET from the center."
                  },
                  %Entry{
                    type: :event,
                    event_kind: :word_stolen,
                    body: "player2 stole SET to make TEST."
                  }
                ]
              }} = Game.get_state(game_id)
    end

    test "adds a single challenge resolution event when a challenge succeeds" do
      game_id = start_steal_game!()

      assert :ok = Game.challenge_word(game_id, "token1", "test")
      {:ok, %{challenges: [%{id: challenge_id}]}} = Game.get_state(game_id)

      assert :ok = Game.challenge_vote(game_id, "token2", challenge_id, false)

      assert {:ok,
              %{
                activity_feed: [
                  %Entry{
                    event_kind: :word_stolen,
                    body: "player1 made SET from the center."
                  },
                  %Entry{
                    event_kind: :word_stolen,
                    body: "player2 stole SET to make TEST."
                  },
                  %Entry{
                    event_kind: :challenge_resolved,
                    body: "Resolved: SET to TEST is INVALID."
                  }
                ]
              }} = Game.get_state(game_id)
    end

    test "uses the resolved wording when a challenge fails" do
      game_id = start_steal_game!()

      assert :ok = Game.challenge_word(game_id, "token1", "test")
      {:ok, %{challenges: [%{id: challenge_id}]}} = Game.get_state(game_id)

      assert :ok = Game.challenge_vote(game_id, "token2", challenge_id, true)

      assert {:ok,
              %{
                activity_feed: [
                  %Entry{
                    event_kind: :word_stolen,
                    body: "player1 made SET from the center."
                  },
                  %Entry{
                    event_kind: :word_stolen,
                    body: "player2 stole SET to make TEST."
                  },
                  %Entry{
                    event_kind: :challenge_resolved,
                    body: "Resolved: SET to TEST is VALID."
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

    test "keeps only the most recent 20 feed entries" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.start_game(game_id, "token1")

      total_messages = ActivityFeed.limit() + 5

      for idx <- 1..total_messages do
        assert :ok = Game.send_chat_message(game_id, "token1", "message #{idx}")
      end

      assert {:ok, %{activity_feed: activity_feed}} = Game.get_state(game_id)

      assert length(activity_feed) == ActivityFeed.limit()
      assert Enum.at(activity_feed, 0).body == "message 6"
      assert List.last(activity_feed).body == "message 25"
    end

    test "rejects chat messages longer than 140 characters" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Game.join_game(game_id, "player1", "token1")
      :ok = Game.start_game(game_id, "token1")

      too_long_message = String.duplicate("a", Game.max_chat_message_length() + 1)

      assert {:error, :message_too_long} =
               Game.send_chat_message(game_id, "token1", too_long_message)

      assert {:ok, %{activity_feed: []}} = Game.get_state(game_id)
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

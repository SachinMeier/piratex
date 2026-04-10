defmodule PiratexWeb.GameChannelTest do
  use PiratexWeb.ChannelCase, async: true

  alias Piratex.DynamicSupervisor
  alias Piratex.Game
  alias PiratexWeb.Protocol
  alias PiratexWeb.UserSocket

  @client_token "test-token-abc"
  @player_name "alice"

  defp new_game do
    {:ok, game_id} = DynamicSupervisor.new_game()
    game_id
  end

  defp connect_socket(token \\ @client_token) do
    {:ok, socket} =
      Phoenix.ChannelTest.connect(UserSocket, %{
        "player_token" => token,
        "client" => "piratex-tui/test"
      })

    socket
  end

  defp join_params(extra \\ %{}) do
    %{
      "player_name" => @player_name,
      "intent" => "join",
      "protocol_major" => Protocol.major(),
      "protocol_minor" => Protocol.minor()
    }
    |> Map.merge(extra)
  end

  describe "join/3" do
    test "joins with intent=join and pushes initial state" do
      game_id = new_game()
      socket = connect_socket()

      {:ok, reply, _socket} =
        subscribe_and_join(socket, "game:#{game_id}", join_params())

      assert reply.game_id == game_id
      assert reply.protocol == %{major: Protocol.major(), minor: Protocol.minor()}
      assert reply.upgrade_available == false
      assert %{turn_timeout_ms: _} = reply.config

      assert_push("state", state)
      assert state.id == game_id
      assert state.status == :waiting
      # challenged_words is converted from MapSet to list at the wire boundary
      assert is_list(state.challenged_words)
    end

    test "rejoins an existing player with intent=rejoin" do
      game_id = new_game()
      :ok = Game.join_game(game_id, @player_name, @client_token)

      socket = connect_socket()

      {:ok, _reply, _socket} =
        subscribe_and_join(
          socket,
          "game:#{game_id}",
          join_params(%{"intent" => "rejoin"})
        )

      assert_push("state", _)
    end

    test "watch intent does not require a token" do
      game_id = new_game()
      socket = connect_socket("")

      {:ok, _reply, _socket} =
        subscribe_and_join(
          socket,
          "game:#{game_id}",
          join_params(%{"intent" => "watch", "player_name" => ""})
        )

      assert_push("state", _)
    end

    test "returns error for nonexistent game" do
      socket = connect_socket()

      assert {:error, %{reason: :not_found}} =
               subscribe_and_join(socket, "game:NOPE", join_params())
    end

    test "returns error for duplicate player name" do
      game_id = new_game()
      :ok = Game.join_game(game_id, @player_name, "other-token")
      socket = connect_socket()

      assert {:error, %{reason: :duplicate_player}} =
               subscribe_and_join(socket, "game:#{game_id}", join_params())
    end

    test "rejects client with outdated major version" do
      game_id = new_game()
      socket = connect_socket()

      assert {:error, error} =
               subscribe_and_join(
                 socket,
                 "game:#{game_id}",
                 join_params(%{"protocol_major" => -1})
               )

      # Elixir's -1 < Protocol.major() so compare returns :client_outdated
      assert error.reason == :client_outdated
      assert error.upgrade_url == Protocol.upgrade_url()
    end
  end

  describe "handle_in — command dispatch" do
    setup do
      game_id = new_game()
      socket = connect_socket()

      {:ok, _reply, socket} =
        subscribe_and_join(socket, "game:#{game_id}", join_params())

      assert_push("state", _)

      %{socket: socket, game_id: game_id}
    end

    test "start_game succeeds for solo player", %{socket: socket} do
      ref = push(socket, "start_game", %{})
      assert_reply(ref, :ok, %{})
    end

    test "flip_letter succeeds after start", %{socket: socket} do
      ref = push(socket, "start_game", %{})
      assert_reply(ref, :ok, %{})
      assert_push("state", _)

      ref = push(socket, "flip_letter", %{})
      assert_reply(ref, :ok, %{})
      assert_push("state", _)
    end

    test "claim_word rejects too-short words", %{socket: socket} do
      push(socket, "start_game", %{}) |> assert_reply(:ok, %{})
      assert_push("state", _)

      ref = push(socket, "claim_word", %{"word" => "a"})
      assert_reply(ref, :error, %{reason: :invalid_word})
    end

    test "challenge_word with no history returns error", %{socket: socket} do
      push(socket, "start_game", %{}) |> assert_reply(:ok, %{})
      assert_push("state", _)

      ref = push(socket, "challenge_word", %{"word" => "whales"})
      assert_reply(ref, :error, %{reason: :word_not_in_play})
    end

    test "send_chat_message fails while waiting", %{socket: socket} do
      ref = push(socket, "send_chat_message", %{"message" => "hi"})
      assert_reply(ref, :error, %{reason: :game_not_playing})
    end

    test "invalid payload returns invalid_payload error", %{socket: socket} do
      ref = push(socket, "claim_word", %{"not_word" => "whales"})
      assert_reply(ref, :error, %{reason: :invalid_payload})
    end
  end

  describe "watch mode" do
    test "rejects all commands with watch_only error" do
      game_id = new_game()
      socket = connect_socket("")

      {:ok, _reply, socket} =
        subscribe_and_join(
          socket,
          "game:#{game_id}",
          join_params(%{"intent" => "watch", "player_name" => ""})
        )

      assert_push("state", _)

      ref = push(socket, "flip_letter", %{})
      assert_reply(ref, :error, %{reason: :watch_only})

      ref = push(socket, "claim_word", %{"word" => "whales"})
      assert_reply(ref, :error, %{reason: :watch_only})
    end
  end

  describe "state push encoding" do
    test "challenged_words is encoded as list of [victim, thief] pairs" do
      game_id = new_game()
      socket = connect_socket()

      {:ok, _reply, _socket} =
        subscribe_and_join(socket, "game:#{game_id}", join_params())

      assert_push("state", state)
      assert is_list(state.challenged_words)
      # Can be JSON-encoded
      assert {:ok, _json} = Jason.encode(state)
    end

    test "encode_state converts MapSet challenged_words" do
      state = %{
        id: "X",
        challenged_words: MapSet.new([{"cat", "cats"}, {"dog", "dogs"}]),
        game_stats: nil
      }

      encoded = PiratexWeb.GameChannel.encode_state(state)
      assert is_list(encoded.challenged_words)

      assert Enum.sort(encoded.challenged_words) == [
               ["cat", "cats"],
               ["dog", "dogs"]
             ]
    end

    test "encode_state converts game_stats.score_timeline tuples to lists" do
      state = %{
        id: "X",
        challenged_words: MapSet.new(),
        game_stats: %{
          total_score: 10,
          score_timeline: %{
            0 => [{0, 0}, {12, 5}, {24, 10}],
            1 => [{0, 0}, {12, 3}]
          }
        }
      }

      encoded = PiratexWeb.GameChannel.encode_state(state)
      assert encoded.game_stats.score_timeline[0] == [[0, 0], [12, 5], [24, 10]]
      assert encoded.game_stats.score_timeline[1] == [[0, 0], [12, 3]]
      assert {:ok, _json} = Jason.encode(encoded)
    end

    test "encode_state passes through nil game_stats" do
      state = %{
        id: "X",
        challenged_words: MapSet.new(),
        game_stats: nil
      }

      encoded = PiratexWeb.GameChannel.encode_state(state)
      assert encoded.game_stats == nil
    end
  end
end

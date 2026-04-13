defmodule PiratexWeb.GameAPIControllerTest do
  use PiratexWeb.ConnCase, async: true

  alias Piratex.DynamicSupervisor
  alias Piratex.Game
  alias PiratexWeb.Protocol

  defp protocol_conn(conn) do
    conn
    |> put_req_header("x-piratex-protocol-major", to_string(Protocol.major()))
    |> put_req_header("x-piratex-protocol-minor", to_string(Protocol.minor()))
  end

  describe "POST /api/games" do
    test "creates a game with default pool when letter_pool is omitted", %{conn: conn} do
      conn =
        conn
        |> protocol_conn()
        |> post(~p"/api/games", %{})

      assert %{"game_id" => game_id} = json_response(conn, 201)
      assert is_binary(game_id)
      assert {:ok, _state} = Game.get_state(game_id)
    end

    test "creates a game with an explicit pool", %{conn: conn} do
      conn =
        conn
        |> protocol_conn()
        |> post(~p"/api/games", %{"letter_pool" => "bananagrams_half"})

      assert %{"game_id" => _game_id} = json_response(conn, 201)
    end

    test "rejects unknown pool with 400", %{conn: conn} do
      conn =
        conn
        |> protocol_conn()
        |> post(~p"/api/games", %{"letter_pool" => "nope"})

      assert json_response(conn, 400) == %{"error" => "invalid_pool"}
    end

    test "returns 426 when protocol major is older than server", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-piratex-protocol-major", "-1")
        |> put_req_header("x-piratex-protocol-minor", "0")
        |> post(~p"/api/games", %{})

      body = json_response(conn, 426)
      assert body["error"] == "client_outdated"
      assert body["server_version"] == Protocol.version_string()
    end
  end

  describe "GET /api/games" do
    test "returns a list of waiting games", %{conn: conn} do
      {:ok, _game_id} = DynamicSupervisor.new_game()

      conn =
        conn
        |> protocol_conn()
        |> get(~p"/api/games")

      body = json_response(conn, 200)
      assert is_list(body["games"])
      assert is_integer(body["page"])
      assert is_boolean(body["has_next"])
      # Don't assert membership: under concurrent test load other tests may
      # fill page 1, and the test is just verifying the endpoint shape.
    end
  end

  describe "GET /api/games/:id" do
    test "returns sanitized game state", %{conn: conn} do
      {:ok, game_id} = DynamicSupervisor.new_game()

      conn =
        conn
        |> protocol_conn()
        |> get(~p"/api/games/#{game_id}")

      body = json_response(conn, 200)
      assert body["id"] == game_id
      assert body["status"] == "waiting"
      assert is_list(body["challenged_words"])
    end

    test "returns 404 for unknown game", %{conn: conn} do
      conn =
        conn
        |> protocol_conn()
        |> get(~p"/api/games/NOPE")

      assert json_response(conn, 404) == %{"error" => "not_found"}
    end
  end

  describe "POST /api/games/:id/players" do
    test "registers a player and returns a token", %{conn: conn} do
      {:ok, game_id} = DynamicSupervisor.new_game()

      conn =
        conn
        |> protocol_conn()
        |> post(~p"/api/games/#{game_id}/players", %{"player_name" => "alice"})

      assert %{
               "game_id" => ^game_id,
               "player_name" => "alice",
               "player_token" => player_token
             } = json_response(conn, 201)

      assert is_binary(player_token)
      assert byte_size(player_token) > 0
    end

    test "returns 409 duplicate_player on name collision", %{conn: conn} do
      {:ok, game_id} = DynamicSupervisor.new_game()
      :ok = Game.join_game(game_id, "alice", "existing-token")

      conn =
        conn
        |> protocol_conn()
        |> post(~p"/api/games/#{game_id}/players", %{"player_name" => "alice"})

      assert json_response(conn, 409) == %{"error" => "duplicate_player"}
    end

    test "returns 404 for unknown game", %{conn: conn} do
      conn =
        conn
        |> protocol_conn()
        |> post(~p"/api/games/NOPE/players", %{"player_name" => "alice"})

      assert json_response(conn, 404) == %{"error" => "not_found"}
    end
  end
end

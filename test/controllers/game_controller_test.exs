defmodule PiratexWeb.GameControllerTest do
  use PiratexWeb.ConnCase, async: true

  test "rejects invalid letter pool params", %{conn: conn} do
    conn = post(conn, ~p"/game/new", %{"letter_pool" => "bogus_pool"})

    assert redirected_to(conn) == ~p"/create_game"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid letter pool"
  end

  test "join_game shows a friendly error for duplicate names", %{conn: conn} do
    {:ok, game_id} = Piratex.DynamicSupervisor.new_game()
    :ok = Piratex.Game.join_game(game_id, "player1", "token1")

    conn = get(conn, ~p"/game/#{game_id}/join_game", %{"player" => "player1"})

    assert redirected_to(conn) == ~p"/game/#{game_id}/join"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "That player name is already taken."
  end

  test "join_game shows a generic fallback message for unknown join errors", %{conn: conn} do
    conn = get(conn, ~p"/game/NOPE/join_game", %{"player" => "player1"})

    assert redirected_to(conn) == ~p"/game/NOPE/join"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Game not found."
  end
end

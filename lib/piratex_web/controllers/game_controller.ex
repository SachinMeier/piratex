defmodule PiratexWeb.GameController do
  use PiratexWeb, :controller

  def new_game(conn, %{"letter_pool" => letter_pool_type}) do
    # start the game
    {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

    # this is a bit of extra back and forth, but it lets us be flexible about when to set
    # the letter pool type. We could also do this at game creation time by passing the state to DynamicSupervisor.new_game
    :ok = Piratex.Game.set_letter_pool_type(game_id, String.to_existing_atom(letter_pool_type))

    conn
    |> clear_session()
    # have the player join the game
    |> redirect(to: ~p"/game/#{game_id}/join")
  end

  def join_game(%{params: %{"id" => game_id}} = conn, %{"player" => player_name} = _params) do
    player_token = Piratex.PlayerService.new_player_token()

    case Piratex.Game.join_game(game_id, player_name, player_token) do
      :ok ->
        conn
        |> put_session("game_id", game_id)
        |> put_session("player_name", player_name)
        |> put_session("player_token", player_token)
        |> redirect(to: ~p"/game/#{game_id}")

      {:error, err} ->
        # on error, redirect back to the join page with the error message
        conn
        |> put_flash(:error, "Error joining game: #{inspect(err)}")
        |> redirect(to: ~p"/game/#{game_id}/join")
    end
  end

  def clear(conn, params) do
    new_game_id = params["new_game_id"]
    _to = params["to"] || "/"

    conn =
      conn
      |> clear_session()

    cond do
      new_game_id && String.length(new_game_id) > 1 ->
        redirect(conn, to: ~p"/game/#{new_game_id}/join")

      true ->
        redirect(conn, to: ~p"/")
    end
  end
end

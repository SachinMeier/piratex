defmodule PiratexWeb.GameController do
  use PiratexWeb, :controller

  def new_game(conn, _params) do
    # start the game
    {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

    conn =
      conn
      |> clear_session()

    # have the player join the game
    redirect(conn, to: ~p"/game/#{game_id}/join")
  end

  def join_game(%{params: %{"id" => game_id}} = conn, %{"player" => player_name} = _params) do
    player_token = Piratex.GameHelpers.new_player_token()
    case Piratex.Game.join_game(game_id, player_name, player_token) do
      :ok ->
        conn
        |> put_session("game_id", game_id)
        |> put_session("player_name", player_name)
        |> put_session("player_token", player_token)
        |> redirect(to: ~p"/game/#{game_id}")

      {:error, _err} ->
        conn
        # |> put_flash(:error, "Error joining game: #{inspect(err)}")
        |> redirect(to: ~p"/find")
    end
  end

  def clear(conn, params) do
    new_game_id = params["new_game_id"]
    _to = params["to"] || "/"

    conn =
      conn
      |> clear_session()

    cond do
      new_game_id && length(new_game_id) > 1 ->
        redirect(conn, to: ~p"/game/#{new_game_id}/join")

      true ->
        redirect(conn, to: ~p"/")
    end
  end
end

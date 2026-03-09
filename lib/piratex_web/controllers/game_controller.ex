defmodule PiratexWeb.GameController do
  use PiratexWeb, :controller

  alias Piratex.LetterPoolService

  def new_game(conn, %{"letter_pool" => letter_pool_type}) do
    case LetterPoolService.letter_pool_from_string(letter_pool_type) do
      {:ok, pool_type} ->
        {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

        :ok = Piratex.Game.set_letter_pool_type(game_id, pool_type)

        conn
        |> clear_session()
        |> redirect(to: ~p"/game/#{game_id}/join")

      :error ->
        conn
        |> put_flash(:error, "Invalid letter pool")
        |> redirect(to: ~p"/create_game")
    end
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
        conn
        |> put_flash(:error, join_error_message(err))
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

  defp join_error_message(:duplicate_player), do: "That player name is already taken."
  defp join_error_message(:player_name_too_short), do: "Player name is too short."
  defp join_error_message(:player_name_too_long), do: "Player name is too long."
  defp join_error_message(:team_name_taken), do: "That player name is unavailable."
  defp join_error_message(:game_full), do: "That game is full."
  defp join_error_message(:game_already_started), do: "That game has already started."
  defp join_error_message(:not_found), do: "Game not found."
  defp join_error_message(_), do: "Unable to join that game."
end

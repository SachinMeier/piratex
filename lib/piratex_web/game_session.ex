defmodule PiratexWeb.GameSession do
  @moduledoc """
  This module is responsible for handling the game session.
  It is called whenever a LiveView for /game/:id is mounted.
  If the player is already in the game, it will rejoin the game.
  If the player is not in the game, it will issue a new token and attempt to join the game.
  """

  use PiratexWeb, :live_view

  use PiratexWeb, :verified_routes

  def on_mount(:new, %{"id" => game_id} = _params, session, socket) do
    session_game_id = session["game_id"]

    if session_game_id do
      # If player already has a session, they can rejoin the game
      player_name = session["player_name"]
      player_token = session["player_token"]

      if session_game_id == game_id do
        # TODO: validate the player_token with the Game
        case Piratex.Game.rejoin_game(game_id, player_name, player_token) do
          :ok ->
            socket =
              socket
              |> assign(game_id: game_id)
              |> assign(player_name: player_name)
              |> assign(player_token: player_token)

            {:cont, socket}

          {:error, err} ->
            socket =
              socket
              |> put_flash("error", "Error rejoining game: #{inspect(err)}")
              |> redirect(to: ~p"/find")

            {:halt, socket}
        end
      else
        # player is joining a different game.
        # We don't really care about the result of leaving the old game
        Piratex.Game.quit_game(session_game_id, player_token)
        # clear the old session and redirect to the new game
        redirect(socket, to: ~p"/clear?new_game_id=#{game_id}")
      end
    else
      # Session doesn't exist.
      socket =
        socket
        # |> put_flash(:error, "No session found. Please join the game.")
        |> redirect(to: ~p"/find")

      {:halt, socket}
    end
  end

  def rejoin_game_from_session(session, socket) do
    session_game_id = session["game_id"]

    if session_game_id do
      # If player already has a session, they can rejoin the game
      player_name = session["player_name"]
      player_token = session["player_token"]

      # TODO: validate the player_token with the Game
      case Piratex.Game.rejoin_game(session_game_id, player_name, player_token) do
        :ok ->
          socket =
            socket
            |> assign(game_id: session_game_id)
            |> assign(player_name: player_name)
            |> assign(player_token: player_token)
            |> redirect(to: ~p"/game/#{session_game_id}")

          {:found, socket}

        {:error, _err} ->
          socket =
            socket
            # |> put_flash(:error, "Error rejoining game: #{inspect(err)}")
            |> redirect(to: ~p"/clear")

          {:not_found, socket}
      end
    else
      {:not_found, socket}
    end
  end
end

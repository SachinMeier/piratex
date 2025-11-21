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
        case Piratex.Game.rejoin_game(game_id, player_name, player_token) do
          :ok ->
            socket =
              socket
              |> assign(game_id: game_id)
              |> assign(player_name: player_name)
              |> assign(player_token: player_token)

            {:cont, socket}


          {:error, _err} ->
            # this is most likely because the player is trying to join an old game.
            # clear the old session and send them to /
            socket =
              socket
              |> put_flash("error", "Error rejoining game")
              |> redirect(to: ~p"/clear")

            {:halt, socket}
        end
      else
        # player is joining a different game.
        # We don't really care about the result of leaving the old game
        Piratex.Game.quit_game(session_game_id, player_token)
        # clear the old session and redirect to the new game
        socket =
          socket
          |> assign_seo_metadata_for_join_game(game_id)
          |> redirect(to: ~p"/clear?new_game_id=#{game_id}")

        {:halt, socket}
      end
    else
      # Session doesn't exist. They are attempting to join a new game.
      socket =
        case Piratex.Game.find_by_id(game_id) do
          {:ok, _} ->
            socket
            |> assign_seo_metadata_for_join_game(game_id)
            |> redirect(to: ~p"/game/#{game_id}/join")

          {:error, :not_found} ->
            socket
            |> put_flash(:error, "Game not found")
            |> redirect(to: ~p"/find")
        end

      {:halt, socket}
    end
  end

  def assign_seo_metadata_for_join_game(socket, game_id) do
    title = "Join Game #{game_id} | Pirate Scrabble"
    description = "Join Pirate Scrabble Game #{game_id}"

    assign(socket, seo_metadata: %{
      og_title: title,
      og_description: description,
      twitter_title: title,
      twitter_description: description
    })
  end

  # This function is similar to on_mount above, but does not handle
  # the game_id param, so it can't be used to join a new game. Instead
  # it allows auto-rejoining a game when the player isn't at the /join or /game/:id page.
  def rejoin_game_from_session(session, socket) do
    session_game_id = session["game_id"]

    if session_game_id do
      # If player already has a session, they can rejoin the game
      player_name = session["player_name"]
      player_token = session["player_token"]

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
            |> redirect(to: ~p"/clear")

          {:not_found, socket}
      end
    else
      {:not_found, socket}
    end
  end
end

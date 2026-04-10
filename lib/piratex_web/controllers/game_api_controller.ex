defmodule PiratexWeb.GameAPIController do
  @moduledoc """
  JSON endpoints consumed by the TUI before any channel can be opened.

  * `POST /api/games` — create a new game, optionally specifying a letter pool.
  * `GET  /api/games` — paginated list of waiting games.
  * `GET  /api/games/:id` — one-shot snapshot of a game's sanitized state.
  * `POST /api/games/:id/players` — register a player, returning a token.

  All responses are JSON. Errors return `{ "error": "<reason>" }` with a
  status code determined by the reason (see TUI_PLAN.md §3.1).

  Authentication is not enforced here: token possession is the entire auth
  model, same as the browser session cookie.
  """

  use PiratexWeb, :controller

  alias Piratex.DynamicSupervisor
  alias Piratex.Game
  alias Piratex.LetterPoolService
  alias Piratex.PlayerService
  alias PiratexWeb.GameChannel
  alias PiratexWeb.Protocol

  plug :check_protocol_headers

  @default_pool :bananagrams

  def create(conn, params) do
    with {:ok, pool_type} <- parse_pool(Map.get(params, "letter_pool")),
         {:ok, game_id} <- DynamicSupervisor.new_game(),
         :ok <- Game.set_letter_pool_type(game_id, pool_type) do
      conn
      |> put_status(:created)
      |> json(%{game_id: game_id})
    else
      {:error, :invalid_pool} -> send_error(conn, :bad_request, :invalid_pool)
      {:error, reason} -> send_error(conn, :internal_server_error, reason)
    end
  end

  def index(conn, params) do
    page =
      params
      |> Map.get("page", "1")
      |> parse_page()

    %{games: games, page: page, has_next: has_next} =
      DynamicSupervisor.list_games_page(page: page)

    json(conn, %{
      games: Enum.map(games, &game_summary/1),
      page: page,
      has_next: has_next
    })
  end

  def show(conn, %{"id" => game_id}) do
    case Game.get_state(game_id) do
      {:ok, state} -> json(conn, GameChannel.encode_state(state))
      {:error, :not_found} -> send_error(conn, :not_found, :not_found)
    end
  end

  def join(conn, %{"id" => game_id} = params) do
    player_name = Map.get(params, "player_name", "")
    player_token = PlayerService.new_player_token()

    case Game.find_by_id(game_id) do
      {:error, :not_found} ->
        send_error(conn, :not_found, :not_found)

      {:ok, _state} ->
        case Game.join_game(game_id, player_name, player_token) do
          :ok ->
            conn
            |> put_status(:created)
            |> json(%{
              game_id: game_id,
              player_name: player_name,
              player_token: player_token
            })

          {:error, reason} ->
            send_error(conn, status_for_reason(reason), reason)
        end
    end
  end

  # Defaults to bananagrams when the client omits or nulls the field.
  defp parse_pool(nil), do: {:ok, @default_pool}
  defp parse_pool(""), do: {:ok, @default_pool}

  defp parse_pool(value) when is_binary(value) do
    case LetterPoolService.letter_pool_from_string(value) do
      {:ok, pool_type} -> {:ok, pool_type}
      :error -> {:error, :invalid_pool}
    end
  end

  defp parse_pool(_value), do: {:error, :invalid_pool}

  defp parse_page(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp game_summary(game_state) do
    %{
      id: game_state.id,
      status: game_state.status,
      player_count: length(game_state.players)
    }
  end

  defp send_error(conn, status, reason) do
    conn
    |> put_status(status)
    |> json(%{error: to_string(reason)})
  end

  # Reason → HTTP status mapping per TUI_PLAN.md §3.1.
  defp status_for_reason(:not_found), do: :not_found
  defp status_for_reason(:game_full), do: :conflict
  defp status_for_reason(:game_already_started), do: :conflict
  defp status_for_reason(:duplicate_player), do: :conflict
  defp status_for_reason(:team_name_taken), do: :conflict
  defp status_for_reason(:player_name_too_short), do: :bad_request
  defp status_for_reason(:player_name_too_long), do: :bad_request
  defp status_for_reason(:invalid_pool), do: :bad_request
  defp status_for_reason(:invalid_body), do: :bad_request
  defp status_for_reason(_), do: :internal_server_error

  # Inspects the X-Piratex-Protocol-Major / X-Piratex-Protocol-Minor headers.
  # Missing headers are treated as 0.0, which triggers :client_outdated on any
  # non-zero server version. Minor behind is acceptable at the HTTP layer.
  defp check_protocol_headers(conn, _opts) do
    {major, minor} = read_protocol_headers(conn)

    case Protocol.compare(major, minor) do
      :ok ->
        conn

      :minor_behind ->
        conn

      :client_outdated ->
        conn
        |> put_status(:upgrade_required)
        |> json(%{
          error: "client_outdated",
          severity: "hard",
          server_version: Protocol.version_string(),
          client_version: "#{major}.#{minor}",
          upgrade_url: Protocol.upgrade_url()
        })
        |> halt()

      :server_outdated ->
        conn
        |> put_status(:upgrade_required)
        |> json(%{
          error: "server_outdated",
          severity: "hard",
          server_version: Protocol.version_string(),
          client_version: "#{major}.#{minor}"
        })
        |> halt()
    end
  end

  defp read_protocol_headers(conn) do
    major = header_int(conn, "x-piratex-protocol-major", 0)
    minor = header_int(conn, "x-piratex-protocol-minor", 0)
    {major, minor}
  end

  defp header_int(conn, name, default) do
    case get_req_header(conn, name) do
      [value | _] ->
        case Integer.parse(value) do
          {n, ""} -> n
          _ -> default
        end

      [] ->
        default
    end
  end
end

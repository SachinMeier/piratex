defmodule PiratexWeb.GameChannel do
  @moduledoc """
  Phoenix Channel adapter for non-LiveView clients. Joins on topic
  `"game:<id>"`, subscribes to the game's PubSub events topic, and forwards
  inbound commands to `Piratex.Game.*`.

  The channel stays thin: every `handle_in/3` clause is a one-line delegation
  to the game API. State is never interpreted here; it's forwarded verbatim
  (after converting the `challenged_words` MapSet to a JSON-friendly list).
  """

  use Phoenix.Channel

  require Logger

  alias Piratex.Config
  alias Piratex.Game
  alias PiratexWeb.Protocol

  @watch_only_error %{reason: :watch_only}

  @impl true
  def join("game:" <> game_id, params, socket) do
    client_major = Map.get(params, "protocol_major", 0)
    client_minor = Map.get(params, "protocol_minor", 0)
    intent = Map.get(params, "intent", "join")
    player_name = Map.get(params, "player_name", "")
    player_token = socket.assigns.player_token

    with :ok <- check_protocol(client_major, client_minor),
         {:ok, _state} <- fetch_game(game_id),
         :ok <- handle_intent(intent, game_id, player_name, player_token) do
      send(self(), :after_join)

      socket =
        socket
        |> assign(:game_id, game_id)
        |> assign(:player_name, player_name)
        |> assign(:intent, intent)
        |> assign(:minor_behind, client_minor < Protocol.minor())

      Phoenix.PubSub.subscribe(Piratex.PubSub, Game.events_topic(game_id))

      {:ok, join_reply(game_id, socket.assigns.minor_behind), socket}
    end
  end

  defp check_protocol(client_major, client_minor) do
    case Protocol.compare(client_major, client_minor) do
      :ok ->
        :ok

      :minor_behind ->
        :ok

      :client_outdated ->
        Logger.warning("protocol client_outdated",
          client_version: "#{client_major}.#{client_minor}",
          server_version: Protocol.version_string()
        )

        {:error,
         %{
           reason: :client_outdated,
           severity: :hard,
           server_version: Protocol.version_string(),
           client_version: "#{client_major}.#{client_minor}",
           upgrade_url: Protocol.upgrade_url()
         }}

      :server_outdated ->
        Logger.warning("protocol server_outdated",
          client_version: "#{client_major}.#{client_minor}",
          server_version: Protocol.version_string()
        )

        {:error,
         %{
           reason: :server_outdated,
           severity: :hard,
           server_version: Protocol.version_string(),
           client_version: "#{client_major}.#{client_minor}"
         }}
    end
  end

  defp fetch_game(game_id) do
    case Game.find_by_id(game_id) do
      {:ok, state} -> {:ok, state}
      {:error, :not_found} -> {:error, %{reason: :not_found}}
    end
  end

  defp handle_intent("join", game_id, player_name, player_token) do
    normalize_game_reply(Game.join_game(game_id, player_name, player_token))
  end

  defp handle_intent("rejoin", game_id, player_name, player_token) do
    normalize_game_reply(Game.rejoin_game(game_id, player_name, player_token))
  end

  defp handle_intent("watch", _game_id, _player_name, _player_token), do: :ok

  defp handle_intent(_other, _game_id, _player_name, _player_token) do
    {:error, %{reason: :invalid_intent}}
  end

  defp normalize_game_reply(:ok), do: :ok
  defp normalize_game_reply({:error, reason}), do: {:error, %{reason: reason}}

  defp join_reply(game_id, minor_behind?) do
    %{
      game_id: game_id,
      protocol: %{
        major: Protocol.major(),
        minor: Protocol.minor()
      },
      upgrade_available: minor_behind?,
      config: game_config()
    }
  end

  defp game_config do
    %{
      turn_timeout_ms: Config.turn_timeout_ms(),
      challenge_timeout_ms: Config.challenge_timeout_ms(),
      min_word_length: Config.min_word_length(),
      max_chat_message_length: Game.max_chat_message_length(),
      min_player_name: Config.min_player_name(),
      max_player_name: Config.max_player_name(),
      min_team_name: Config.min_team_name(),
      max_team_name: Config.max_team_name()
    }
  end

  @impl true
  def handle_info(:after_join, socket) do
    case Game.get_state(socket.assigns.game_id) do
      {:ok, state} ->
        push(socket, "state", encode_state(state))
        {:noreply, socket}

      {:error, :not_found} ->
        {:stop, {:shutdown, :game_not_found}, socket}
    end
  end

  def handle_info({:new_state, state}, socket) do
    push(socket, "state", encode_state(state))
    {:noreply, socket}
  end

  # Sanitized state contains tuples that Jason cannot encode directly:
  #
  #   * `challenged_words` is a `MapSet` of `{victim, thief}` tuples.
  #   * `game_stats.score_timeline` is `%{team_idx => [{letter_count, score}, ...]}`.
  #
  # Convert both at the wire boundary so `Piratex.Helpers.state_for_player/1`
  # stays untouched and the LiveView keeps working unchanged.
  @doc false
  def encode_state(state) do
    state
    |> Map.update!(:challenged_words, &encode_challenged_words/1)
    |> Map.update(:game_stats, nil, &encode_game_stats/1)
  end

  defp encode_challenged_words(%MapSet{} = mapset) do
    mapset
    |> MapSet.to_list()
    |> Enum.map(fn {victim, thief} -> [victim, thief] end)
  end

  defp encode_challenged_words(list) when is_list(list) do
    Enum.map(list, fn
      {victim, thief} -> [victim, thief]
      [_, _] = pair -> pair
    end)
  end

  defp encode_game_stats(nil), do: nil

  defp encode_game_stats(%{} = stats) do
    Map.update(stats, :score_timeline, %{}, fn timeline ->
      Map.new(timeline, fn {team_idx, points} ->
        {team_idx, Enum.map(points, fn {x, y} -> [x, y] end)}
      end)
    end)
  end

  ########## Inbound commands ##########

  @impl true
  def handle_in(_event, _payload, %{assigns: %{intent: "watch"}} = socket) do
    {:reply, {:error, @watch_only_error}, socket}
  end

  def handle_in("start_game", _payload, socket) do
    reply_with(Game.start_game(socket.assigns.game_id, socket.assigns.player_token), socket)
  end

  def handle_in("create_team", %{"team_name" => team_name}, socket) do
    Game.create_team(socket.assigns.game_id, socket.assigns.player_token, team_name)
    |> reply_with(socket)
  end

  def handle_in("join_team", %{"team_id" => team_id}, socket) when is_integer(team_id) do
    Game.join_team(socket.assigns.game_id, socket.assigns.player_token, team_id)
    |> reply_with(socket)
  end

  def handle_in("set_letter_pool_type", %{"pool_type" => pool_type}, socket)
      when is_binary(pool_type) do
    case Piratex.LetterPoolService.letter_pool_from_string(pool_type) do
      {:ok, pool_type_atom} ->
        Game.set_letter_pool_type(socket.assigns.game_id, pool_type_atom)
        |> reply_with(socket)

      :error ->
        {:reply, {:error, %{reason: :invalid_pool}}, socket}
    end
  end

  def handle_in("flip_letter", _payload, socket) do
    Game.flip_letter(socket.assigns.game_id, socket.assigns.player_token)
    |> reply_with(socket)
  end

  def handle_in("claim_word", %{"word" => word}, socket) when is_binary(word) do
    Game.claim_word(socket.assigns.game_id, socket.assigns.player_token, word)
    |> reply_with(socket)
  end

  def handle_in("challenge_word", %{"word" => word}, socket) when is_binary(word) do
    Game.challenge_word(socket.assigns.game_id, socket.assigns.player_token, word)
    |> reply_with(socket)
  end

  def handle_in(
        "challenge_vote",
        %{"challenge_id" => challenge_id, "vote" => vote},
        socket
      )
      when is_integer(challenge_id) and is_boolean(vote) do
    Game.challenge_vote(socket.assigns.game_id, socket.assigns.player_token, challenge_id, vote)
    |> reply_with(socket)
  end

  def handle_in("send_chat_message", %{"message" => message}, socket) when is_binary(message) do
    Game.send_chat_message(socket.assigns.game_id, socket.assigns.player_token, message)
    |> reply_with(socket)
  end

  def handle_in("end_game_vote", _payload, socket) do
    Game.end_game_vote(socket.assigns.game_id, socket.assigns.player_token)
    |> reply_with(socket)
  end

  def handle_in("leave_waiting_game", _payload, socket) do
    Game.leave_waiting_game(socket.assigns.game_id, socket.assigns.player_token)
    |> reply_with(socket)
  end

  def handle_in("quit_game", _payload, socket) do
    Game.quit_game(socket.assigns.game_id, socket.assigns.player_token)
    |> reply_with(socket)
  end

  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{reason: :invalid_payload}}, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{game_id: game_id} ->
        Phoenix.PubSub.unsubscribe(Piratex.PubSub, Game.events_topic(game_id))

      _ ->
        :ok
    end

    :ok
  end

  defp reply_with(:ok, socket), do: {:reply, {:ok, %{}}, socket}

  defp reply_with({:error, reason}, socket),
    do: {:reply, {:error, %{reason: reason}}, socket}
end

defmodule Piratex.Game do
  @moduledoc """
  Game is a GenServer that manages the state for a single game. It maintains a token
  for every player and receives calls from the client to update the game state. It
  also uses PubSub to communicate state changes back to all clients.
  """
  use GenServer

  alias Piratex.GameHelpers
  alias Piratex.Player
  alias Piratex.WordSteal
  alias Piratex.Services.ChallengeService.Challenge
  alias Piratex.Services.ChallengeService
  alias Piratex.Services.WordClaimService

  # 1 minute for the first player to join
  @new_game_timeout 60_000
  # games timeout after 1 hour of inactivity
  @game_timeout 3_600_000
  # 10 seconds at the end of game for claims
  @end_game_time 10_000

  @type game_status :: :waiting | :playing | :finished

  @derive {Inspect, except: [:letter_pool]}

  @type t :: %__MODULE__{
    # game_id
    id: String.t(),
    # game status
    status: game_status(),
    # list of players
    players: list(Player.t()),
    # idx of player in players whose turn it is
    turn: non_neg_integer(),
    # list of unflipped letters left
    letter_pool: list(String.t()),
    # list of single letters in the center. This is sorted chronologically and is for users
    center: list(String.t()),
    # same as center, but sorted alphabetically for word-stealing algo
    center_sorted: list(String.t()),
    # history of words made by all players in descending order of creation (most recent first)
    history: list(WordSteal.t()),
    # list of challenges
    # this list is in ascending order of creation (oldest first), though there should only ever be 1 at a time
    challenges: list(Challenge.t()),
    # list of challenges that have been voted on.
    # this list is in descending order of creation (most recent first)
    past_challenges: list(Challenge.t())
  }

  defstruct [
    :id,
    :status,
    :players,
    :turn,
    :letter_pool,
    :center,
    :center_sorted,
    :history,
    :challenges,
    :past_challenges
  ]

  @doc """
  Creates a new game.
  """
  @spec new_game(String.t()) :: t()
  def new_game(id) do
    %__MODULE__{
      id: id,
      status: :waiting,
      players: [],
      turn: 0,
      letter_pool: Piratex.GameHelpers.letter_pool(),
      center: [],
      center_sorted: [],
      history: [],
      challenges: [],
      past_challenges: []
    }
  end

  @doc """
  Generates a new game ID.
  """
  @spec new_game_id() :: String.t()
  def new_game_id() do
    :crypto.strong_rand_bytes(4)
    |> Base.encode32(padding: false)
    |> String.upcase()
  end

  @doc """
  Starts a new game.
  """
  @spec start_link(String.t()) :: {:ok, pid()}
  def start_link(id) do
    GenServer.start_link(__MODULE__, %{id: id}, name: via_tuple(id))
  end

  @doc """
  Returns the via tuple for the game.
  """
  def via_tuple(id), do: {:via, Registry, {Piratex.Game.Registry, id}}

  # Events Topic is for Game to publish to LiveView Clients
  @spec events_topic(String.t()) :: String.t()
  def events_topic(id), do: "game-events:#{id}"
  # def moves_topic(id), do: "game-moves:#{id}"

  @doc """
  Initializes the game.
  """
  @impl true
  def init(%{id: id}) do
    state = new_game(id)
    {:ok, state, game_timeout(state)}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state_for_player(state), state, game_timeout(state)}
  end

  def handle_call({:join, player_name, player_token}, _from, %{status: :waiting} = state) do
    cond do
      length(state.players) >= GameHelpers.max_players() ->
        {:reply, {:error, :game_full}, state, game_timeout(state)}

      !GameHelpers.player_is_unique?(state, player_name, player_token) ->
        {:reply, {:error, :duplicate_player}, state, game_timeout(state)}

      true ->
        # IO.puts("Joining game #{state.id} with name #{player_name} and token #{player_token}")
        new_player = Player.new(player_name, player_token)
        new_state = GameHelpers.add_player(state, new_player)
        broadcast_new_state(new_state)
        {:reply, :ok, new_state, game_timeout(state)}
    end
  end

  def handle_call({:join, _player_name, _player_token}, _from, %{status: :playing} = state) do
    {:reply, {:error, :game_already_started}, state, game_timeout(state)}
  end

  def handle_call({:rejoin, player_name, player_token}, _from, state) do
    # ensure player is in the game.
    # TODO: This doesn't prevent token duplication
    # (player using multiple clients by copying over the token)
    case GameHelpers.find_player(state, player_token) do
      nil -> {:reply, {:error, :not_found}, state, game_timeout(state)}
      _ ->
        IO.puts("Rejoining game #{state.id} with name #{player_name} and token #{player_token}")
        {:reply, :ok, state, game_timeout(state)}
    end
  end

  def handle_call({:leave_waiting_game, player_token}, _from, state) do
    # actually remove the player from the list
    new_players = Enum.filter(state.players, fn %{token: token} -> token != player_token end)
    if length(new_players) == 0 do
      Process.send(self(), :stop, [])
      {:reply, :ok, state, game_timeout(state)}
    else
      new_state = Map.put(state, :players, new_players)
      broadcast_new_state(new_state)
      {:reply, :ok, new_state, game_timeout(state)}
    end
  end

  def handle_call({:quit, player_token}, _from, state) do
    # if a player quits mid game, just mark them as quit, but don't remove them. Their
    # words must stay for others to steal
    new_players = Enum.map(state.players, fn %{token: token} = player ->
      if token == player_token do
        Piratex.Player.quit(player)
      else
        player
      end
    end)

    new_state =
      Map.put(state, :players, new_players)

    # TODO: if all players have quit, show end score? everyone's quit so who cares

    broadcast_new_state(new_state)
    {:reply, :ok, new_state, game_timeout(state)}
  end

  def handle_call({:start_game, _player_token}, _from, %{status: :waiting} = state) do
    # TODO: only let the player who started the game start it
    new_state = Map.put(state, :status, :playing)
    broadcast_new_state(new_state)
    {:reply, :ok, new_state, game_timeout(state)}
  end

  def handle_call({:flip_letter, player_token}, _from, %{status: :playing} = state) do
    if GameHelpers.is_player_turn?(state, player_token) do
      new_state = GameHelpers.update_state_new_letter(state)
      if GameHelpers.no_more_letters?(new_state) do
        Process.send_after(self(), :end_game, @end_game_time)
      end
      broadcast_new_state(new_state)
      {:reply, :ok, new_state, game_timeout(state)}
    else
      {:reply, {:error, :not_your_turn}, state, game_timeout(state)}
    end
  end

  def handle_call({:flip_letter, _player_token}, _from, state) do
    {:reply, {:error, :game_not_playing}, state, game_timeout(state)}
  end

  # TODO: add rate limiting on invalid claims
  # TODO: allow players to dispute claims as derivative
  def handle_call({:claim_word, player_token, word}, _from, %{status: :playing} = state) do
    # verify player_token and fetch that player
    with {_, player = %Player{status: :playing}} <- {:find_player, GameHelpers.find_player(state, player_token)},
         {_, {:ok, new_state}} <- {:handle_word_claim, WordClaimService.handle_word_claim(state, player, word)} do

        broadcast_new_state(new_state)
        {:reply, :ok, new_state, game_timeout(state)}
    else
      {:find_player, nil} ->
        IO.puts("Player not found")
        {:reply, {:error, :not_found}, state, game_timeout(state)}
      # if word is invalid, no state change.
      {:handle_word_claim, {err, state}} ->
        # TODO: add rate limiting on invalid claims
        {:reply, {:error, err}, state, game_timeout(state)}
    end
  end

  def handle_call({:claim_word, _player_token, _word}, _from, state) do
    {:reply, {:error, :game_not_playing}, state, game_timeout(state)}
  end

  def handle_call({:challenge_word, player_token, word}, _from, state) do
    case ChallengeService.handle_word_challenge(state, player_token, word) do
      {:error, err} ->
        {:reply, {:error, err}, state, game_timeout(state)}

      state ->
        broadcast_new_state(state)
        {:reply, :ok, state, game_timeout(state)}
    end
  end

  def handle_call({:challenge_vote, player_token, challenge_id, vote}, _from, state) do
    IO.inspect("CALL: challenge vote")
    case ChallengeService.handle_challenge_vote(state, player_token, challenge_id, vote) do
      {:error, err} ->
        {:reply, {:error, err}, state, game_timeout(state)}

      state ->
        broadcast_new_state(state)
        {:reply, :ok, state, game_timeout(state)}
    end
  end

  def handle_call(:end_game, _from, state) do
    send(self(), :end_game)
    {:reply, :ok, state, game_timeout(state)}
  end

  @impl true
  def handle_info(:end_game, state) do
    state =
      state
      |> Map.put(:status, :finished)
      |> GameHelpers.calculate_scores()
    broadcast_new_state(state)
    {:noreply, state}
  end

  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info(:timeout, state) do
    IO.puts("Game #{state.id} timed out")
    {:stop, :normal, state}
  end

  @impl true
  def terminate(reason, state) do
    IO.puts("Game #{state.id} terminated: #{inspect(reason)}")
    :ok
  end

  # Functions

  @doc """
  Broadcasts the new state to the game events topic.
  We currently don't send updates, just the entire new state.
  might be inefficient data-wise, but it prevents having to implement
  game logic on the LiveView.
  """
  @spec broadcast_new_state(t()) :: :ok
  def broadcast_new_state(state) do
    publish_state = state_for_player(state)
    Phoenix.PubSub.broadcast(Piratex.PubSub, events_topic(state.id), {:new_state, publish_state})
  end

  @doc """
  Returns the state for a player.
  """
  @spec state_for_player(t()) :: map()
  def state_for_player(state) do
    %{
      # id will be used by clients to make calls to the correct game process
      id: state.id,
      status: state.status,
      # we strip the tokens from the state to avoid leaking tokens
      players: drop_internal_states(state.players),
      # whose turn it is
      turn: state.turn,
      # clients check this to disable the Flip button when game is over.
      letter_pool: state.letter_pool,
      # only give the chronologically sorted center to the player
      center: state.center,
      history: state.history,
      challenges: state.challenges,
      # clients use this to show/hide the challenge button on past
      past_challenges: state.past_challenges
    }
  end

  @doc """
  Removes the player tokens and status from the state. We only send the player
  name, words, and score to the client not the tokens of all players (for obvious reasons)
  """
  @spec drop_internal_states(list(Player.t())) :: list(map())
  def drop_internal_states(players) do
    players
    |> Enum.map(&Player.drop_internal_state/1)
  end

  # Games with no players timeout after 1 minute of inactivity
  # Games with players timeout after 1 hour of inactivity
  @spec game_timeout(t()) :: non_neg_integer()
  defp game_timeout(%{players: []}), do: @new_game_timeout
  defp game_timeout(_), do: @game_timeout

  ########## Player API ##########

  def find_by_id(game_id) do
    case Registry.lookup(Piratex.Game.Registry, game_id) do
      [{pid, _}] -> {:ok, GenServer.call(pid, :get_state)}
      [] -> {:error, :not_found}
    end
  end

  def join_game(game_id, player_name, player_token) do
    genserver_call(game_id, {:join, player_name, player_token})
  end

  def rejoin_game(game_id, player_name, player_token) do
    case find_by_id(game_id) do
      {:ok, %{status: :playing} = _state} -> genserver_call(game_id, {:rejoin, player_name, player_token})
      {:ok, %{status: :waiting} = _state} -> genserver_call(game_id, {:rejoin, player_name, player_token})
      {:ok, %{status: :finished} = _state} -> {:error, :game_finished}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def leave_waiting_game(game_id, player_token) do
    genserver_call(game_id, {:leave_waiting_game, player_token})
  end

  def quit_game(game_id, player_token) do
    genserver_call(game_id, {:quit, player_token})
  end

  def start_game(game_id, player_token) do
    genserver_call(game_id, {:start_game, player_token})
  end

  def get_state(game_id) do
    genserver_call(game_id, :get_state)
  end

  def flip_letter(game_id, player_token) do
    genserver_call(game_id, {:flip_letter, player_token})
  end

  def claim_word(game_id, player_token, word) do
    genserver_call(game_id, {:claim_word, player_token, String.downcase(word)})
  end

  def challenge_word(game_id, player_token, word) do
    genserver_call(game_id, {:challenge_word, player_token, word})
  end

  def challenge_vote(game_id, player_token, challenge_id, vote) do
    genserver_call(game_id, {:challenge_vote, player_token, challenge_id, vote})
  end

  def end_game(game_id) do
    genserver_call(game_id, :end_game)
  end

  def genserver_call(game_id, data) do
    GenServer.call(Piratex.Game.via_tuple(game_id), data)
  end
end

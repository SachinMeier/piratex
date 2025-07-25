defmodule Piratex.Game do
  @moduledoc """
  Game is a GenServer that manages the state for a single game. It maintains a token
  for every player and receives calls from the client to update the game state. It
  also uses PubSub to communicate state changes back to all clients.
  """
  use GenServer

  alias Piratex.Helpers
  alias Piratex.Player
  alias Piratex.Team
  alias Piratex.WordSteal
  alias Piratex.ChallengeService.Challenge
  alias Piratex.Config

  alias Piratex.ChallengeService
  alias Piratex.PlayerService
  alias Piratex.ScoreService
  alias Piratex.TurnService
  alias Piratex.TeamService
  alias Piratex.WordClaimService

  @type game_status :: :waiting | :playing | :finished

  @derive {Inspect, except: [:letter_pool]}

  @type t :: %__MODULE__{
          # game_id
          id: String.t(),
          # game status
          status: game_status(),
          # map of %{player_token => team_id}
          players_teams: map(),
          # list of teams
          teams: list(Team.t()),
          # list of unassigned players. TODO: Clear when the game starts
          players: list(Player.t()),
          # total_turn is the total turn. turn is calculated as total_turn % length(players)
          total_turn: non_neg_integer(),
          # idx of player in players whose turn it is
          turn: non_neg_integer(),
          # list of unflipped letters left
          letter_pool: list(String.t()),
          # initial letter count. used to show the progress bar
          initial_letter_count: pos_integer(),
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
          past_challenges: list(Challenge.t()),
          # map of %{player_name => true} for players who have voted to end the game.
          # this is used to skip the end game delay if all players have voted to end the game.
          end_game_votes: map(),
          # last action at. Allows the game to timeout if no player actions are made.
          last_action_at: DateTime.t()
        }

  defstruct [
    :id,
    :status,
    :players_teams,
    :teams,
    :players,
    :total_turn,
    :turn,
    :letter_pool,
    :initial_letter_count,
    :center,
    :center_sorted,
    :history,
    :challenges,
    :past_challenges,
    :end_game_votes,
    :last_action_at
  ]

  @doc """
  Creates a new game.
  """
  @spec new_game(String.t()) :: t()
  def new_game(id) do
    %__MODULE__{
      id: id,
      status: :waiting,
      players_teams: %{},
      teams: [],
      players: [],
      total_turn: 0,
      turn: 0,
      letter_pool: [],
      initial_letter_count: 0,
      center: [],
      center_sorted: [],
      history: [],
      challenges: [],
      past_challenges: [],
      end_game_votes: %{},
      last_action_at: DateTime.utc_now()
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
  @spec start_link(String.t() | t()) :: {:ok, pid()}
  def start_link(id, state \\ nil) do
    if state == nil do
      GenServer.start_link(__MODULE__, id, name: via_tuple(id))
    else
      GenServer.start_link(__MODULE__, state, name: via_tuple(state.id))
    end
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
  Initializes the game. If the id is a binary, it is a new game. If the id is a map, it is an existing game.
  This allows testing to pass in a custom state but could be used to load/resume a game.
  """
  @impl true
  def init(id) when is_binary(id) do
    state = new_game(id)
    {:ok, state, game_timeout(state)}
  end

  def init(state) when is_map(state) do
    {:ok, state, game_timeout(state)}
  end

  @spec set_last_action_at(t()) :: t()
  def set_last_action_at(state) do
    Map.put(state, :last_action_at, DateTime.utc_now())
  end

  @spec load_letter_pool(t(), atom()) :: t()
  def load_letter_pool(state, pool_type) do
    {letter_count,letter_pool} = Piratex.LetterPoolService.load_letter_pool(pool_type)
    state
    |> Map.put(:letter_pool, letter_pool)
    |> Map.put(:initial_letter_count, letter_count)
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state_for_player(state), state, game_timeout(state)}
  end

  def handle_call(:get_players_teams, _from, state) do
    {:reply, sanitize_players_teams(state), state, game_timeout(state)}
  end

  def handle_call({:join, player_name, player_token}, _from, %{status: :waiting} = state) do
    player_name_len = String.length(player_name)
    cond do
      # error if the game is full.
      PlayerService.count_unquit_players(state) >= Config.max_players() ->
        {:reply, {:error, :game_full}, state, game_timeout(state)}

      # error if the player name is too short
      player_name_len < Config.min_player_name() ->
        {:reply, {:error, :player_name_too_short}, state, game_timeout(state)}

      # error if the player name is too long
      player_name_len > Config.max_player_name() ->
        {:reply, {:error, :player_name_too_long}, state, game_timeout(state)}

      # error if the player name is already taken
      !PlayerService.player_is_unique?(state, player_name, player_token) ->
        {:reply, {:error, :duplicate_player}, state, game_timeout(state)}

      # error if the player's name is also a team's name
      !TeamService.team_name_unique?(state, player_name) ->
        {:reply, {:error, :team_name_taken}, state, game_timeout(state)}

      true ->
        new_player = Player.new(player_name, player_token)

        with %{} = state <- PlayerService.add_player(state, new_player) do
          {result, new_state} = assign_new_player_to_team(state, new_player)
          broadcast_new_state(new_state)
          {:reply, result, new_state, game_timeout(new_state)}
        end
    end
  end

  def handle_call({:join, _player_name, _player_token}, _from, %{status: :playing} = state) do
    {:reply, {:error, :game_already_started}, state, game_timeout(state)}
  end

  def handle_call({:rejoin, _player_name, player_token}, _from, state) do
    # ensure player is in the game.
    # TODO: This doesn't prevent token duplication
    # (player using multiple clients by copying over the token)
    case PlayerService.find_player(state, player_token) do
      nil ->
        {:reply, {:error, :not_found}, state, game_timeout(state)}

      _ ->
        {:reply, :ok, state, game_timeout(state)}
    end
  end

  # creates a new team and automatically assigns the creating player to that team
  def handle_call({:create_team, player_token, team_name}, _from, %{status: :waiting} = state) do
    team_name_len = String.length(team_name)

    with %Player{status: :playing} <- PlayerService.find_player(state, player_token) do
      cond do
        length(state.teams) >= Config.max_teams() ->
          {:reply, {:error, :no_more_teams_allowed}, state, game_timeout(state)}

        # error if the team name is too short
        team_name_len < Config.min_team_name() ->
          {:reply, {:error, :player_name_too_short}, state, game_timeout(state)}

        # error if the team name is too long
        team_name_len > Config.max_team_name() ->
          {:reply, {:error, :player_name_too_long}, state, game_timeout(state)}

        # error if the proposed team name is a player's name
        !PlayerService.player_is_unique?(state, team_name, "") ->
          {:reply, {:error, :team_name_taken}, state, game_timeout(state)}

        !TeamService.team_name_unique?(state, team_name) ->
          {:reply, {:error, :team_name_taken}, state, game_timeout(state)}

        true ->
          state = TeamService.create_team(state, player_token, team_name)

          broadcast_new_state(state)
          {:reply, :ok, state, game_timeout(state)}
      end
    else
      _ ->
      {:reply, {:error, :player_not_found}, state, game_timeout(state)}
    end
  end

  def handle_call({:join_team, player_token, team_id}, _from, state) do
    new_state = TeamService.add_player_to_team(state, player_token, team_id)

    broadcast_new_state(new_state)
    {:reply, :ok, new_state, game_timeout(new_state)}
  end

  def handle_call({:leave_waiting_game, player_token}, _from, %{status: :waiting} = state) do
    # actually remove the player from the game state
    new_state = PlayerService.remove_player(state, player_token)

    if length(new_state.players) == 0 do
      Process.send(self(), :stop, [])
      {:reply, :ok, state, game_timeout(state)}
    else
      # if this leaves an empty team, remove it.
      new_state = TeamService.remove_empty_teams(new_state)
      broadcast_new_state(new_state)
      {:reply, :ok, new_state, game_timeout(new_state)}
    end
  end

  def handle_call({:leave_waiting_game, _player_token}, _from, state) do
    {:reply, {:error, :game_already_started}, state, game_timeout(state)}
  end

  def handle_call({:quit, player_token}, _from, state) do
    # if a player quits mid game, just mark them as quit, but don't remove them. Their
    # words must stay for others to steal
    new_players =
      Enum.map(state.players, fn %{token: token} = player ->
        if token == player_token do
          Piratex.Player.quit(player)
        else
          player
        end
      end)

    # Check that there are remaining players still playing
    if Enum.any?(new_players, fn %{status: status} -> status == :playing end) do
      new_state = Map.put(state, :players, new_players)
      # if it was the quitter's turn, skip to next turn.
      new_state =
        if TurnService.is_player_turn?(new_state, player_token) do
          TurnService.next_turn(new_state)
        else
          new_state
        end

      case new_state.status do
        :playing ->
          # if the game is finished, check if the game_over vote is resolved
          if Helpers.no_more_letters?(new_state) and all_unquit_players_voted_to_end_game?(new_state) do
            Process.send(self(), :end_game, [])
          end
          # if there is an open challenge, check if it's resolved by the quit
          new_state =
            if ChallengeService.open_challenge?(new_state) do
              # This will reevaluate the challenge
              ChallengeService.remove_quitter_vote(new_state, player_token)
            else
              new_state
            end

          broadcast_new_state(new_state)
          {:reply, :ok, new_state, game_timeout(new_state)}

        :waiting ->
          new_state = TeamService.remove_empty_teams(new_state)
          broadcast_new_state(new_state)
          {:reply, :ok, new_state, game_timeout(new_state)}

        _ ->
          {:reply, :ok, new_state, game_timeout(new_state)}
      end
    else
      # if there are no players left, kill the game (don't calculate scores)
      {:reply, :ok, state, 0}
    end
  end

  def handle_call({:start_game, _player_token}, _from, %{status: :waiting} = state) do
    # TODO: only let the player who started the game start it
    new_state =
      state
      |> Map.put(:status, :playing)
      |> set_last_action_at()
      # use players_teams to assign all players to their permanent team
      |> TeamService.assign_players_to_teams()


    # if no letter pool is set, load the default bananagrams pool
    new_state =
      if state.initial_letter_count == 0 do
        load_letter_pool(new_state, :bananagrams)
      else
        new_state
      end

    broadcast_new_state(new_state)
    # start the turn timeout if there are more than 1 player
    if length(state.players) > 1 do
      TurnService.start_turn_timeout(state.total_turn)
    end

    {:reply, :ok, new_state, game_timeout(new_state)}
  end
  def handle_call({:start_game, _player_token}, _from, state) do
    {:reply, :game_already_started, state, game_timeout(state)}
  end

  def handle_call({:set_letter_pool_type, pool_type}, _from, %{status: :waiting} = state) do
    new_state = load_letter_pool(state, pool_type)

    {:reply, :ok, new_state, game_timeout(new_state)}
  end

  def handle_call({:set_letter_pool_type, _pool_type}, _from, %{status: _} = state) do
    {:reply, {:error, :game_already_started}, state, game_timeout(state)}
  end

  def handle_call({:flip_letter, player_token}, _from, %{status: :playing} = state) do
    cond do
      # Don't allow flipping letter if there is an open challenge
      ChallengeService.open_challenge?(state) ->
        {:reply, {:error, :challenge_open}, state, game_timeout(state)}

      # Don't allow flipping letter if it's not the player's turn
      !TurnService.is_player_turn?(state, player_token) ->
        state = set_last_action_at(state)
        {:reply, {:error, :not_your_turn}, state, game_timeout(state)}

      # Don't allow flipping letter if there are no more letters
      Helpers.no_more_letters?(state) ->
        {:reply, {:error, :no_more_letters}, state, game_timeout(state)}

      true ->
        new_state = TurnService.update_state_flip_letter(state)

        if Helpers.no_more_letters?(new_state) do
          Process.send_after(self(), :end_game, Config.end_game_time_ms())
        end

        new_state = set_last_action_at(new_state)
        broadcast_new_state(new_state)
        {:reply, :ok, new_state, game_timeout(new_state)}
    end
  end

  def handle_call({:flip_letter, _player_token}, _from, state) do
    {:reply, {:error, :game_not_playing}, state, game_timeout(state)}
  end

  # TODO: add rate limiting on invalid claims
  def handle_call({:claim_word, player_token, word}, _from, %{status: :playing} = state) do
    # verify player_token and fetch that player
    with {_, player = %Player{status: :playing}} <-
           {:find_player, PlayerService.find_player(state, player_token)},
        {_, team = %Team{}} <- {:find_team, Helpers.lookup_team(state, player_token)},
         {_, {:ok, new_state}} <-
           {:handle_word_claim, WordClaimService.handle_word_claim(state, team, player,word)} do
      new_state = set_last_action_at(new_state)
      broadcast_new_state(new_state)
      {:reply, :ok, new_state, game_timeout(new_state)}
    else
      # catch player not found & player not playing (quit)
      {:find_player, _} ->
        {:reply, {:error, :player_not_found}, state, game_timeout(state)}

      {:find_team, _} ->
        {:reply, {:error, :team_not_found}, state, game_timeout(state)}

      # if word is invalid, no state change.
      {:handle_word_claim, {err, state}} ->
        # TODO: add rate limiting on invalid claims
        state = set_last_action_at(state)
        {:reply, {:error, err}, state, game_timeout(state)}
    end
  end

  def handle_call({:claim_word, _player_token, _word}, _from, state) do
    {:reply, {:error, :game_not_playing}, state, game_timeout(state)}
  end

  def handle_call({:challenge_word, player_token, word}, _from, state) do
    case ChallengeService.handle_word_challenge(state, player_token, word) do
      {:error, err} ->
        state = set_last_action_at(state)
        {:reply, {:error, err}, state, game_timeout(state)}

      state ->
        new_state = set_last_action_at(state)
        broadcast_new_state(new_state)
        # challenge timeout is handled by the challenge service
        # so that it can be cancelled if the challenge is resolved
        {:reply, :ok, new_state, game_timeout(new_state)}
    end
  end

  def handle_call({:challenge_vote, player_token, challenge_id, vote}, _from, state) do
    case ChallengeService.handle_challenge_vote(state, player_token, challenge_id, vote) do
      {:error, err} ->
        {:reply, {:error, err}, state, game_timeout(state)}

      new_state ->
        broadcast_new_state(new_state)
        {:reply, :ok, new_state, game_timeout(new_state)}
    end
  end

  def handle_call({:end_game_vote, player_token}, _from, %{status: :playing} = state) do
    with {_, player = %Player{status: :playing}} <-
      {:find_player, PlayerService.find_player(state, player_token)} do
        new_state =
          Map.update(state, :end_game_votes, %{player.name => true},
            fn votes ->
              Map.put(votes, player.name, true)
            end)

        if all_unquit_players_voted_to_end_game?(new_state) do
          Process.send(self(), :end_game, [])
        end

        broadcast_new_state(new_state)
        {:reply, :ok, new_state, game_timeout(new_state)}
    else
      # catch player not found & player not playing (quit)
      {:find_player, _} ->
        {:reply, {:error, :not_found}, state, game_timeout(state)}
    end
  end

  def handle_call({:end_game_vote, _player_token}, _from, state) do
    {:reply, {:error, :game_not_endable}, state, game_timeout(state)}
  end

  defp all_unquit_players_voted_to_end_game?(state) do
    # for each player, check that they have either quit or voted to end the game
    Enum.reduce_while(state.players, true, fn player, acc ->
      cond do
        player.status == :quit ->
          {:cont, acc}
        Map.get(state.end_game_votes, player.name, false) ->
          {:cont, acc}
        true ->
          {:halt, false}
      end
    end)
  end

  # assign a new player to their own new team unless the max_teams limit is hit,
  # in which case we just assign the player to the first team.
  # TODO: maybe assign to a random team? qui bono
  defp assign_new_player_to_team(state, new_player) do
    if TeamService.team_count(state) >= Config.max_teams() do
      %{teams: [team | _]} = state
      # assign player to the first team.
      new_state = TeamService.add_player_to_team(state, new_player.token, team.id)
      {:ok, new_state}
    else
      # assign the player to a new team
      new_state = TeamService.create_team(state, new_player.token, Team.default_name(new_player.name))
      {:ok, new_state}
    end
  end

  @impl true
  def handle_info(:end_game, state) do
    new_state =
      # end all challenges
      Enum.reduce(state.challenges, state, fn challenge, state ->
        ChallengeService.timeout_challenge(state, challenge.id)
      end)
      |> Map.put(:status, :finished)
      |> ScoreService.calculate_team_scores()

    broadcast_new_state(new_state)
    {:noreply, new_state, game_timeout(state)}
  end

  # this clause handles a timeout for a turn. However, if game has progressed beyond
  # that turn, we ignore it.
  def handle_info({:turn_timeout, total_turn}, %{total_turn: current_total_turn} = state) do
    cond do
      # if the game is not playing, ignore the timeout. game is finished.
      state.status != :playing ->
        {:noreply, state, game_timeout(state)}

      # check if the game has timed out
      DateTime.compare(
        state.last_action_at,
        DateTime.add(DateTime.utc_now(), -Config.game_timeout_ms(), :millisecond)
      ) == :lt ->
        {:stop, :normal, state}

      # if there is an ongoing challenge, just restart the turn timeout for current turn.
      # not perfectly accurate, but simple
      ChallengeService.open_challenge?(state) ->
        # only start a new timeout if the timeout is for the current turn
        if total_turn == current_total_turn do
          TurnService.start_turn_timeout(current_total_turn)
        end

        {:noreply, state, game_timeout(state)}

      # if there are no players left, exit
      !Enum.any?(state.players, &Player.is_playing?/1) ->
        {:stop, :normal, state}

      # if this timeout is for the current turn, move to the next turn
      total_turn == current_total_turn ->
        new_state = TurnService.next_turn(state)
        broadcast_new_state(new_state)
        {:noreply, new_state, game_timeout(new_state)}

      # if this timeout is for a past turn, ignore it
      true ->
        {:noreply, state, game_timeout(state)}
    end
  end

  def handle_info({:challenge_timeout, challenge_id}, %{status: :playing} = state) do
    new_state = ChallengeService.timeout_challenge(state, challenge_id)
    broadcast_new_state(new_state)
    {:noreply, new_state, game_timeout(new_state)}
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
    Map.take(state, [
      # id will be used by clients to make calls to the correct game process
      :id,
      :status,
      # whose turn it is
      :turn,
      :teams,
      # clients check this to disable the Flip button when game is over.
      :letter_pool,
      :initial_letter_count,
      # only give the chronologically sorted center to the player
      :center,
      :history,
      :challenges,
      # clients use this to show/hide the challenge button on past
      :past_challenges,
      :end_game_votes
    ])
    |> Map.put(:players_teams, sanitize_players_teams(state))
    # we strip the tokens from the state to avoid leaking tokens
    |> Map.put(:players, drop_internal_states(state.players))
  end

  # map the player_token to player_name to avoid exposing tokens
  defp sanitize_players_teams(%{players_teams: players_teams} = state) do
    Map.new(players_teams, fn {player_token, team_id} ->
      {PlayerService.find_player(state, player_token).name, team_id}
    end)
  end

  @doc """
  Removes the player tokens and status from the state. We only send the player
  name, words, and score to the client not the tokens of all players (for obvious reasons)
  """
  @spec drop_internal_states(list(Player.t())) :: list(map())
  def drop_internal_states(players) do
    Enum.map(players, &Player.drop_internal_state/1)
  end

  # Games with no players timeout after 1 minute of inactivity
  # Games with players timeout after 1 hour of inactivity
  @spec game_timeout(t()) :: non_neg_integer()
  defp game_timeout(%{players: []}), do: Config.new_game_timeout_ms()
  defp game_timeout(_), do: Config.game_timeout_ms()

  ########## Player API ##########

  def find_by_id(game_id) do
    case Registry.lookup(Piratex.Game.Registry, game_id) do
      [{pid, _}] -> {:ok, GenServer.call(pid, :get_state)}
      [] -> {:error, :not_found}
    end
  end

  def create_team(game_id, player_token, team_name) do
    case find_by_id(game_id) do
      {:ok, %{status: :waiting} = _state} ->
        genserver_call(game_id, {:create_team, player_token, team_name})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def join_team(game_id, player_token, team_id) do
    case find_by_id(game_id) do
      {:ok, %{status: :waiting} = _state} ->
        genserver_call(game_id, {:join_team, player_token, team_id})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def join_game(game_id, player_name, player_token) do
    case find_by_id(game_id) do
      {:ok, %{status: :waiting} = _state} ->
        genserver_call(game_id, {:join, player_name, player_token})

      {:ok, %{status: _} = _state} ->
        {:error, :game_already_started}

      _ ->
        {:error, :not_found}
    end
  end

  def rejoin_game(game_id, player_name, player_token) do
    case find_by_id(game_id) do
      {:ok, %{status: _} = _state} ->
        genserver_call(game_id, {:rejoin, player_name, player_token})

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def leave_waiting_game(game_id, player_token) do
    genserver_call(game_id, {:leave_waiting_game, player_token})
  rescue
    _ -> {:error, :not_found}
  end

  def quit_game(game_id, player_token) do
    case find_by_id(game_id) do
      {:ok, %{status: :playing} = _state} ->
        genserver_call(game_id, {:quit, player_token})

      _ ->
        {:error, :not_found}
    end
  # TODO: i don't think this rescue prevents any crashes.
  rescue
    _ -> {:error, :not_found}
  end

  def start_game(game_id, player_token) do
    case find_by_id(game_id) do
      {:ok, _state} ->
        genserver_call(game_id, {:start_game, player_token})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def set_letter_pool_type(game_id, letter_pool_type) do
    case find_by_id(game_id) do
      {:ok, _state} ->
        genserver_call(game_id, {:set_letter_pool_type, letter_pool_type})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def get_state(game_id) do
    case find_by_id(game_id) do
      {:ok, state} -> {:ok, state}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def get_players_teams(game_id) do
    case find_by_id(game_id) do
      {:ok, _state} -> genserver_call(game_id, :get_players_teams)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def flip_letter(game_id, player_token) do
    case find_by_id(game_id) do
      {:ok, %{status: :playing} = _state} ->
        genserver_call(game_id, {:flip_letter, player_token})
      {:ok, _state} -> {:error, :game_not_playing}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def claim_word(game_id, player_token, word) do
    case find_by_id(game_id) do
      {:ok, %{status: :playing} = _state} ->
        genserver_call(game_id, {:claim_word, player_token, String.downcase(word)})
      {:ok, _state} -> {:error, :game_not_playing}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def challenge_word(game_id, player_token, word) do
    case find_by_id(game_id) do
      {:ok, %{status: :playing} = _state} ->
        genserver_call(game_id, {:challenge_word, player_token, word})
      {:ok, _state} -> {:error, :game_not_playing}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def challenge_vote(game_id, player_token, challenge_id, vote) do
    case find_by_id(game_id) do
      {:ok, %{status: :playing} = _state} ->
        genserver_call(game_id, {:challenge_vote, player_token, challenge_id, vote})
      {:ok, _state} -> {:error, :game_not_playing}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def end_game_vote(game_id, player_token) do
    case find_by_id(game_id) do
      {:ok, %{status: :playing} = _state} ->
        genserver_call(game_id, {:end_game_vote, player_token})
      {:ok, _state} -> {:error, :game_not_playing}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def genserver_call(game_id, data) do
    game_id
    |> Piratex.Game.via_tuple()
    |> GenServer.call(data)
  end
end

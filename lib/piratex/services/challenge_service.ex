defmodule Piratex.ChallengeService do
  @moduledoc """
  Handles the logic for handling word challenges and voting on them.
  """

  alias Piratex.Helpers
  alias Piratex.WordSteal
  alias Piratex.Player
  alias Piratex.Game
  alias Piratex.Config

  alias Piratex.PlayerService
  alias Piratex.TeamService

  defmodule Challenge do
    @moduledoc """
    A challenge is a record of a word being challenged by a player and the votes for/against it.
    votes are a map of player tokens to a boolean value where true is for the word being valid.
    """

    alias Piratex.Player
    alias Piratex.Helpers

    @type t :: %__MODULE__{
            # id allows players to vote on a specific challenge with no
            # race conditions or stale data worries
            id: non_neg_integer(),
            # the steal being challenged
            word_steal: WordSteal.t(),
            # player_name -> bool. true is for the word being valid.
            votes: map(),
            # result of the challenge. true is for the word being valid. nil if not yet resolved.
            result: boolean() | nil,
            # reference to the timeout timer. cancel this timer if the challenge is resolved
            timeout_ref: reference() | nil
          }

    defstruct [
      :id,
      :word_steal,
      :votes,
      :result,
      :timeout_ref
    ]

    @doc """
    new creates a new Challenge from a WordSteal.t()
    """
    @spec new(WordSteal.t(), map()) :: t()
    def new(word_steal, votes \\ %{}) do
      %__MODULE__{
        id: Piratex.Helpers.new_id(),
        word_steal: word_steal,
        votes: votes,
        result: nil,
        # will be set elsewhere
        timeout_ref: nil
      }
    end

    @doc """
    new_with_timeout creates a new Challenge from a WordSteal.t() and starts a timeout timer.
    """
    @spec new_with_timeout(WordSteal.t(), map()) :: t()
    def new_with_timeout(word_steal, votes \\ %{}) do
      challenge = new(word_steal, votes)
      timeout_ref = start_challenge_timeout(challenge.id)
      Map.put(challenge, :timeout_ref, timeout_ref)
    end

    def start_challenge_timeout(challenge_id) do
      Process.send_after(self(), {:challenge_timeout, challenge_id}, Config.challenge_timeout_ms())
    end

    @doc """
    checks whether the player has already voted based on whether their name
    is in the votes map
    """
    @spec player_already_voted?(t(), Player.t()) :: boolean()
    def player_already_voted?(challenge, %{name: player_name} = _player) do
      Map.has_key?(challenge.votes, player_name)
    end

    @doc """
    add_vote registers one additional vote to a challenge.
    """
    @spec add_vote(t(), Player.t(), boolean()) :: t()
    def add_vote(%{votes: votes} = challenge, player, vote) do
      Map.put(challenge, :votes, Map.put(votes, player.name, vote))
    end

    @doc """
    count_votes returns a tuple of number of votes accepting
    the word and rejecting the word respectively
    """
    @spec count_votes(t()) :: {non_neg_integer(), non_neg_integer()}
    def count_votes(%{votes: votes}) do
      Enum.reduce(votes, {0, 0}, fn {_, vote}, {acc_t, acc_f} ->
        if vote do
          {acc_t + 1, acc_f}
        else
          {acc_t, acc_f + 1}
        end
      end)
    end
  end

  @doc """
  open_challenge? returns true if there is an open challenge, false otherwise.
  """
  @spec open_challenge?(map()) :: boolean()
  def open_challenge?(%{challenges: []}), do: false
  def open_challenge?(%{challenges: _}), do: true

  @type challenge_error :: :word_not_in_play | :word_steal_not_found | :already_challenged | :player_not_found | :unknown_error

  @doc """
  handles all logic for a player requesting a new challenge to a word.
  Performs a few checks before adding the challenge to the game.
  - Word is currently in play (cannot challenge a word that has since been stolen)
  - exact word steal (old_word -> new_word) has not been challenged before
  """
  @spec handle_word_challenge(Game.t(), String.t(), String.t()) :: Game.t() | {:error, challenge_error()}
  def handle_word_challenge(state, player_token, word) do
    with {_, true} <- {:word_in_play, Helpers.word_in_play?(state, word)},
         {_, word_steal = %WordSteal{}} <- {:find_word_steal, find_word_steal(state, word)},
         {_, false} <- {:already_challenged, word_already_challenged?(state, word_steal)},
         {_, player = %Player{}} <- {:find_player, PlayerService.find_player(state, player_token)} do
      add_challenge(state, player, word_steal)
    else
      {:word_in_play, false} ->
        {:error, :word_not_in_play}

      {:find_word_steal, nil} ->
        {:error, :word_steal_not_found}

      {:already_challenged, true} ->
        {:error, :already_challenged}

      {:find_player, nil} ->
        {:error, :player_not_found}

      _ ->
        {:error, :unknown_error}
    end
  end

  # adds the challenge to the state. Usually, there will only be 1 challenge at a time
  # since the game is paused while challenges are voted upon, but its possible two
  # challenges are issued in quick succession.
  @spec add_challenge(Game.t(), Player.t(), WordSteal.t()) :: Game.t()
  defp add_challenge(%{challenges: challenges} = state, %{token: player_token}, word_steal) do
    challenge = Challenge.new_with_timeout(word_steal)
    state = Map.put(state, :challenges, challenges ++ [challenge])
    # challenging player automatically votes against the word
    handle_challenge_vote(state, player_token, challenge.id, false)
  end

  @spec find_word_steal(Game.t(), String.t()) :: Challenge.t() | nil
  def find_word_steal(%{history: history}, word) do
    Enum.find(history, fn word_steal -> word_steal.thief_word == word end)
  end

  @doc """
  Checks if the word steal has previously been challenged. If so, it cannot be challenged again.
  """
  @spec word_already_challenged?(Game.t(), WordSteal.t()) :: boolean()
  def word_already_challenged?(
         %{
           challenges: challenges,
           past_challenges: past_challenges
         },
         word_steal
       ) do
    Enum.any?(challenges, fn challenge -> WordSteal.match?(challenge.word_steal, word_steal) end) ||
      Enum.any?(past_challenges, fn challenge ->
        WordSteal.match?(challenge.word_steal, word_steal)
      end)
  end

  @type challenge_vote_error :: :challenge_not_found | :player_not_found | :already_voted | :unknown_error

  @doc """
  handle_challenge_vote handles a player's vote on a specific challenge. If the vote is decisive,
  this function handles all results of a completed challenge.
  """
  @spec handle_challenge_vote(Game.t(), String.t(), non_neg_integer(), boolean()) ::
          Game.t() | {:error, challenge_vote_error()}
  def handle_challenge_vote(%{players: _players} = state, player_token, challenge_id, vote) do
    with {_, {challenge_idx, challenge = %Challenge{}}} <-
           {:find_challenge, find_challenge_with_index(state, challenge_id)},
         {_, player = %Player{}} <- {:find_player, PlayerService.find_player(state, player_token)},
         {_, false} <- {:already_voted, Challenge.player_already_voted?(challenge, player)} do
      player_ct = PlayerService.count_unquit_players(state)
      player_ct_even? = rem(player_ct, 2) == 0
      threshold = ceil(player_ct / 2.0)

      challenge = Challenge.add_vote(challenge, player, vote)

      # valid -> word_steal is upheld, invalid -> word_steal is overturned
      {valid_ct, invalid_ct} = Challenge.count_votes(challenge)

      cond do
        # if either side has MORE than the threshold, its settled.
        # word_steal is valid and challenge fails
        valid_ct > threshold ->
          fail_challenge(state, challenge)

        # word_steal is invalid and challenge succeeds
        invalid_ct > threshold ->
          succeed_challenge(state, challenge)

        # tie goes to the thief, so if player_ct is even and
        # valid already has 50% of the total vote, we can call it valid
        player_ct_even? and valid_ct == threshold ->
          fail_challenge(state, challenge)

        # if player_ct is odd, meeting the threshold is sufficient to settle the challenge
        !player_ct_even? and valid_ct == threshold ->
          fail_challenge(state, challenge)

        !player_ct_even? and invalid_ct == threshold ->
          succeed_challenge(state, challenge)

        # vote incomplete
        true ->
          challenges = List.replace_at(state.challenges, challenge_idx, challenge)
          Map.put(state, :challenges, challenges)
      end
    else
      {:find_challenge, {:error, :challenge_not_found}} ->
        {:error, :challenge_not_found}

      {:find_player, nil} ->
        {:error, :player_not_found}

      {:already_voted, true} ->
        {:error, :already_voted}

      _e ->
        {:error, :unknown_error}
    end
  end

  @spec find_challenge_with_index(Game.t(), non_neg_integer()) ::
          {non_neg_integer(), Challenge.t()} | {:error, :challenge_not_found}
  defp find_challenge_with_index(%{challenges: challenges}, challenge_id) do
    case Enum.find_index(challenges, fn challenge -> challenge.id == challenge_id end) do
      nil -> {:error, :challenge_not_found}
      idx -> {idx, Enum.at(challenges, idx)}
    end
  end

  @doc """
  forcefully resolves a challenge by checking the vote and settling based on plurality.
  This is called when a challenge has timed out. Tie still goes to the thief (valid).
  """
  @spec timeout_challenge(Game.t(), non_neg_integer()) :: Game.t()
  def timeout_challenge(state, challenge_id) do
    with {_, {_challenge_idx, challenge = %Challenge{}}} <-
           {:find_challenge, find_challenge_with_index(state, challenge_id)},
         {_, {valid_ct, invalid_ct}} <- {:count_votes, Challenge.count_votes(challenge)} do
      if invalid_ct > valid_ct do
        # word_steal is invalid and challenge succeeds
        succeed_challenge(state, challenge)
      else
        # word_steal is valid and challenge fails
        fail_challenge(state, challenge)
      end
    else
      # if the challenge is not found, we can just ignore it. It was probably already resolved
      {:find_challenge, _err} ->
        state
    end
  end

  # succeed_challenge is when the word_steal is overturned as invalid.
  @spec succeed_challenge(Game.t(), Challenge.t()) :: Game.t()
  defp succeed_challenge(state, challenge) do
    if challenge.timeout_ref do
      Process.cancel_timer(challenge.timeout_ref)
    end

    challenge = Map.put(challenge, :result, false)

    state
    |> undo_word_steal(challenge.word_steal)
    |> move_challenge_to_past(challenge)
  end

  # fail_challenge is when the word_steal is upheld as valid.
  @spec succeed_challenge(Game.t(), Challenge.t()) :: Game.t()
  defp fail_challenge(state, challenge) do
    if challenge.timeout_ref do
      Process.cancel_timer(challenge.timeout_ref)
    end

    challenge = Map.put(challenge, :result, true)
    move_challenge_to_past(state, challenge)
  end

  @spec undo_word_steal(Game.t(), WordSteal.t()) :: Game.t()
  defp undo_word_steal(
        state,
        %WordSteal{
          victim_team_idx: victim_team_idx,
          victim_word: victim_word,
          thief_team_idx: thief_team_idx,
          thief_word: thief_word
        } = word_steal
      ) do
    center_letters_used = get_center_letters_used(thief_word, victim_word)
    thief_team = Enum.at(state.teams, thief_team_idx)
    victim_team_id =
      if victim_team_idx do
        Enum.at(state.teams, victim_team_idx) |> Map.get(:id)
      else
        nil
      end

    state
    |> TeamService.remove_word_from_team(thief_team, thief_word)
    |> TeamService.add_word_to_team(victim_team_id, victim_word)
    |> Helpers.add_letters_to_center(center_letters_used)
    |> remove_word_steal_from_history(word_steal)
  end

  @spec move_challenge_to_past(Game.t(), Challenge.t()) :: Game.t()
  defp move_challenge_to_past(state, challenge) do
    # remove challenge from challenges
    challenges = Enum.reject(state.challenges, fn c -> c.id == challenge.id end)
    # add challenge to past_challenges
    past_challenges = [challenge | state.past_challenges]

    state
    |> Map.put(:challenges, challenges)
    |> Map.put(:past_challenges, past_challenges)
  end


  # get_center_letters_used takes a new word (thief_word) and an old word (victim_word)
  # and finds the letters only included in the thief_word.
  @spec get_center_letters_used(String.t(), String.t()) :: list(String.t())
  defp get_center_letters_used(thief_word, victim_word) do
    thief_word_letters = String.graphemes(thief_word)
    # if victim_word is nil, all letters came from the center
    victim_word_letters = if victim_word, do: String.graphemes(victim_word), else: []
    thief_word_letters -- victim_word_letters
  end

  # remove_word_steal_from_history deletes the most recent WordSteal of old_word -> new_word
  @spec remove_word_steal_from_history(Game.t(), WordSteal.t()) :: Game.t()
  defp remove_word_steal_from_history(%{history: history} = state, word_steal) do
    new_history = List.delete(history, word_steal)
    Map.put(state, :history, new_history)
  end
end

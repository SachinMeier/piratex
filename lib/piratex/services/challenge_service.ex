defmodule Piratex.Services.ChallengeService do
  @moduledoc """
  Handles the logic for handling word challenges and voting on them.
  """

  alias Piratex.GameHelpers
  alias Piratex.WordSteal
  alias Piratex.Player
  alias Piratex.Game

  defmodule Challenge do
    @moduledoc """
    A challenge is a record of a word being challenged by a player and the votes for/against it.
    votes are a map of player tokens to a boolean value where true is for the word being valid.
    """

    alias Piratex.Player

    @type t :: %__MODULE__{
      # id allows players to vote on a specific challenge with no
      # race conditions or stale data worries
      id: non_neg_integer(),
      # the steal being challenged
      word_steal: WordSteal.t(),
      # player_name -> bool. true is for the word being valid.
      votes: map(),
      # result of the challenge. true is for the word being valid. nil if not yet resolved.
      result: boolean() | nil
    }

    defstruct [
      :id,
      :word_steal,
      :votes,
      :result
    ]

    @doc """
    new creates a new Challenge from a WordSteal.t()
    """
    @spec new(WordSteal.t(), map()) :: t()
    def new(word_steal, votes \\ %{}) do
      %__MODULE__{
        id: new_id(),
        word_steal: word_steal,
        votes: votes,
        result: nil
      }
    end

    # only needs to be unique per game. 65536 should be sufficient
    @spec new_id() :: non_neg_integer()
    defp new_id() do
      :crypto.strong_rand_bytes(2) |> :binary.decode_unsigned()
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
  handles all logic for a player requesting a new challenge to a word.
  Performs a few checks before adding the challenge to the game.
  - Word is currently in play (cannot challenge a word that has since been stolen)
  - exact word steal (old_word -> new_word) has not been challenged before
  """
  @spec handle_word_challenge(Game.t(), String.t(), String.t()) :: Game.t()
  def handle_word_challenge(state, player_token, word) do
    with {_, true} <- {:word_in_play, GameHelpers.word_in_play?(state, word)},
         {_, word_steal = %WordSteal{}} <- {:find_word_steal, find_word_steal(state, word)},
         {_, false} <- {:already_challenged, is_word_already_challenged?(state, word_steal)},
         {_, player = %Player{}} <- {:find_player, GameHelpers.find_player(state, player_token)} do

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
    end
  end

  # adds the challenge to the state. Usually, there will only be 1 challenge at a time
  # since the game is paused while challenges are voted upon, but its possible two
  # challenges are issued in quick succession.
  @spec add_challenge(Game.t(), Player.t(), WordSteal.t()) :: Game.t()
  defp add_challenge(%{challenges: challenges} = state, player, word_steal) do
    # challenging player automatically votes against the word
    challenge = Challenge.new(word_steal, %{player.name => false})
    Map.put(state, :challenges, challenges ++ [challenge])
  end

  # TODO: consider only looking at the last N word_steals
  @spec find_word_steal(Game.t(), String.t()) :: Challenge.t() | nil
  defp find_word_steal(%{history: history}, word) do
    Enum.find(history, fn word_steal -> word_steal.thief_word == word end)
  end

  @spec is_word_already_challenged?(Game.t(), WordSteal.t()) :: boolean()
  defp is_word_already_challenged?(%{
    challenges: challenges,
    past_challenges: past_challenges
  }, word_steal) do
    Enum.any?(challenges, fn challenge -> WordSteal.match?(challenge.word_steal, word_steal) end) ||
      Enum.any?(past_challenges, fn challenge -> WordSteal.match?(challenge.word_steal, word_steal) end)
  end

  @type challenge_vote_error ::  :challenge_not_found | :player_not_found | :already_voted

  @doc """
  handle_challenge_vote handles a player's vote on a specific challenge. If the vote is decisive,
  this function handles all results of a completed challenge.
  """
  @spec handle_challenge_vote(Game.t(), String.t(), non_neg_integer(), boolean()) :: Game.t() | {:error, challenge_vote_error()}
  def handle_challenge_vote(%{players: _players} = state, player_token, challenge_id, vote) do
    with {_, {challenge_idx, challenge = %Challenge{}}} <- {:find_challenge, find_challenge_with_index(state, challenge_id)},
         {_, player = %Player{}} <- {:find_player, GameHelpers.find_player(state, player_token)},
         {_, false} <- {:already_voted, Challenge.player_already_voted?(challenge, player)} do

      player_ct = GameHelpers.count_unquit_players(state)
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

        # vote incomplete
        true ->
          challenges = List.replace_at(state.challenges, challenge_idx, challenge)
          Map.put(state, :challenges, challenges)
      end
    else
      {:find_challenge, nil} ->
        {:error, :challenge_not_found}

      {:find_player, nil} ->
        {:error, :player_not_found}

      {:already_voted, true} ->
        {:error, :already_voted}
    end
  end

  @spec find_challenge_with_index(Game.t(), non_neg_integer()) :: {non_neg_integer(), Challenge.t()} |  {:error, :challenge_not_found}
  defp find_challenge_with_index(%{challenges: challenges}, challenge_id) do
    case Enum.find_index(challenges, fn challenge -> challenge.id == challenge_id end) do
      nil -> {:error, :challenge_not_found}
      idx -> {idx, Enum.at(challenges, idx)}
    end
  end

  # succeed_challenge is when the word_steal is overturned as invalid.
  @spec succeed_challenge(Game.t(), Challenge.t()) :: Game.t()
  defp succeed_challenge(state, challenge) do
    challenge = Map.put(challenge, :result, false)
    state
    |> undo_word_steal(challenge.word_steal)
    |> move_challenge_to_past(challenge)
  end

  # fail_challenge is when the word_steal is upheld as valid.
  @spec succeed_challenge(Game.t(), Challenge.t()) :: Game.t()
  defp fail_challenge(state, challenge) do
    challenge = Map.put(challenge, :result, true)
    move_challenge_to_past(state, challenge)
  end

  @spec undo_word_steal(Game.t(), WordSteal.t()) :: Game.t()
  def undo_word_steal(state, %WordSteal{
    victim_idx: victim_idx,
    victim_word: victim_word,
    thief_idx: thief_idx,
    thief_word: thief_word
  } = word_steal) do
    center_letters_used = GameHelpers.get_center_letters_used(thief_word, victim_word)
    thief_player = Enum.at(state.players, thief_idx)
    victim_player = if victim_idx, do: Enum.at(state.players, victim_idx), else: nil

    state
    |> GameHelpers.remove_word_from_player(thief_player, thief_word)
    |> GameHelpers.add_word_to_player(victim_player, victim_word)
    |> GameHelpers.add_letters_to_center(center_letters_used)
    |> GameHelpers.remove_word_steal_from_history(word_steal)
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
end

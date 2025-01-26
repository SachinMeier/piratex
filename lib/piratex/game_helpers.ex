defmodule Piratex.GameHelpers do
  @moduledoc """
  Helper functions for the game.
  """

  alias Piratex.Game
  alias Piratex.Player
  alias Piratex.WordSteal

  @max_players 6
  @spec max_players() :: non_neg_integer()
  def max_players(), do: @max_players

  @letter_pool_size 144
  def letter_pool_size(), do: @letter_pool_size

  @letter_pool [
    # 13 As
    "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a",
    # 3 Bs
    "b", "b", "b",
    # 3 Cs
    "c", "c", "c",
    # 6 Ds
    "d", "d", "d", "d", "d", "d",
    # 18 Es
    "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e",
    # 3 Fs
    "f", "f", "f",
    # 4 Gs
    "g", "g", "g", "g",
    # 3 Hs
    "h", "h", "h",
    # 12 Is
    "i", "i", "i", "i", "i", "i", "i", "i", "i", "i", "i", "i",
    # 2 Js
    "j", "j",
    # 2 Ks
    "k", "k",
    # 5 Ls
    "l", "l", "l", "l", "l",
    # 3 Ms
    "m", "m", "m",
    # 8 Ns
    "n", "n", "n", "n", "n", "n", "n", "n",
    # 11 Os
    "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o",
    # 3 Ps
    "p", "p", "p",
    # 2 Qs
    "q", "q",
    # 9 Rs
    "r", "r", "r", "r", "r", "r", "r", "r", "r",
    # 6 Ss
    "s", "s", "s", "s", "s", "s",
    # 9 Ts
    "t", "t", "t", "t", "t", "t", "t", "t", "t",
    # 6 Us
    "u", "u", "u", "u", "u", "u",
    # 3 Vs
    "v", "v", "v",
    # 3 Ws
    "w", "w", "w",
    # 2 Xs
    "x", "x",
    # 3 Ys
    "y", "y", "y",
    # 2 Zs
    "z", "z"
  ]
  @doc """
  Uses the bananagrams letter distribution. 144 letters in total.
  A: 13
  B: 3
  C: 3
  D: 6
  E: 18
  F: 3
  G: 4
  H: 3
  I: 12
  J: 2
  K: 2
  L: 5
  M: 3
  N: 8
  O: 11
  P: 3
  Q: 2
  R: 9
  S: 6
  T: 9
  U: 6
  V: 3
  W: 3
  X: 2
  Y: 3
  Z: 2
  """
  @spec letter_pool() :: list(String.t())
  def letter_pool(), do: @letter_pool

  ##### Word Management Functions #####

  @doc """
  Checks if a word is in play.
  assumes all words are lowercase
  """
  @spec word_in_play?(map(), String.t()) :: boolean()
  def word_in_play?(%{players: players} = _state, word) do
    Enum.any?(players, fn %{words: words} = _player -> word in words end)
  end

  @doc """
  removes a word from a player's words.
  new words don't require removing a word from anyone if they only use the center.
  This case is handled by the first clause.
  """
  @spec remove_word_from_player(Game.t(), Player.t() | nil, String.t() | nil) :: map()
  def remove_word_from_player(state, nil,  nil), do: state
  def remove_word_from_player(%{players: players} = state, %{token: player_token} = _player, word) do
    player_idx = find_player_index(state, player_token)
    player =
      players
      |> Enum.at(player_idx)
      |> Player.remove_word(word)

    new_players = List.replace_at(players, player_idx, player)

    state
    |> Map.put(:players, new_players)
  end

  @doc """
  adds a word to a player's words. This may be a noop in the case of undoing a
  word steal after a successful challenge where the word was built exclusively from the middle.
  """
  @spec add_word_to_player(Game.t(), Player.t() | nil, String.t() | nil) :: map()
  def add_word_to_player(state, nil, nil), do: state
  def add_word_to_player(%{players: players} = state, %{token: player_token} = _player, word) do
    case find_player_index(state, player_token) do
      # this case handles the case where a word was created from the center
      # and is then challenged and invalidated.
      nil ->
        state

      player_idx ->
        player = Enum.at(players, player_idx)
        new_players = List.replace_at(players, player_idx, Player.add_word(player, word))
        state
        |> Map.put(:players, new_players)
    end
  end

  @doc """
  removes letters from the center. There are two centers in a Game:
  - center: sorted chronologically (desc)
  - center_sorted: sorted_alphabetically (asc)
  """
  @spec remove_letters_from_center(Game.t(), list(String.t())) :: map()
  def remove_letters_from_center(%{center: center, center_sorted: center_sorted} = state, letters_used) do
    new_center = center -- letters_used
    # This seems quicker than resorting new_center entirely
    # removing items by first occurrence shouldn't unsort a sorted list
    new_center_sorted = center_sorted -- letters_used

    state
    |> Map.put(:center, new_center)
    |> Map.put(:center_sorted, new_center_sorted)
  end

  @doc """
  add_word_steal_to_history adds a WordSteal to the Game's history
  so that it can be challenged and potentially reverted
  """
  @spec add_word_steal_to_history(Game.t(), Player.t(), String.t(), Player.t(), String.t()) :: map()
  def add_word_steal_to_history(%{history: history} = state, %{token: thief_token} = _thief_player, new_word, victim_player, old_word) do
    word_steal = WordSteal.new(%{
        victim_idx: if(victim_player, do: find_player_index(state, victim_player.token), else: nil),
        victim_word: old_word,
        thief_idx: find_player_index(state, thief_token),
        thief_word: new_word
      })

    Map.put(state, :history, [word_steal | history])
  end

  @doc """
  remove_word_steal_from_history deletes the most recent wordsteal of old_word -> new_word
  """
  @spec remove_word_steal_from_history(Game.t(), WordSteal.t()) :: Game.t()
  def remove_word_steal_from_history(%{history: history} = state, word_steal) do
    new_history = List.delete(history, word_steal)
    Map.put(state, :history, new_history)
  end

  @doc """
  get_center_letters_used takes a new word (thief_word) and an old word (victim_word)
  and finds the letters only included in the thief_word.
  """
  @spec get_center_letters_used(String.t(), String.t()) :: list(String.t())
  def get_center_letters_used(thief_word, victim_word) do
    thief_word_letters = String.graphemes(thief_word)
    # if victim_word is nil, all letters came from the center
    victim_word_letters = if victim_word, do: String.graphemes(victim_word), else: []
    thief_word_letters -- victim_word_letters
  end


  @doc """
  Checks if the word steal has previously been challenged. If so, it cannot be challenged again.
  """
  @spec word_steal_has_been_challenged?(map(), WordSteal.t()) :: boolean()
  def word_steal_has_been_challenged?(%{past_challenges: past_challenges} = _state, %WordSteal{thief_word: curr_thief_word, victim_word: curr_victim_word} = _word_steal) do
    Enum.any?(past_challenges, fn %{word_steal: %{thief_word: thief_word, victim_word: victim_word}} = _challenge ->
      thief_word == curr_thief_word &&
      victim_word == curr_victim_word
    end)
  end

  @doc """
  Checks if the word claim has previously been successfully challenged and rejected.
  """
  @spec is_recidivist_word_claim?(map(), String.t(), String.t()) :: boolean()
  def is_recidivist_word_claim?(%{past_challenges: past_challenges} = _state, curr_thief_word, curr_victim_word) do
    Enum.any?(past_challenges, fn %{word_steal: %{thief_word: thief_word, victim_word: victim_word}} = challenge ->
      curr_thief_word == thief_word &&
      curr_victim_word == victim_word &&
      # challenge result is false means the word was declared invalid
      !challenge.result
    end)
  end

  @doc """
  Updates the state to add a new letter to the center and remove it from the letter pool.
  If the letter pool is empty, it returns the state unchanged.
  """
  @spec update_state_flip_letter(map()) :: map()
  def update_state_flip_letter(%{letter_pool: []} = state), do: state
  def update_state_flip_letter(%{letter_pool: letter_pool} = state) do
    rand_idx = :rand.uniform(length(letter_pool)) - 1
    new_letter = Enum.at(letter_pool, rand_idx)
    new_letter_pool = List.delete_at(letter_pool, rand_idx)

    state
    |> add_letters_to_center([new_letter])
    |> next_turn()
    |> Map.put(:letter_pool, new_letter_pool)
  end

  @doc """
  This function is used by multiple functions to add letters to the center
  in the case of flipping a new letter or returning letters after a successful challenge
  """
  def add_letters_to_center(state, letters) do
    # TODO: not the most efficient, but its only done on lists with >1 letter in
    # the case of a successful challenge
    Enum.reduce(letters, state, fn letter, acc ->
      {new_center, new_center_sorted} = add_new_letter_to_center(acc.center, letter)
      acc
      |> Map.put(:center, new_center)
      |> Map.put(:center_sorted, new_center_sorted)
    end)
  end

  @doc """
  next_turn is recursive and sets the turn to the next player that has not quit.
  """
  def next_turn(%{players: players, turn: turn} = state) do
    turn = rem(turn + 1, length(players))
    state = Map.put(state, :turn, turn)
    case Enum.at(players, turn) do
      %Player{status: :quit} ->
        next_turn(state)
      _ ->
        state
    end
  end

  @doc """
  Checks if there are no more letters in the letter pool.
  """
  @spec no_more_letters?(Game.t()) :: boolean()
  def no_more_letters?(%{letter_pool: []}), do: true
  def no_more_letters?(_), do: false

  @doc """
  Adds a new letter to the center and returns the new center sorted chronologically and alphabetically.
  """
  @spec add_new_letter_to_center(list(String.t()), String.t()) :: {list(String.t()), list(String.t())}
  def add_new_letter_to_center(center, new_letter) do
    # center is sorted chronologically (desc) for player clarity
    center = [new_letter | center]

    # center_sorted is sorted alphabetically (asc) for efficient word building
    # TODO: make this more efficient since rest of list is already sorted
    {center, Enum.sort(center)}
  end

  #### End Game Functions ####

  @doc """
  Calculates the scores for each player.
  Score is calculated as the number of letters in all words minus the number of words.
  Put another way, drop one letter from each word and count the remaining letters.
  """
  @spec calculate_scores(map()) :: map()
  def calculate_scores(%{players: players} = state) do
    players_with_scores = Enum.map(players, &Player.calculate_score/1)
    Map.put(state, :players, players_with_scores)
  end

  #### Player Management Functions ####

  @doc """
  Adds a player to the game.
  """
  @spec add_player(map(), Player.t()) :: {:ok, map()} | {:error, atom()}
  def add_player(%{players: players} = state, player) do
    if length(players) >= @max_players do
      {:error, :game_full}
    else
      Map.put(state, :players, players ++ [player])
    end
  end

  @doc """
  Finds the player with the given token.
  """
  @spec find_player(map(), String.t()) :: {String.t(), any()} | nil
  def find_player(%{players: players}, player_token) do
    Enum.find(players, fn %{token: token} = _player -> token == player_token end)
  end

  @doc """
  Finds the index of the player with the given token.
  """
  @spec find_player_index(map(), String.t()) :: integer()
  def find_player_index(%{players: players}, player_token) do
    Enum.find_index(players, fn %{token: token} = _player -> token == player_token end)
  end

  @doc """
  Checks if the player name and token are unique.
  """
  @spec player_is_unique?(map(), String.t(), String.t()) :: boolean()
  def player_is_unique?(%{players: players}, player_name, player_token) do
    Enum.all?(players, fn %{token: token, name: name} = _player -> token != player_token && name != player_name end)
  end

  @doc """
  Checks if it is the given player's turn.
  """
  @spec is_player_turn?(map(), String.t()) :: boolean()
  def is_player_turn?(%{players: players, turn: turn}, player_token) do
    %{token: token} = Enum.at(players, turn)
    player_token == token
  end

  @doc """
  Counts the number of players that have not quit.
  """
  @spec count_unquit_players(map()) :: integer()
  def count_unquit_players(%{players: players}) do
    Enum.count(players, fn %{status: status} -> status != :quit end)
  end

  @doc """
  Generates a new player token.
  """
  @spec new_player_token() :: String.t()
  def new_player_token() do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64(padding: false)
  end
end

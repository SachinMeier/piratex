defmodule Piratex.WordClaimService do
  @moduledoc """
  Handles all logic of requests to create a new word.
  """
  alias Piratex.Dictionary
  alias Piratex.Helpers
  alias Piratex.Player
  alias Piratex.WordSteal
  alias Piratex.Config
  alias Piratex.TeamService

  # assign each letter a prime number.
  # this is so that we can use the prime factorization of words to check for anagrams efficiently.
  @prime_alphabet %{
    "a" => 2,
    "b" => 3,
    "c" => 5,
    "d" => 7,
    "e" => 11,
    "f" => 13,
    "g" => 17,
    "h" => 19,
    "i" => 23,
    "j" => 29,
    "k" => 31,
    "l" => 37,
    "m" => 41,
    "n" => 43,
    "o" => 47,
    "p" => 53,
    "q" => 59,
    "r" => 61,
    "s" => 67,
    "t" => 71,
    "u" => 73,
    "v" => 79,
    "w" => 83,
    "x" => 89,
    "y" => 97,
    "z" => 101
  }

  @doc """
  calculates the product of the prime factorization of a word.
  if two words have the same product, they are anagrams.
  only public for tests
  """
  @spec calculate_word_product(String.t() | [String.t()]) :: integer()
  def calculate_word_product(word) when is_binary(word) do
    word
    |> String.downcase()
    |> String.graphemes()
    |> calculate_word_product()
  end

  # assumes the letters are lowercase
  def calculate_word_product(letters) when is_list(letters) do
    letters
    |> Enum.map(&Map.fetch!(@prime_alphabet, &1))
    |> Enum.product()
  end

  @doc """
  Adds the product of a new letter to the product of a word.
  only public for tests
  """
  @spec add_letter_to_word_product(non_neg_integer(), String.t()) :: non_neg_integer()
  def add_letter_to_word_product(product, new_letter) do
    new_letter_product = Map.fetch!(@prime_alphabet, new_letter)
    product * new_letter_product
  end

  @doc """
  Handles the claim of a new word and returns the resulting state.
  """
  @spec handle_word_claim(map(), Team.t(), Player.t(), String.t()) ::
          {:ok, map()} | {word_claim_error(), map()}
  def handle_word_claim(%{center_sorted: center_sorted} = state, thief_team, thief_player, new_word) do
    cond do
      # enforce min word length
      String.length(new_word) < Config.min_word_length() ->
        {:invalid_word, state}

      # ensure new_word is a valid word
      !Dictionary.is_word?(new_word) ->
        {:invalid_word, state}

      # ensure new_word doesn't already exist in game
      Helpers.word_in_play?(state, new_word) ->
        {:word_in_play, state}

      true ->
        # calculate product once
        new_word_product = calculate_word_product(new_word)

        # first, see if we can build the word entirely from the center
        # NOTE: this will take a full word from the center even if stealing
        # from another player also works (and would be better for the player
        # assuming its not their own word)
        case attempt_find_center_letters(center_sorted, new_word_product) do
          {true, letters_used} ->
            # Check if this word has been previously challenged and rejected
            # TODO: this could be checked first to skip the attempt_find_center_letters call
            if is_recidivist_word_claim?(state, new_word, nil) do
              {:invalid_word, state}
            else
              # last two nils are because it's not stealing from anyone's old word
              new_state =
                update_state_for_word_steal(state, %{
                  letters_used: letters_used,
                  thief_team: thief_team,
                  thief_player: thief_player,
                  new_word: new_word,
                  victim_team: nil,
                  old_word: nil
                })

              {:ok, new_state}
            end

          {false, []} ->
            # if couldn't build word from center, try to steal it from another word
            attempt_steal_word_from_players(state, thief_team, thief_player, new_word, new_word_product)
        end
    end
  end


  @doc """
  Checks if the word claim has previously been successfully challenged and rejected.
  """
  @spec is_recidivist_word_claim?(map(), String.t(), String.t()) :: boolean()
  def is_recidivist_word_claim?(
        %{past_challenges: past_challenges} = _state,
        curr_thief_word,
        curr_victim_word
      ) do
    curr_word_steal = %{
      thief_word: curr_thief_word,
      victim_word: curr_victim_word
    }

    Enum.any?(past_challenges, fn %{
                                    word_steal: past_word_steal,
                                    result: result
                                  } ->
      # challenge result is false means the word was declared invalid
      WordSteal.match?(curr_word_steal, past_word_steal) &&
        !result
    end)
  end

  # Attempts to steal a word from another player.
  @spec attempt_steal_word_from_players(map(), Team.t(), Player.t(), String.t(), non_neg_integer()) ::
          {:ok, map()} | {:invalid_word, map()}
  defp attempt_steal_word_from_players(
         %{teams: teams} = state,
         thief_team,
         thief_player,
         new_word,
         new_word_product
       ) do
    Enum.reduce_while(teams, {:cannot_make_word, state}, fn %{words: words} = victim_team, {curr_err, state} ->
      # this function will do all state updates if necessary
      # we still need to pass in new_word and new_word_product to handle state updates.
      case attempt_steal_word_from_player(state, words, new_word, new_word_product) do
        {:ok, old_word, letters_used} ->
          new_state =
            update_state_for_word_steal(state, %{
              letters_used: letters_used,
              thief_team: thief_team,
              thief_player: thief_player,
              new_word: new_word,
              victim_team: victim_team,
              old_word: old_word
            })

          {:halt, {:ok, new_state}}

        # if the word is not stolen, no state update occurs
        # we prefer to bubble up errors other than :cannot_make_word for clarity
        # this will mostly be :invalid_word until we have more granular errors
        :cannot_make_word ->
          {:cont, {curr_err, state}}

        err ->
          {:cont, {err, state}}
      end
    end)
  end

  # Attempts to build a word from the (sorted) center using the letters of another word.
  @spec attempt_steal_word_from_player(map(), list(String.t()), String.t(), non_neg_integer()) ::
          {:ok, String.t(), list(String.t())} | word_claim_error()
  defp attempt_steal_word_from_player(%{center_sorted: center_sorted} = state, words, new_word, new_word_product) do
    # This is a subset-product problem.
    # We need to find a word in words that is an anagram (same product) of new_word and some of the center's letters.
    # If we find such a subset, the word can be stolen.
    # Otherwise, the word cannot be stolen.
    Enum.reduce_while(words, :cannot_make_word, fn word, curr_res ->
      word_product = calculate_word_product(word)

      cond do
        # you must add at least 1 letter to steal a word
        new_word_product == word_product ->
          {:cont, :invalid_word}

        # Check if this exact old_word->new_word steal has been previously challenged and rejected
        # Technically, we only need to check this inside the next block, but it's cleaner code to do it here.
        is_recidivist_word_claim?(state, new_word, word) ->
          {:cont, :invalid_word}

        # this checks if new_word contains all letters in (old) word
        rem(new_word_product, word_product) == 0 ->
          # this is the product of the letters we need from the center to make the new word from this word
          target_center_product = div(new_word_product, word_product)

          case attempt_find_center_letters(center_sorted, target_center_product) do
            {true, letters_used} ->
              {:halt, {:ok, word, letters_used}}

            {false, []} ->
              # we use curr_res instead of :cannot_make_word to preserve a possible :invalid_word error
              # from an earlier word since that's more informative
              {:cont, curr_res}
          end

        # word is not a subset of new_word.
        true ->
          # we use curr_res instead of :cannot_make_word to preserve a possible :invalid_word error
          # from an earlier word since that's more informative
          {:cont, curr_res}
      end
    end)
  end

  # find the required letters from the center to reach the target product. Target product is the
  # product of the letters we need from the middle to build the new word from the old word.
  @spec attempt_find_center_letters(list(String.t()), non_neg_integer()) ::
          {boolean(), list(String.t())}
  defp attempt_find_center_letters(center_sorted, target_product) do
    # TODO: quick check to see if it is possible:
    # rem(target_product, calculate_word_product(center)) == 0
    do_attempt_find_center_letters(center_sorted, target_product, [])
  end

  # target_product=1 means we have all the letters we need
  defp do_attempt_find_center_letters(_center_sorted, 1, letters_used), do: {true, letters_used}

  # we ran out of letters and have not reached the target product
  defp do_attempt_find_center_letters([], target_product, _letters_used) when target_product > 1,
    do: {false, []}

  defp do_attempt_find_center_letters([letter | center_sorted], target_product, letters_used) do
    letter_product = Map.fetch!(@prime_alphabet, letter)

    cond do
      letter_product > target_product ->
        # we can exit early if the letter is greater than the target,
        # since letters in center_sorted are sorted asc
        {false, []}

      # this check determines if the letter is needed for the word.
      rem(target_product, letter_product) == 0 ->
        # continue recursively with the new target product and the letter used.
        do_attempt_find_center_letters(center_sorted, div(target_product, letter_product), [
          letter | letters_used
        ])

      true ->
        # we determined that this letter is not in the target word. try skipping this letter
        do_attempt_find_center_letters(center_sorted, target_product, letters_used)
    end
  end

  @type word_claim_error :: :word_in_play | :invalid_word | :cannot_make_word

  @doc """
  Updates the state for a word steal.
  1. removes the old word from the victim team (if one exists)
  2. adds the new word to the thief team
  3. removes the letters used from the center
  only public for tests
  """
  @spec update_state_for_word_steal(
          map(),
          %{
            letters_used: list(String.t()),
            thief_team: Team.t(),
            thief_player: Player.t(),
            new_word: String.t(),
            victim_team: Team.t(),
            old_word: String.t()
          }
        ) :: map()
  def update_state_for_word_steal(state, %{
    letters_used: letters_used,
    thief_team: thief_team,
    thief_player: thief_player,
    new_word: new_word,
    victim_team: victim_team,
    old_word: old_word
  }) do
    # we have to use tokens here because the players themselves are updated.
    state
    # TODO: think about doing this in one pass
    # 1. take old_word from victim (can be same player as thief)
    |> TeamService.remove_word_from_team(victim_team, old_word)
    # 2. give new_word to thief
    |> TeamService.add_word_to_team(thief_team.id, new_word)
    # 3. remove letters from center
    |> remove_letters_from_center(letters_used)
    # 4. add word steal to history
    # TODO: revert this call to use the players not teams (to store player-based history))
    |> add_word_steal_to_history(thief_team, thief_player, new_word, victim_team, old_word)
  end

  # removes letters from the center. There are two set-identical centers in a Game:
  # - center: sorted chronologically (desc)
  # - center_sorted: sorted_alphabetically (asc)
  @spec remove_letters_from_center(Game.t(), list(String.t())) :: map()
  defp remove_letters_from_center(
        %{center: center, center_sorted: center_sorted} = state,
        letters_used
      ) do
    new_center = center -- letters_used
    # This seems quicker than resorting new_center entirely
    # removing items by first occurrence shouldn't unsort a sorted list
    new_center_sorted = center_sorted -- letters_used

    state
    |> Map.put(:center, new_center)
    |> Map.put(:center_sorted, new_center_sorted)
  end

  # add_word_steal_to_history adds a WordSteal to the Game's history
  # so that it can be challenged and potentially reverted
  @spec add_word_steal_to_history(Game.t(), Team.t(), Player.t(), String.t(), Team.t(), String.t()) ::
          map()
  defp add_word_steal_to_history(
        %{history: history} = state,
        thief_team,
        %{token: thief_token} = _thief_player,
        new_word,
        victim_team,
        old_word
      ) do
    word_steal =
      WordSteal.new(%{
        victim_team_idx:
          if(victim_team, do: TeamService.find_team_index(state, victim_team.id), else: nil),
        victim_word: old_word,
        thief_team_idx: TeamService.find_team_index(state, thief_team.id),
        thief_player_idx: Helpers.find_player_index(state, thief_token),
        thief_word: new_word
      })

    Map.put(state, :history, [word_steal | history])
  end
end

defmodule Piratex.LetterPoolServiceTest do
  use ExUnit.Case

  alias Piratex.LetterPoolService

  describe "letter_pool_options/0" do
    test "returns a list of tuples with string labels and atom types" do
      options = LetterPoolService.letter_pool_options()

      assert is_list(options)
      assert length(options) == 2

      Enum.each(options, fn {label, type} ->
        assert is_binary(label)
        assert is_atom(type)
      end)
    end

    test "includes standard and half pool options" do
      options = LetterPoolService.letter_pool_options()

      assert {"Standard", :bananagrams} in options
      assert {"Half", :bananagrams_half} in options
    end
  end

  describe "letter_pool_from_string/1" do
    test "converts \"bananagrams\" to :bananagrams" do
      assert LetterPoolService.letter_pool_from_string("bananagrams") == :bananagrams
    end

    test "converts \"bananagrams_half\" to :bananagrams_half" do
      assert LetterPoolService.letter_pool_from_string("bananagrams_half") == :bananagrams_half
    end
  end

  describe "bananagrams_pool/0" do
    test "returns a {144, list} tuple" do
      {count, pool} = LetterPoolService.bananagrams_pool()

      assert count == 144
      assert is_list(pool)
    end

    test "pool list contains exactly 144 letters" do
      {_count, pool} = LetterPoolService.bananagrams_pool()

      assert length(pool) == 144
    end

    test "pool contains only lowercase single-character strings" do
      {_count, pool} = LetterPoolService.bananagrams_pool()

      Enum.each(pool, fn letter ->
        assert is_binary(letter)
        assert String.length(letter) == 1
        assert letter == String.downcase(letter)
      end)
    end
  end

  describe "bananagrams_pool_half/0" do
    test "returns a {79, list} tuple" do
      {count, pool} = LetterPoolService.bananagrams_pool_half()

      assert count == 79
      assert is_list(pool)
    end

    test "pool list contains exactly 79 letters" do
      {_count, pool} = LetterPoolService.bananagrams_pool_half()

      assert length(pool) == 79
    end

    test "pool contains only lowercase single-character strings" do
      {_count, pool} = LetterPoolService.bananagrams_pool_half()

      Enum.each(pool, fn letter ->
        assert is_binary(letter)
        assert String.length(letter) == 1
        assert letter == String.downcase(letter)
      end)
    end
  end

  describe "bananagrams_pool_counts/0" do
    test "returns the expected letter count map" do
      counts = LetterPoolService.bananagrams_pool_counts()

      expected = %{
        "a" => 13,
        "b" => 3,
        "c" => 3,
        "d" => 6,
        "e" => 18,
        "f" => 3,
        "g" => 4,
        "h" => 3,
        "i" => 12,
        "j" => 2,
        "k" => 2,
        "l" => 5,
        "m" => 3,
        "n" => 8,
        "o" => 11,
        "p" => 3,
        "q" => 2,
        "r" => 9,
        "s" => 6,
        "t" => 9,
        "u" => 6,
        "v" => 3,
        "w" => 3,
        "x" => 2,
        "y" => 3,
        "z" => 2
      }

      assert counts == expected
    end

    test "counts sum to 144" do
      counts = LetterPoolService.bananagrams_pool_counts()
      total = counts |> Map.values() |> Enum.sum()

      assert total == 144
    end

    test "covers all 26 letters" do
      counts = LetterPoolService.bananagrams_pool_counts()

      assert map_size(counts) == 26
    end
  end

  describe "bananagrams_pool_half_counts/0" do
    test "returns the expected letter count map" do
      counts = LetterPoolService.bananagrams_pool_half_counts()

      expected = %{
        "a" => 7,
        "b" => 2,
        "c" => 2,
        "d" => 3,
        "e" => 9,
        "f" => 2,
        "g" => 2,
        "h" => 2,
        "i" => 6,
        "j" => 1,
        "k" => 1,
        "l" => 3,
        "m" => 2,
        "n" => 4,
        "o" => 6,
        "p" => 2,
        "q" => 1,
        "r" => 5,
        "s" => 3,
        "t" => 5,
        "u" => 3,
        "v" => 2,
        "w" => 2,
        "x" => 1,
        "y" => 2,
        "z" => 1
      }

      assert counts == expected
    end

    test "counts sum to 79" do
      counts = LetterPoolService.bananagrams_pool_half_counts()
      total = counts |> Map.values() |> Enum.sum()

      assert total == 79
    end

    test "covers all 26 letters" do
      counts = LetterPoolService.bananagrams_pool_half_counts()

      assert map_size(counts) == 26
    end
  end

  describe "load_letter_pool/1" do
    test "loads bananagrams pool with :bananagrams" do
      {count, pool} = LetterPoolService.load_letter_pool(:bananagrams)

      assert count == 144
      assert length(pool) == 144
    end

    test "loads half pool with :bananagrams_half" do
      {count, pool} = LetterPoolService.load_letter_pool(:bananagrams_half)

      assert count == 79
      assert length(pool) == 79
    end

    test "pool matches bananagrams_pool/0 directly" do
      assert LetterPoolService.load_letter_pool(:bananagrams) ==
               LetterPoolService.bananagrams_pool()
    end

    test "pool matches bananagrams_pool_half/0 directly" do
      assert LetterPoolService.load_letter_pool(:bananagrams_half) ==
               LetterPoolService.bananagrams_pool_half()
    end
  end

  describe "load_letter_pool via Game GenServer" do
    test "start_game loads the default bananagrams pool" do
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()
      {:ok, %{initial_letter_count: 0}} = Piratex.Game.get_state(game_id)

      :ok = Piratex.Game.start_game(game_id, "token1")

      {:ok, %{initial_letter_count: 144}} = Piratex.Game.get_state(game_id)
    end

    test "load half game and test letter distribution" do
      {half_letter_count, _half_letter_pool} = LetterPoolService.bananagrams_pool_half()
      half_counts = LetterPoolService.bananagrams_pool_half_counts()
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Piratex.Game.join_game(game_id, "player1", "token1")

      :ok = Piratex.Game.set_letter_pool_type(game_id, :bananagrams_half)
      :ok = Piratex.Game.start_game(game_id, "token1")

      for _ <- 1..half_letter_count do
        :ok = Piratex.Game.flip_letter(game_id, "token1")
      end

      {:ok, %{initial_letter_count: ^half_letter_count, center: center, letter_pool: []}} =
        Piratex.Game.get_state(game_id)

      Enum.each(half_counts, fn {letter, count} ->
        assert Enum.count(center, fn l -> l == letter end) == count
      end)

      {:error, :no_more_letters} = Piratex.Game.flip_letter(game_id, "token1")
    end

    test "load full game and test letter distribution" do
      {full_letter_count, _full_letter_pool} = LetterPoolService.bananagrams_pool()
      full_counts = LetterPoolService.bananagrams_pool_counts()
      {:ok, game_id} = Piratex.DynamicSupervisor.new_game()

      :ok = Piratex.Game.join_game(game_id, "player1", "token1")

      :ok = Piratex.Game.set_letter_pool_type(game_id, :bananagrams)
      :ok = Piratex.Game.start_game(game_id, "token1")

      for _ <- 1..full_letter_count do
        :ok = Piratex.Game.flip_letter(game_id, "token1")
      end

      {:ok, %{initial_letter_count: ^full_letter_count, center: center, letter_pool: []}} =
        Piratex.Game.get_state(game_id)

      Enum.each(full_counts, fn {letter, count} ->
        assert Enum.count(center, fn l -> l == letter end) == count
      end)

      {:error, :no_more_letters} = Piratex.Game.flip_letter(game_id, "token1")
    end
  end
end

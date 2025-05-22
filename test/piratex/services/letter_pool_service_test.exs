defmodule Piratex.LetterPoolServiceTest do
  use ExUnit.Case

  alias Piratex.LetterPoolService

  describe "load_letter_pool" do
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

      {:ok, %{initial_letter_count: ^half_letter_count, center: center, letter_pool: []}} = Piratex.Game.get_state(game_id)

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

      {:ok, %{initial_letter_count: ^full_letter_count, center: center, letter_pool: []}} = Piratex.Game.get_state(game_id)

      Enum.each(full_counts, fn {letter, count} ->
        assert Enum.count(center, fn l -> l == letter end) == count
      end)

      {:error, :no_more_letters} = Piratex.Game.flip_letter(game_id, "token1")
    end
  end
end

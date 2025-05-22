defmodule Piratex.LetterPoolService do
  @moduledoc """
  This module provides functions for managing letter pools.
  """

  @type pool_type :: :bananagrams | :bananagrams_half

  @spec letter_pool_options() :: list({String.t(), pool_type()})
  def letter_pool_options() do
    [
      {"Standard", :bananagrams},
      {"Half", :bananagrams_half}
    ]
  end

  @spec load_letter_pool(pool_type()) :: list(String.t())
  def load_letter_pool(pool_type) do
    case pool_type do
      :bananagrams -> bananagrams_pool()
      :bananagrams_half -> bananagrams_pool_half()
    end
  end

  @doc """
  Returns the letter counts for Bananagrams.
  """
  @bananagrams_counts_letter_count 144
  @bananagrams_counts %{
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
    "z" => 2,
  }

  @bananagrams_half_counts_letter_count 79
  @bananagrams_half_counts %{
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
    "z" => 1,
  }

  @doc """
  Returns the standard letter pool for Bananagrams.
  """
  @spec bananagrams_pool() :: {pos_integer(), list(String.t())}
  def bananagrams_pool() do
    {@bananagrams_counts_letter_count, counts_to_letter_pool(@bananagrams_counts)}
  end

  @doc """
  Returns the letter pool for Bananagrams with
  half as many of each letter (rounded up)
  """
  @spec bananagrams_pool_half() :: {pos_integer(), list(String.t())}
  def bananagrams_pool_half() do
    {@bananagrams_half_counts_letter_count,
      Enum.map(@bananagrams_counts, fn {letter, ct} ->
        {letter, div2ceil(ct, 2)}
      end)
      |> counts_to_letter_pool()
    }
  end

  @spec counts_to_letter_pool(map()) :: list(String.t())
  defp counts_to_letter_pool(counts) do
    Enum.flat_map(counts, fn {letter, ct} ->
      List.duplicate(letter, ct)
    end)
  end

  @spec div2ceil(pos_integer(), pos_integer()) :: pos_integer()
  defp div2ceil(a, b) do
    div(a, b) + if rem(a, b) > 0, do: 1, else: 0
  end
end

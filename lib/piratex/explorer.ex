defmodule Piratex.Services.Explorer do
  alias Piratex.Services.WordClaimService
  alias Piratex.Dictionary

  def froms(word) do
    word_product = WordClaimService.calculate_word_product(word)
    word_length = String.length(word)

    Dictionary.words()
    |> Enum.filter(fn word ->
      # first filter out longer words
      if String.length(word) > word_length do
        word
        |> WordClaimService.calculate_word_product()
        |> then(&rem(word_product, &1) == 0 and &1 != word_product)
      else
        false
      end
    end)
    |> Enum.sort_by(&String.length/1, :desc)
  end

  def tos(word) do
    word_product = WordClaimService.calculate_word_product(word)
    word_length = String.length(word)

    Dictionary.words()
    |> Enum.filter(fn word ->
      # first filter out shorter words
      if String.length(word) < word_length do
        word
        |> WordClaimService.calculate_word_product()
        |> then(&rem(&1, word_product) == 0 and &1 != word_product)
      else
        false
      end
    end)
    |> Enum.sort_by(&String.length/1, :asc)
  end
end

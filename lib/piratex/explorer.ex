defmodule Piratex.Services.Explorer do
  alias Piratex.Services.WordClaimService
  alias Piratex.Dictionary

  def froms(word) do
    word_product = WordClaimService.calculate_word_product(word)

    Dictionary.words()
    |> Enum.filter(fn word ->
      word
      |> WordClaimService.calculate_word_product()
      |> then(&rem(word_product, &1) == 0 and &1 != word_product)
    end)
    |> Enum.sort_by(&String.length/1, :desc)
  end

  def tos(word) do
    word_product = WordClaimService.calculate_word_product(word)

    Dictionary.words()
    |> Enum.filter(fn word ->
      word
      |> WordClaimService.calculate_word_product()
      |> then(&rem(&1, word_product) == 0 and &1 != word_product)
    end)
    |> Enum.sort_by(&String.length/1, :asc)
  end
end

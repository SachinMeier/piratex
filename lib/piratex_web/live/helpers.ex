defmodule PiratexWeb.Live.Helpers do
  alias Piratex.Helpers

  def noreply(socket), do: {:noreply, socket}
  def ok(v), do: {:ok, v}

  def precompute_challengeable_history(state) do
    state.history
    |> Enum.take(3)
    |> Enum.map(fn %{thief_word: thief_word} = word_steal ->
      challengeable =
        Helpers.word_in_play?(state, thief_word) and
          not MapSet.member?(state.challenged_words, {word_steal.victim_word, thief_word})

      {word_steal, challengeable}
    end)
  end
end

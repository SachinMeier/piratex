defmodule Piratex.ChatFilter do
  @moduledoc false

  @blocked_words ~w(
    fuck shit damn bitch asshole
    cunt dick pussy nigger nigga faggot
  )

  @grawlix ~w(& * ! $ %)

  # Build regex patterns at compile time — each letter in the middle of the word
  # gets a `+` so repeated characters are caught (e.g. "fuuuck", "shiiit").
  @blocked_patterns Enum.map(@blocked_words, fn word ->
    pattern =
      word
      |> String.graphemes()
      |> Enum.map(fn char -> Regex.escape(char) <> "+" end)
      |> Enum.join()

    Regex.compile!("(?i)" <> pattern)
  end)

  @spec censor(String.t()) :: String.t()
  def censor(message) do
    Enum.reduce(@blocked_patterns, message, fn pattern, acc ->
      Regex.replace(pattern, acc, fn match ->
        len = String.length(match)

        if len <= 2 do
          grawlix(len)
        else
          first = String.first(match)
          last = String.last(match)
          first <> grawlix(len - 2) <> last
        end
      end)
    end)
  end

  defp grawlix(len) do
    @grawlix
    |> Stream.cycle()
    |> Enum.take(len)
    |> Enum.join()
  end
end

defmodule Piratex.DictionaryTest do
  use ExUnit.Case

  setup do
    case Piratex.Dictionary.start_link(nil) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} -> raise "Failed to start dictionary: #{inspect(reason)}"
    end
    :ok
  end

  test "is_word? returns true for a valid word" do
    assert Piratex.Dictionary.is_word?("these")
    assert Piratex.Dictionary.is_word?("abapical")
    assert Piratex.Dictionary.is_word?("dekagram")
    assert Piratex.Dictionary.is_word?("zythums")
  end

  test "is_word? returns false for an invalid word" do
    refute Piratex.Dictionary.is_word?(" ")
    refute Piratex.Dictionary.is_word?("zyzzy vasa")
    refute Piratex.Dictionary.is_word?("")
    refute Piratex.Dictionary.is_word?("deez")
    refute Piratex.Dictionary.is_word?("fdsa")
  end
end

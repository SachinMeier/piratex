defmodule Piratex.DictionaryTest do
  use ExUnit.Case, async: true

  setup do
    case Piratex.Dictionary.start_link(nil) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} -> raise "Failed to start dictionary: #{inspect(reason)}"
    end

    :ok
  end

  describe "start_link/1" do
    test "returns error when already started" do
      assert {:error, {:already_started, _pid}} = Piratex.Dictionary.start_link(nil)
    end
  end

  describe "init/1" do
    test "creates ETS table with correct options" do
      table_name = Piratex.Dictionary
      assert :ets.info(table_name) != :undefined
      assert :ets.info(table_name, :named_table) == true
      assert :ets.info(table_name, :type) == :set
      assert :ets.info(table_name, :protection) == :protected
      assert :ets.info(table_name, :read_concurrency) == true
      assert :ets.info(table_name, :write_concurrency) == false
    end

    test "loads dictionary into ETS table" do
      table_name = Piratex.Dictionary
      [{:dictionary, words}] = :ets.lookup(table_name, :dictionary)
      assert is_list(words)
      assert length(words) > 0
    end
  end

  describe "load_words/0" do
    test "returns a non-empty list" do
      words = Piratex.Dictionary.load_words()
      assert is_list(words)
      assert length(words) > 0
    end

    test "returns a list of strings" do
      words = Piratex.Dictionary.load_words()
      assert Enum.all?(words, &is_binary/1)
    end

    test "contains known words" do
      words = Piratex.Dictionary.load_words()
      assert "these" in words
      assert "abapical" in words
      assert "zyzzyva" in words
    end

    test "returns expected word count from test dictionary" do
      words = Piratex.Dictionary.load_words()
      assert length(words) == 57
    end

    test "contains first word in test dictionary" do
      words = Piratex.Dictionary.load_words()
      assert "abapical" in words
    end

    test "contains last word in test dictionary" do
      words = Piratex.Dictionary.load_words()
      assert "zyzzyva" in words
    end

    test "does not contain duplicate words" do
      words = Piratex.Dictionary.load_words()
      unique_words = Enum.uniq(words)
      assert length(words) == length(unique_words)
    end

    test "all words are lowercase" do
      words = Piratex.Dictionary.load_words()
      assert Enum.all?(words, fn word -> word == String.downcase(word) end)
    end

    test "no words contain whitespace" do
      words = Piratex.Dictionary.load_words()
      assert Enum.all?(words, fn word -> not String.contains?(word, [" ", "\t", "\n"]) end)
    end

    test "minimum word length is 3" do
      words = Piratex.Dictionary.load_words()
      assert Enum.all?(words, fn word -> String.length(word) >= 3 end)
    end
  end

  describe "is_word?/1" do
    test "returns true for a valid word" do
      assert Piratex.Dictionary.is_word?("these")
      assert Piratex.Dictionary.is_word?("abapical")
      assert Piratex.Dictionary.is_word?("dekagram")
      assert Piratex.Dictionary.is_word?("zyzzyva")
    end

    test "returns false for an invalid word" do
      refute Piratex.Dictionary.is_word?(" ")
      refute Piratex.Dictionary.is_word?("zyzzy vasa")
      refute Piratex.Dictionary.is_word?("")
      refute Piratex.Dictionary.is_word?("deez")
      refute Piratex.Dictionary.is_word?("fdsa")
    end

    test "returns false for uppercase input" do
      refute Piratex.Dictionary.is_word?("THESE")
      refute Piratex.Dictionary.is_word?("These")
      refute Piratex.Dictionary.is_word?("ZYZZYVA")
    end

    test "returns false for very long non-existent words" do
      refute Piratex.Dictionary.is_word?("abcdefghijklmnopqrstuvwxyz")
      refute Piratex.Dictionary.is_word?(String.duplicate("a", 100))
    end

    test "returns false for single-character strings" do
      refute Piratex.Dictionary.is_word?("a")
      refute Piratex.Dictionary.is_word?("z")
      refute Piratex.Dictionary.is_word?("x")
    end

    test "returns true for first word in test dictionary" do
      assert Piratex.Dictionary.is_word?("abapical")
    end

    test "returns true for last word in test dictionary" do
      assert Piratex.Dictionary.is_word?("zyzzyva")
    end

    test "returns false for two-letter words" do
      refute Piratex.Dictionary.is_word?("ab")
      refute Piratex.Dictionary.is_word?("xy")
      refute Piratex.Dictionary.is_word?("zz")
    end

    test "returns false for words with numbers" do
      refute Piratex.Dictionary.is_word?("word1")
      refute Piratex.Dictionary.is_word?("123")
      refute Piratex.Dictionary.is_word?("test2word")
    end

    test "returns false for words with special characters" do
      refute Piratex.Dictionary.is_word?("word!")
      refute Piratex.Dictionary.is_word?("test@word")
      refute Piratex.Dictionary.is_word?("word-test")
      refute Piratex.Dictionary.is_word?("word's")
    end

    test "returns false for words with leading/trailing whitespace" do
      refute Piratex.Dictionary.is_word?(" these")
      refute Piratex.Dictionary.is_word?("these ")
      refute Piratex.Dictionary.is_word?(" these ")
    end

    test "handles concurrent lookups correctly" do
      tasks =
        Enum.map(1..100, fn _ ->
          Task.async(fn ->
            assert Piratex.Dictionary.is_word?("these")
            refute Piratex.Dictionary.is_word?("notaword")
          end)
        end)

      Enum.each(tasks, &Task.await/1)
    end

    test "returns false for words with unicode characters" do
      refute Piratex.Dictionary.is_word?("café")
      refute Piratex.Dictionary.is_word?("naïve")
      refute Piratex.Dictionary.is_word?("résumé")
    end

    test "returns true for common short words in test dictionary" do
      assert Piratex.Dictionary.is_word?("ace")
      assert Piratex.Dictionary.is_word?("ate")
      assert Piratex.Dictionary.is_word?("bat")
      assert Piratex.Dictionary.is_word?("cat")
      assert Piratex.Dictionary.is_word?("tea")
      assert Piratex.Dictionary.is_word?("met")
    end

    test "returns true for long words in test dictionary" do
      assert Piratex.Dictionary.is_word?("abapical")
      assert Piratex.Dictionary.is_word?("dekagram")
      assert Piratex.Dictionary.is_word?("blenders")
      assert Piratex.Dictionary.is_word?("blunders")
    end
  end
end

defmodule Piratex.Dictionary do
  @moduledoc """
  ETS table for storing the dictionary words and providing
  a server for checking if a word is valid.
  """
  use GenServer

  @table_name __MODULE__

  @dictionary_key :dictionary

  @doc """
  Starts the dictionary server.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: @table_name)
  end

  @doc """
  Initializes the dictionary by loading the words from the dictionary file into an ETS table.
  """
  def init(_ok) do
    ets_tid = :ets.new(@table_name, [
      :set,
      :named_table,
      :protected,
      read_concurrency: true,
      write_concurrency: false
    ])
    :ets.insert(@table_name, {@dictionary_key, load_words()})

    {:ok, ets_tid}
  end

  @doc """
  Loads the words from the dictionary file into a list.
  """
  @spec load_words() :: list(String.t())
  def load_words() do
    # IO.puts("Loading words from dictionary.txt")
    IO.inspect(Path.wildcard("assets/"), label: "/assets")
    IO.inspect(Path.wildcard("assets/static/"), label: "/assets/static")
    IO.inspect(Path.wildcard("static/"), label: "/static")
    IO.inspect(Path.wildcard("priv/"), label: "/priv")
    # IO.inspect(Path.wildcard("priv/data/"), label: "/priv/data/")
    # {res, words} = File.read!("priv/data/dictionary.txt")
    # IO.inspect(res, label: "Loaded words. Result")
    # String.split(words)
    ["bit", "bot", "bat"]
  end

  @doc """
  Checks if a word is in the dictionary.
  TODO: binary search.
  """
  @spec is_word?(String.t()) :: boolean()
  def is_word?(word) do
    [{@dictionary_key, words}] = :ets.lookup(@table_name, @dictionary_key)
    word in words
  end
end

defmodule Piratex.Dictionary do
  @moduledoc """
  ETS table for storing the dictionary words and providing
  a server for checking if a word is valid.
  """
  use GenServer

  alias Piratex.Config

  @table_name __MODULE__

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
    ets_tid =
      :ets.new(@table_name, [
        :set,
        :named_table,
        :protected,
        read_concurrency: true,
        write_concurrency: false
      ])

    @table_name
    |> :ets.insert(Enum.map(load_words(), &{&1}))

    {:ok, ets_tid}
  end

  @doc """
  Loads the words from the dictionary file into a list.
  """
  @spec load_words() :: list(String.t())
  def load_words() do
    :piratex
    |> Application.app_dir("priv/data/")
    |> Path.join(Config.dictionary_file_name())
    |> File.read!()
    |> String.split("\n", trim: true)
  end

  @doc """
  Checks if a word is in the dictionary.
  """
  @spec is_word?(String.t()) :: boolean()
  def is_word?(word) do
    :ets.member(@table_name, word)
  end
end

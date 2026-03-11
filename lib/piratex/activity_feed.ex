defmodule Piratex.ActivityFeed do
  @moduledoc """
  Helpers for the playing-stage chat and event feed.
  """

  alias Piratex.Helpers

  @feed_limit 200

  defmodule Entry do
    @moduledoc """
    A single activity feed entry.
    """

    @type entry_type :: :player_message | :event
    @type event_kind :: :word_stolen | :challenge_resolved | :word_invalidated | :player_quit

    @type t :: %__MODULE__{
            id: non_neg_integer(),
            type: entry_type(),
            body: String.t(),
            player_name: String.t() | nil,
            event_kind: event_kind() | nil,
            inserted_at: DateTime.t(),
            metadata: map()
          }

    defstruct [
      :id,
      :type,
      :body,
      :player_name,
      :event_kind,
      :inserted_at,
      :metadata
    ]
  end

  @spec entries(map()) :: [Entry.t()]
  def entries(state) do
    Map.get(state, :activity_feed, [])
  end

  @spec append(map(), Entry.t()) :: map()
  def append(state, %Entry{} = entry) do
    next_entries =
      state
      |> entries()
      |> Kernel.++([entry])
      |> Enum.take(-@feed_limit)

    Map.put(state, :activity_feed, next_entries)
  end

  @spec append_player_message(map(), String.t(), String.t()) :: map()
  def append_player_message(state, player_name, body) do
    append(state, player_message(player_name, body))
  end

  @spec append_event(map(), Entry.event_kind(), String.t(), map()) :: map()
  def append_event(state, event_kind, body, metadata \\ %{}) do
    append(state, event(event_kind, body, metadata))
  end

  @spec player_message(String.t(), String.t()) :: Entry.t()
  def player_message(player_name, body) do
    %Entry{
      id: Helpers.new_id(4),
      type: :player_message,
      player_name: player_name,
      body: body,
      inserted_at: DateTime.utc_now(),
      metadata: %{}
    }
  end

  @spec event(Entry.event_kind(), String.t(), map()) :: Entry.t()
  def event(event_kind, body, metadata \\ %{}) do
    %Entry{
      id: Helpers.new_id(4),
      type: :event,
      event_kind: event_kind,
      body: body,
      inserted_at: DateTime.utc_now(),
      metadata: metadata
    }
  end
end

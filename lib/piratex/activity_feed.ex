defmodule Piratex.ActivityFeed do
  @moduledoc """
  Helpers for the playing-stage chat and event feed.
  """

  alias Piratex.Helpers

  @feed_limit 20

  defmodule Entry do
    @moduledoc """
    A single activity feed entry.
    """

    @type entry_type :: :player_message | :event
    @type event_kind :: :word_stolen | :challenge_resolved | :player_quit

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

  @type queue_t :: :queue.queue(Entry.t())

  @spec new() :: queue_t()
  def new do
    :queue.new()
  end

  @spec append(map(), Entry.t()) :: map()
  def append(state, %Entry{} = entry) do
    next_feed =
      state
      |> Map.get(:activity_feed, new())
      |> to_queue()
      |> then(&:queue.in(entry, &1))
      |> trim_queue()

    Map.put(state, :activity_feed, next_feed)
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

  @spec entries(map() | queue_t() | [Entry.t()] | nil) :: [Entry.t()]
  def entries(%{} = state) do
    state
    |> Map.get(:activity_feed, nil)
    |> entries()
  end

  def entries({_, _} = activity_feed) do
    :queue.to_list(activity_feed)
  end

  def entries(activity_feed) when is_list(activity_feed) do
    activity_feed
  end

  def entries(nil), do: []

  @spec limit() :: pos_integer()
  def limit do
    @feed_limit
  end

  defp to_queue({_, _} = activity_feed), do: activity_feed
  defp to_queue(activity_feed) when is_list(activity_feed), do: :queue.from_list(activity_feed)
  defp to_queue(nil), do: new()

  defp trim_queue(activity_feed) do
    if :queue.len(activity_feed) > @feed_limit do
      {{:value, _oldest_entry}, trimmed_feed} = :queue.out(activity_feed)
      trimmed_feed
    else
      activity_feed
    end
  end
end

defmodule PiratexWeb.Live.WatchGame do
  use PiratexWeb, :live_view

  alias Piratex.Config
  alias Piratex.Game

  import PiratexWeb.Live.Helpers

  import PiratexWeb.Components.FinishedComponent
  import PiratexWeb.Components.Waiting
  import PiratexWeb.Components.Playing

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    case Game.get_state(game_id) do
      {:ok, game_state} ->
        # connected? prevents duplicate subscriptions. We only need to subscribe to playing games
        if connected?(socket) and game_state.status in [:waiting, :playing] do
          Phoenix.PubSub.subscribe(Piratex.PubSub, Game.events_topic(game_state.id))
        end

        socket
        |> assign(
          watch_only: true,
          my_name: "",
          game_id: game_id,
          game_state: game_state,
          my_team_id: 0,
          chat_form: to_form(%{"message" => ""}),
          visible_word_steal: nil,
          challengeable_history: precompute_challengeable_history(game_state),
          game_progress_bar: game_state.status == :playing,
          letter_pool_size: Config.letter_pool_size(),
          max_chat_message_length: Game.max_chat_message_length(),
          challenge_timeout_ms: Config.challenge_timeout_ms(),
          show_teams_modal: false,
          show_hotkeys_modal: false,
          max_name_length: 0,
          valid_team_name: false,
          zen_mode: false,
          auto_flip: false,
          show_teams_modal: false,
          show_hotkeys_modal: false,
          speech_recording: false,
          speech_results: nil
        )
        |> ok()

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Game not found")
        |> redirect(to: ~p"/find")
        |> ok()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= case @game_state.status do %>
      <% :waiting -> %>
        <.waiting
          game_state={@game_state}
          watch_only={true}
          my_team_id={@my_team_id}
          max_name_length={@max_name_length}
          valid_team_name={@valid_team_name}
        />
      <% :playing -> %>
        <.playing
          game_state={@game_state}
          watch_only={true}
          challengeable_history={@challengeable_history}
          challenge_timeout_ms={@challenge_timeout_ms}
          max_chat_message_length={@max_chat_message_length}
          visible_word_steal={@visible_word_steal}
          show_teams_modal={@show_teams_modal}
          my_team_id={@my_team_id}
          show_hotkeys_modal={@show_hotkeys_modal}
        />
      <% :finished -> %>
        <.finished game_state={@game_state} />
    <% end %>
    """
  end

  @impl true
  def terminate(_reason, socket) do
    Phoenix.PubSub.unsubscribe(Piratex.PubSub, Game.events_topic(socket.assigns.game_id))
    :ok
  end

  @impl true
  def handle_event("hotkeys", _, socket) do
    # ignore this for watch-only
    noreply(socket)
  end

  def handle_event("quit_game", _, socket) do
    noreply(socket)
  end

  def handle_event("show_word_steal", %{"word" => word_steal}, socket) do
    word_steal =
      Piratex.ChallengeService.find_word_steal(socket.assigns.game_state, word_steal)

    socket
    |> assign(visible_word_steal: word_steal)
    |> noreply()
  end

  def handle_event("hide_word_steal", _params, socket) do
    socket
    |> assign(visible_word_steal: nil)
    |> noreply()
  end

  def handle_event("toggle_teams_modal", _params, socket) do
    socket
    |> assign(show_teams_modal: !socket.assigns.show_teams_modal)
    |> noreply()
  end

  def handle_event("toggle_hotkeys_modal", _params, socket) do
    socket
    |> assign(show_hotkeys_modal: !socket.assigns.show_hotkeys_modal)
    |> noreply()
  end

  def handle_event("hide_modal", _params, socket) do
    socket
    |> assign(
      show_teams_modal: false,
      show_hotkeys_modal: false,
      visible_word_steal: nil,
      speech_results: nil
    )
    |> noreply()
  end

  # catchall for events that watchers don't need
  def handle_event(_, _, socket) do
    noreply(socket)
  end

  @impl true
  def handle_info({:new_state, state}, socket) do
    old_pool_size = socket.assigns.game_state.letter_pool_count
    new_pool_size = state.letter_pool_count
    tile_flipped? = new_pool_size < old_pool_size

    socket
    |> assign(
      # TODO: split this out into a separate event
      game_state: state,
      challengeable_history: precompute_challengeable_history(state),
      game_progress_bar: state.status == :playing
    )
    |> then(fn socket ->
      if tile_flipped?, do: push_event(socket, "play_sound", %{sound: "click"}), else: socket
    end)
    |> noreply()
  end

  def handle_info({:game_stats, game_stats}, socket) do
    socket
    |> assign(game_stats: game_stats)
    |> noreply()
  end
end

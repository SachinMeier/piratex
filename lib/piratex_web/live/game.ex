defmodule PiratexWeb.Live.Game do
  use PiratexWeb, :live_view

  import PiratexWeb.Live.Helpers

  import PiratexWeb.Components.PiratexComponents
  import PiratexWeb.Components.HistoryComponent
  import PiratexWeb.Components.ChallengeComponent
  import PiratexWeb.Components.WordStealComponent
  import PiratexWeb.Components.TeamsComponent
  import PiratexWeb.Components.HotkeysComponent
  import PiratexWeb.Components.FinishedComponent

  alias Piratex.Game
  alias Piratex.Config
  alias Piratex.ChallengeService

  @impl true
  def mount(_params, _session, socket) do
    # this is set in GameSession.on_mount
    player_name = socket.assigns.player_name
    # TODO: we currently only store the game_id, not the pid,
    # so we need to lookup the pid every time we send any message or remount
    game_id = socket.assigns.game_id
    case Game.get_state(game_id) do
      {:ok, game_state} ->
        my_turn_idx = determine_my_turn_idx(player_name, game_state)

        # connected? prevents duplicate subscriptions. We only need to subscribe to playing games
        if connected?(socket) and game_state.status in [:waiting, :playing] do
          Phoenix.PubSub.subscribe(Piratex.PubSub, Game.events_topic(game_state.id))
        end

        socket
        |> assign(
          my_name: player_name,
          my_turn_idx: my_turn_idx,
          game_id: game_state.id,
          game_state: game_state,
          my_team_id: determine_my_team_id(player_name, game_state.players_teams),
          word_form: to_form(%{"word" => ""}),
          visible_word_steal: nil,
          game_progress_bar: game_state.status == :playing,
          letter_pool_size: Config.letter_pool_size(),
          min_word_length: Config.min_word_length(),
          # TODO: validate team name
          valid_team_name: false,
          min_name_length: Config.min_player_name(),
          max_name_length: Config.max_player_name(),
          zen_mode: false,
          auto_flip: false,
          show_teams_modal: false,
          show_hotkeys_modal: false,
          speech_recording: false,
          speech_results: nil
        )
        |> assign_seo_metadata()
        |> set_page_title()
        |> ok()

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Game not found")
        |> redirect(to: ~p"/find")
        |> ok()
    end

    # socket
    # |> assign(game_state: fake_game_state())
    # |> set_page_title()
    # |> ok()
  end

  def assign_seo_metadata(socket) do
    title = "Game #{socket.assigns.game_id} | Pirate Scrabble"
    description = "Game #{socket.assigns.game_id}"

    assign(socket, seo_metadata: %{
      og_title: title,
      og_description: description,
      twitter_title: title,
      twitter_description: description
    })
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    noreply(socket)
  end

  @impl true
  def terminate(_reason, socket) do
    Phoenix.PubSub.unsubscribe(Piratex.PubSub, Game.events_topic(socket.assigns.game_id))
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= case @game_state.status do %>
      <% :waiting -> %>
        <.waiting {assigns} />
      <% :playing -> %>
        <.playing {assigns} />
      <% :finished -> %>
        <.finished {assigns} />
    <% end %>
    """
  end

  attr :game_state, :map, required: true

  defp waiting(assigns) do
    ~H"""
    <div class="flex flex-col mx-auto justify-around">
      <div class="mx-auto">
        <.tile_word word="teams" />
      </div>

      <.team_selection teams={@game_state.teams} players_teams={@game_state.players_teams} my_team_id={@my_team_id} />

      <.render_new_team_form
        :if={length(@game_state.teams) < Config.max_teams()}
        max_name_length={@max_name_length}
        valid_team_name={@valid_team_name}
      />

      <div class="flex flex-col gap-y-4 mx-auto">
        <.ps_button phx_click="start_game" width="w-full">
          START
        </.ps_button>
      </div>
    </div>
    """
  end

  attr :max_name_length, :integer, required: true
  attr :valid_team_name, :boolean, required: true

  defp render_new_team_form(assigns) do
    ~H"""
    <div class="mx-auto my-8">
      <.form
        for={%{}}
        phx-change="validate_new_team_name"
        phx-submit="create_team"
        class="flex flex-row mx-auto w-full"
      >
        <.ps_text_input
          id="team_name_input"
          name="team"
          field={:team}
          placeholder="Name"
          value=""
          maxlength={@max_name_length}
          class="rounded-r-none border-r-0"
        />
        <.ps_button type="submit" class="rounded-l-none" disabled={!@valid_team_name} disabled_style={false}>
          NEW TEAM
        </.ps_button>
      </.form>
    </div>
    """
  end

  attr :game_state, :map, required: true
  attr :my_turn_idx, :integer, required: true
  attr :word_value, :string, required: true

  defp playing(assigns) do
    ~H"""
    <div id="game_wrapper" class="flex flex-col" phx-hook="Hotkeys">
      <div id="board_center_and_actions" class="flex flex-col sm:flex-row gap-4 md:gap-8">
        <.center center={@game_state.center} />

        <.player_action_area
          my_name={@my_name}
          game_state={@game_state}
          word_form={@word_form}
          min_word_length={@min_word_length}
          is_turn={my_turn?(@my_turn_idx, @game_state)}
          speech_recording={@speech_recording}
          paused={ChallengeService.open_challenge?(@game_state)}
          auto_flip={@auto_flip}
        />
      </div>

      <%= if @zen_mode do %>
        <.zen_mode game_state={@game_state} />
      <% else %>
        <div class="flex flex-col md:flex-row justify-between w-full mt-8">
          <div class="flex flex-wrap gap-4">
            <%= for team <- @game_state.teams do %>
              <.team_word_area team={team} />
            <% end %>
          </div>
          <.history game_state={@game_state} paused={ChallengeService.open_challenge?(@game_state)} />
        </div>
      <% end %>
    </div>
    <.render_modal {assigns} />
    """
  end

  attr :center, :list, required: true

  defp center(assigns) do
    ~H"""
    <%!-- Desktop view --%>
    <div
      id="board_center"
      class="flex flex-wrap gap-1 sm:gap-2 w-full max-h-52 overflow-y-auto overscroll-contain no-scrollbar rounded-md p-4 pt-0"
    >
      <%= for letter <- @center do %>
        <div class="hidden sm:block md:my-0">
          <.tile letter={letter} />
        </div>
        <div class="block sm:hidden mt-1">
          <.tile_sm letter={letter} />
          <%!-- {String.upcase(letter)} --%>
        </div>
      <% end %>
    </div>
    """
  end

  # TODO: if all players have quit, show a message saying the team is empty
  attr :team, :map, required: true

  defp team_word_area(assigns) do
    ~H"""
    <%= if @team.words != [] do %>
      <%!-- Desktop view --%>
      <div
        id={"board_player_#{@team.name}"}
        class="hidden sm:flex flex-col min-w-48 rounded-md border-2 border-black dark:border-white min-h-48"
      >
        <button phx-click="toggle_teams_modal">
          <div class="w-full px-auto text-center border-b-2 border-black dark:border-white">
            {@team.name}
          </div>
        </button>
        <div class="flex flex-col h-full mx-2 mb-2 pb-1 overflow-x-auto overscroll-contain no-scrollbar">
          <%= for word <- @team.words do %>
            <div class="mt-2">
              <.word_in_play word={word} abbrev={0} />
            </div>
          <% end %>
        </div>
      </div>
      <%!-- Mobile view --%>
      <div class="flex flex-col sm:hidden">
        <button phx-click="toggle_teams_modal">
          <div class="w-full px-auto text-center border-b-2 border-black dark:border-white">
            {@team.name}
          </div>
        </button>
        <div class="flex flex-col mx-2 mb-2 pb-1 overflow-x-auto overscroll-contain no-scrollbar">
          <%= for word <- @team.words do %>
            <div class="mt-1">
              <.word_in_play word={word} abbrev={0} />
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp player_action_area(assigns) do
    # TODO: maybe make the text input and submit a component with merged borders.
    # NOTE: hotkeys.js is listening for Enter key presses to focus on the word input text box based on the id.
    ~H"""
    <div id="actions_area" class="flex flex-col" phx-hook="SpeechRecognition">
      <div class="flex flex-col xs:flex-row sm:flex-col gap-4">
        <.form
          for={@word_form}
          phx-submit="submit_new_word"
          phx-change="word_change"
          class="flex flex-row w-full min-w-[260px]"
        >
          <.ps_text_input
            id="new_word_input"
            name="word"
            form={@word_form}
            field={:word}
            autocomplete={false}
            placeholder="New Word"
            text_size="text-base xs:text-xl"
            class="w-full xs:max-w-48 md:max-w-full xs:rounded-r-none"
            max_width=""
          />
          <.ps_button type="submit" class="hidden xs:block rounded-l-none border-l-0 w-full max-w-24" disabled={@paused}>
            SUBMIT
          </.ps_button>
        </.form>

        <!-- Speech recognition button -->
        <div class="flex flex-row gap-2 justify-center">
          <.ps_button
            phx-click="toggle_speech_recognition"
            disabled={@paused}
            class={"w-full #{if @speech_recording, do: "recording", else: ""}"}
          >
            <%= if @speech_recording do %>
              <span class="flex items-center justify-center gap-2">
                <span class="recording-dot"></span>
                Listening...
              </span>
            <% else %>
              <span class="flex items-center justify-center gap-2">
                🎤
              </span>
            <% end %>
          </.ps_button>
          <%!-- Flip / End game button --%>
          <%= if @game_state.letter_pool == [] and !voted_to_end_game?(@my_name, @game_state) do %>
            <.ps_button
              class="w-full mx-auto"
              phx_click="end_game_vote"
              phx_disable_with="Ending Game..."
            >
              END GAME
            </.ps_button>
          <% else %>
            <.ps_button
              class="w-full mx-auto"
              phx_click="flip_letter"
              phx_disable_with="Flipping..."
              disabled={!@is_turn || @paused}
            >
              <%= cond do %>
                <% @game_state.letter_pool == [] -> %>
                  Game Over

                <% @is_turn && @auto_flip -> %>
                  [AUTO]

                <% @is_turn -> %>
                  FLIP
                <% true -> %>
                  <div class="hidden md:block">
                    {trunc_player_name(Enum.at(@game_state.players, @game_state.turn).name)}
                  </div>
                  <div class="block md:hidden">
                    FLIP
                  </div>
              <% end %>
            </.ps_button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp trunc_player_name(name) do
    if String.length(name) > 12 do
      String.slice(name, 0, 10) <> "..."
    else
      name
    end
  end

  defp zen_mode(assigns) do
    ~H"""
    <div class="mt-8 flex flex-row flex-wrap gap-x-8 gap-y-4 w-full">
      <%= for team <- @game_state.teams do %>
        <%= if team.words != [] do %>
          <div class="flex flex-col h-full mx-2 mb-2 pb-1 overflow-x-auto overscroll-contain no-scrollbar">
            <%= for word <- team.words do %>
              <div class="mt-2">
                <.word_in_play word={word} abbrev={0} />
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_modal(assigns) do
    ~H"""
    <%= cond do %>
      <% ChallengeService.open_challenge?(@game_state) -> %>
        <.ps_modal title="challenge">
          <.challenge
            challenge={Enum.at(@game_state.challenges, 0)}
            player_name={@player_name}
          />
        </.ps_modal>
      <% @visible_word_steal != nil -> %>
        <.ps_modal title="word steal">
          <.word_steal players={@game_state.players} teams={@game_state.teams} word_steal={@visible_word_steal} />
        </.ps_modal>
      <% @show_teams_modal -> %>
        <.ps_modal title="teams">
          <.teams teams={@game_state.teams} players_teams={@game_state.players_teams} my_team_id={@my_team_id} />
        </.ps_modal>
      <% @show_hotkeys_modal -> %>
        <.ps_modal title="hotkeys">
          <.hotkeys_modal />
        </.ps_modal>
      <% true -> %>
    <% end %>
    """
  end

  # EVENT HANDLING

  @impl true
  def handle_event("validate_new_team_name", %{"team" => team}, socket) do
    name_length =
      team
      |> String.trim()
      |> String.length()

    valid? =
      name_length >= socket.assigns.min_name_length and
        name_length <= socket.assigns.max_name_length

    socket
    |> assign(valid_team_name: valid?)
    |> noreply()
  end

  def handle_event("create_team", %{"team" => team_name}, socket) do
    Game.create_team(socket.assigns.game_id, socket.assigns.player_token, team_name)
    noreply(socket)
  end

  def handle_event("join_team", %{"team_id" => team_id}, socket) do
    team_id = String.to_integer(team_id)
    Game.join_team(socket.assigns.game_id, socket.assigns.player_token, team_id)
    noreply(socket)
  end

  def handle_event("start_game", _params, socket) do
    Game.start_game(socket.assigns.game_id, socket.assigns.player_token)
    noreply(socket)
  end

  def handle_event(
        "hotkey",
        %{
          "key" => key,
          "ctrl" => ctrl,
          "shift" => shift,
          "meta" => meta
        },
        %{assigns: %{game_state: %{status: :playing} = game_state}} = socket
      ) do
    case {key, shift, ctrl || meta} do
      # show hotkey modal
      {"0", _, _} ->
        socket
        |> assign(show_hotkeys_modal: !socket.assigns.show_hotkeys_modal)
        |> noreply()

      {"1", _, _} ->
        # challenge most recent word
        case game_state.history do
          [] ->
            noreply(socket)

          history ->
            word_steal = Enum.at(history, 0)
            handle_event("challenge_word", %{"word" => word_steal.thief_word}, socket)
        end

      {"2", _, _} ->
        # vote valid on challenge
        case socket.assigns.game_state.challenges do
          [] ->
            noreply(socket)

          [challenge | _] ->
            handle_event("accept_steal", %{"challenge_id" => "#{challenge.id}"}, socket)
        end

      {"3", _, _} ->
        # toggle teams modal
        socket
        |> assign(show_teams_modal: !socket.assigns.show_teams_modal)
        |> noreply()

      {"5", _, _} ->
        # toggle speech recognition
        toggle_speech_recognition(socket)

      {"6", _, _} ->
        # Auto Flip
        send(self(), :auto_flip)

        socket
        |> assign(auto_flip: !socket.assigns.auto_flip)
        |> noreply()

      {"7", _, _} ->
        # vote invalid on challenge
        case socket.assigns.game_state.challenges do
          [] ->
            noreply(socket)

          [challenge | _] ->
            handle_event("reject_steal", %{"challenge_id" => "#{challenge.id}"}, socket)
        end

      {"8", _, _} ->
        # Zen Mode
        socket
        |> assign(zen_mode: !socket.assigns.zen_mode)
        |> noreply()

      # Space => FLIP
      {" ", _, _} ->
        if socket.assigns.game_state.letter_pool == [] do
          if !voted_to_end_game?(socket.assigns.my_name, socket.assigns.game_state) do
            handle_event("end_game_vote", %{}, socket)
          end
        else
          handle_event("flip_letter", %{}, socket)
        end

      # Close any modal
      {"Escape", _, _} ->
        handle_event("hide_modal", %{}, socket)

      _ ->
        noreply(socket)
    end
  end

  def handle_event(
        "submit_new_word",
        %{"word" => word},
        %{assigns: %{min_word_length: min_word_length}} = socket
      ) do
    if String.length(word) < min_word_length do
      socket
      |> reset_word_form()
      |> noreply()
    else
      Game.claim_word(
        socket.assigns.game_id,
        socket.assigns.player_token,
        String.downcase(word)
      )
      |> case do
        :ok ->
          socket

        {:error, error} ->
          put_flash(socket, :error, error)
      end
      |> reset_word_form()
      |> noreply()
    end
  end

  # I don't know why this is needed to reset the word after submit, but it is
  def handle_event("word_change", %{"word" => word}, socket) do
    socket
    |> assign(word_form: to_form(%{"word" => word}))
    |> noreply()
  end

  def handle_event("flip_letter", _params, %{assigns: %{player_token: player_token}} = socket) do
    # Don't allow flipping if there are challenges pending
    if !ChallengeService.open_challenge?(socket.assigns.game_state) do
      Game.flip_letter(socket.assigns.game_id, player_token)
    end

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

  def handle_event(
        "challenge_word",
        %{"word" => word},
        %{assigns: %{player_token: player_token}} = socket
      ) do
    Game.challenge_word(socket.assigns.game_id, player_token, word)
    noreply(socket)
  end

  def handle_event(
        "accept_steal",
        %{"challenge_id" => challenge_id},
        %{assigns: %{player_token: player_token}} = socket
      ) do
    Game.challenge_vote(
      socket.assigns.game_id,
      player_token,
      String.to_integer(challenge_id),
      true
    )

    noreply(socket)
  end

  def handle_event(
        "reject_steal",
        %{"challenge_id" => challenge_id},
        %{assigns: %{player_token: player_token}} = socket
      ) do
    Game.challenge_vote(
      socket.assigns.game_id,
      player_token,
      String.to_integer(challenge_id),
      false
    )

    noreply(socket)
  end

  def handle_event(
        "leave_waiting_game",
        _params,
        %{assigns: %{player_token: player_token}} = socket
      ) do
    Game.leave_waiting_game(socket.assigns.game_id, player_token)

    socket
    |> redirect(to: ~p"/clear")
    |> noreply()
  end

  def handle_event("end_game_vote", _params, %{assigns: %{player_token: player_token}} = socket) do
    Game.end_game_vote(socket.assigns.game_id, player_token)
    noreply(socket)
  end

  def handle_event("quit_game", _params, %{assigns: %{player_token: player_token}} = socket) do
    Game.quit_game(socket.assigns.game_id, player_token)

    socket
    |> redirect(to: ~p"/clear")
    |> noreply()
  end

  # Speech recognition event handlers
  def handle_event("toggle_speech_recognition", _params, socket) do
    toggle_speech_recognition(socket)
  end

  def handle_event("speech_started", _params, socket) do
    socket
    |> assign(speech_recording: true)
    |> noreply()
  end

  def handle_event("speech_ended", _params, socket) do
    socket
    |> assign(speech_recording: false)
    |> noreply()
  end

  def handle_event("speech_results", %{"results" => results}, socket) do
    IO.puts("Speech results: #{inspect(results)}")

    results
    # Only try the first 5 results
    |> Enum.take(5)
    |> Enum.reduce_while(nil, fn %{"confidence" => _, "transcript" => transcript}, _acc ->
      if String.contains?(transcript, " ") do
        {:cont, nil}
      else
        Game.claim_word(
          socket.assigns.game_id,
          socket.assigns.player_token,
          transcript
        )
        |> case do
          :ok ->
            {:halt, transcript}

          # If we hit one of these errors, no use in submitting other words
          {:error, err} when err in [:not_found, :game_not_playing, :player_not_found, :team_not_found] ->
            {:halt, nil}

          # if this word is invalid, try others
          {:error, _error} ->
            {:cont, nil}
        end
      end
    end)

    socket
    |> assign(
      speech_results: results,
      speech_recording: false
    )
    |> noreply()
  end

  def handle_event("speech_error", %{"error" => error}, socket) do
    IO.puts("Speech recognition error: #{error}")
    socket
    |> assign(
      speech_recording: false,
      speech_results: nil
    )
    |> put_flash(:error, error)
    |> noreply()
  end

  def handle_event("submit_speech_word", %{"word" => word}, socket) do
    if String.length(word) < socket.assigns.min_word_length do
      socket
      |> put_flash(:error, "Word must be at least #{socket.assigns.min_word_length} letters")
      |> noreply()
    else
      Game.claim_word(
        socket.assigns.game_id,
        socket.assigns.player_token,
        String.downcase(word)
      )
      |> case do
        :ok ->
          socket
          |> assign(
            speech_results: nil
          )

        {:error, error} ->
          put_flash(socket, :error, error)
      end
      |> noreply()
    end
  end

  def handle_event("select_speech_alternative", %{"word" => word}, socket) do
    Game.claim_word(
      socket.assigns.game_id,
      socket.assigns.player_token,
      String.downcase(word)
    )
    |> case do
      :ok ->
        socket
        |> assign(
          speech_results: nil
        )

      {:error, error} ->
        put_flash(socket, :error, error)
    end
    |> noreply()
  end

  def handle_event("cancel_speech", _params, socket) do
    socket
    |> assign(
      speech_results: nil,
      speech_recording: false
    )
    |> noreply()
  end

  @impl true
  def handle_info({:new_state, state}, socket) do
    if my_turn?(socket.assigns.my_turn_idx, state) and socket.assigns.auto_flip do
      Process.send_after(self(), :auto_flip, 1000)
    end

    socket
    |> assign(
      # TODO: split this out into a separate event
      my_team_id: determine_my_team_id(socket.assigns.my_name, state.players_teams),
      game_state: state,
      game_progress_bar: state.status == :playing
    )
    |> set_page_title()
    |> noreply()
  end

  def handle_info({:game_stats, game_stats}, socket) do
    socket
    |> assign(game_stats: game_stats)
    |> noreply()
  end

  def handle_info(:auto_flip, socket) do
    if my_turn?(socket) do
      handle_event("flip_letter", %{}, socket)
    end

    noreply(socket)
  end

  defp toggle_speech_recognition(socket) do
    if socket.assigns.speech_recording do
      socket
      |> assign(speech_recording: false)
      |> push_event("stop_recognition", %{})
      |> noreply()
    else
      IO.puts("Starting speech recognition...")
      socket
      |> assign(speech_recording: true)
      |> push_event("start_recognition", %{})
      |> noreply()
    end
  end

  # TODO: to avoid name-related mistakes, lookup index from Game? names should be uniq anyway.
  def determine_my_turn_idx(player_name, game_state) do
    Enum.find_index(game_state.players, fn %{name: name} -> name == player_name end)
  end

  defp determine_my_team_id(player_name, players_teams) do
    Enum.find_value(players_teams, fn {name, team_id} ->
      if name == player_name do
        team_id
      end
    end)
  end

  defp my_turn?(my_turn_idx, game_state) do
    my_turn_idx == game_state.turn
  end

  defp my_turn?(socket) do
    my_turn?(socket.assigns.my_turn_idx, socket.assigns.game_state)
  end

  defp reset_word_form(socket) do
    assign(socket, word_form: to_form(%{"word" => ""}))
  end

  defp voted_to_end_game?(player_name, game_state) do
    Map.has_key?(game_state.end_game_votes, player_name)
  end

  def set_page_title(socket) do
    title =
      if socket.assigns.game_state.status == :playing &&
          my_turn?(socket) do
        "YOUR TURN - Pirate Scrabble"
      else
        "Pirate Scrabble"
      end

    assign(socket, page_title: title)
  end
end

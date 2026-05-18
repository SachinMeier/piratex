defmodule PiratexWeb.Components.Playing do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias Piratex.ChallengeService

  import PiratexWeb.Components.ActivityFeedComponent
  import PiratexWeb.Components.HistoryComponent
  import PiratexWeb.Components.PiratexComponents
  import PiratexWeb.Components.TeamsComponent
  import PiratexWeb.Components.HotkeysComponent
  import PiratexWeb.Components.ChallengeComponent
  import PiratexWeb.Components.WordStealComponent

  attr :game_state, :map, required: true
  attr :watch_only, :boolean, default: false
  attr :my_name, :string, default: ""
  attr :challengeable_history, :list, required: true
  attr :zen_mode, :boolean, default: false
  attr :challenge_timeout_ms, :integer, required: true
  attr :chat_form, :any, default: nil
  attr :max_chat_message_length, :integer, required: true
  attr :visible_word_steal, :any, default: nil
  attr :show_teams_modal, :boolean, default: false
  attr :my_team_id, :any, default: nil
  attr :show_hotkeys_modal, :boolean, default: false
  # player-only attrs (used when watch_only is false)
  attr :is_turn, :boolean, default: false
  attr :word_form, :any, default: nil
  attr :min_word_length, :integer, default: 3
  attr :auto_flip, :boolean, default: false
  attr :turn_timeout_ms, :integer, default: 60_000

  def playing(assigns) do
    ~H"""
    <% challenge_open? = ChallengeService.open_challenge?(@game_state) %>
    <div id="game_wrapper" class="flex flex-col" phx-hook="Hotkeys">
      <span id="sound_player" phx-hook="SoundPlayer" class="hidden"></span>
      <%!--
        Layout track. On mobile (<md) it is `position: fixed` filling the viewport
        below the header, with two full-viewport panes the user swipes between. On
        desktop it becomes the existing two-column grid; the pane <section>s
        collapse via `md:contents` so their children land directly in the grid.
      --%>
      <div
        id="layout_track"
        phx-hook="MobilePanes"
        data-challenge-open={if challenge_open?, do: "true", else: "false"}
        class="mobile-pane-track flex snap-x snap-mandatory overflow-x-auto overscroll-x-contain no-scrollbar md:static md:grid md:gap-6 md:grid-cols-[minmax(0,1fr)_260px] md:items-start md:gap-x-8 md:gap-y-8 md:overflow-visible md:overscroll-auto md:snap-none"
      >
        <%!-- Pane 1: primary play surface (tiles, action area, team words) --%>
        <section
          data-pane="primary"
          class={[
            "mobile-pane relative flex h-full shrink-0 basis-full flex-col gap-6 overflow-x-hidden overscroll-contain px-4 pt-4 pb-16 snap-start snap-always md:contents",
            if(challenge_open?, do: "overflow-y-hidden", else: "overflow-y-auto")
          ]}
        >
          <div class="min-w-0 md:col-start-1 md:row-start-1">
            <.center center={@game_state.center} />
          </div>

          <div :if={not @watch_only} class="w-full md:col-start-2 md:row-start-1">
            <.player_action_area
              my_name={@my_name}
              game_state={@game_state}
              word_form={@word_form}
              min_word_length={@min_word_length}
              paused={challenge_open?}
              auto_flip={@auto_flip}
              is_turn={@is_turn}
              turn_timeout_ms={@turn_timeout_ms}
              active_player_count={@game_state.active_player_count}
            />
          </div>

          <%= if @zen_mode do %>
            <div class="md:col-start-1 md:row-start-2">
              <.zen_mode game_state={@game_state} />
            </div>
          <% else %>
            <div class="md:col-start-1 md:row-start-2">
              <div class="flex flex-wrap gap-4">
                <%= for team <- @game_state.teams do %>
                  <.team_word_area
                    team={team}
                    has_active_players={team_has_active_players?(@game_state, team.id)}
                  />
                <% end %>
              </div>
            </div>
          <% end %>

          <%!--
            Challenge modal lives inside pane 1 so the user can swipe to pane 2 and
            access chat while a challenge is open. On mobile it positions absolutely
            within pane 1; on desktop it switches to fixed-viewport (pane 1's
            md:contents removes its box, so absolute would have no anchor anyway).
          --%>
          <.challenge_panel
            :if={challenge_open?}
            challenge={Enum.at(@game_state.challenges, 0)}
            player_name={@my_name}
            watch_only={@watch_only}
            challenge_timeout_ms={@challenge_timeout_ms}
          />
        </section>

        <%!-- Pane 2: history + chat/activity feed --%>
        <section
          :if={not @zen_mode}
          data-pane="feed"
          class="mobile-pane flex h-full shrink-0 basis-full flex-col overflow-hidden overscroll-contain px-4 pt-4 pb-[calc(env(safe-area-inset-bottom,0px)+4rem)] snap-start snap-always md:contents md:pb-0"
        >
          <div class="flex min-h-0 w-full flex-1 flex-col md:col-start-2 md:row-start-2">
            <.history
              watch_only={@watch_only}
              challengeable_history={@challengeable_history}
              paused={challenge_open?}
            />
            <.activity_panel
              activity_feed={@game_state.activity_feed}
              watch_only={@watch_only}
              my_name={@my_name}
              chat_form={@chat_form}
              max_chat_message_length={@max_chat_message_length}
            />
          </div>
        </section>
      </div>

      <%!--
        Pane indicator dots — fixed at the bottom of the viewport on mobile so they
        are always reachable as a tap fallback if the user can't or won't swipe.
      --%>
      <%!--
        phx-update="ignore" prevents morphdom from resetting the dot classes
        on every LiveView patch. Without it, every chat message / state update
        snaps the active class back to whatever the server-rendered HTML says,
        making the dot desync from the actual visible pane.
      --%>
      <div
        :if={not @zen_mode}
        id="mobile_pane_dots"
        phx-update="ignore"
        class="mobile-pane-dots fixed inset-x-0 bottom-3 z-30 flex justify-center gap-3 md:hidden"
      >
        <button
          type="button"
          data-pane-dot="primary"
          class="mobile-pane-dot active"
          aria-label="Show play surface"
        ></button>
        <button
          type="button"
          data-pane-dot="feed"
          class="mobile-pane-dot"
          aria-label="Show history and chat"
        ></button>
      </div>
    </div>

    <.render_modal
      visible_word_steal={@visible_word_steal}
      game_state={@game_state}
      show_teams_modal={@show_teams_modal}
      my_team_id={@my_team_id}
      show_hotkeys_modal={@show_hotkeys_modal}
    />
    """
  end

  attr :center, :list, required: true

  defp center(assigns) do
    ~H"""
    <%!-- Desktop view --%>
    <div
      id="board_center"
      class="flex flex-wrap content-start gap-1 sm:gap-2 w-full max-h-40 md:h-40 overflow-y-auto overscroll-contain no-scrollbar rounded-md p-4 pt-0"
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
  attr :has_active_players, :boolean, required: true

  defp team_word_area(assigns) do
    ~H"""
    <%= if @team.words != [] do %>
      <%!-- Desktop view --%>
      <div
        id={"board_player_#{@team.name}"}
        class="team-word-area hidden sm:flex flex-col min-w-48 rounded-md border-2 min-h-48"
        style="border-color: var(--theme-border);"
      >
        <button phx-click="toggle_teams_modal" class="team-name-button">
          <div
            class="w-full px-auto text-center border-b-2"
            style="border-color: var(--theme-border);"
          >
            {@team.name}
          </div>
        </button>
        <div class="flex flex-col h-full mx-2 mb-2 pb-1 overflow-x-auto overscroll-contain no-scrollbar">
          <%= if @team.words == [] and !@has_active_players do %>
            <div class="mt-2 text-sm opacity-75">No active players</div>
          <% else %>
            <%= for word <- @team.words do %>
              <div class="mt-2">
                <.word_in_play word={word} abbrev={0} />
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
      <%!-- Mobile view --%>
      <div
        class="team-word-area flex flex-col sm:hidden border-2 rounded-md"
        style="border-color: var(--theme-border);"
      >
        <button phx-click="toggle_teams_modal" class="team-name-button">
          <div
            class="w-full px-auto text-center border-b-2"
            style="border-color: var(--theme-border);"
          >
            {@team.name}
          </div>
        </button>
        <div class="flex flex-col mx-2 mb-2 pb-1 overflow-x-auto overscroll-contain no-scrollbar">
          <%= if @team.words == [] and !@has_active_players do %>
            <div class="mt-1 text-sm opacity-75">No active players</div>
          <% else %>
            <%= for word <- @team.words do %>
              <div class="mt-1">
                <.word_in_play word={word} abbrev={0} />
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  def render_modal(assigns) do
    ~H"""
    <%= cond do %>
      <% @visible_word_steal != nil -> %>
        <.ps_modal title="word steal">
          <.word_steal
            players={@game_state.players}
            teams={@game_state.teams}
            word_steal={@visible_word_steal}
          />
        </.ps_modal>
      <% @show_teams_modal -> %>
        <.ps_modal title="teams">
          <.teams
            teams={@game_state.teams}
            players_teams={@game_state.players_teams}
            my_team_id={@my_team_id}
          />
        </.ps_modal>
      <% @show_hotkeys_modal -> %>
        <.ps_modal title="hotkeys">
          <.hotkeys_modal />
        </.ps_modal>
      <% true -> %>
    <% end %>
    """
  end

  attr :challenge, :map, required: true
  attr :player_name, :string, required: true
  attr :watch_only, :boolean, default: false
  attr :challenge_timeout_ms, :integer, required: true

  defp challenge_panel(assigns) do
    # Outer is a full-screen flex centerer with pointer-events: none so clicks
    # outside the modal box pass through to underlying chat/etc. Inner box has
    # pointer-events: auto and a max-width so it stays inside the viewport on
    # narrow screens. Inline pointer-events styles guard against any class
    # specificity issue in case Tailwind utility order is overridden.
    ~H"""
    <div
      id="challenge_panel"
      class="absolute inset-0 z-[60] flex items-start justify-center pt-[15vh] md:fixed md:items-center md:pt-0"
      style="pointer-events: none;"
    >
      <div
        class="mx-4 max-w-[calc(100vw-2rem)] p-4 rounded-lg shadow-xl md:mx-0 md:p-6"
        style="pointer-events: auto; background-color: var(--theme-modal-bg); border: 2px solid var(--theme-modal-border);"
      >
        <div class="flex flex-col gap-4 px-2 py-2 md:px-4">
          <div class="mx-auto mb-4">
            <.tile_word word="Challenge" class="flex-wrap justify-center" />
          </div>
          <.challenge
            challenge={@challenge}
            player_name={@player_name}
            watch_only={@watch_only}
            challenge_timeout_ms={@challenge_timeout_ms}
          />
        </div>
      </div>
    </div>
    """
  end

  defp player_action_area(assigns) do
    # TODO: maybe make the text input and submit a component with merged borders.
    # NOTE: hotkeys.js is listening for Enter key presses to focus on the word input text box based on the id.
    ~H"""
    <div id="actions_area" class="flex w-full flex-col">
      <div class="flex flex-col xs:flex-row sm:flex-col gap-4">
        <.form
          for={@word_form}
          phx-submit={JS.push("submit_new_word") |> JS.dispatch("reset-input", to: "#new_word_input")}
          phx-change="word_change"
          class="flex w-full min-w-0 flex-row"
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
            phx-debounce="blur"
          />
          <.ps_button
            type="submit"
            class="hidden xs:block rounded-l-none border-l-0 w-full max-w-24"
            disabled={@paused}
          >
            SUBMIT
          </.ps_button>
        </.form>

        <div class="flex flex-row gap-2 justify-center items-center">
          <%!-- Flip / End game button --%>
          <%= if @game_state.letter_pool_count == 0 and !voted_to_end_game?(@my_name, @game_state) do %>
            <.ps_button
              class="w-full mx-auto"
              phx-click="end_game_vote"
              phx_disable_with="Ending Game..."
            >
              END GAME
            </.ps_button>
          <% else %>
            <.ps_button
              class="w-full mx-auto"
              phx-click="flip_letter"
              phx_disable_with="Flipping..."
              disabled={!@is_turn || @paused}
            >
              <span class="flex items-center justify-center gap-2">
                <%= cond do %>
                  <% @game_state.letter_pool_count == 0 -> %>
                    Game Over
                  <% @is_turn && @auto_flip -> %>
                    [AUTO]
                  <% @is_turn -> %>
                    FLIP
                  <% true -> %>
                    <span class="hidden md:inline">
                      {truncate_player_name(Enum.at(@game_state.players, @game_state.turn).name)}'s turn
                    </span>
                    <span class="inline md:hidden">
                      FLIP
                    </span>
                <% end %>
                <.countdown_timer
                  :if={@active_player_count > 1 and @game_state.letter_pool_count > 0}
                  id="turn-timer"
                  duration_ms={@turn_timeout_ms}
                  epoch={@game_state.total_turn}
                  paused={@paused}
                />
              </span>
            </.ps_button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def zen_mode(assigns) do
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

  defp voted_to_end_game?(player_name, game_state) do
    Map.has_key?(game_state.end_game_votes, player_name)
  end

  defp truncate_player_name(player_name) do
    if String.length(player_name) > 10 do
      String.slice(player_name, 0, 7) <> "..."
    else
      player_name
    end
  end

  defp team_has_active_players?(game_state, team_id) do
    Enum.any?(game_state.players, fn player ->
      player.team_id == team_id and player.status == :playing
    end)
  end
end

defmodule PiratexWeb.Components.Playing do
  use Phoenix.Component

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
      <div class="grid gap-6 md:grid-cols-[minmax(0,1fr)_260px] md:items-start md:gap-x-8 md:gap-y-8">
        <div
          id="main_playing_area"
          class="contents md:relative md:col-start-1 md:row-span-2 md:flex md:min-w-0 md:flex-col md:gap-8"
        >
          <div id="board_center_and_actions" class="order-1 min-w-0">
            <.center center={@game_state.center} />
          </div>

          <.challenge_panel
            :if={challenge_open?}
            challenge={Enum.at(@game_state.challenges, 0)}
            player_name={@my_name}
            watch_only={@watch_only}
            challenge_timeout_ms={@challenge_timeout_ms}
          />

          <%= if @zen_mode do %>
            <div class="order-4">
              <.zen_mode game_state={@game_state} />
            </div>
          <% else %>
            <div class="order-4">
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
        </div>

        <div :if={not @watch_only} class="order-2 w-full md:col-start-2 md:row-start-1">
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

        <%= if not @zen_mode do %>
          <div class="order-5 flex w-full flex-col md:col-start-2 md:row-start-2">
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
        <% end %>
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
    ~H"""
    <div
      id="challenge_panel"
      class="order-3 mt-6 w-full md:absolute md:inset-0 md:z-20 md:mt-0 md:flex md:h-full md:items-start md:justify-center md:px-4 md:pt-6 md:pb-4"
    >
      <div class="hidden md:block absolute inset-0 backdrop-blur-sm"></div>
      <div
        class="relative w-full max-w-md rounded-lg border-2 px-6 py-8 shadow-xl"
        style="border-color: var(--theme-modal-border); background-color: var(--theme-modal-bg); color: var(--theme-text);"
      >
        <div class="mb-4 flex justify-center">
          <.tile_word word="Challenge" />
        </div>
        <.challenge
          challenge={@challenge}
          player_name={@player_name}
          watch_only={@watch_only}
          challenge_timeout_ms={@challenge_timeout_ms}
        />
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
          phx-submit="submit_new_word"
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
            phx-debounce="300"
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

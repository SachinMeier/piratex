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
  attr :my_turn_idx, :integer, required: true
  attr :word_value, :string, required: true
  attr :watch_only, :boolean, default: false
  attr :is_turn, :boolean, required: true
  attr :my_name, :string, required: true

  def playing(assigns) do
    ~H"""
    <div id="game_wrapper" class="flex flex-col" phx-hook="Hotkeys">
      <span id="sound_player" phx-hook="SoundPlayer" class="hidden"></span>
      <div id="board_center_and_actions" class="flex flex-col sm:flex-row gap-4 md:gap-8">
        <.center center={@game_state.center} />

        <.player_action_area
          :if={not @watch_only}
          my_name={@my_name}
          game_state={@game_state}
          word_form={@word_form}
          min_word_length={@min_word_length}
          speech_recording={@speech_recording}
          paused={ChallengeService.open_challenge?(@game_state)}
          auto_flip={@auto_flip}
          is_turn={@is_turn}
          turn_timeout_ms={@turn_timeout_ms}
          active_player_count={@game_state.active_player_count}
        />
      </div>

      <.challenge_panel
        :if={ChallengeService.open_challenge?(@game_state)}
        challenge={Enum.at(@game_state.challenges, 0)}
        player_name={@my_name}
        watch_only={@watch_only}
        challenge_timeout_ms={@challenge_timeout_ms}
      />

      <%= if @zen_mode do %>
        <.zen_mode game_state={@game_state} />
      <% else %>
        <div class="mt-8 flex flex-col gap-6 md:flex-row md:items-start md:justify-between">
          <div class="flex flex-wrap gap-4">
            <%= for team <- @game_state.teams do %>
              <.team_word_area
                team={team}
                has_active_players={team_has_active_players?(@game_state, team.id)}
              />
            <% end %>
          </div>
          <div class="flex w-full flex-col md:w-auto">
            <.history
              watch_only={@watch_only}
              game_state={@game_state}
              paused={ChallengeService.open_challenge?(@game_state)}
            />
            <.activity_panel
              activity_feed={@game_state.activity_feed}
              watch_only={@watch_only}
              my_name={@my_name}
              chat_form={@chat_form}
              max_chat_message_length={@max_chat_message_length}
            />
          </div>
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
  attr :has_active_players, :boolean, required: true

  defp team_word_area(assigns) do
    ~H"""
    <%= if @team.words != [] or !@has_active_players do %>
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
      class="mt-6 w-full max-w-2xl self-center rounded-lg border-2 px-4 py-4 shadow-xl"
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
            <.speech_recognition_button paused={@paused} speech_recording={@speech_recording} />

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

  attr :paused, :boolean, required: true
  attr :speech_recording, :boolean, required: true

  defp speech_recognition_button(assigns) do
    ~H"""
    <.ps_button
      phx-click="toggle_speech_recognition"
      disabled={@paused}
      class={"max-w-36  #{if @speech_recording, do: "recording", else: ""}"}
    >
      <%= if @speech_recording do %>
        <span class="flex items-center justify-center gap-2">
          <span class="recording-dot"></span> Listening...
        </span>
      <% else %>
        <span class="flex items-center justify-center gap-2">
          🎤
        </span>
      <% end %>
    </.ps_button>
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

defmodule PiratexWeb.Components.Playing do
  use Phoenix.Component

  alias Piratex.ChallengeService

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

  def playing(assigns) do
    ~H"""
    <div id="game_wrapper" class="flex flex-col" phx-hook="Hotkeys">
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
          <.history watch_only={@watch_only} game_state={@game_state} paused={ChallengeService.open_challenge?(@game_state)} />
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

  def render_modal(assigns) do
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

        <div class="flex flex-row gap-2 justify-center">
          <.speech_recognition_button paused={@paused} speech_recording={@speech_recording} />
          <%#-- Flip / End game button --%>
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
              disabled={(!@is_turn) || @paused}
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
                    {Enum.at(@game_state.players, @game_state.turn).name}'s turn
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
    """
  end

  defp voted_to_end_game?(player_name, game_state) do
    Map.has_key?(game_state.end_game_votes, player_name)
  end

end

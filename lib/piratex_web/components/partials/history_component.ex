defmodule PiratexWeb.Components.HistoryComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  alias Piratex.Helpers
  alias Piratex.ChallengeService

  attr :game_state, :map, required: true
  attr :paused, :boolean, required: true
  attr :watch_only, :boolean, default: false

  def history(assigns) do
    ~H"""
    <div class="flex flex-col px-4 mt-4 md:mt-0 md:pr-0">
      <%= if @game_state.history != [] do %>
        <div class="mb-4 mx-auto md:mx-0">
          <.tile_word word="History" />
        </div>
      <% end %>
      <%= for %{thief_word: thief_word} = word_steal <- Enum.take(@game_state.history, 3) do %>
        <div class="flex flex-row justify-between mt-2">
          <.word_in_play word={thief_word} abbrev={5} />

          <.challenge_word_button
            :if={not @watch_only and
              Helpers.word_in_play?(@game_state, thief_word) and
                !ChallengeService.word_already_challenged?(@game_state, word_steal)
            }
            word={thief_word}
            paused={@paused}
          />
        </div>
      <% end %>
    </div>
    """
  end

  defp challenge_word_button(assigns) do
    ~H"""
    <.link href="#" phx-click="challenge_word" phx-value-word={@word}>
      <.tile letter="X" />
    </.link>
    """
  end
end

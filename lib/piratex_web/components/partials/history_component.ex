defmodule PiratexWeb.Components.HistoryComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  attr :challengeable_history, :list, required: true
  attr :paused, :boolean, required: true
  attr :watch_only, :boolean, default: false

  def history(assigns) do
    ~H"""
    <div id="history_panel" class="mt-4 flex w-full flex-col md:mt-0 md:min-h-[11rem]">
      <div class="mx-auto mb-4 md:mx-0">
        <.tile_word word="History" />
      </div>
      <%= for {%{thief_word: thief_word}, challengeable} <- @challengeable_history do %>
        <div class="mt-2 flex w-full items-center pr-2">
          <div class="min-w-0 flex-1">
            <.word_in_play word={thief_word} abbrev={5} />
          </div>

          <div class="ml-auto shrink-0">
            <.challenge_word_button
              :if={not @watch_only and challengeable}
              word={thief_word}
              paused={@paused}
            />
          </div>
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

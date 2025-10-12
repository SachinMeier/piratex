defmodule PiratexWeb.Components.SpeechConfirmationComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  attr :recognition_results, :list, required: true
  attr :min_word_length, :integer, required: true

  def speech_confirmation(assigns) do
    ~H"""
    <%= if @recognition_results != [] do %>
      <div class="flex flex-col gap-6">
        <div class="text-center">
          <h3 class="text-lg font-semibold mb-2">Did we hear you correctly?</h3>
          <p class="text-sm text-gray-600 dark:text-gray-400">Choose the correct word or edit it manually</p>
        </div>

        <!-- Primary recognized word -->
        <div class="flex flex-col items-center gap-2">
          <div class="text-sm font-medium">Recognized:</div>
          <div class="flex justify-center">
            <.tile_word word={hd(@recognition_results)["transcript"]} size="lg" />
          </div>
        </div>

        <!-- Alternative options (if available) -->
        <%= if length(@recognition_results) > 1 do %>
          <div class="flex flex-col gap-2">
            <div class="text-sm font-medium">Other options:</div>
            <div class="flex flex-wrap gap-2 justify-center">
              <%= for {result, index} <- Enum.with_index(@recognition_results) do %>
                <%= if index > 0 do %>
                  <button
                    phx-click="select_speech_alternative"
                    phx-value-word={result["transcript"]}
                    class="px-3 py-2 border-2 border-gray-300 dark:border-gray-600 rounded-md hover:border-black dark:hover:border-white transition-colors"
                  >
                    <.tile_word word={result["transcript"]} size="sm" />
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Manual editing -->
        <div class="flex flex-col gap-2">
          <div class="text-sm font-medium">Or edit manually:</div>
          <form phx-submit="submit_speech_word" class="flex flex-row gap-2">
            <.ps_text_input
              id="speech_word_edit"
              name="word"
              field={:word}
              value={hd(@recognition_results)["transcript"]}
              placeholder="Edit the word"
              class="flex-1"
            />
            <.ps_button type="submit" class="px-4">
              Submit
            </.ps_button>
          </form>
        </div>

        <!-- Action buttons -->
        <.ps_button phx-click="cancel_speech" class="px-4">
          Cancel
        </.ps_button>
      </div>
    <% else %>
      <div class="flex flex-col gap-2">
        <div class="text-center">
          <h3 class="text-lg font-semibold mb-2">No word was recognized</h3>
          <.ps_button phx-click="cancel_speech" class="px-4">
            Cancel
          </.ps_button>
        </div>
      </div>
    <% end %>
    """
  end
end

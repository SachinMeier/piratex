defmodule PiratexWeb.Components.ChallengeComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  attr :challenge, :map, required: true
  attr :player_name, :string, required: true
  attr :watch_only, :boolean, default: false
  attr :challenge_timeout_ms, :integer, required: true

  def challenge(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <div class="flex flex-col items-center gap-2 text-center">
        <%= if @challenge.word_steal.victim_word do %>
          <div class="flex flex-col items-center gap-2 md:flex-row">
            <span>Old Word</span>
            <.tile_word word={@challenge.word_steal.victim_word} />
            <span>New Word</span>
            <.tile_word word={@challenge.word_steal.thief_word} />
          </div>
        <% else %>
          <div class="flex flex-col items-center gap-2">
            <span>Word Under Challenge</span>
            <.tile_word word={@challenge.word_steal.thief_word} />
          </div>
        <% end %>
      </div>

      <%= cond do %>
        <% @watch_only -> %>
          <div class="flex flex-col items-center gap-2 text-center">
            <div>Challenge in progress...</div>
            <.countdown_timer
              id={"challenge-timer-#{@challenge.id}"}
              duration_ms={@challenge_timeout_ms}
              epoch={@challenge.id}
              paused={false}
            />
          </div>
        <% has_voted?(@challenge, @player_name) -> %>
          <div class="flex flex-col items-center gap-2 text-center">
            <div>Waiting for other players to vote...</div>
            <.countdown_timer
              id={"challenge-timer-#{@challenge.id}"}
              duration_ms={@challenge_timeout_ms}
              epoch={@challenge.id}
              paused={false}
            />
          </div>
        <% true -> %>
          <div class="flex w-full flex-col items-center gap-3 md:flex-row md:justify-around">
            <.ps_button phx_click="accept_steal" phx-value-challenge_id={@challenge.id}>
              VALID (2)
            </.ps_button>
            <.countdown_timer
              id={"challenge-timer-#{@challenge.id}"}
              duration_ms={@challenge_timeout_ms}
              epoch={@challenge.id}
              paused={false}
            />
            <.ps_button phx_click="reject_steal" phx-value-challenge_id={@challenge.id}>
              INVALID (7)
            </.ps_button>
          </div>
      <% end %>
    </div>
    """
  end

  defp has_voted?(challenge, player_name) do
    Map.has_key?(challenge.votes, player_name)
  end
end

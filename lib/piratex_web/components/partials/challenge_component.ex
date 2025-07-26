defmodule PiratexWeb.Components.ChallengeComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  def challenge(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <%= if @challenge.word_steal.victim_word do %>
        Old Word: <.tile_word word={@challenge.word_steal.victim_word} /> New Word:
      <% end %>
      <.tile_word word={@challenge.word_steal.thief_word} />
    </div>
    <%= if has_voted?(@challenge, @player_name) do %>
      Waiting for other players to vote...
    <% else %>
      <div class="flex flex-row w-full justify-around">
        <.ps_button phx_click="accept_steal" phx-value-challenge_id={@challenge.id}>
          VALID
        </.ps_button>
        <.ps_button phx_click="reject_steal" phx-value-challenge_id={@challenge.id}>
          INVALID
        </.ps_button>
      </div>
    <% end %>
    """
  end

  defp has_voted?(challenge, player_name) do
    Map.has_key?(challenge.votes, player_name)
  end
end

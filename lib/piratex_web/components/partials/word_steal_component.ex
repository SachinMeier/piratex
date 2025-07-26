defmodule PiratexWeb.Components.WordStealComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  def word_steal(assigns) do
    ~H"""
    <div class="flex flex-col gap-2">
      <div class="flex flex-row gap-2">
        Thief: <%= thief_name(@players, @word_steal) %> (<%= thief_team_name(@teams, @word_steal) %>)
      </div>
      <%= if @word_steal.victim_word do %>
        Old Word: <.tile_word word={@word_steal.victim_word} /> New Word:
      <% else %>
        Word:
      <% end %>
      <.tile_word word={@word_steal.thief_word} />
      <div class="mt-4 mx-auto">
        <.ps_button phx-click="hide_word_steal">
          DONE
        </.ps_button>
      </div>
    </div>
    """
  end

  defp thief_name(players, word_steal) do
    Enum.at(players, word_steal.thief_player_idx).name
  end

  defp thief_team_name(teams, word_steal) do
    Enum.at(teams, word_steal.thief_team_idx).name
  end
end

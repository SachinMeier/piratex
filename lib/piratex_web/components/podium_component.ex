defmodule PiratexWeb.Components.PodiumComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  attr :ranked_teams, :list, required: true
  attr :team_ct, :integer, required: true
  attr :players, :list, required: true

  def podium(assigns) do
    ~H"""
    <div class="hidden lg:grid lg:grid-cols-3 gap-2">
      <div class="my-2 col-1 pt-16">
        <%= if @team_ct > 2 do %>
          <.podium_team team={Enum.at(@ranked_teams, 2) |> elem(1)} players={@players} rank={Enum.at(@ranked_teams, 2) |> elem(0)} podium={true} />
        <% else %>
          &nbsp;
        <% end %>
      </div>
      <div class="my-2 col-2">
        <.podium_team team={Enum.at(@ranked_teams, 0) |> elem(1)} players={@players} rank={Enum.at(@ranked_teams, 0) |> elem(0)} podium={true} />
      </div>
      <div class={"my-2 col-3 pt-8"}>
        <%= if @team_ct > 1 do %>
          <.podium_team team={Enum.at(@ranked_teams, 1) |> elem(1)} players={@players} rank={Enum.at(@ranked_teams, 1) |> elem(0)} podium={true} />
        <% end %>
      </div>
      <%= for {{rank, team}, idx} <- Enum.drop(Enum.with_index(@ranked_teams), min(@team_ct, 3)) do %>
        <div class={"my-2 col-#{idx+1}"}>
          <.podium_team team={team} players={@players} rank={rank} podium={false} />
        </div>
      <% end %>
    </div>
    <%!-- Mobile --%>
    <div class="flex flex-col gap-2 lg:hidden">
      <%= for {rank, team} <- @ranked_teams do %>
        <div class={"my-2"}>
          <.podium_team team={team} players={@players} rank={rank} podium={false} />
        </div>
      <% end %>
    </div>
    """
  end

  attr :team, :map, required: true
  attr :rank, :integer, required: true
  attr :podium, :boolean, default: false
  attr :players, :list, required: true

  defp podium_team(assigns) do
    ~H"""
      <div
        id={"podium_team_#{@team.name}"}
        class="flex flex-col min-w-48 rounded-md border-2 border-black dark:border-white min-h-48"
      >
        <div class="w-full px-auto text-center border-b-2 border-black dark:border-white">
          {@rank}. {@team.name} ({@team.score})
          <div class="flex flex-col gap-2 mx-auto">
            <% team_id = @team.id %>
            <%= for %{team_id: ^team_id, name: player_name} <- @players do %>
                <%= player_name %>
            <% end %>
          </div>
        </div>
        <div class="flex flex-col mx-2 mb-2 max-w-[400px] overflow-x-auto">
          <%= for word <- Enum.sort_by(@team.words, &String.length(&1), :desc) do %>
            <div class="mt-2">
              <.tile_word word={word} />
            </div>
          <% end %>
        </div>
      </div>
    """
  end
end

defmodule PiratexWeb.Components.TeamsComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  attr :teams, :list, required: true
  attr :players_teams, :map, required: true
  attr :my_team_id, :integer, required: true
  attr :watch_only, :boolean, default: false

  def teams(assigns) do
    ~H"""
    <div
      class="flex flex-col sm:flex-row flex-wrap justify-around gap-4"
      phx-click-away="toggle_teams_modal"
    >
      <%= for team <- @teams do %>
        <.team_roster_area
          team={team}
          players_teams={@players_teams}
          is_my_team={team.id == @my_team_id}
        />
      <% end %>
    </div>

    <div class="mx-auto mt-4">
      <.ps_button phx-click="hide_modal">
        DONE
      </.ps_button>
    </div>
    """
  end

  attr :teams, :list, required: true
  attr :my_team_id, :integer, required: true
  attr :players_teams, :map, required: true
  attr :watch_only, :boolean, default: false

  def team_selection(assigns) do
    ~H"""
    <div class="my-8">
      <div class="flex flex-col sm:flex-row justify-around gap-4">
        <%= for team <- @teams do %>
          <div class="my-4 mx-auto flex flex-col items-center gap-4">
            <.team_roster_area
              team={team}
              players_teams={@players_teams}
              is_my_team={team.id == @my_team_id}
            />

            <%= if not @watch_only do %>
              <div class="flex sm:hidden">
                <%= if team.id != @my_team_id do %>
                  <.join_team_form team_id={team.id} />
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if not @watch_only do %>
        <div class="flex-row hidden sm:flex justify-around gap-4">
          <%= for team <- @teams do %>
            <div class="flex min-w-48 justify-center">
              <%= if team.id != @my_team_id do %>
                <.join_team_form team_id={team.id} />
              <% else %>
                &nbsp;
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :team, :map, required: true
  attr :players_teams, :map, required: true
  attr :is_my_team, :boolean, required: true

  defp team_roster_area(assigns) do
    ~H"""
    <div
      class="team-word-area flex min-h-40 min-w-48 flex-col rounded-md border-2"
      style="border-color: var(--theme-border); color: var(--theme-text);"
    >
      <div
        class="team-name-button w-full border-b-2 px-4 py-1 text-center font-semibold"
        style="border-color: var(--theme-border);"
      >
        {if @is_my_team, do: "• "}{@team.name}
      </div>

      <ol class="mx-8 my-4 list-decimal space-y-2">
        <%= for {player_name, team_id} when team_id == @team.id <- @players_teams do %>
          <li>{player_name}</li>
        <% end %>
      </ol>
    </div>
    """
  end

  attr :team_id, :integer, required: true

  defp join_team_form(assigns) do
    ~H"""
    <.form for={%{}} phx-submit="join_team" phx-value-team_id={@team_id}>
      <.ps_button type="submit">
        JOIN
      </.ps_button>
    </.form>
    """
  end

  attr :team, :map, required: true
  attr :is_my_team, :boolean, required: true

  def team_name(assigns) do
    ~H"""
    <div class="text-center">
      <span class="inline-block border-b-2" style="border-color: var(--theme-border);">
        {if @is_my_team, do: "• "}{@team.name}
      </span>
    </div>
    """
  end
end

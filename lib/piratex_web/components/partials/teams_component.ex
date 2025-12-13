defmodule PiratexWeb.Components.TeamsComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  attr :teams, :list, required: true
  attr :players_teams, :list, required: true
  attr :my_team_id, :integer, required: true
  attr :watch_only, :boolean, default: false

  def teams(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row flex-wrap justify-around gap-4" phx-click-away="toggle_teams_modal">
      <%= for team <- @teams do %>
        <div class="flex flex-col gap-2 mx-8">
          <.team_name team={team} is_my_team={team.id == @my_team_id} />
          <div class="flex flex-col gap-2 mx-auto">
            <%= for {player_name, player_team_id} <- @players_teams do %>
              <%= if player_team_id == team.id do %>
                <div>
                  <%= player_name %>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>

    <div class="mx-auto mt-4">
        <.ps_button phx-click="hide_teams_modal">
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
          <div class="my-4 mx-auto">
            <.team_name team={team} is_my_team={team.id == @my_team_id} />
            <div class="my-4 mx-auto">
              <ul class="list-decimal my-4">
                <%= for {player_name, team_id} when team_id == team.id <- @players_teams do %>
                  <li>{player_name}</li>
                <% end %>
              </ul>

              <%= if not @watch_only do %>
                <div class="flex sm:hidden">
                  <%= if team.id != @my_team_id do %>
                    <.join_team_form team_id={team.id} />
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <%= if not @watch_only do %>
        <div class="flex-row hidden sm:flex justify-around gap-4">
          <%= for team <- @teams do %>
            <div class="w-8">
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
    <div class="border-b-2 border-black dark:border-white">
      <%= if @is_my_team, do: "• " %><%= @team.name %>
    </div>
    """
  end
end

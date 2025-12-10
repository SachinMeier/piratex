defmodule PiratexWeb.Components.Waiting do
  use Phoenix.Component

  alias Piratex.Config

  import PiratexWeb.Components.PiratexComponents
  import PiratexWeb.Components.TeamsComponent

  attr :game_state, :map, required: true
  attr :watch_only, :boolean, default: false

  def waiting(assigns) do
    ~H"""
    <div class="flex flex-col mx-auto justify-around">
      <div class="mx-auto">
        <.tile_word word="teams" />
      </div>

      <.team_selection
        watch_only={@watch_only}
        teams={@game_state.teams}
        players_teams={@game_state.players_teams}
        my_team_id={@my_team_id} />

      <%= if not @watch_only do %>
        <.render_new_team_form
          :if={length(@game_state.teams) < Config.max_teams()}
          max_name_length={@max_name_length}
          valid_team_name={@valid_team_name}
        />

        <%= if not @watch_only do %>
          <div class="flex flex-col gap-y-4 mx-auto">
            <.ps_button phx_click="start_game" width="w-full">
            START
            </.ps_button>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :max_name_length, :integer, required: true
  attr :valid_team_name, :boolean, required: true

  defp render_new_team_form(assigns) do
    ~H"""
    <div class="mx-auto my-8">
      <.form
        for={%{}}
        phx-change="validate_new_team_name"
        phx-submit="create_team"
        class="flex flex-row mx-auto w-full"
      >
        <.ps_text_input
          id="team_name_input"
          name="team"
          field={:team}
          placeholder="Name"
          value=""
          maxlength={@max_name_length}
          class="rounded-r-none border-r-0"
        />
        <.ps_button type="submit" class="rounded-l-none" disabled={!@valid_team_name} disabled_style={false}>
          NEW TEAM
        </.ps_button>
      </.form>
    </div>
    """
  end
end

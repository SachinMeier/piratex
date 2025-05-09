defmodule PiratexWeb.Components.PodiumComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  attr :ranked_players, :list, required: true
  attr :player_ct, :integer, required: true

  def podium(assigns) do
    ~H"""
    <div class="hidden lg:grid lg:grid-cols-3 gap-2">
      <div class="my-2 col-1 pt-16">
        <%= if @player_ct > 2 do %>
          <.podium_player player={Enum.at(@ranked_players, 2) |> elem(1)} rank={Enum.at(@ranked_players, 2) |> elem(0)} podium={true} />
        <% else %>
          &nbsp;
        <% end %>
      </div>
      <div class="my-2 col-2">
        <.podium_player player={Enum.at(@ranked_players, 0) |> elem(1)} rank={Enum.at(@ranked_players, 0) |> elem(0)} podium={true} />
      </div>
      <div class={"my-2 col-3 pt-8"}>
        <%= if @player_ct > 1 do %>
          <.podium_player player={Enum.at(@ranked_players, 1) |> elem(1)} rank={Enum.at(@ranked_players, 1) |> elem(0)} podium={true} />
        <% end %>
      </div>
      <%= for {{rank, player}, idx} <- Enum.drop(Enum.with_index(@ranked_players), min(@player_ct, 3)) do %>
        <div class={"my-2 col-#{idx+1}"}>
          <.podium_player player={player} rank={rank} podium={false} />
        </div>
      <% end %>
    </div>
    <%!-- Mobile --%>
    <div class="flex flex-col gap-2 lg:hidden">
      <%= for {rank, player} <- @ranked_players do %>
        <div class={"my-2"}>
          <.podium_player player={player} rank={rank} podium={false} />
        </div>
      <% end %>
    </div>
    """
  end

  attr :player, :map, required: true
  attr :rank, :integer, required: true
  attr :podium, :boolean, default: false

  # <div class={if @podium and @rank <= 3, do: "pt-#{12 * (@rank-1)}", else: ""}>
  #
  defp podium_player(assigns) do
    ~H"""
      <div
        id={"podium_player_#{@player.name}"}
        class="flex flex-col min-w-48 rounded-md border-2 border-black dark:border-white min-h-48"
      >
        <div class="w-full px-auto text-center border-b-2 border-black dark:border-white">
          {@rank}. {@player.name} ({@player.score})
        </div>
        <div class="flex flex-col mx-2 mb-2 max-w-[400px] overflow-x-auto">
          <%= for word <- Enum.sort_by(@player.words, &String.length(&1), :desc) do %>
            <div class="mt-2">
              <.tile_word word={word} />
            </div>
          <% end %>
        </div>
      </div>
    """
  end
end

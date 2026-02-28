defmodule PiratexWeb.Live.Preview do
  use PiratexWeb, :live_view

  import PiratexWeb.Live.Helpers
  import PiratexWeb.Components.ScoreGraphComponent

  def mount(_, _session, socket) do
    timeline = %{
      0 => [
        {0, 0},
        {10, 2},
        {25, 6},
        {40, 10},
        {55, 14},
        {70, 20},
        {85, 26},
        {100, 30},
        {120, 35}
      ],
      1 => [{0, 0}, {15, 2}, {30, 5}, {50, 12}, {65, 16}, {80, 22}, {95, 27}, {110, 32}],
      2 => [{0, 0}, {20, 3}, {35, 7}, {45, 9}, {60, 13}, {75, 17}, {90, 21}, {105, 24}, {130, 28}]
    }

    teams = [
      %{name: "Pirates"},
      %{name: "Buccaneers"},
      %{name: "Corsairs"}
    ]

    socket
    |> assign(
      timeline: timeline,
      teams: teams,
      range: 144,
      max_score: 35
    )
    |> ok()
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-4">
      <.score_graph
        timeline={@timeline}
        teams={@teams}
        range={@range}
        max_score={@max_score}
        class="w-full"
      />
    </div>
    """
  end
end

defmodule PiratexWeb.Live.About do
  use PiratexWeb, :live_view

  import PiratexWeb.Live.Helpers
  import PiratexWeb.Components.PiratexComponents

  def mount(_params, _session, socket) do
    socket
    |> assign_seo_metadata()
    |> ok()
  end

  def assign_seo_metadata(socket) do
    title = "About | Pirate Scrabble"
    description = "About Pirate Scrabble"

    assign(socket, seo_metadata: %{
      og_title: title,
      og_description: description,
      twitter_title: title,
      twitter_description: description
    })
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 justify-center mt-4 px-8 mx-auto max-w-3xl">
      <.tile_word class="mx-auto mb-4" word="about" />
      <.render_game_info />

      <.render_how_to_play />

      <.render_game_origin />

      <.render_code_section />

      <div class="flex justify-center mt-4 mx-auto cursor-pointer ">
        <.ps_button to={~p"/"} type="button" class="cursor-pointer ">
          BACK
        </.ps_button>
      </div>
    </div>
    """
  end

  defp render_game_info(assigns) do
    ~H"""
    <div class="mb-4">
      <p class="text-lg mb-2">
        Pirate Scrabble is an online multiplayer word game where players compete to
        create and steal words using letter tiles.
      </p>
    </div>
    """
  end

  defp render_how_to_play(assigns) do
    ~H"""
    <.tile_word class="mx-auto my-4" word="how to play" />
    <ul class="list-disc ml-5">
      <%= for step <- how_to_play() do %>
        <li class="text-lg mb-1">{step}</li>
      <% end %>
    </ul>
    <div class="mx-auto mb-4">
      <.ps_button to={~p"/rules"}>
        RULES
      </.ps_button>
    </div>
    """
  end

  defp render_game_origin(assigns) do
    ~H"""
    <.tile_word class="mx-auto" word="origin" />
    <div class="mb-4">
      <p class="text-lg mb-2">
        My friend Nick taught me this game.
        I have met several people who know this game and likewise don't know the origin.
        GPT-5 insists that one "Tom Davy" is the creator.
      </p>
    </div>
    """
  end

  defp render_code_section(assigns) do
    ~H"""
    <.tile_word class="mx-auto" word="code" />
    <div class="mb-4">
      <p class="text-lg mb-2">
        The code is open source and available on GitHub. There are open PRs for additional cool features that are too intensive
        to add to the online version, since it uses free hosting.
      </p>
    </div>
    <.render_github_link />
    """
  end

  defp render_github_link(assigns) do
    ~H"""
    <div class="mb-4 mx-auto">
      <a href="https://github.com/SachinMeier/piratex" target="_blank" class="inline-flex items-center gap-2 hover:opacity-80 transition-opacity">
        <img src="/images/github-black.svg" alt="GitHub" class="h-8 w-8" style={"filter: brightness(0) invert(var(--theme-icon-filter, 0));"} />
        <span>View on GitHub</span>
      </a>
    </div>
    """
  end

  def how_to_play() do
    [
      "Create a new game or join an existing one",
      "Take turns flipping letters into the center",
      "Submit words you can make from the center letters",
      "Steal words from other players by adding letters to their words",
      "Score points based on word length and ownership",
      "Win by having the highest score when all letters are used"
    ]
  end
end

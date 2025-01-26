defmodule PiratexWeb.Live.RulesLive do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      overview: overview(),
      rules: rules(Piratex.Services.WordClaimService.min_word_length())
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center mt-4 px-8 mx-auto max-w-3xl">
      <.tile_word class="mx-auto mb-4" word="overview" />

      <.render_overview overview={@overview} />

      <.tile_word class="mx-auto my-4" word="rules" />

      <.render_rules rules={@rules} />

      <div class="flex justify-center mt-4 mx-auto cursor-pointer ">
        <.ps_button to={~p"/"} type="button" class="cursor-pointer ">
          BACK
        </.ps_button>
      </div>
    </div>
    """
  end

  def render_overview(assigns) do
    ~H"""
    <ul class="list-disc mb-2">
      <%= for o <- @overview do %>
        <li><%= o %></li>
      <% end %>
    </ul>
    """
  end

  def overview() do
    [
      "The object of the game is to make more and longer words than your opponents.",
      "Players take turns flipping letters into the center. When a player sees a word, they submit it and it is added to their area.",
      "Players create new words from the letters in the center. They also take words from other players (including themselves) by adding letters from the center to existing words.",
      "The player with the highest score after all letters have been flipped wins."
    ]
  end

  def render_rules(assigns) do
    ~H"""
    <ul class="list-decimal mb-2">
      <%= for section <- @rules do %>
        <div class="text-lg font-extrabold mt-2"><%= section.title %></div>
        <%= for rule <- section.rules do %>
          <li><%= rule %></li>
        <% end %>
      <% end %>
    </ul>
    """
  end

  def rules(min_word_length) do
    [
      %{
        title: "Word Creation",
        rules: [
          "All words must be at least #{min_word_length} letters long.",
          "Stealing a word requires using all of the letters in the existing words and at least one new letter from the center.",
          "The same word cannot be present more than once at a time.",
          "When a new word is created, it cannot share an English root word with the word from which it was created.",
          "If a new word violates the previous rule, a player should challenge the word and other players should vote to accept or reject the new word."
        ],
        },
      %{
        title: "Winning",
        rules: [
          "The game ends shortly after all letters have been flipped.",
        "The player with the highest score wins.",
        "A player's score is the number of letters in the words they own minus the number of words they own."
      ]
      }
    ]
  end

  def handle_event("back", _params, socket) do
    {:noreply, redirect(socket, to: "/")}
  end
end

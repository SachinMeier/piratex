defmodule PiratexWeb.Live.Rules do
  use PiratexWeb, :live_view

  import PiratexWeb.Live.Helpers
  import PiratexWeb.Components.PiratexComponents
  import PiratexWeb.Components.HotkeysComponent

  def mount(_params, _session, socket) do
    socket
     |> assign(
       flipping_title: true,
       overview: overview(),
       rules: rules(Piratex.Config.min_word_length())
     )
     |> assign_seo_metadata()
     |> ok()
  end

  def assign_seo_metadata(socket) do
    title = "Rules | Pirate Scrabble"
    description = "Rules for Pirate Scrabble"

    assign(socket, seo_metadata: %{
      og_title: title,
      og_description: description,
      twitter_title: title,
      twitter_description: description
    })
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center mt-4 px-8 mx-auto max-w-3xl">
      <.tile_word class="mx-auto mb-4" word="overview" />

      <.render_overview overview={@overview} />

      <.tile_word class="mx-auto my-4" word="rules" />

      <.render_rules rules={@rules} />

      <.tile_word class="mx-auto my-4" word="example" />

      <.example />

      <.tile_word class="mx-auto my-4" word="hotkeys" />

      <.hotkeys_modal click_away={false} />

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
        <li>{o}</li>
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
        <div class="text-lg font-extrabold mt-2">{section.title}</div>
        <%= for rule <- section.rules do %>
          <li>{rule}</li>
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
        ]
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

  def example(assigns) do
    ~H"""
    <div class="my-8">
      <div class="flex flex-col gap-4">
        <p>To start the game, players take turns clicking the "flip" button to flip a new letter into the "center".</p>

        <p>If a player sees a word made up of letters in the center, they type that word into the textbox and submit.</p>

        <p>If the following letters are in the center, a player can submit the word "cat".</p>

        <div class="flex flex-row gap-4">
          <.tile_word word="a" />
          <.tile_word word="c" />
          <.tile_word word="t" />
          <.icon name="hero-arrow-right-solid" class="h-8 w-8" />
          <.tile_word word="cat" />
        </div>

        <p>Now, that player will own the word "cat". However, if a <.tile letter="p"/> is flipped into the center, any player can submit the word "pact".</p>

        <div class="flex flex-row gap-4">
          <.tile_word word="cat" />
          <.icon name="hero-plus-solid" class="h-8 w-8" />
          <.tile_word word="p" />
          <.icon name="hero-arrow-right-solid" class="h-8 w-8" />
          <.tile_word word="pact" />
        </div>

        <p>The player who submitted "pact" steals the 3 letters from "cat" and the "p" from the center and now owns "pact".</p>

        <p>NOTE: due to rule #4, if an "s" had been flipped instead of a "p", the following steal would not be allowed:</p>

        <div class="flex flex-row gap-4">
          <p class="block my-auto">INVALID:</p>
          <.tile_word word="cat" />
          <.icon name="hero-plus-solid" class="h-8 w-8" />
          <.tile_word word="s" />
          <.icon name="hero-arrow-right-solid" class="h-8 w-8" />
          <.tile_word word="cats" />
        </div>

        <p>However, the word "acts" would be a valid steal from "cat", because they do not share an English root word.</p>

        <div class="flex flex-row gap-4">
          <p class="block my-auto">VALID:</p>
          <.tile_word word="cat" />
          <.icon name="hero-plus-solid" class="h-8 w-8" />
          <.tile_word word="s" />
          <.icon name="hero-arrow-right-solid" class="h-8 w-8" />
          <.tile_word word="acts" />
        </div>
      </div>
    </div>
    """
  end

  def handle_event("back", _params, socket) do
    socket
    |> redirect(to: "/")
    |> noreply()
  end
end

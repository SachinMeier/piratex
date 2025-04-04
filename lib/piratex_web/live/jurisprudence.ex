defmodule PiratexWeb.Live.JurisprudenceLive do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       jurisprudence_list: jurisprudence_list()
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col justify-center mt-4 px-8 mx-auto max-w-3xl">
      <.tile_word class="mx-auto mb-8" word="jurisprudence" />

      <div>
        <.tile_word class="mx-auto mb-4" word="dictionary" />

        The community has decided that Merriam Webster is the source of truth for word validity,
        assuming it meets the criteria below.

        <.tile_word class="mx-auto my-4" word="variants" />

        The community has decided that the following kinds of words are not allowed:
        <ul class="list-disc mb-2 pl-5">
          <li>Abbreviations</li>
          <li>Acronyms</li>
          <li>Scottish variants</li>
          <li>Proper nouns</li>
        </ul>

        <.tile_word class="mx-auto my-4" word="specific cases" />

        Below are a list of word steals that have been deliberated by the community:

        <%= for word_steal <- @jurisprudence_list do %>
          <div class="flex flex-col gap-2">
            <%= word_steal.old_word %> -> <%= word_steal.new_word %>: <%= word_steal.verdict %>. <%= word_steal.reason %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def jurisprudence_list() do

    [
      %{old_word: "tone", new_word: "atone", verdict: :valid, reason: "atone comes from the root \"at one\""},
      %{old_word: "one", new_word: "atone", verdict: :invalid, reason: "atone comes from the root \"at one\""},
      %{old_word: "genius", new_word: "ingenious", verdict: :valid, reason: "different root words"},

    ]
  end
end

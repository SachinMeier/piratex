defmodule PiratexWeb.Live.ExplorerLive do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  @impl true
  def mount(%{"word" => word}, _session, socket) do
    case validate_word(word) do
      {:ok, word} ->
        # TODO: make this async or paginated. For many words this is just too much.
        froms = Piratex.Services.Explorer.froms(word)
        tos = Piratex.Services.Explorer.tos(word)

        {:ok, assign(socket, word: word, valid_word: true, froms: froms, tos: tos)}
      {:error, _} ->
        {:ok, assign(socket, word: word, valid_word: false)}
    end
  end

  @impl true
  def render(%{valid_word: true} = assigns) do
    ~H"""
    <div>
      <.tile_word size="lg" word={@word} class="justify-center my-4" />
      <div class="grid grid-cols-2 gap-4">
        <div class="flex flex-col gap-y-4 ">
          <%= for from <- @froms do %>
            <.link href={~p"/explorer/#{from}"}>
              <.tile_word word={from} />
            </.link>
          <% end %>
        </div>
        <div class="flex flex-col gap-y-4 ">
          <%= for to <- @tos do %>
            <.link href={~p"/explorer/#{to}"}>
              <.tile_word word={to} />
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def render(%{valid_word: false} = assigns) do
    ~H"""
    <div>
      <.tile_word size="lg" word={"invalid word"} class="justify-center" />
    </div>
    """
  end

  defp validate_word(word) do
    with word <- String.trim(word),
         word <- String.downcase(word),
        true <- Piratex.Dictionary.is_word?(word),
         true <- String.length(word) > 2,
         true <- String.length(word) < 15,
         true <- Regex.match?(~r/\A[a-z]+\z/, word) do
      {:ok, word}
    else
      _ -> {:error, "Invalid word"}
    end
  end
end

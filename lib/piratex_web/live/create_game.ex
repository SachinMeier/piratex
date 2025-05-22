defmodule PiratexWeb.Live.CreateGame do
  use PiratexWeb, :live_view

  import PiratexWeb.Components.PiratexComponents

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 justify-center max-w-48 mx-auto">
      <.form for={%{}} action={~p"/game/new"} method="POST">
        <input type="hidden" name="letter_pool" value="bananagrams" />
        <.ps_button type="submit" class="text-left w-full">
          REGULAR GAME
        </.ps_button>
      </.form>
      <.form for={%{}} action={~p"/game/new"} method="POST">
        <input type="hidden" name="letter_pool" value="bananagrams_half" />
        <.ps_button type="submit" class="text-left w-full">
          MINI GAME
        </.ps_button>
      </.form>
    </div>
    """
  end
end

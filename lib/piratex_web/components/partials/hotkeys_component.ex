defmodule PiratexWeb.Components.HotkeysComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  def hotkeys_modal(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <.hotkey hotkey="␣" description="Flip" />
      <.hotkey hotkey="0" description="Toggle hotkey help" />
      <.hotkey hotkey="1" description="Challenge most recent word" />
      <.hotkey hotkey="3" description="Toggle teams list" />
      <.hotkey hotkey="6" description="Toggle auto-flip" />
      <.hotkey hotkey="8" description="Toggle zen mode" />
    </div>
    """
  end

  attr :hotkey, :string, required: true
  attr :description, :string, required: true

  defp hotkey(assigns) do
    ~H"""
    <div class="flex flex-row gap-2">
      <.tile_word word={@hotkey} />
      <div class="block my-auto">
        <%= @description %>
      </div>
    </div>
    """
  end
end

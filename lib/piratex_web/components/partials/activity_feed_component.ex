defmodule PiratexWeb.Components.ActivityFeedComponent do
  use Phoenix.Component

  import PiratexWeb.Components.PiratexComponents

  attr :activity_feed, :list, required: true
  attr :watch_only, :boolean, default: false
  attr :my_name, :string, default: ""
  attr :chat_form, :any, default: nil
  attr :max_chat_message_length, :integer, required: true

  def activity_panel(assigns) do
    ~H"""
    <div id="activity_panel" class="mt-6 flex w-full flex-col gap-3 md:min-w-[18rem] md:max-w-[18rem]">
      <div class="mx-auto md:mx-0">
        <.tile_word word="Chat" />
      </div>

      <div
        class="activity-feed-shell flex min-h-64 max-h-[24rem] flex-col overflow-hidden rounded-md border-2"
        style="border-color: var(--theme-border); background-color: transparent;"
      >
        <div
          id="activity_feed"
          phx-hook="AutoScrollFeed"
          class="min-h-0 flex-1 overflow-y-auto overscroll-contain px-3 py-3"
        >
          <%= if @activity_feed == [] do %>
            <div class="activity-feed-empty px-3 py-12 text-center italic opacity-70">
              Chat messages and game events will appear here.
            </div>
          <% else %>
            <div class="flex flex-col gap-2">
              <%= for entry <- @activity_feed do %>
                <.activity_entry entry={entry} my_name={@my_name} />
              <% end %>
            </div>
          <% end %>
        </div>

        <.form
          :if={not @watch_only}
          for={@chat_form}
          phx-submit="send_chat_message"
          phx-change="chat_change"
          class="border-t-2 p-2"
          style="border-color: var(--theme-border);"
        >
          <div class="flex items-stretch gap-2">
            <.ps_text_input
              id="chat_message_input"
              name="message"
              form={@chat_form}
              field={:message}
              autocomplete={false}
              placeholder="Talk to the table..."
              text_size="text-sm"
              class="w-full"
              max_width=""
              maxlength={@max_chat_message_length}
            />
            <.ps_button type="submit" class="shrink-0 px-3 py-2 text-sm">
              SEND
            </.ps_button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :entry, :map, required: true
  attr :my_name, :string, default: ""

  defp activity_entry(%{entry: %{type: :event}} = assigns) do
    ~H"""
    <div class="px-2 py-1 text-center text-sm italic opacity-70">
      {@entry.body}
    </div>
    """
  end

  defp activity_entry(assigns) do
    ~H"""
    <div class={"flex #{bubble_alignment(@entry, @my_name)}"}>
      <div
        class={"max-w-[82%] rounded-xl px-3 py-2 #{bubble_text_alignment(@entry, @my_name)}"}
        style="background-color: var(--theme-modal-bg); color: var(--theme-text); box-shadow: var(--theme-tile-shadow);"
      >
        <div class="mb-0.5 text-[9px] uppercase tracking-[0.18em] opacity-70">
          {sender_label(@entry, @my_name)}
        </div>
        <div class="text-sm leading-4">
          {@entry.body}
        </div>
      </div>
    </div>
    """
  end

  defp bubble_alignment(%{player_name: player_name}, my_name)
       when is_binary(my_name) and my_name != "" and player_name == my_name,
       do: "justify-end"

  defp bubble_alignment(_entry, _my_name), do: "justify-start"

  defp bubble_text_alignment(%{player_name: player_name}, my_name)
       when is_binary(my_name) and my_name != "" and player_name == my_name,
       do: "text-right"

  defp bubble_text_alignment(_entry, _my_name), do: "text-left"

  defp sender_label(%{player_name: player_name}, my_name)
       when is_binary(my_name) and my_name != "" and player_name == my_name,
       do: "You"

  defp sender_label(%{player_name: player_name}, _my_name), do: player_name
end

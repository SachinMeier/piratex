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
    <div id="activity_panel" class="mt-6 flex w-full flex-col">
      <div
        class="activity-feed-shell flex h-[40vh] max-h-[24rem] min-h-[12rem] w-full flex-col overflow-hidden rounded-md"
        style="background-color: transparent;"
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
          phx-debounce="300"
          class="w-full shrink-0 p-2"
        >
          <div class="flex w-full items-stretch gap-2">
            <.ps_text_input
              id="chat_message_input"
              name="message"
              form={@chat_form}
              field={:message}
              autocomplete={false}
              placeholder="Talk to the table..."
              text_size="text-sm"
              class="min-w-0 flex-1"
              max_width=""
              maxlength={@max_chat_message_length}
            />
            <.ps_button type="submit" width="w-20" class="shrink-0 text-sm">
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
        class="max-w-[82%] rounded-xl border-2 px-3 py-2 text-left"
        style="background-color: var(--theme-chat-bubble-bg, var(--theme-modal-bg)); border-color: var(--theme-chat-bubble-border, var(--theme-border)); color: var(--theme-text); box-shadow: var(--theme-chat-bubble-shadow);"
      >
        <div class="mb-0.5 text-[9px] uppercase tracking-[0.18em] opacity-70">
          {sender_label(@entry, @my_name)}
        </div>
        <div class="text-sm leading-4" style="hyphens: auto; overflow-wrap: anywhere;">
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

  defp sender_label(%{player_name: player_name}, my_name)
       when is_binary(my_name) and my_name != "" and player_name == my_name,
       do: "You"

  defp sender_label(%{player_name: player_name}, _my_name), do: player_name
end

defmodule PiratexWeb.Components.PiratexComponents do
  use Phoenix.Component

  use PiratexWeb, :verified_routes

  alias Phoenix.LiveView.JS
  import PiratexWeb.Gettext
  import PiratexWeb.CoreComponents

  attr :word, :string, required: true
  attr :size, :string, default: "md"
  attr :class, :string, default: ""

  def flipping_tile_word(assigns) do
    ~H"""
    <div class="flex flex-row">
      <%= for {letter, idx} <- Enum.with_index(String.graphemes(String.upcase(@word))) do %>
        <.flipping_tile letter={letter} idx={idx} id={"#{@word}-#{idx}"} />
      <% end %>
    </div>
    """
  end

  attr :letter, :string, required: true
  attr :id, :string, required: true
  attr :idx, :integer, required: true

  def flipping_tile(assigns) do
    ~H"""
    <div
      class="flipping-tile-container grid w-10 h-10 mx-1 perspective-1000"
      phx-hook="TileFlipping"
      data-index={@idx}
      id={"tile-#{@id}"}
    >
      <div class="flipping-tile-face col-start-1 row-start-1">
        <.tile_lg letter={""} mx={0} />
      </div>
      <div class="flipping-tile-face flipping-tile-back col-start-1 row-start-1">
        <.tile_lg letter={@letter} mx={0} />
      </div>
    </div>
    """
  end

  attr :word, :string, required: true
  attr :size, :string, default: "md"
  attr :class, :string, default: ""

  @doc """
  Renders a word with tiles.
  """
  def tile_word(assigns) do
    ~H"""
    <div class={"flex flex-row #{@class}"}>
      <%= for letter <- String.graphemes(String.upcase(@word)) do %>
        <%= if @size == "lg" do %>
          <.tile_lg letter={letter} />
        <% else %>
          <.tile letter={letter} />
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :letter, :string, required: true
  attr :class, :string, default: ""
  attr :mx, :integer, default: 1

  def tile_lg(assigns) do
    ~H"""
    <div class={"text-3xl font-bold w-10 h-10 min-w-10 min-h-10 mx-#{@mx} pt-[2px] text-center select-none border-2 border-black bg-white dark:border-white dark:bg-black dark:text-white rounded-md shadow-[0_2px_2px_0_rgba(0,0,0,1)] dark:shadow-[0_2px_2px_0_rgba(255,255,255,1)]"}>
      <div class="-my-[2px]">
        {String.upcase(@letter)}
      </div>
    </div>
    """
  end

  attr :letter, :string, required: true

  def tile(assigns) do
    ~H"""
    <div class="text-2xl font-bold w-8 h-8 min-w-8 min-h-8 mx-[2px] text-center select-none border-2 border-black bg-white dark:border-white dark:bg-black dark:text-white rounded-md shadow-[0_2px_2px_0_rgba(0,0,0,1)] dark:shadow-[0_2px_2px_0_rgba(255,255,255,1)]">
      <div class="-my-[2px]">
        {String.upcase(@letter)}
      </div>
    </div>
    """
  end

  def ellipsis(assigns) do
    ~H"""
    <div class="text-xl font-bold w-8 h-8 mx-[2px] text-center select-none border-2 border-black bg-white dark:border-white dark:bg-black dark:text-white rounded-md shadow-[0_2px_2px_0_rgba(0,0,0,1)] dark:shadow-[0_2px_2px_0_rgba(255,255,255,1)]">
      ...
    </div>
    """
  end

  slot :inner_block, required: true
  attr :type, :string, default: "button"
  attr :to, :string, default: nil
  attr :method, :atom, default: :get
  attr :phx_click, :string, default: nil
  attr :class, :string, default: ""
  attr :width, :string, default: "w-fit"
  attr :disabled, :boolean, default: false
  attr :disabled_style, :boolean, default: true
  attr :phx_disable_with, :string, default: nil
  attr :data_confirm, :string, default: nil
  attr :rest, :global, include: ~w(form name value navigate patch phx-disable-with)

  def ps_button(assigns) do
    ~H"""
    <%= cond do %>
      <% @to -> %>
        <.link
          href={@to}
          class={"block phx-submit-loading:opacity-75 #{ps_button_classes(@disabled and @disabled_style)} #{@class}"}
          width={@width}
        >
          {render_slot(@inner_block)}
        </.link>
      <% @phx_click != nil -> %>
        <.link {@rest} phx-click={@phx_click} class={"block #{@class}"} width={@width}>
          <button
            {@rest}
            type={@type}
            disabled={@disabled}
            data-confirm={@data_confirm}
            class={"phx-submit-loading:opacity-75 #{ps_button_classes(@disabled and @disabled_style)} #{@class}"}
          >
            {render_slot(@inner_block)}
          </button>
        </.link>
      <% true -> %>
        <button
          type={@type}
          disabled={@disabled}
          data-confirm={@data_confirm}
          phx-disable-with={@phx_disable_with}
          class={"phx-submit-loading:opacity-75 #{ps_button_classes(@disabled and @disabled_style)} #{@class}"}
          {@rest}
        >
          {render_slot(@inner_block)}
        </button>
    <% end %>
    """
  end

  defp ps_button_classes(disabled) do
    if disabled do
      "border-2 border-white dark:border-black cursor-default"
    else
      # border & shadow
      "border-2 border-black dark:border-white cursor-pointer shadow-[0_2px_2px_0_rgba(0,0,0,1)] dark:shadow-[0_2px_2px_0_rgba(255,255,255,1)] active:shadow-[0_0px_0px_0_rgba(0,0,0,1)] active:translate-y-[2px] transition-all duration-75"
    end <>
      "bg-white dark:bg-black dark:text-white px-4 py-2 rounded-md"
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  def ps_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 z-40 flex items-center justify-center">
      <div class="bg-white dark:bg-black dark:border-2 dark:border-white p-6 rounded-lg shadow-xl z-50">
        <div class="flex flex-col gap-4 px-4 py-2">
          <div class="mb-4">
            <.tile_word word={@title} />
          </div>
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  # slot :inner_block, required: true
  # attr :type, :string, default: "button"
  # attr :class, :string, default: ""

  # def ps_inner_button(assigns) do
  #   ~H"""
  #   <button type={@type} class={"bg-white border-2 border-black dark:border-white dark:bg-black dark:text-white px-4 py-2 rounded-md shadow-[0_2px_2px_0_rgba(0,0,0,1)] #{@class}"}>
  #     <%= render_slot(@inner_block) %>
  #   </button>
  #   """
  # end

  attr :label, :string, default: nil
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :form, :any, default: nil
  attr :value, :string, default: nil
  attr :field, :any, required: true
  attr :type, :string, default: "text"
  attr :autocomplete, :boolean, default: false
  attr :placeholder, :string, default: ""
  attr :class, :string, default: ""
  attr :minlength, :integer, default: nil
  attr :maxlength, :integer, default: nil

  def ps_text_input(assigns) do
    ~H"""
    <.label :if={@label} for={@id} class="text-black dark:text-white">{@label}</.label>
    <input
      id={@id}
      name={@name}
      value={if @form != nil, do: Phoenix.HTML.Form.input_value(@form, @field), else: @value}
      type={@type}
      placeholder={@placeholder}
      autocomplete={if @autocomplete, do: "on", else: "off"}
      minlength={@minlength}
      maxlength={@maxlength}
      class={"bg-white border-2 text-xl max-w-48 border-black dark:border-white dark:bg-black dark:text-white px-4 py-2 rounded-md shadow-[0_2px_2px_0_rgba(0,0,0,1)] dark:shadow-[0_2px_2px_0_rgba(255,255,255,1)] focus:border-black focus:ring-black dark:focus:border-white dark:focus:ring-white #{@class}"}
    />
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.ps_flash kind={:info} flash={@flash} />
      <.ps_flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.ps_flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def ps_flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-mounted={JS.hide(to: "##{@id}", transition: "fade-out", time: 3000)}
      role="alert"
      class={[
        "font-sahitya fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1 transition-opacity duration-600",
        @kind == :info &&
          "bg-white text-black shadow-md ring-black border-2 border-black dark:bg-black dark:text-white dark:ring-white dark:border-white",
        @kind == :error &&
          "bg-black text-white shadow-md ring-white dark:bg-white dark:text-black dark:ring-black dark:border-black"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.ps_flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def ps_flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.ps_flash kind={:info} title={gettext("Success!")} flash={@flash} />
      <.ps_flash kind={:error} title={gettext("Error!")} flash={@flash} />
      <.ps_flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.ps_flash>

      <.ps_flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.ps_flash>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: false, default: nil
  attr :class, :string, required: false, default: "w-6 h-6"
  attr :rest, :global

  def ps_icon(assigns) do
    ~H"""
    <svg aria-labelledby="title" class={@class} {@rest}>
      <title lang="en">{@label || @name}</title>
      <use
        width="100%"
        height="100%"
        href={~p"/assets/icons/#{@name}"}
        style="color: inherit; fill: currentColor;"
      />
    </svg>
    """
  end

  def game_progress_bar(assigns) do
    ~H"""
    <%= if assigns[:game_progress_bar] do %>
      <div
        id="game_progress_bar"
        class="h-1 bg-black dark:bg-white"
        style={
        "width: #{(length(assigns[:game_state].letter_pool) / assigns[:game_state].initial_letter_count) * 100}%"
      }
      >
      </div>
    <% end %>
    """
  end
end

defmodule PiratexWeb.Components.PiratexComponents do
  use Phoenix.Component

  use PiratexWeb, :verified_routes

  alias Phoenix.LiveView.JS
  use Gettext, backend: PiratexWeb.Gettext
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
        <%= case @size do %>
          <% "lg" -> %>
            <.tile_lg letter={letter} />
          <% "md" -> %>
            <.tile letter={letter} />
          <% "sm" -> %>
            <.tile_sm letter={letter} />
          <% _ -> %>
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
    <div
      class={"text-3xl font-bold w-10 h-10 min-w-10 min-h-10 mx-#{@mx} pt-[2px] text-center select-none border-2 rounded-md"}
      style={"border-color: var(--theme-tile-border); background-color: var(--theme-tile-bg); color: var(--theme-tile-text); box-shadow: var(--theme-tile-shadow);"}
    >
      <div class="-my-[2px]">
        {String.upcase(@letter)}
      </div>
    </div>
    """
  end

  attr :letter, :string, required: true

  def tile(assigns) do
    ~H"""
    <div
      class="text-2xl font-bold w-8 h-8 min-w-8 min-h-8 mx-[2px] text-center select-none border-2 rounded-md"
      style={"border-color: var(--theme-tile-border); background-color: var(--theme-tile-bg); color: var(--theme-tile-text); box-shadow: var(--theme-tile-shadow);"}
    >
      <div class="-my-[2px]">
        {String.upcase(@letter)}
      </div>
    </div>
    """
  end

  # Small tiles have no shadow
  def tile_sm(assigns) do
    ~H"""
    <div
      class="text-lg font-bold w-6 h-6 min-w-6 min-h-6 mx-[2px] text-center select-none border-2 rounded-md"
      style={"border-color: var(--theme-tile-border); background-color: var(--theme-tile-bg); color: var(--theme-tile-text);"}
    >
      <div class="-my-[4px]">
        {String.upcase(@letter)}
      </div>
    </div>
    """
  end

  def ellipsis(assigns) do
    ~H"""
    <div
      class="text-xl font-bold w-8 h-8 mx-[2px] text-center select-none border-2 rounded-md"
      style={"border-color: var(--theme-tile-border); background-color: var(--theme-tile-bg); color: var(--theme-tile-text); box-shadow: var(--theme-tile-shadow);"}
    >
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
    assigns = assign(assigns,
      button_style: ps_button_style(assigns.disabled and assigns.disabled_style),
      button_classes: ps_button_classes(assigns.disabled and assigns.disabled_style)
    )
    ~H"""
    <%= cond do %>
      <% @to -> %>
        <.link
          href={@to}
          class={"block phx-submit-loading:opacity-75 #{@button_classes} #{@class}"}
          style={@button_style}
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
            class={"phx-submit-loading:opacity-75 #{@button_classes} #{@width} #{@class}"}
            style={@button_style}
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
          class={"phx-submit-loading:opacity-75 #{@button_classes} #{@class}"}
          style={@button_style}
          {@rest}
        >
          {render_slot(@inner_block)}
        </button>
    <% end %>
    """
  end

  defp ps_button_classes(disabled) do
    base_classes = "border-2 px-4 py-2 rounded-md"
    if disabled do
      "#{base_classes} cursor-default"
    else
      "#{base_classes} cursor-pointer active:translate-y-[2px] transition-all duration-75"
    end
  end

  defp ps_button_style(disabled) do
    if disabled do
      "border-color: var(--theme-button-disabled-border); background-color: var(--theme-button-bg); color: var(--theme-button-text);"
    else
      "border-color: var(--theme-button-border); background-color: var(--theme-button-bg); color: var(--theme-button-text); box-shadow: var(--theme-button-shadow);"
    end
  end


  attr :title, :string, required: true
  slot :inner_block, required: true

  def ps_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-40 flex items-center justify-center" style={"background-color: var(--theme-modal-overlay);"}>
      <div
        class="p-6 rounded-lg shadow-xl z-50"
        style={"background-color: var(--theme-modal-bg); border: 2px solid var(--theme-modal-border);"}
      >
        <div class="flex flex-col gap-4 px-4 py-2">
          <div class="mx-auto mb-4">
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
  attr :text_size, :string, default: "text-xl"
  attr :class, :string, default: ""
  attr :max_width, :string, default: "max-w-48"
  attr :minlength, :integer, default: nil
  attr :maxlength, :integer, default: nil

  def ps_text_input(assigns) do
    ~H"""
    <.label :if={@label} for={@id} style={"color: var(--theme-text);"}>{@label}</.label>
    <input
      id={@id}
      name={@name}
      value={if @form != nil, do: Phoenix.HTML.Form.input_value(@form, @field), else: @value}
      type={@type}
      placeholder={@placeholder}
      autocomplete={if @autocomplete, do: "on", else: "off"}
      minlength={@minlength}
      maxlength={@maxlength}
      class={"border-2 #{@text_size} #{@max_width} px-4 py-2 rounded-md #{@class}"}
      style={"background-color: var(--theme-input-bg); border-color: var(--theme-input-border); color: var(--theme-input-text); box-shadow: var(--theme-tile-shadow);"}
      onfocus={"this.style.borderColor = 'var(--theme-input-focus-border)'; this.style.boxShadow = '0 0 0 1px var(--theme-input-focus-ring)';"}
      onblur={"this.style.borderColor = 'var(--theme-input-border)'; this.style.boxShadow = 'var(--theme-tile-shadow)';"}
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
      class="font-sahitya fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1 transition-opacity duration-600 border-2"
      style={
        if @kind == :info do
          "background-color: var(--theme-flash-info-bg); color: var(--theme-flash-info-text); border-color: var(--theme-flash-info-border); box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); --tw-ring-color: var(--theme-flash-info-ring);"
        else
          "background-color: var(--theme-flash-error-bg); color: var(--theme-flash-error-text); border-color: var(--theme-flash-error-border); box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); --tw-ring-color: var(--theme-flash-error-ring);"
        end
      }
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
        class="h-1"
        style={
        "width: #{(length(assigns[:game_state].letter_pool) / assigns[:game_state].initial_letter_count) * 100}%; background-color: var(--theme-progress-bg);"
      }
      >
      </div>
    <% end %>
    """
  end

  attr :phx_click, :any
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""

  def plus_button(assigns) do
    ~H"""
    <button
      phx-click={@phx_click}
      class={"w-10 h-10 min-w-10 min-h-10 mx-1 pt-[2px] text-center select-none #{plus_button_classes(@disabled)}"}
      style={plus_button_style(@disabled)}
    >
      <div class="text-4xl font-bold -my-[6px]">
        +
      </div>
    </button>
    """
  end

  defp plus_button_classes(disabled) do
    base_classes = "border-2 py-2 rounded-md"
    if disabled do
      "#{base_classes} cursor-default"
    else
      "#{base_classes} cursor-pointer active:translate-y-[2px] transition-all duration-75"
    end
  end

  defp plus_button_style(disabled) do
    if disabled do
      "border-color: var(--theme-button-disabled-border); background-color: var(--theme-button-bg); color: var(--theme-button-text);"
    else
      "border-color: var(--theme-button-border); background-color: var(--theme-button-bg); color: var(--theme-button-text); box-shadow: var(--theme-button-shadow);"
    end
  end

  attr :word, :string, required: true
  attr :abbrev, :integer, default: 5

  def word_in_play(assigns) do
    ~H"""
    <button class="hidden sm:flex sm:flex-row" phx-click="show_word_steal" phx-value-word={@word}>
      <%= if @abbrev > 0 and String.length(@word) > @abbrev do %>
        <.tile_word word={String.slice(@word, 0, @abbrev)} />
        <.ellipsis />
      <% else %>
        <.tile_word word={@word} />
      <% end %>
    </button>
    <button class="flex sm:hidden text-monospace tracking-wider" phx-click="show_word_steal" phx-value-word={@word}>
      <%!-- <.tile_word size="sm" word={@word} /> --%>
      {String.upcase(@word)}
    </button>
    """
  end
end

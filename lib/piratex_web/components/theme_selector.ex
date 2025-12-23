defmodule PiratexWeb.Components.ThemeSelector do
  use Phoenix.Component

  def theme_selector(assigns) do
    ~H"""
    <div class="flex items-center justify-center">
      <select
        id="themeSelector"
        phx-hook="ThemeSelector"
        class="text-center bg-[var(--theme-input-bg)] border-2 border-[var(--theme-input-border)] text-[var(--theme-input-text)] p-1 rounded-md text-sm cursor-pointer focus:border-[var(--theme-input-focus-border)] focus:ring-[var(--theme-input-focus-ring)] focus:outline-none"
        onchange="setTheme(this.value)"
      >
        <option value="light">Light</option>
        <option value="dark">Dark</option>
        <option value="pirates">Pirates</option>
      </select>
    </div>
    """
  end
end

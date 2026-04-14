defmodule PiratexWeb.Components.ThemeSelector do
  @moduledoc """
  Theme selector dropdown component.

  When the active theme is `pirates`, the wrapper is removed from the DOM
  entirely by the `ThemeSelectorWrapper` hook on mount, and by
  `window.setTheme` when the user switches to pirates at runtime. A CSS
  fallback in `assets/css/app.css` hides the wrapper if JavaScript does
  not run. On light/dark themes the wrapper stays in the DOM and visible.
  """
  use Phoenix.Component

  def theme_selector(assigns) do
    ~H"""
    <div id="themeSelectorWrapper" phx-hook="ThemeSelectorWrapper" class="items-center justify-center">
      <select
        id="themeSelector"
        phx-hook="ThemeSelector"
        class="appearance-none text-center bg-[var(--theme-input-bg)] border-2 border-[var(--theme-input-border)] text-[var(--theme-input-text)] p-1 rounded-md text-sm cursor-pointer focus:border-[var(--theme-input-focus-border)] focus:ring-[var(--theme-input-focus-ring)] focus:outline-none"
        onchange="setTheme(this.value)"
      >
        <option value="light">Light</option>
        <option value="dark">Dark</option>
        <option value="pirates">Pirates</option>
      </select>
    </div>
    <script>
      (function(){
        var t=localStorage.getItem('theme')||'pirates';
        if(t!=='pirates')return;
        var w=document.getElementById('themeSelectorWrapper');
        if(w)w.remove();
      })();
    </script>
    """
  end
end

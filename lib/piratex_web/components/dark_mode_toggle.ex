defmodule PiratexWeb.Components.DarkModeToggle do
  use Phoenix.Component

  def dark_mode_toggle(assigns) do
    ~H"""
    <div class="flex items-center justify-center bg-lightBg text-lightText dark:bg-darkBg dark:text-darkText transition-colors duration-300">
      <label class="relative inline-flex items-center cursor-pointer">
        <input type="checkbox" id="darkModeToggle" class="sr-only peer" onclick="toggleDarkMode()">
        <div class="w-11 h-6 bg-black peer-focus:outline-none rounded-full dark:bg-white peer-checked:bg-black dark:peer-checked:bg-white transition-colors duration-300"></div>
        <span class="absolute left-1 top-1 w-4 h-4 bg-white dark:bg-black rounded-full transition-transform duration-300 peer-checked:translate-x-5"></span>
      </label>
    </div>
    """
  end
end

export const ThemeSelector = {
  mounted() {
    this.syncThemeSelector();
  },

  updated() {
    this.syncThemeSelector();
  },

  syncThemeSelector() {
    const themeSelector = document.getElementById('themeSelector');
    if (themeSelector) {
      const currentTheme = window.getTheme ? window.getTheme() : (localStorage.getItem('theme') || 'light');
      themeSelector.value = currentTheme;
    }
  }
}


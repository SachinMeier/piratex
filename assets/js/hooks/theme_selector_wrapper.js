export const ThemeSelectorWrapper = {
  mounted() {
    const theme = (window.getTheme && window.getTheme()) || localStorage.getItem('theme') || 'pirates';
    if (theme === 'pirates') {
      this.el.remove();
    }
  }
}

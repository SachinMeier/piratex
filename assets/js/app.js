// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import {Hotkeys} from "./hooks/hotkeys"
import {TileFlipping} from "./hooks/tile_flipping"
import {TabSwitcher} from "./hooks/tab_switcher"
import {SpeechRecognition} from "./hooks/speech_recognition"
import {ThemeSelector} from "./hooks/theme_selector"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    Hotkeys,
    TileFlipping,
    TabSwitcher,
    SpeechRecognition,
    ThemeSelector
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Theme management
const VALID_THEMES = ['light', 'dark', 'pirates'];
const DEFAULT_THEME = 'light';

function setTheme(themeName) {
  if (!VALID_THEMES.includes(themeName)) {
    console.warn(`Invalid theme: ${themeName}. Using default: ${DEFAULT_THEME}`);
    themeName = DEFAULT_THEME;
  }
  
  // Remove all theme classes
  document.documentElement.removeAttribute('data-theme');
  document.documentElement.classList.remove('dark');
  
  // Set new theme
  if (themeName === 'dark') {
    // Keep dark class for backward compatibility during migration
    document.documentElement.classList.add('dark');
  }
  document.documentElement.setAttribute('data-theme', themeName);
  
  // Save to localStorage
  localStorage.setItem('theme', themeName);
  
  // Update theme selector if it exists
  const themeSelector = document.getElementById('themeSelector');
  if (themeSelector) {
    themeSelector.value = themeName;
  }
}

function getTheme() {
  return localStorage.getItem('theme') || DEFAULT_THEME;
}

// Initialize theme immediately to prevent flash (runs before DOMContentLoaded)
(function() {
  const savedTheme = localStorage.getItem('theme') || DEFAULT_THEME;
  if (savedTheme === 'dark') {
    document.documentElement.classList.add('dark');
  }
  document.documentElement.setAttribute('data-theme', savedTheme);
})();

// Expose theme functions globally
window.setTheme = setTheme;
window.getTheme = getTheme;

// Update theme selector on page load and after LiveView updates
document.addEventListener('DOMContentLoaded', () => {
  syncThemeSelector();
});

// Also sync after LiveView navigation
document.addEventListener('phx:page-loading-stop', () => {
  // Small delay to ensure DOM is updated
  setTimeout(syncThemeSelector, 10);
});

function syncThemeSelector() {
  const themeSelector = document.getElementById('themeSelector');
  if (themeSelector) {
    const currentTheme = getTheme();
    if (themeSelector.value !== currentTheme) {
      themeSelector.value = currentTheme;
    }
  }
}
// Ink entry point. Builds the API client + socket URL from CLI args, sets
// up alternate-screen mode so output doesn't pollute the scrollback, and
// renders the App tree.

import React from "react";
import { render } from "ink";

import { AppRoot } from "./app.js";
import { ApiClient } from "./api.js";
import { parseCliArgs } from "./config.js";
import { PROTOCOL_VERSION } from "./contract.js";

function maybePrintVersion(): boolean {
  const argv = process.argv;
  if (argv.includes("--version") || argv.includes("-v")) {
    const pkg = "0.1.0";
    console.log(
      `piratex ${pkg} (protocol ${PROTOCOL_VERSION.major}.${PROTOCOL_VERSION.minor})`,
    );
    return true;
  }
  return false;
}

function maybePrintHelp(): boolean {
  const argv = process.argv;
  if (argv.includes("--help") || argv.includes("-h")) {
    console.log(
      [
        "piratex — terminal client for Pirate Scrabble",
        "",
        "Usage:",
        "  piratex [GAME_ID] [--server URL]",
        "",
        "Arguments:",
        "  GAME_ID         Optional. Skip the home menu and jump straight",
        "                  to the username prompt for this game.",
        "",
        "Options:",
        "  --server URL    Server URL (default: wss://piratescrabble.com)",
        "  --version       Print version and exit",
        "  --help          Show this help",
        "",
        "Environment:",
        "  PIRATEX_SERVER    Same as --server",
        "  PIRATEX_USERNAME  Auto-fill your player name; if the server rejects",
        "                    it (too short, duplicate, etc.) you'll be asked",
        "                    to enter a name manually.",
        "",
        "Examples:",
        "  piratex                              # main menu",
        "  piratex ABC1234                      # jump to join ABC1234",
        "  PIRATEX_USERNAME=sachin piratex ABC  # auto-join as 'sachin'",
        "  piratex ABC1234 --server ...         # same, against a dev server",
      ].join("\n"),
    );
    return true;
  }
  return false;
}

function enterAlternateScreen() {
  if (process.stdout.isTTY) {
    // Enter alternate screen buffer + hide cursor. Ink draws on this
    // isolated buffer and the user's original terminal contents survive
    // underneath.
    process.stdout.write("\x1b[?1049h");
    process.stdout.write("\x1b[?25l");
  }
}

function exitAlternateScreen() {
  if (process.stdout.isTTY) {
    // Clear whatever Ink left in the alt buffer, show the cursor again,
    // and exit the alt buffer. This sequence leaves the user's original
    // terminal clean — no leftover Ink frames sitting in scrollback.
    process.stdout.write("\x1b[2J\x1b[H");
    process.stdout.write("\x1b[?25h");
    process.stdout.write("\x1b[?1049l");
  }
}

function main() {
  if (maybePrintVersion() || maybePrintHelp()) return;

  const cli = parseCliArgs();
  const api = new ApiClient(cli.server.httpUrl);

  enterAlternateScreen();

  // exitOnCtrlC is disabled so the App can intercept Ctrl+C and show a
  // two-press confirmation (Claude Code-style). The first press shows
  // a toast "press Ctrl+C again to quit"; the second press within 3s
  // actually exits via useApp().exit().
  const ink = render(
    <AppRoot
      api={api}
      socketUrl={cli.server.socketUrl}
      initialGameId={cli.gameId}
      defaultUsername={cli.defaultUsername}
    />,
    { exitOnCtrlC: false },
  );

  let exiting = false;
  const exitNow = (code: number) => {
    if (exiting) return;
    exiting = true;
    try {
      ink.unmount();
    } catch {
      // already unmounted
    }
    exitAlternateScreen();
    // The Phoenix socket's heartbeat timers keep the Node event loop
    // alive even after Ink unmounts. Force a clean exit.
    process.exit(code);
  };

  // Graceful exit path: Ink's useApp().exit() resolves this promise.
  ink.waitUntilExit().then(
    () => exitNow(0),
    () => exitNow(1),
  );

  // SIGTERM (kill) exits immediately without confirm — this is for
  // process managers, not interactive users.
  process.on("SIGTERM", () => exitNow(0));

  // Last-resort handlers: if anything escapes all try/catch layers,
  // clean up the alternate screen buffer before dying. Without these
  // the terminal stays in raw/alt-buffer mode and the user has to
  // blindly type `reset`.
  process.on("uncaughtException", () => exitNow(1));
  process.on("unhandledRejection", () => exitNow(1));
}

main();

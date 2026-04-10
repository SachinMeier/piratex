// Ink entry point. Builds the API client + socket URL from CLI args, sets
// up alternate-screen mode so output doesn't pollute the scrollback, and
// renders the App tree.

import React from "react";
import { render } from "ink";

import { AppRoot } from "./app.js";
import { ApiClient } from "./api.js";
import { parseServerConfig } from "./config.js";
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
        "  piratex [--server URL]",
        "",
        "Options:",
        "  --server URL    Server URL (default: wss://piratescrabble.com)",
        "  --version       Print version and exit",
        "  --help          Show this help",
        "",
        "Environment:",
        "  PIRATEX_SERVER  Same as --server",
      ].join("\n"),
    );
    return true;
  }
  return false;
}

function enterAlternateScreen() {
  if (process.stdout.isTTY) {
    process.stdout.write("\x1b[?1049h");
  }
}

function exitAlternateScreen() {
  if (process.stdout.isTTY) {
    process.stdout.write("\x1b[?1049l");
  }
}

function main() {
  if (maybePrintVersion() || maybePrintHelp()) return;

  const config = parseServerConfig();
  const api = new ApiClient(config.httpUrl);

  enterAlternateScreen();

  const ink = render(<AppRoot api={api} socketUrl={config.socketUrl} />);

  const cleanup = () => {
    try {
      ink.unmount();
    } catch {
      // ignore
    }
    exitAlternateScreen();
  };

  ink.waitUntilExit().then(cleanup, cleanup);
  process.on("SIGINT", cleanup);
  process.on("SIGTERM", cleanup);
}

main();

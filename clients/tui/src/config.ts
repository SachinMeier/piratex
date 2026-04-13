// Runtime config: parses --server and the optional positional game-id
// argument from argv, and derives HTTP/WS URLs for the API client and
// Phoenix socket.

const DEFAULT_SERVER = "wss://piratescrabble.com";

export interface ServerConfig {
  httpUrl: string;
  socketUrl: string;
  rawUrl: string;
}

export interface CliArgs {
  server: ServerConfig;
  /** Optional positional game-id — if present, skip the home menu and
      route directly to the JoinPrompt (or auto-join if a default
      username is set) for this game. */
  gameId: string | null;
  /** Optional pre-set player name from PIRATEX_USERNAME. When present,
      the TUI never shows a username prompt — it auto-fills this value
      when joining or creating a game. */
  defaultUsername: string | null;
}

export function parseServerConfig(argv: string[] = process.argv): ServerConfig {
  const raw = extractServerFlag(argv) ?? DEFAULT_SERVER;
  return deriveConfig(raw);
}

export function parseCliArgs(argv: string[] = process.argv): CliArgs {
  const envUsername = process.env["PIRATEX_USERNAME"]?.trim();
  return {
    server: parseServerConfig(argv),
    gameId: extractGameId(argv),
    defaultUsername: envUsername && envUsername.length > 0 ? envUsername : null,
  };
}

function extractServerFlag(argv: string[]): string | null {
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--server" && i + 1 < argv.length) {
      return argv[i + 1]!;
    }
    if (arg?.startsWith("--server=")) {
      return arg.slice("--server=".length);
    }
  }
  const envUrl = process.env["PIRATEX_SERVER"];
  return envUrl ?? null;
}

// Walks argv looking for the first positional argument that isn't a flag
// and isn't the value of a --server flag. Returns the uppercased game id
// or null. Skips argv[0] (node/bun binary) and argv[1] (script path).
function extractGameId(argv: string[]): string | null {
  let skipNext = false;
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg) continue;
    if (skipNext) {
      skipNext = false;
      continue;
    }
    if (arg === "--server") {
      skipNext = true;
      continue;
    }
    if (arg.startsWith("--")) {
      // --server=... and other flags
      continue;
    }
    // First positional wins.
    return arg.toUpperCase();
  }
  return null;
}

function deriveConfig(raw: string): ServerConfig {
  const trimmed = raw.replace(/\/+$/, "");

  const wsUrl = toWs(trimmed);
  const httpUrl = toHttp(trimmed);

  return {
    rawUrl: trimmed,
    httpUrl,
    socketUrl: `${wsUrl}/socket`,
  };
}

function toWs(url: string): string {
  if (url.startsWith("wss://") || url.startsWith("ws://")) return url;
  if (url.startsWith("https://")) return "wss://" + url.slice("https://".length);
  if (url.startsWith("http://")) return "ws://" + url.slice("http://".length);
  return "wss://" + url;
}

function toHttp(url: string): string {
  if (url.startsWith("https://") || url.startsWith("http://")) return url;
  if (url.startsWith("wss://")) return "https://" + url.slice("wss://".length);
  if (url.startsWith("ws://")) return "http://" + url.slice("ws://".length);
  return "https://" + url;
}

// Runtime config: parses --server from argv and derives HTTP/WS URLs.

const DEFAULT_SERVER = "wss://piratescrabble.com";

export interface ServerConfig {
  httpUrl: string;
  socketUrl: string;
  rawUrl: string;
}

export function parseServerConfig(argv: string[] = process.argv): ServerConfig {
  const raw = extractServerFlag(argv) ?? DEFAULT_SERVER;
  return deriveConfig(raw);
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

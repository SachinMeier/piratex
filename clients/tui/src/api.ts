// HTTP client for the JSON API. Wraps the four /api/* endpoints.

import {
  ApiError,
  CreateGameResponse,
  GameState,
  GamesListResponse,
  JoinGameResponse,
  LetterPoolType,
  PROTOCOL_VERSION,
} from "./contract.js";

export class ApiClientError extends Error {
  readonly status: number;
  readonly reason: string;
  readonly detail: ApiError | null;

  constructor(status: number, reason: string, detail: ApiError | null) {
    super(reason);
    this.status = status;
    this.reason = reason;
    this.detail = detail;
  }
}

function protocolHeaders(): Record<string, string> {
  return {
    "content-type": "application/json",
    "x-piratex-protocol-major": String(PROTOCOL_VERSION.major),
    "x-piratex-protocol-minor": String(PROTOCOL_VERSION.minor),
  };
}

async function parseJson<T>(res: Response): Promise<T> {
  if (res.ok) {
    return (await res.json()) as T;
  }
  let detail: ApiError | null = null;
  try {
    detail = (await res.json()) as ApiError;
  } catch {
    // no json body; fall through
  }
  const reason = detail?.error ?? `http_${res.status}`;
  throw new ApiClientError(res.status, reason, detail);
}

export class ApiClient {
  constructor(private readonly httpUrl: string) {}

  async createGame(pool: LetterPoolType = "bananagrams"): Promise<CreateGameResponse> {
    const res = await fetch(`${this.httpUrl}/api/games`, {
      method: "POST",
      headers: protocolHeaders(),
      body: JSON.stringify({ letter_pool: pool }),
    });
    return parseJson<CreateGameResponse>(res);
  }

  async listGames(page = 1): Promise<GamesListResponse> {
    const res = await fetch(`${this.httpUrl}/api/games?page=${page}`, {
      method: "GET",
      headers: protocolHeaders(),
    });
    return parseJson<GamesListResponse>(res);
  }

  async getGame(gameId: string): Promise<GameState> {
    const res = await fetch(`${this.httpUrl}/api/games/${gameId}`, {
      method: "GET",
      headers: protocolHeaders(),
    });
    return parseJson<GameState>(res);
  }

  async joinGame(gameId: string, playerName: string): Promise<JoinGameResponse> {
    const res = await fetch(`${this.httpUrl}/api/games/${gameId}/players`, {
      method: "POST",
      headers: protocolHeaders(),
      body: JSON.stringify({ player_name: playerName }),
    });
    return parseJson<JoinGameResponse>(res);
  }
}

// Top-level React context holding the single CurrentSession, the latest
// GameState, and the toast slot. All screens read from useGame().

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import type { Channel, Socket } from "phoenix";

import { ApiClient } from "./api.js";
import {
  GameConfig,
  GameState,
  LetterPoolType,
  SessionIntent,
} from "./contract.js";
import {
  ChannelJoinResult,
  connectAndJoin,
  onStatePush,
  ProtocolMismatchError,
  pushAsync,
} from "./socket.js";

export interface CurrentSession {
  gameId: string;
  playerName: string;
  playerToken: string;
  intent: "player" | "watch";
  socket: Socket;
  channel: Channel;
  config: GameConfig;
  upgradeAvailable: boolean;
}

export type Toast = {
  kind: "info" | "error";
  message: string;
  id: number;
};

export interface UpgradeRequired {
  reason: "client_outdated" | "server_outdated";
  serverVersion: string;
  clientVersion: string;
  upgradeUrl?: string;
}

export type StartSessionParams =
  | { kind: "create"; pool: LetterPoolType; playerName: string }
  | { kind: "join"; gameId: string; playerName: string }
  | { kind: "watch"; gameId: string };

export interface GameContextValue {
  session: CurrentSession | null;
  gameState: GameState | null;
  toast: Toast | null;
  upgradeAvailable: boolean;
  upgradeRequired: UpgradeRequired | null;
  startSession(params: StartSessionParams): Promise<void>;
  quitSession(): Promise<void>;
  tearDownSession(): void;
  push<T = Record<string, unknown>>(event: string, payload?: unknown): Promise<T>;
  showToast(kind: "info" | "error", message: string, ttlMs?: number): void;
  dismissToast(): void;
  api: ApiClient;
}

export const GameContext = createContext<GameContextValue | null>(null);

export function useGame(): GameContextValue {
  const ctx = useContext(GameContext);
  if (!ctx) {
    throw new Error("useGame must be used inside GameProvider");
  }
  return ctx;
}

interface GameProviderProps {
  api: ApiClient;
  socketUrl: string;
  children: React.ReactNode;
}

export function GameProvider({ api, socketUrl, children }: GameProviderProps) {
  const [session, setSession] = useState<CurrentSession | null>(null);
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [toast, setToast] = useState<Toast | null>(null);
  const [upgradeRequired, setUpgradeRequired] =
    useState<UpgradeRequired | null>(null);
  const startingSession = useRef(false);
  const statePushCleanup = useRef<(() => void) | null>(null);
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const toastIdCounter = useRef(0);

  const dismissToast = useCallback(() => {
    if (toastTimer.current) {
      clearTimeout(toastTimer.current);
      toastTimer.current = null;
    }
    setToast(null);
  }, []);

  const showToast = useCallback(
    (kind: "info" | "error", message: string, ttlMs = 5000) => {
      if (toastTimer.current) clearTimeout(toastTimer.current);
      toastIdCounter.current += 1;
      setToast({ kind, message, id: toastIdCounter.current });
      if (ttlMs > 0) {
        toastTimer.current = setTimeout(() => {
          setToast(null);
          toastTimer.current = null;
        }, ttlMs);
      }
    },
    [],
  );

  const tearDownSession = useCallback(() => {
    if (!session) return;
    if (statePushCleanup.current) {
      statePushCleanup.current();
      statePushCleanup.current = null;
    }
    try {
      session.channel.leave();
    } catch {
      /* noop */
    }
    try {
      session.socket.disconnect();
    } catch {
      /* noop */
    }
    setSession(null);
    setGameState(null);
  }, [session]);

  const quitSession = useCallback(async () => {
    if (!session) return;
    // Every step is individually guarded so quit never throws — the user
    // must always be able to leave, even if the game no longer exists on
    // the server or the connection is already dead.
    if (session.intent === "player") {
      try {
        await pushAsync(session.channel, "quit_game", {});
      } catch {
        /* swallow — server may have already cleaned up the game */
      }
    }
    try {
      statePushCleanup.current?.();
      statePushCleanup.current = null;
    } catch {
      /* noop */
    }
    try {
      session.channel.leave();
    } catch {
      /* noop */
    }
    try {
      session.socket.disconnect();
    } catch {
      /* noop */
    }
    setSession(null);
    setGameState(null);
  }, [session]);

  const push = useCallback(
    async <T = Record<string, unknown>,>(
      event: string,
      payload: unknown = {},
    ): Promise<T> => {
      if (!session) {
        throw new Error("no active session");
      }
      return pushAsync<T>(session.channel, event, payload);
    },
    [session],
  );

  const startSession = useCallback(
    async (params: StartSessionParams): Promise<void> => {
      if (session || startingSession.current) {
        throw new Error("session already active");
      }
      startingSession.current = true;
      try {
        let gameId: string;
        let playerName: string;
        let playerToken: string;
        let intent: SessionIntent;
        let sessionKind: "player" | "watch";

        if (params.kind === "create") {
          const created = await api.createGame(params.pool);
          gameId = created.game_id;
          const joined = await api.joinGame(gameId, params.playerName);
          playerName = joined.player_name;
          playerToken = joined.player_token;
          intent = "rejoin";
          sessionKind = "player";
        } else if (params.kind === "join") {
          const joined = await api.joinGame(params.gameId, params.playerName);
          gameId = joined.game_id;
          playerName = joined.player_name;
          playerToken = joined.player_token;
          intent = "rejoin";
          sessionKind = "player";
        } else {
          gameId = params.gameId;
          playerName = "";
          playerToken = "";
          intent = "watch";
          sessionKind = "watch";
        }

        let joined: ChannelJoinResult;
        try {
          joined = await connectAndJoin({
            socketUrl,
            gameId,
            playerName,
            playerToken,
            intent,
          });
        } catch (err) {
          if (err instanceof ProtocolMismatchError) {
            setUpgradeRequired({
              reason: err.reason,
              serverVersion: err.serverVersion,
              clientVersion: err.clientVersion,
              upgradeUrl: err.upgradeUrl,
            });
          }
          throw err;
        }

        const unsubscribe = onStatePush(joined.channel, (state) => {
          setGameState(state);
        });
        statePushCleanup.current = unsubscribe;

        // Reconnect-error debouncing: first error in a window fires a toast,
        // subsequent errors within 10s are suppressed. Successful reconnect
        // resets the counter and shows a brief info toast.
        let reconnectErrorAt: number | null = null;
        joined.socket.onError(() => {
          const now = Date.now();
          if (reconnectErrorAt === null || now - reconnectErrorAt > 10_000) {
            reconnectErrorAt = now;
            showToast("error", "connection lost, retrying…", 5000);
          }
        });
        joined.socket.onOpen(() => {
          if (reconnectErrorAt !== null) {
            reconnectErrorAt = null;
            showToast("info", "reconnected", 3000);
          }
        });

        setSession({
          gameId,
          playerName,
          playerToken,
          intent: sessionKind,
          socket: joined.socket,
          channel: joined.channel,
          config: joined.reply.config,
          upgradeAvailable: joined.reply.upgrade_available,
        });
      } finally {
        startingSession.current = false;
      }
    },
    [api, session, socketUrl],
  );

  useEffect(() => {
    return () => {
      if (toastTimer.current) clearTimeout(toastTimer.current);
    };
  }, []);

  const value = useMemo<GameContextValue>(
    () => ({
      session,
      gameState,
      toast,
      upgradeAvailable: session?.upgradeAvailable ?? false,
      upgradeRequired,
      startSession,
      quitSession,
      tearDownSession,
      push,
      showToast,
      dismissToast,
      api,
    }),
    [
      session,
      gameState,
      toast,
      upgradeRequired,
      startSession,
      quitSession,
      tearDownSession,
      push,
      showToast,
      dismissToast,
      api,
    ],
  );

  return <GameContext.Provider value={value}>{children}</GameContext.Provider>;
}

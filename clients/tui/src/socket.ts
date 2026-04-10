// Phoenix Channel wiring for the TUI.
// Uses the official `phoenix` package's Socket and Channel clients, which
// work in Node.js out of the box once a WebSocket implementation (`ws`) is
// registered on the global scope.

import { Socket, Channel, Push } from "phoenix";
// @ts-ignore — `ws` has no named default export and we only need the class.
import WebSocket from "ws";

import {
  GameState,
  JoinReply,
  PROTOCOL_VERSION,
  SessionIntent,
} from "./contract.js";

// Phoenix JS client expects a global WebSocket. Node doesn't provide one.
// Stub it with `ws` the first time this module loads.
const globalAny = globalThis as unknown as { WebSocket?: unknown };
if (typeof globalAny.WebSocket === "undefined") {
  globalAny.WebSocket = WebSocket;
}

export interface ChannelJoinResult {
  socket: Socket;
  channel: Channel;
  reply: JoinReply;
}

export interface ChannelJoinParams {
  socketUrl: string;
  gameId: string;
  playerName: string;
  playerToken: string;
  intent: SessionIntent;
  clientLabel?: string;
}

export interface PushError extends Error {
  readonly reason: string;
  readonly payload: unknown;
}

/**
 * Connects the socket and joins the game channel. Resolves with the
 * connected socket, the joined channel, and the initial join reply.
 *
 * The returned socket is already `connect()`ed; the returned channel has
 * already received the first state push by the time this resolves.
 */
export function connectAndJoin(
  params: ChannelJoinParams,
): Promise<ChannelJoinResult> {
  const socket = new Socket(params.socketUrl, {
    params: {
      player_token: params.playerToken,
      client: params.clientLabel ?? "piratex-tui/0.1.0",
    },
    // Keep reconnect enabled but quiet in the TUI logs.
    logger: () => {},
  });

  return new Promise((resolve, reject) => {
    let settled = false;
    const settleError = (err: Error) => {
      if (settled) return;
      settled = true;
      try {
        socket.disconnect();
      } catch {
        // ignore
      }
      reject(err);
    };

    socket.onError(() => {
      settleError(new Error("socket_error"));
    });

    try {
      socket.connect();
    } catch (err) {
      settleError(err as Error);
      return;
    }

    const channel = socket.channel(`game:${params.gameId}`, {
      player_name: params.playerName,
      intent: params.intent,
      protocol_major: PROTOCOL_VERSION.major,
      protocol_minor: PROTOCOL_VERSION.minor,
    });

    channel
      .join()
      .receive("ok", (reply: unknown) => {
        if (settled) return;
        settled = true;
        resolve({
          socket,
          channel,
          reply: reply as JoinReply,
        });
      })
      .receive("error", (reply: unknown) => {
        const reason =
          typeof reply === "object" && reply !== null && "reason" in reply
            ? String((reply as { reason: unknown }).reason)
            : "join_error";
        const err = Object.assign(new Error(reason), { payload: reply });
        settleError(err);
      })
      .receive("timeout", () => {
        settleError(new Error("join_timeout"));
      });
  });
}

/**
 * Promise wrapper for Phoenix channel pushes. Resolves on "ok" with the
 * reply payload; rejects on "error" with the reason atom or on "timeout".
 */
export function pushAsync<T = Record<string, unknown>>(
  channel: Channel,
  event: string,
  payload: unknown = {},
  timeoutMs = 5000,
): Promise<T> {
  return new Promise((resolve, reject) => {
    const push: Push = channel.push(event, payload ?? {}, timeoutMs);
    push
      .receive("ok", (reply: unknown) => resolve(reply as T))
      .receive("error", (reply: unknown) => {
        const reason = extractReason(reply);
        const err = Object.assign(new Error(reason), {
          reason,
          payload: reply,
        }) as PushError;
        reject(err);
      })
      .receive("timeout", () => {
        const err = Object.assign(new Error("timeout"), {
          reason: "timeout",
          payload: null,
        }) as PushError;
        reject(err);
      });
  });
}

function extractReason(reply: unknown): string {
  if (typeof reply === "object" && reply !== null && "reason" in reply) {
    const raw = (reply as { reason: unknown }).reason;
    if (typeof raw === "string") return raw;
    if (typeof raw === "object" && raw !== null && "reason" in raw) {
      const nested = (raw as { reason: unknown }).reason;
      if (typeof nested === "string") return nested;
    }
  }
  return "unknown_error";
}

/** Subscribes a callback to `state` pushes. Returns an unsubscribe function. */
export function onStatePush(
  channel: Channel,
  cb: (state: GameState) => void,
): () => void {
  const ref = channel.on("state", (payload: unknown) => {
    cb(payload as GameState);
  });
  return () => channel.off("state", ref);
}

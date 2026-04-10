// Lightweight countdown timer driven by setInterval. Re-renders ~10/s while
// active so the on-screen clock looks smooth.

import { useEffect, useState } from "react";

export interface CountdownState {
  remainingMs: number;
  expired: boolean;
}

/**
 * Returns the remaining time until `startedAt + durationMs`, ticking every
 * `tickMs`. Reset by changing `startedAt` (e.g. on a new total_turn or
 * a new challenge id).
 */
export function useCountdown(
  startedAt: number,
  durationMs: number,
  tickMs = 250,
): CountdownState {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    setNow(Date.now());
    const id = setInterval(() => setNow(Date.now()), tickMs);
    return () => clearInterval(id);
  }, [startedAt, durationMs, tickMs]);

  const elapsed = now - startedAt;
  const remaining = Math.max(0, durationMs - elapsed);
  return {
    remainingMs: remaining,
    expired: remaining <= 0,
  };
}

/** Format `ms` as `M:SS`. */
export function formatCountdown(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  const minutes = Math.floor(total / 60);
  const seconds = total % 60;
  return `${minutes}:${seconds.toString().padStart(2, "0")}`;
}

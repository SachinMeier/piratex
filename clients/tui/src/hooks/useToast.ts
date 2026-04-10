// Convenience re-exports for the toast slot owned by the GameProvider.
// The toast state lives in the provider so it can survive screen
// transitions, but consumers usually just want a hook that returns
// `{ toast, show, dismiss }`.

import { useGame } from "../game-provider.js";

export interface UseToast {
  toast: ReturnType<typeof useGame>["toast"];
  show(kind: "info" | "error", message: string, ttlMs?: number): void;
  dismiss(): void;
}

export function useToast(): UseToast {
  const game = useGame();
  return {
    toast: game.toast,
    show: game.showToast,
    dismiss: game.dismissToast,
  };
}

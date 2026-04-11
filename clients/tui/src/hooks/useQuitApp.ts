// useQuitApp — returns a function that gracefully tears down any active
// session and exits the application via Ink's useApp().exit(). index.tsx's
// cleanup handler takes care of the alternate-screen sequence and the
// hard process.exit() needed to release the Phoenix socket heartbeat.

import { useCallback } from "react";
import { useApp } from "ink";
import { useGame } from "../game-provider.js";

export function useQuitApp(): () => Promise<void> {
  const { exit } = useApp();
  const game = useGame();

  return useCallback(async () => {
    if (game.session) {
      try {
        await game.quitSession();
      } catch {
        // ignore — we're exiting anyway
      }
    }
    exit();
  }, [game, exit]);
}

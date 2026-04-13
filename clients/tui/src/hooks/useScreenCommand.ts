// Unified input/command state for non-playing screens.
//
// Wraps `useBottomCommand` with the conventional `:q`/`:qa`/`:b`/`:back`/
// `:?` handlers, plus a help-popup state machine with Esc-to-close
// wired in. Every centered-menu screen uses this instead of re-wiring
// the same five handlers and the same Esc listener in every file.
//
// Usage:
//
//   const screen = useScreenCommand({
//     onQuit: quitApp,
//     onBack: onCancel,
//     extra: {
//       n: () => onChoice("create"),
//       j: () => onChoice("find"),
//     },
//   });
//
//   // screen.commandMode / screen.buffer → pass to BottomCommandBar
//   // screen.showHelp → gate the help popup
//   // screen.enterCommandMode() → for text inputs that detect ":" typed
//   //   into an empty field and want to hand off to the command bar.

import { useCallback, useState } from "react";
import { useInput as useInkInput } from "ink";
import {
  ColonHandlers,
  useBottomCommand,
} from "./useBottomCommand.js";

export interface UseScreenCommandParams {
  onQuit: () => void;
  onBack?: () => void;
  /** Additional colon handlers, e.g. `{ n: () => onChoice("create") }`. */
  extra?: ColonHandlers;
}

export interface ScreenCommandState {
  commandMode: boolean;
  buffer: string;
  enterCommandMode(): void;
  showHelp: boolean;
  closeHelp(): void;
}

/** Appends the conventional help-command hint to a prefix hint string.
 *
 * Example:
 *   hintWithHelp("↑↓/jk navigate  ·  l/enter select  ·  :q quit", showHelp)
 *   // → "...  ·  :q quit  ·  :? help"      when showHelp is false
 *   // → "...  ·  :q quit  ·  esc/:? close help"  when showHelp is true
 */
export function hintWithHelp(prefix: string, showHelp: boolean): string {
  return showHelp
    ? `${prefix}  ·  esc/:? close help`
    : `${prefix}  ·  :? help`;
}

export function useScreenCommand(
  params: UseScreenCommandParams,
): ScreenCommandState {
  const [showHelp, setShowHelp] = useState(false);
  const toggleHelp = useCallback(() => setShowHelp((s) => !s), []);
  const closeHelp = useCallback(() => setShowHelp(false), []);

  const handlers: ColonHandlers = {
    q: params.onQuit,
    qa: params.onQuit,
    ...(params.onBack && { b: params.onBack, back: params.onBack }),
    ...params.extra,
    "?": toggleHelp,
  };

  const bottom = useBottomCommand(handlers);

  // Esc closes the help popup when it's open and we're not in command
  // mode (command-mode's own Esc cancels the buffered command and takes
  // priority).
  useInkInput((_, key) => {
    if (key.escape && showHelp && !bottom.commandMode) {
      closeHelp();
    }
  });

  return {
    commandMode: bottom.commandMode,
    buffer: bottom.buffer,
    enterCommandMode: bottom.enterCommandMode,
    showHelp,
    closeHelp,
  };
}

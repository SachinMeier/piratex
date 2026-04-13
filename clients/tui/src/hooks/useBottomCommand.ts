// useBottomCommand — state machine for a bottom command bar shared across
// every non-Playing screen.
//
// Behavior:
//
//   idle                 → user types ":" → command mode (buffer = "")
//   command mode + char  → append to buffer
//   command mode + enter → look up buffer in handlers; call or no-op; idle
//   command mode + esc   → idle (cancel)
//   command mode + bkspc → delete char; if buffer empty → idle
//
// Screens that also have a text input (e.g. JoinPrompt) should use their
// input's onChange to detect a ":" typed into an empty buffer and call
// enterCommandMode() explicitly, because ink-text-input absorbs keystrokes
// before useInkInput sees them when it's focused.

import { useCallback, useRef, useState } from "react";
import { useInput as useInkInput } from "ink";

export type ColonHandlers = Record<string, () => void>;

export interface BottomCommandState {
  commandMode: boolean;
  buffer: string;
  enterCommandMode(): void;
}

export function useBottomCommand(handlers: ColonHandlers): BottomCommandState {
  const [commandMode, setCommandMode] = useState(false);
  const [buffer, setBuffer] = useState("");
  const handlersRef = useRef(handlers);
  handlersRef.current = handlers;

  const enterCommandMode = useCallback(() => {
    setCommandMode(true);
    setBuffer("");
  }, []);

  const exit = useCallback(() => {
    setCommandMode(false);
    setBuffer("");
  }, []);

  useInkInput((input, key) => {
    if (!commandMode) {
      if (input === ":") {
        setCommandMode(true);
        setBuffer("");
      }
      return;
    }

    if (key.escape) {
      exit();
      return;
    }

    if (key.return) {
      const cmd = buffer.trim();
      exit();
      const h = handlersRef.current[cmd];
      if (h) h();
      return;
    }

    if (key.backspace || key.delete) {
      setBuffer((b) => {
        if (b.length === 0) {
          setCommandMode(false);
          return "";
        }
        return b.slice(0, -1);
      });
      return;
    }

    if (input && input.length === 1 && !key.ctrl && !key.meta) {
      setBuffer((b) => b + input);
    }
  });

  return { commandMode, buffer, enterCommandMode };
}

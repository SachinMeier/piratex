// Three-mode input state machine: normal | command | chat.
//
// Pure reducer + React hook. The reducer is exported for unit tests so we
// can verify every transition without spinning up Ink.

import { useCallback, useReducer } from "react";

export type InputMode = "normal" | "command" | "chat";

export interface InputState {
  mode: InputMode;
  buffer: string;
}

export const INITIAL_INPUT_STATE: InputState = {
  mode: "normal",
  buffer: "",
};

export type Key =
  | { kind: "char"; value: string }
  | { kind: "space" }
  | { kind: "enter" }
  | { kind: "backspace" }
  | { kind: "escape" };

/**
 * Output of one keystroke. Either a state transition only, or a state
 * transition plus an Effect that the caller should perform (submit a word,
 * flip a letter, run a command, send a chat message).
 */
export type InputEffect =
  | { kind: "submit_word"; word: string }
  | { kind: "flip_letter" }
  | { kind: "run_command"; buffer: string }
  | { kind: "send_chat"; message: string }
  | { kind: "panel_close" };

export interface InputResult {
  state: InputState;
  effect: InputEffect | null;
}

const LETTER_RE = /^[a-zA-Z]$/;

export function reduceInput(state: InputState, key: Key): InputResult {
  switch (state.mode) {
    case "normal":
      return reduceNormal(state, key);
    case "command":
      return reduceCommand(state, key);
    case "chat":
      return reduceChat(state, key);
  }
}

function reduceNormal(state: InputState, key: Key): InputResult {
  switch (key.kind) {
    case "char": {
      // Mode-switch characters only fire on an empty buffer.
      if (key.value === ":") {
        if (state.buffer.length === 0) {
          return { state: { mode: "command", buffer: "" }, effect: null };
        }
        return { state, effect: null };
      }
      if (key.value === "/") {
        if (state.buffer.length === 0) {
          return { state: { mode: "chat", buffer: "" }, effect: null };
        }
        return { state, effect: null };
      }
      // Letters: auto-lowercase, append. Everything else (digits,
      // punctuation, symbols) is silently ignored in normal mode.
      if (LETTER_RE.test(key.value)) {
        return {
          state: { ...state, buffer: state.buffer + key.value.toLowerCase() },
          effect: null,
        };
      }
      return { state, effect: null };
    }

    case "space":
      // Always flip — words have no spaces.
      return { state, effect: { kind: "flip_letter" } };

    case "enter":
      if (state.buffer.length === 0) {
        return { state, effect: null };
      }
      return {
        state: { ...state, buffer: "" },
        effect: { kind: "submit_word", word: state.buffer },
      };

    case "backspace":
      if (state.buffer.length === 0) return { state, effect: null };
      return {
        state: { ...state, buffer: state.buffer.slice(0, -1) },
        effect: null,
      };

    case "escape":
      // Esc clears the buffer; if it was already empty, the caller can
      // close any open panel via the panel_close effect.
      if (state.buffer.length === 0) {
        return { state, effect: { kind: "panel_close" } };
      }
      return { state: { ...state, buffer: "" }, effect: null };
  }
}

function reduceCommand(state: InputState, key: Key): InputResult {
  switch (key.kind) {
    case "char":
      return {
        state: { ...state, buffer: state.buffer + key.value },
        effect: null,
      };

    case "space":
      // Spaces inside commands are literal but uncommon; allow them.
      return {
        state: { ...state, buffer: state.buffer + " " },
        effect: null,
      };

    case "enter": {
      const buffer = state.buffer;
      return {
        state: INITIAL_INPUT_STATE,
        effect: { kind: "run_command", buffer },
      };
    }

    case "backspace":
      if (state.buffer.length === 0) {
        // Backspace on empty command buffer pops back to normal mode.
        return { state: INITIAL_INPUT_STATE, effect: null };
      }
      return {
        state: { ...state, buffer: state.buffer.slice(0, -1) },
        effect: null,
      };

    case "escape":
      return { state: INITIAL_INPUT_STATE, effect: null };
  }
}

function reduceChat(state: InputState, key: Key): InputResult {
  switch (key.kind) {
    case "char":
      // Everything is literal in chat mode — including ':', '/', digits.
      return {
        state: { ...state, buffer: state.buffer + key.value },
        effect: null,
      };

    case "space":
      return {
        state: { ...state, buffer: state.buffer + " " },
        effect: null,
      };

    case "enter": {
      if (state.buffer.length === 0) {
        return { state: INITIAL_INPUT_STATE, effect: null };
      }
      const message = state.buffer;
      return {
        state: INITIAL_INPUT_STATE,
        effect: { kind: "send_chat", message },
      };
    }

    case "backspace":
      if (state.buffer.length === 0) {
        return { state: INITIAL_INPUT_STATE, effect: null };
      }
      return {
        state: { ...state, buffer: state.buffer.slice(0, -1) },
        effect: null,
      };

    case "escape":
      return { state: INITIAL_INPUT_STATE, effect: null };
  }
}

/** React hook wrapping the reducer. */
export function useInputState(
  onEffect: (effect: InputEffect) => void,
): {
  state: InputState;
  handleKey: (key: Key) => void;
  reset: () => void;
} {
  const [state, dispatch] = useReducer(
    (prev: InputState, key: Key): InputState => {
      const { state: next, effect } = reduceInput(prev, key);
      if (effect) onEffect(effect);
      return next;
    },
    INITIAL_INPUT_STATE,
  );

  const handleKey = useCallback((key: Key) => dispatch(key), []);
  const reset = useCallback(
    () => dispatch({ kind: "escape" } as Key),
    [],
  );

  return { state, handleKey, reset };
}

/** Returns the prompt prefix shown to the user for a given mode. */
export function promptPrefix(mode: InputMode): string {
  switch (mode) {
    case "normal":
      return "> ";
    case "command":
      return "> :";
    case "chat":
      return "> /";
  }
}

// Pure command parser. Maps a command-mode buffer to an Action.
// No React, no IO — fully unit-testable.

export type CommandAction =
  | { kind: "enter_chat" }
  | { kind: "challenge"; index: 0 | 1 | 2 }
  | { kind: "vote"; vote: boolean }
  | { kind: "toggle_panel"; panel: "teams" | "hotkeys" | "history" }
  | { kind: "back" }
  | { kind: "react_pirate" }
  | { kind: "react_argh" }
  | { kind: "quit_confirm" }
  | { kind: "quit_immediate" }
  | { kind: "unknown"; raw: string };

const REACT_PHRASES = [
  "nice steal!",
  "well done!",
  "slick!",
  "yarrr!",
] as const;

export function parseCommand(buffer: string): CommandAction {
  const trimmed = buffer.trim();
  switch (trimmed) {
    // Challenge — number alias and letter alias
    case "c":
    case "c1":
    case "1":
      return { kind: "challenge", index: 0 };
    case "c2":
      return { kind: "challenge", index: 1 };
    case "c3":
      return { kind: "challenge", index: 2 };

    // Vote
    case "y":
      return { kind: "vote", vote: true };
    case "n":
      return { kind: "vote", vote: false };

    // Panel swaps
    case "t":
      return { kind: "toggle_panel", panel: "teams" };
    case "h":
      return { kind: "toggle_panel", panel: "history" };
    case "?":
      return { kind: "toggle_panel", panel: "hotkeys" };

    // Quick reactions
    case "o":
      return { kind: "react_pirate" };
    case "!":
      return { kind: "react_argh" };

    // Back (close any open panel on the Playing screen)
    case "b":
    case "back":
      return { kind: "back" };

    // Quit
    case "q":
      return { kind: "quit_confirm" };
    case "qa":
      return { kind: "quit_immediate" };

    default:
      return { kind: "unknown", raw: trimmed };
  }
}

/** Picks a random reaction phrase for `:o`. Pure given the random function. */
export function pickReactionPhrase(rand: () => number = Math.random): string {
  const idx = Math.floor(rand() * REACT_PHRASES.length);
  return REACT_PHRASES[idx] ?? REACT_PHRASES[0]!;
}

export const REACT_PHRASE_LIST = REACT_PHRASES;

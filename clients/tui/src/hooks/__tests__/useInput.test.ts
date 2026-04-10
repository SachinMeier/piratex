import { describe, expect, test } from "vitest";
import {
  INITIAL_INPUT_STATE,
  Key,
  promptPrefix,
  reduceInput,
} from "../useInput.js";

const press = (state = INITIAL_INPUT_STATE) => ({
  char(value: string) {
    return reduceInput(state, { kind: "char", value });
  },
  space() {
    return reduceInput(state, { kind: "space" });
  },
  enter() {
    return reduceInput(state, { kind: "enter" });
  },
  backspace() {
    return reduceInput(state, { kind: "backspace" });
  },
  escape() {
    return reduceInput(state, { kind: "escape" });
  },
});

function applyKeys(keys: Key[]) {
  let state = INITIAL_INPUT_STATE;
  const effects: unknown[] = [];
  for (const k of keys) {
    const { state: next, effect } = reduceInput(state, k);
    state = next;
    if (effect) effects.push(effect);
  }
  return { state, effects };
}

describe("normal mode", () => {
  test("letters lowercase and append", () => {
    const r = press().char("W");
    expect(r.state.buffer).toBe("w");
    expect(r.state.mode).toBe("normal");
    expect(r.effect).toBeNull();
  });

  test("typing builds a word", () => {
    const { state } = applyKeys([
      { kind: "char", value: "w" },
      { kind: "char", value: "h" },
      { kind: "char", value: "A" },
      { kind: "char", value: "l" },
      { kind: "char", value: "e" },
      { kind: "char", value: "s" },
    ]);
    expect(state.buffer).toBe("whales");
    expect(state.mode).toBe("normal");
  });

  test("digits and punctuation are silently ignored", () => {
    const r = press().char("3");
    expect(r.state.buffer).toBe("");

    const r2 = press().char("!");
    expect(r2.state.buffer).toBe("");

    const r3 = press().char(",");
    expect(r3.state.buffer).toBe("");
  });

  test("space fires flip", () => {
    const r = press().space();
    expect(r.effect).toEqual({ kind: "flip_letter" });
    expect(r.state.buffer).toBe("");
  });

  test("space fires flip even with non-empty buffer", () => {
    const start = { mode: "normal" as const, buffer: "wha" };
    const r = press(start).space();
    expect(r.effect).toEqual({ kind: "flip_letter" });
    expect(r.state.buffer).toBe("wha"); // not cleared
  });

  test("enter on non-empty buffer submits word and clears", () => {
    const start = { mode: "normal" as const, buffer: "whales" };
    const r = press(start).enter();
    expect(r.effect).toEqual({ kind: "submit_word", word: "whales" });
    expect(r.state.buffer).toBe("");
  });

  test("enter on empty buffer is a no-op", () => {
    const r = press().enter();
    expect(r.effect).toBeNull();
    expect(r.state).toEqual(INITIAL_INPUT_STATE);
  });

  test(": on empty buffer enters command mode", () => {
    const r = press().char(":");
    expect(r.state.mode).toBe("command");
    expect(r.state.buffer).toBe("");
  });

  test(": on non-empty buffer is ignored", () => {
    const start = { mode: "normal" as const, buffer: "wha" };
    const r = press(start).char(":");
    expect(r.state.mode).toBe("normal");
    expect(r.state.buffer).toBe("wha");
  });

  test("/ on empty buffer enters chat mode", () => {
    const r = press().char("/");
    expect(r.state.mode).toBe("chat");
    expect(r.state.buffer).toBe("");
  });

  test("/ on non-empty buffer is ignored", () => {
    const start = { mode: "normal" as const, buffer: "wha" };
    const r = press(start).char("/");
    expect(r.state.mode).toBe("normal");
    expect(r.state.buffer).toBe("wha");
  });

  test("backspace deletes last char", () => {
    const start = { mode: "normal" as const, buffer: "whales" };
    const r = press(start).backspace();
    expect(r.state.buffer).toBe("whale");
  });

  test("backspace on empty buffer is a no-op", () => {
    const r = press().backspace();
    expect(r.state).toEqual(INITIAL_INPUT_STATE);
  });

  test("esc with empty buffer fires panel_close", () => {
    const r = press().escape();
    expect(r.effect).toEqual({ kind: "panel_close" });
  });

  test("esc clears non-empty buffer", () => {
    const start = { mode: "normal" as const, buffer: "wha" };
    const r = press(start).escape();
    expect(r.state.buffer).toBe("");
    expect(r.effect).toBeNull();
  });
});

describe("command mode", () => {
  const cmd = { mode: "command" as const, buffer: "" };

  test("characters append literally", () => {
    const r = press(cmd).char("c");
    expect(r.state.mode).toBe("command");
    expect(r.state.buffer).toBe("c");
  });

  test("digits append literally", () => {
    const start = { mode: "command" as const, buffer: "c" };
    const r = press(start).char("1");
    expect(r.state.buffer).toBe("c1");
  });

  test("enter dispatches run_command and resets to normal", () => {
    const start = { mode: "command" as const, buffer: "c1" };
    const r = press(start).enter();
    expect(r.effect).toEqual({ kind: "run_command", buffer: "c1" });
    expect(r.state.mode).toBe("normal");
    expect(r.state.buffer).toBe("");
  });

  test("backspace deletes last command char", () => {
    const start = { mode: "command" as const, buffer: "c2" };
    const r = press(start).backspace();
    expect(r.state.mode).toBe("command");
    expect(r.state.buffer).toBe("c");
  });

  test("backspace on empty command buffer pops to normal mode", () => {
    const r = press(cmd).backspace();
    expect(r.state).toEqual(INITIAL_INPUT_STATE);
  });

  test("esc cancels and returns to normal", () => {
    const start = { mode: "command" as const, buffer: "qa" };
    const r = press(start).escape();
    expect(r.state).toEqual(INITIAL_INPUT_STATE);
  });
});

describe("chat mode", () => {
  const chat: import("../useInput.js").InputState = {
    mode: "chat",
    buffer: "",
  };

  test("characters including digits and punctuation append literally", () => {
    let state: import("../useInput.js").InputState = chat;
    for (const c of "Hi 1 :2 / 3!") {
      const r = press(state).char(c);
      state = r.state;
    }
    expect(state.buffer).toBe("Hi 1 :2 / 3!");
  });

  test("space appends literal space", () => {
    const r = press(chat).space();
    expect(r.state.buffer).toBe(" ");
    expect(r.effect).toBeNull();
  });

  test("enter sends and returns to normal", () => {
    const start = { mode: "chat" as const, buffer: "hello world" };
    const r = press(start).enter();
    expect(r.effect).toEqual({ kind: "send_chat", message: "hello world" });
    expect(r.state).toEqual(INITIAL_INPUT_STATE);
  });

  test("enter on empty chat buffer just exits to normal", () => {
    const r = press(chat).enter();
    expect(r.effect).toBeNull();
    expect(r.state).toEqual(INITIAL_INPUT_STATE);
  });

  test("backspace on empty chat buffer pops to normal", () => {
    const r = press(chat).backspace();
    expect(r.state).toEqual(INITIAL_INPUT_STATE);
  });

  test("esc cancels", () => {
    const start = { mode: "chat" as const, buffer: "halfway" };
    const r = press(start).escape();
    expect(r.state).toEqual(INITIAL_INPUT_STATE);
  });
});

describe("promptPrefix", () => {
  test("normal", () => expect(promptPrefix("normal")).toBe("> "));
  test("command", () => expect(promptPrefix("command")).toBe("> :"));
  test("chat", () => expect(promptPrefix("chat")).toBe("> /"));
});

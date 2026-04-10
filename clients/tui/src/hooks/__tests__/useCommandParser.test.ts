import { describe, expect, test } from "vitest";
import {
  parseCommand,
  pickReactionPhrase,
  REACT_PHRASE_LIST,
} from "../useCommandParser.js";

describe("parseCommand", () => {
  test("c, c1, 1 → challenge index 0", () => {
    for (const buf of ["c", "c1", "1"]) {
      expect(parseCommand(buf)).toEqual({ kind: "challenge", index: 0 });
    }
  });

  test("c2 → challenge index 1", () => {
    expect(parseCommand("c2")).toEqual({ kind: "challenge", index: 1 });
  });

  test("c3 → challenge index 2", () => {
    expect(parseCommand("c3")).toEqual({ kind: "challenge", index: 2 });
  });

  test("y / 2 → vote valid", () => {
    expect(parseCommand("y")).toEqual({ kind: "vote", vote: true });
    expect(parseCommand("2")).toEqual({ kind: "vote", vote: true });
  });

  test("n / 7 → vote invalid", () => {
    expect(parseCommand("n")).toEqual({ kind: "vote", vote: false });
    expect(parseCommand("7")).toEqual({ kind: "vote", vote: false });
  });

  test("t / 3 → toggle teams", () => {
    expect(parseCommand("t")).toEqual({ kind: "toggle_panel", panel: "teams" });
    expect(parseCommand("3")).toEqual({ kind: "toggle_panel", panel: "teams" });
  });

  test("h → toggle history", () => {
    expect(parseCommand("h")).toEqual({
      kind: "toggle_panel",
      panel: "history",
    });
  });

  test("? / 0 → toggle hotkeys", () => {
    expect(parseCommand("?")).toEqual({
      kind: "toggle_panel",
      panel: "hotkeys",
    });
    expect(parseCommand("0")).toEqual({
      kind: "toggle_panel",
      panel: "hotkeys",
    });
  });

  test("z / 8 → zen", () => {
    expect(parseCommand("z")).toEqual({ kind: "toggle_zen" });
    expect(parseCommand("8")).toEqual({ kind: "toggle_zen" });
  });

  test("o → react pirate", () => {
    expect(parseCommand("o")).toEqual({ kind: "react_pirate" });
  });

  test("! → react argh", () => {
    expect(parseCommand("!")).toEqual({ kind: "react_argh" });
  });

  test("q → quit_confirm", () => {
    expect(parseCommand("q")).toEqual({ kind: "quit_confirm" });
  });

  test("qa → quit_immediate", () => {
    expect(parseCommand("qa")).toEqual({ kind: "quit_immediate" });
  });

  test("unknown commands return unknown action", () => {
    expect(parseCommand("asdf")).toEqual({ kind: "unknown", raw: "asdf" });
    expect(parseCommand("foo")).toEqual({ kind: "unknown", raw: "foo" });
  });

  test("trims leading and trailing whitespace", () => {
    expect(parseCommand("  c1  ")).toEqual({ kind: "challenge", index: 0 });
  });
});

describe("pickReactionPhrase", () => {
  test("returns one of the react phrases", () => {
    const phrase = pickReactionPhrase(() => 0);
    expect(REACT_PHRASE_LIST).toContain(phrase);
  });

  test("indexing is deterministic with given rand fn", () => {
    expect(pickReactionPhrase(() => 0)).toBe(REACT_PHRASE_LIST[0]);
    expect(pickReactionPhrase(() => 0.99)).toBe(
      REACT_PHRASE_LIST[REACT_PHRASE_LIST.length - 1],
    );
  });
});

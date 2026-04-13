import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { parseCliArgs } from "../config.js";

const ORIGINAL_ENV = { ...process.env };

beforeEach(() => {
  delete process.env["PIRATEX_USERNAME"];
  delete process.env["PIRATEX_SERVER"];
});

afterEach(() => {
  process.env = { ...ORIGINAL_ENV };
});

describe("parseCliArgs", () => {
  test("defaults: no game id, no default username", () => {
    const cli = parseCliArgs(["node", "piratex"]);
    expect(cli.gameId).toBeNull();
    expect(cli.defaultUsername).toBeNull();
    expect(cli.server.socketUrl).toBe("wss://piratescrabble.com/socket");
  });

  test("positional arg becomes gameId (uppercased)", () => {
    const cli = parseCliArgs(["node", "piratex", "abc1234"]);
    expect(cli.gameId).toBe("ABC1234");
  });

  test("PIRATEX_USERNAME is exposed as defaultUsername", () => {
    process.env["PIRATEX_USERNAME"] = "sachin";
    const cli = parseCliArgs(["node", "piratex"]);
    expect(cli.defaultUsername).toBe("sachin");
  });

  test("whitespace-only PIRATEX_USERNAME is treated as unset", () => {
    process.env["PIRATEX_USERNAME"] = "   ";
    const cli = parseCliArgs(["node", "piratex"]);
    expect(cli.defaultUsername).toBeNull();
  });

  test("PIRATEX_USERNAME is trimmed", () => {
    process.env["PIRATEX_USERNAME"] = "  sachin  ";
    const cli = parseCliArgs(["node", "piratex"]);
    expect(cli.defaultUsername).toBe("sachin");
  });

  test("game id + PIRATEX_USERNAME together", () => {
    process.env["PIRATEX_USERNAME"] = "sachin";
    const cli = parseCliArgs(["node", "piratex", "abc1234"]);
    expect(cli.gameId).toBe("ABC1234");
    expect(cli.defaultUsername).toBe("sachin");
  });

  test("--server flag is not captured as gameId", () => {
    const cli = parseCliArgs([
      "node",
      "piratex",
      "--server",
      "http://localhost:4001",
    ]);
    expect(cli.gameId).toBeNull();
    expect(cli.server.httpUrl).toBe("http://localhost:4001");
  });

  test("--server=URL style", () => {
    const cli = parseCliArgs([
      "node",
      "piratex",
      "--server=http://localhost:4001",
      "abc1234",
    ]);
    expect(cli.gameId).toBe("ABC1234");
    expect(cli.server.httpUrl).toBe("http://localhost:4001");
  });
});

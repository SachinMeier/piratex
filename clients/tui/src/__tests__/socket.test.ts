import { describe, expect, test } from "vitest";

import {
  parseProtocolMismatch,
  ProtocolMismatchError,
} from "../socket.js";

describe("parseProtocolMismatch", () => {
  test("maps :client_outdated reply to a ProtocolMismatchError with all fields", () => {
    const err = parseProtocolMismatch({
      reason: "client_outdated",
      severity: "hard",
      server_version: "1.4",
      client_version: "1.2",
      upgrade_url: "https://example.test/releases/latest",
    });

    expect(err).toBeInstanceOf(ProtocolMismatchError);
    expect(err?.reason).toBe("client_outdated");
    expect(err?.severity).toBe("hard");
    expect(err?.serverVersion).toBe("1.4");
    expect(err?.clientVersion).toBe("1.2");
    expect(err?.upgradeUrl).toBe("https://example.test/releases/latest");
  });

  test("maps :server_outdated reply, with no upgrade_url", () => {
    const err = parseProtocolMismatch({
      reason: "server_outdated",
      severity: "hard",
      server_version: "1.1",
      client_version: "1.3",
    });

    expect(err).toBeInstanceOf(ProtocolMismatchError);
    expect(err?.reason).toBe("server_outdated");
    expect(err?.serverVersion).toBe("1.1");
    expect(err?.clientVersion).toBe("1.3");
    expect(err?.upgradeUrl).toBeUndefined();
  });

  test("returns null for unrelated reasons", () => {
    expect(parseProtocolMismatch({ reason: "not_found" })).toBeNull();
    expect(parseProtocolMismatch({ reason: "watch_only" })).toBeNull();
    expect(parseProtocolMismatch({ reason: "invalid_intent" })).toBeNull();
  });

  test("returns null for non-object / null / primitive payloads", () => {
    expect(parseProtocolMismatch(null)).toBeNull();
    expect(parseProtocolMismatch(undefined)).toBeNull();
    expect(parseProtocolMismatch("client_outdated")).toBeNull();
    expect(parseProtocolMismatch(42)).toBeNull();
  });

  test("coerces missing string fields to empty strings without throwing", () => {
    const err = parseProtocolMismatch({
      reason: "client_outdated",
    });

    expect(err).toBeInstanceOf(ProtocolMismatchError);
    expect(err?.serverVersion).toBe("");
    expect(err?.clientVersion).toBe("");
    expect(err?.upgradeUrl).toBeUndefined();
  });

  test("ignores non-string upgrade_url", () => {
    const err = parseProtocolMismatch({
      reason: "client_outdated",
      server_version: "1.4",
      client_version: "1.0",
      upgrade_url: 123,
    });

    expect(err?.upgradeUrl).toBeUndefined();
  });
});

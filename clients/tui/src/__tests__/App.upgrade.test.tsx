// End-to-end routing: App should render UpgradePrompt whenever the game
// context reports upgradeRequired, and a subtle banner above the screen
// when only upgradeAvailable is set.
import React from "react";
import { describe, expect, test } from "vitest";
import { render } from "ink-testing-library";

import { App } from "../app.js";
import {
  GameContext,
  GameContextValue,
  UpgradeRequired,
} from "../game-provider.js";

function makeContext(overrides: Partial<GameContextValue>): GameContextValue {
  const noop = () => {};
  const asyncNoop = async () => {};
  return {
    session: null,
    gameState: null,
    toast: null,
    upgradeAvailable: false,
    upgradeRequired: null,
    startSession: asyncNoop,
    quitSession: asyncNoop,
    tearDownSession: noop,
    push: async () => ({}) as never,
    showToast: noop,
    dismissToast: noop,
    api: {} as GameContextValue["api"],
    ...overrides,
  };
}

function renderApp(ctx: GameContextValue) {
  return render(
    <GameContext.Provider value={ctx}>
      <App initialGameId={null} />
    </GameContext.Provider>,
  );
}

describe("App version-mismatch routing", () => {
  test("renders UpgradePrompt when upgradeRequired is set (hard mismatch)", () => {
    const upgradeRequired: UpgradeRequired = {
      reason: "client_outdated",
      serverVersion: "2.0",
      clientVersion: "1.5",
      upgradeUrl: "https://example.test/upgrade",
    };
    const { lastFrame } = renderApp(makeContext({ upgradeRequired }));
    const frame = lastFrame() ?? "";

    expect(frame).toContain("piratex needs to be upgraded");
    expect(frame).toContain("your version: 1.5");
    expect(frame).toContain("server version: 2.0");
    expect(frame).toContain("https://example.test/upgrade");
    // The home menu MUST NOT render underneath the upgrade prompt.
    expect(frame).not.toContain("create game");
  });

  test("renders the soft banner when only upgradeAvailable is set", () => {
    const { lastFrame } = renderApp(makeContext({ upgradeAvailable: true }));
    const frame = lastFrame() ?? "";

    expect(frame).toContain("upgrade available");
    // The soft banner must NOT hijack the screen the way the hard prompt does.
    expect(frame).not.toContain("piratex needs to be upgraded");
  });

  test("hides the soft banner when a hard upgrade prompt is taking over", () => {
    const upgradeRequired: UpgradeRequired = {
      reason: "server_outdated",
      serverVersion: "1.1",
      clientVersion: "1.3",
    };
    const { lastFrame } = renderApp(
      makeContext({ upgradeAvailable: true, upgradeRequired }),
    );
    const frame = lastFrame() ?? "";

    expect(frame).toContain("piratex needs to be upgraded");
    expect(frame).not.toContain("upgrade available — see :about");
  });

  test("no banner and no prompt when neither flag is set", () => {
    const { lastFrame } = renderApp(makeContext({}));
    const frame = lastFrame() ?? "";

    expect(frame).not.toContain("piratex needs to be upgraded");
    expect(frame).not.toContain("upgrade available");
  });
});

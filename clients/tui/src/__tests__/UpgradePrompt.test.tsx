import React from "react";
import { describe, expect, test } from "vitest";
import { render } from "ink-testing-library";

import { UpgradePrompt } from "../menus/UpgradePrompt.js";

describe("UpgradePrompt", () => {
  test("renders both versions, the install hint, and the upgrade url", () => {
    const { lastFrame } = render(
      <UpgradePrompt
        serverVersion="1.4"
        clientVersion="1.2"
        upgradeUrl="https://example.test/releases/latest"
      />,
    );

    const frame = lastFrame() ?? "";
    expect(frame).toContain("piratex needs to be upgraded");
    expect(frame).toContain("your version: 1.2");
    expect(frame).toContain("server version: 1.4");
    expect(frame).toContain("install.sh");
    expect(frame).toContain("https://example.test/releases/latest");
    expect(frame).toContain("[q] quit");
  });

  test("falls back to the default upgrade url when none provided", () => {
    const { lastFrame } = render(
      <UpgradePrompt serverVersion="2.0" clientVersion="1.0" />,
    );

    expect(lastFrame() ?? "").toContain(
      "https://github.com/SachinMeier/piratex/releases/latest",
    );
  });
});

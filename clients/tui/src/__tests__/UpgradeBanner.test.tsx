import React from "react";
import { describe, expect, test } from "vitest";
import { render } from "ink-testing-library";

import { UpgradeBanner } from "../components/UpgradeBanner.js";

describe("UpgradeBanner", () => {
  test("shows the soft upgrade hint", () => {
    const { lastFrame } = render(<UpgradeBanner />);
    const frame = lastFrame() ?? "";
    expect(frame).toContain("upgrade available");
    expect(frame).toContain(":about");
  });
});

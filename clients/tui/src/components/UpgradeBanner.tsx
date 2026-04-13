// Soft upgrade banner: server reported that our minor version is behind.
// The session still joined successfully, so we render a single-line yellow
// hint instead of blocking the UI like UpgradePrompt does for hard
// mismatches.
import React from "react";
import { Box, Text } from "ink";

export function UpgradeBanner() {
  return (
    <Box justifyContent="center">
      <Text color="yellow">⚠ upgrade available — see :about</Text>
    </Box>
  );
}

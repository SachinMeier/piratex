// Hard protocol-mismatch screen.
import React from "react";
import { Box, Text, useApp, useInput as useInkInput } from "ink";

interface UpgradePromptProps {
  serverVersion: string;
  clientVersion: string;
  upgradeUrl?: string;
}

export function UpgradePrompt({
  serverVersion,
  clientVersion,
  upgradeUrl = "https://github.com/SachinMeier/piratex/releases/latest",
}: UpgradePromptProps) {
  const { exit } = useApp();

  useInkInput((rawInput) => {
    if (rawInput === "q" || rawInput === "Q") exit();
  });

  return (
    <Box flexDirection="column" flexGrow={1} justifyContent="center">
      <Box justifyContent="center">
        <Text bold color="yellow">
          ⚠ piratex needs to be upgraded
        </Text>
      </Box>
      <Box justifyContent="center" marginTop={1}>
        <Text>your version: {clientVersion}</Text>
      </Box>
      <Box justifyContent="center">
        <Text>server version: {serverVersion}</Text>
      </Box>
      <Box justifyContent="center" marginTop={1}>
        <Text>install the latest:</Text>
      </Box>
      <Box justifyContent="center">
        <Text color="cyan">
          curl -fsSL https://raw.githubusercontent.com/SachinMeier/piratex/main/clients/tui/install.sh | sh
        </Text>
      </Box>
      <Box justifyContent="center" marginTop={1}>
        <Text dimColor>{upgradeUrl}</Text>
      </Box>
      <Box justifyContent="center" marginTop={1}>
        <Text dimColor>[q] quit</Text>
      </Box>
    </Box>
  );
}

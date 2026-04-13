// Static about text. Single page.
import React from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import { useBottomCommand } from "../hooks/useBottomCommand.js";
import { useQuitApp } from "../hooks/useQuitApp.js";
import { BottomCommandBar } from "../components/BottomCommandBar.js";

interface AboutTextProps {
  onCancel(): void;
}

export function AboutText({ onCancel }: AboutTextProps) {
  const quitApp = useQuitApp();
  const bottom = useBottomCommand({
    q: quitApp,
    qa: quitApp,
    b: onCancel,
    back: onCancel,
  });

  useInkInput((rawInput, key) => {
    if (bottom.commandMode) return;
    if (key.escape || rawInput === "q" || rawInput === "Q") {
      onCancel();
    }
  });

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE — ABOUT
        </Text>
      </Box>

      <Box flexGrow={1} flexDirection="column" paddingX={4} paddingY={1}>
        <Text>
          Pirate Scrabble is a real-time multiplayer word game where players
          compete to create and steal words from a shared pool of letters.
        </Text>
        <Text> </Text>
        <Text>This is the terminal client.</Text>
        <Text> </Text>
        <Text>Source: https://github.com/SachinMeier/piratex</Text>
        <Text>Web client: https://piratescrabble.com</Text>
        <Text> </Text>
        <Text dimColor>
          The game is taught by passing it from player to player. The author
          learned it from a friend named Nick. Origin uncertain.
        </Text>
      </Box>

      <BottomCommandBar
        commandMode={bottom.commandMode}
        buffer={bottom.buffer}
        hint=":b back  ·  :q quit  ·  :? help"
      />
    </Box>
  );
}

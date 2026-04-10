import React from "react";
import { Box, Text, useApp } from "ink";
import { VimSelect, VimSelectItem } from "../components/VimSelect.js";

type HomeChoice = "create" | "find" | "watch" | "rules" | "about" | "quit";

interface HomeMenuProps {
  onChoice(choice: Exclude<HomeChoice, "quit">): void;
}

const ITEMS: readonly VimSelectItem<HomeChoice>[] = [
  { label: "New Game", value: "create" },
  { label: "Join Game", value: "find" },
  { label: "Watch Game", value: "watch" },
  { label: "Rules", value: "rules" },
  { label: "About", value: "about" },
  { label: "Quit", value: "quit" },
];

export function HomeMenu({ onChoice }: HomeMenuProps) {
  const { exit } = useApp();

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE
        </Text>
      </Box>

      <Box flexGrow={1} />

      <Box justifyContent="center">
        <Box flexDirection="column" paddingX={4}>
          <VimSelect
            items={ITEMS}
            onSelect={(item) => {
              if (item.value === "quit") {
                exit();
                return;
              }
              onChoice(item.value);
            }}
          />
        </Box>
      </Box>

      <Box flexGrow={1} />

      <Box justifyContent="center">
        <Text dimColor>j/k to move · enter or l to select</Text>
      </Box>
    </Box>
  );
}

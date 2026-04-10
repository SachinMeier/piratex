import React from "react";
import { Box, Text, useApp } from "ink";
import SelectInput from "ink-select-input";

interface HomeMenuProps {
  onChoice(
    choice: "create" | "find" | "watch" | "rules" | "about",
  ): void;
}

const ITEMS = [
  { label: "New Game", value: "create" as const },
  { label: "Join Game", value: "find" as const },
  { label: "Watch Game", value: "watch" as const },
  { label: "Rules", value: "rules" as const },
  { label: "About", value: "about" as const },
  { label: "Quit", value: "quit" as const },
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
          <SelectInput
            items={ITEMS as any}
            onSelect={(item: { value: string }) => {
              if (item.value === "quit") {
                exit();
                return;
              }
              onChoice(item.value as Parameters<HomeMenuProps["onChoice"]>[0]);
            }}
          />
        </Box>
      </Box>

      <Box flexGrow={1} />

      <Box justifyContent="center">
        <Text dimColor>arrow keys to navigate, enter to select</Text>
      </Box>
    </Box>
  );
}

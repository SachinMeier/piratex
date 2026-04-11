// Simple bordered title bar used by most non-home screens. The home
// screen uses TitleTiles instead (tiles for each letter of "PIRATE
// SCRABBLE"), but subtitle pages like "— CREATE GAME" or "— RULES" use
// this plainer bordered bar.
import React from "react";
import { Box, Text } from "ink";

interface TitleBarProps {
  text: string;
}

export function TitleBar({ text }: TitleBarProps) {
  return (
    <Box justifyContent="center" borderStyle="round" borderColor="gray">
      <Text bold color="cyan">
        {text}
      </Text>
    </Box>
  );
}

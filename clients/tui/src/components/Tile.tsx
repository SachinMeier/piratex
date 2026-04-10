// Single letter rendered as a small box.
import React from "react";
import { Box, Text } from "ink";

interface TileProps {
  letter: string;
  highlight?: boolean;
}

export function Tile({ letter, highlight = false }: TileProps) {
  const ch = (letter ?? "").toUpperCase();
  return (
    <Box
      borderStyle="round"
      borderColor={highlight ? "cyan" : "gray"}
      paddingX={1}
      marginRight={1}
    >
      <Text bold color={highlight ? "cyan" : "white"}>
        {ch}
      </Text>
    </Box>
  );
}

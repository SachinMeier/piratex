// The center pool of letters.
//
// Rendered as box-bordered tiles (one Tile component per letter). The
// Playing screen wraps Center inside a flex-grow middle region so that
// even though each tile is three lines tall, the overall layout stays
// anchored to the top and bottom of the terminal viewport.
import React from "react";
import { Box, Text } from "ink";
import { Tile } from "./Tile.js";

interface CenterProps {
  center: string[];
}

export function Center({ center }: CenterProps) {
  if (center.length === 0) {
    return (
      <Box paddingX={2} paddingY={1}>
        <Text dimColor italic>
          (no letters in center yet)
        </Text>
      </Box>
    );
  }

  return (
    <Box paddingX={2} paddingY={0} flexWrap="wrap">
      {center.map((letter, idx) => (
        <Tile key={idx} letter={letter} />
      ))}
    </Box>
  );
}

// The center pool of letters.
//
// Height-stable: each letter renders as a single-row inverse cell so a
// full 144-letter pool takes predictable vertical space (~3-4 rows at
// 80 columns) instead of the ~15+ rows that the old 3-line box-drawn
// tiles produced. This keeps the overall layout from jumping around as
// letters are flipped.
import React from "react";
import { Box, Text } from "ink";

interface CenterProps {
  center: string[];
}

export function Center({ center }: CenterProps) {
  if (center.length === 0) {
    return (
      <Box paddingX={2} paddingY={1} borderStyle="round" borderColor="gray">
        <Text dimColor italic>
          (no letters in center yet)
        </Text>
      </Box>
    );
  }

  return (
    <Box
      paddingX={2}
      paddingY={1}
      borderStyle="round"
      borderColor="gray"
      flexWrap="wrap"
    >
      {center.map((letter, idx) => (
        <Box key={idx} marginRight={1}>
          <Text bold inverse color="cyan">
            {" "}
            {letter.toUpperCase()}{" "}
          </Text>
        </Box>
      ))}
    </Box>
  );
}

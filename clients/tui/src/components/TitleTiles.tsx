// Renders a title string as a row of bordered tiles, one per letter.
// Spaces become gaps between word groups. Used for the home-screen title.
import React from "react";
import { Box, Text } from "ink";

interface TitleTilesProps {
  text: string;
}

export function TitleTiles({ text }: TitleTilesProps) {
  const chars = text.toUpperCase().split("");
  return (
    <Box>
      {chars.map((char, i) => {
        if (char === " ") {
          return <Box key={i} width={2} />;
        }
        return (
          <Box
            key={i}
            borderStyle="round"
            borderColor="cyan"
            paddingX={1}
          >
            <Text bold color="cyan">
              {char}
            </Text>
          </Box>
        );
      })}
    </Box>
  );
}

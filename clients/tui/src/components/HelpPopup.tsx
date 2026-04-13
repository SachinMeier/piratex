// Shared bordered popup used for the `:?` help panels across every
// non-playing screen. Gives the panels a consistent look (rounded gray
// border, 56-column width, centered bold-cyan title, 1 row of bottom
// padding via marginBottom).
import React from "react";
import { Box, Text } from "ink";

interface HelpPopupProps {
  title: string;
  children: React.ReactNode;
}

export function HelpPopup({ title, children }: HelpPopupProps) {
  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor="gray"
      paddingX={2}
      width={56}
      marginBottom={1}
    >
      <Box justifyContent="center" marginBottom={1}>
        <Text bold color="cyan">
          {title}
        </Text>
      </Box>
      {children}
    </Box>
  );
}

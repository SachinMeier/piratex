// Bottom command bar shown on every non-Playing screen. Mirrors Claude
// Code's input-at-the-bottom layout: a one-line entry field with a
// hint/status line underneath.
//
// Visual states:
//
//   idle      →   > _                                  (inverse cursor cell)
//   command   →   > :buf_                              (prompted command)
//
// The bar does not manage its own state — the parent screen drives it
// via useBottomCommand and passes the resulting flags in.
import React from "react";
import { Box, Text } from "ink";

interface BottomCommandBarProps {
  commandMode: boolean;
  buffer: string;
  hint?: string;
  /** When true, show a subtle "start typing : for commands" placeholder. */
  idlePlaceholder?: string;
}

export function BottomCommandBar({
  commandMode,
  buffer,
  hint,
  idlePlaceholder,
}: BottomCommandBarProps) {
  return (
    <Box flexDirection="column" flexShrink={0}>
      <Box paddingX={2}>
        <Text color={commandMode ? "cyan" : undefined}>
          {commandMode ? "> :" : "> "}
        </Text>
        <Text>{commandMode ? buffer : ""}</Text>
        <Text inverse> </Text>
        {!commandMode && idlePlaceholder && (
          <>
            <Text>{"   "}</Text>
            <Text dimColor italic>
              {idlePlaceholder}
            </Text>
          </>
        )}
      </Box>
      {hint && (
        <Box paddingX={2}>
          <Text dimColor>{hint}</Text>
        </Box>
      )}
    </Box>
  );
}

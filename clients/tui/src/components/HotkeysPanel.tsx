// Static reference panel — shown via :? / :0 swap.
import React from "react";
import { Box, Text } from "ink";

const HOTKEYS: Array<[string, string]> = [
  ["letters", "build a word"],
  ["enter", "submit word / send chat / run command"],
  ["space", "flip a letter / end-game vote"],
  [":", "enter command mode"],
  ["/", "enter chat mode (one-shot)"],
  ["esc", "clear input / close panel"],
  ["", ""],
  [":c / :c1 / :1", "challenge most recent word"],
  [":c2 / :c3", "challenge 2nd / 3rd most recent"],
  [":y / :2", "vote valid"],
  [":n / :7", "vote invalid"],
  [":t / :3", "toggle teams panel"],
  [":h", "toggle history panel"],
  [":? / :0", "toggle this panel"],
  [":z / :8", "toggle zen mode"],
  [":o", "send a quick reaction"],
  [":!", "send 'argh!' to chat"],
  [":q", "quit (with confirm)"],
  [":qa", "quit immediately"],
];

export function HotkeysPanel() {
  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor="cyan"
      paddingX={1}
      flexGrow={1}
    >
      <Box justifyContent="center">
        <Text bold color="cyan">
          HOTKEYS
        </Text>
      </Box>
      {HOTKEYS.map(([key, desc], idx) => (
        <Text key={idx}>
          <Text bold color={key ? "yellow" : undefined}>
            {key.padEnd(16)}
          </Text>
          <Text>{desc}</Text>
        </Text>
      ))}
    </Box>
  );
}

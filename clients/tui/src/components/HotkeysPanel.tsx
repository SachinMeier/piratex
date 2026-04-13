// Static reference panel — shown via :? swap.
import React from "react";
import { Box, Text } from "ink";

type Row = { section: string } | { key: string; desc: string };

const ROWS: Row[] = [
  { section: "MAIN" },
  { key: "space", desc: "flip a letter / end-game vote" },
  { key: ":", desc: "enter command mode" },
  { key: "esc", desc: "clear input / close panel" },

  { section: "CHALLENGES" },
  { key: ":c / :c1 / :1", desc: "challenge most recent word" },
  { key: ":c2 / :c3", desc: "challenge 2nd / 3rd most recent" },
  { key: ":y", desc: "vote valid on the open challenge" },
  { key: ":n", desc: "vote invalid on the open challenge" },

  { section: "CHAT" },
  { key: "/", desc: "enter chat mode" },
  { key: ":o", desc: "send a quick reaction" },
  { key: ":!", desc: "send 'argh!' to chat" },

  { section: "OTHER" },
  { key: ":t", desc: "toggle teams panel" },
  { key: ":h", desc: "toggle history panel" },
  { key: ":?", desc: "toggle this hotkeys panel" },
  { key: ":q", desc: "quit (with confirm)" },
  { key: ":qa", desc: "quit immediately, no confirm" },
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
      {ROWS.map((row, idx) => {
        if ("section" in row) {
          return (
            <Box key={idx} marginTop={idx === 0 ? 0 : 1}>
              <Text bold color="cyan">
                {row.section}
              </Text>
            </Box>
          );
        }
        return (
          <Text key={idx}>
            <Text> </Text>
            <Text bold color="yellow">
              {row.key.padEnd(16)}
            </Text>
            <Text>{row.desc}</Text>
          </Text>
        );
      })}
    </Box>
  );
}

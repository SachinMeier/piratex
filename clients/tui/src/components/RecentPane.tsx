// Three-row "recent" pane: latest word steals with their challenge labels.
// Replaces the old detailed history pane in the regular playing layout.
import React from "react";
import { Box, Text } from "ink";
import { WordSteal } from "../contract.js";

interface RecentPaneProps {
  history: WordSteal[];
  challengeable: boolean[];
  width?: number;
  maxLabelChars?: number;
}

const ROWS = 3;

export function RecentPane({
  history,
  challengeable,
  width = 18,
  maxLabelChars = 8,
}: RecentPaneProps) {
  const padded: (WordSteal | null)[] = [];
  for (let i = 0; i < ROWS; i++) {
    padded.push(history[i] ?? null);
  }

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor="gray"
      paddingX={1}
      width={width}
    >
      <Text bold color="gray">
        recent
      </Text>
      {padded.map((entry, idx) => {
        if (!entry) {
          return <Text key={idx}>{" "}</Text>;
        }
        const can = challengeable[idx] === true;
        const label = `:c${idx + 1}`;
        const word = ellipsize(entry.thief_word.toUpperCase(), maxLabelChars);
        return (
          <Text key={idx}>
            <Text color={can ? "yellow" : "gray"} dimColor={!can}>
              {label}
            </Text>
            <Text> </Text>
            <Text color={can ? "white" : "gray"} dimColor={!can}>
              {word}
            </Text>
          </Text>
        );
      })}
    </Box>
  );
}

function ellipsize(text: string, max: number): string {
  if (text.length <= max) return text;
  if (max <= 1) return "…";
  return text.slice(0, max - 1) + "…";
}

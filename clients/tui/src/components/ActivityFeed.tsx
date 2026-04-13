// Rolling activity feed: shows the most recent N entries from state.activity_feed.
// Server already trims to 20, so the client just slices the tail to fit.
import React from "react";
import { Box, Text } from "ink";
import { ActivityEntry } from "../contract.js";

interface ActivityFeedProps {
  entries: ActivityEntry[];
  maxRows?: number;
  width?: number;
}

export function ActivityFeed({
  entries,
  maxRows = 4,
  width,
}: ActivityFeedProps) {
  const tail = entries.slice(-maxRows);

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor="gray"
      paddingX={1}
      width={width}
      flexGrow={width ? 0 : 1}
    >
      <Text bold color="gray">
        activity
      </Text>
      {tail.length === 0 ? (
        <Text dimColor>—</Text>
      ) : (
        tail.map((entry) => (
          <Text key={entry.id} color={colorFor(entry)}>
            {formatEntry(entry)}
          </Text>
        ))
      )}
    </Box>
  );
}

function colorFor(entry: ActivityEntry): string | undefined {
  if (entry.type === "player_message") return "white";
  if (entry.event_kind === "challenge_resolved") return "yellow";
  if (entry.event_kind === "player_quit") return "red";
  return "gray";
}

function formatEntry(entry: ActivityEntry): string {
  const time = formatTime(entry.inserted_at);
  if (entry.type === "player_message" && entry.player_name) {
    return `${time} ${entry.player_name}: ${entry.body}`;
  }
  return `${time} ${entry.body}`;
}

function formatTime(iso: string): string {
  try {
    const d = new Date(iso);
    const hh = d.getHours().toString().padStart(2, "0");
    const mm = d.getMinutes().toString().padStart(2, "0");
    return `${hh}:${mm}`;
  } catch {
    return "--:--";
  }
}

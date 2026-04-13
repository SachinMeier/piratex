// Full history panel — shown via :h panel swap.
// Displays every word steal with thief, victim, and team info.
import React from "react";
import { Box, Text } from "ink";
import { PlayerSummary, Team, WordSteal } from "../contract.js";

interface HistoryPanelProps {
  history: WordSteal[];
  teams: Team[];
  players: PlayerSummary[];
}

export function HistoryPanel({ history, teams, players }: HistoryPanelProps) {
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
          HISTORY
        </Text>
      </Box>
      {history.length === 0 ? (
        <Text dimColor>no word steals yet</Text>
      ) : (
        history.slice(0, 12).map((ws, idx) => {
          const thiefTeam = teams[ws.thief_team_idx]?.name ?? "?";
          const thiefPlayer = players[ws.thief_player_idx]?.name ?? "?";
          const arrow = ws.victim_word
            ? `${ws.victim_word.toUpperCase()} → ${ws.thief_word.toUpperCase()}`
            : `(center) → ${ws.thief_word.toUpperCase()}`;
          return (
            <Text key={idx}>
              <Text color="white">{arrow}</Text>
              <Text dimColor>
                {"  "}
                {thiefPlayer} ({thiefTeam})
              </Text>
            </Text>
          );
        })
      )}
    </Box>
  );
}

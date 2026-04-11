// One team's word area. Used inside the playing screen team grid.
//
// Each team gets a hardcoded color from TEAM_PALETTE cycled by index,
// so the border + header match visually. The current player's team is
// additionally marked with a cyan cursor glyph in the header.
import React from "react";
import { Box, Text } from "ink";
import { Team } from "../contract.js";

// Hardcoded palette, one entry per team index (up to Config.max_teams = 6).
// Picked to be visually distinct on both light and dark terminals.
const TEAM_PALETTE = [
  "cyan",
  "magenta",
  "yellow",
  "green",
  "red",
  "blue",
] as const;

export function teamColor(teamIndex: number): string {
  if (teamIndex < 0) return "white";
  return TEAM_PALETTE[teamIndex % TEAM_PALETTE.length]!;
}

interface TeamPanelProps {
  team: Team;
  teamIndex: number;
  isMyTeam: boolean;
  hasActivePlayers: boolean;
  width?: number;
}

export function TeamPanel({
  team,
  teamIndex,
  isMyTeam,
  hasActivePlayers,
  width = 18,
}: TeamPanelProps) {
  const color = teamColor(teamIndex);
  const showEmpty = team.words.length === 0;

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor={color}
      paddingX={1}
      width={width}
      marginRight={1}
    >
      <Box justifyContent="center">
        <Text bold color={color}>
          {isMyTeam ? "▸ " : ""}
          {team.name} ({team.words.length})
        </Text>
      </Box>
      {showEmpty && !hasActivePlayers ? (
        <Text dimColor>no active players</Text>
      ) : showEmpty ? (
        <Text dimColor>—</Text>
      ) : (
        team.words.map((word) => (
          <Text key={word} color="white">
            {word.toUpperCase()}
          </Text>
        ))
      )}
    </Box>
  );
}

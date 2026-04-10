// One team's word area. Used inside the playing screen team grid.
import React from "react";
import { Box, Text } from "ink";
import { Team } from "../contract.js";

interface TeamPanelProps {
  team: Team;
  isMyTeam: boolean;
  hasActivePlayers: boolean;
  width?: number;
}

export function TeamPanel({
  team,
  isMyTeam,
  hasActivePlayers,
  width = 18,
}: TeamPanelProps) {
  const borderColor = isMyTeam ? "cyan" : "gray";
  const showEmpty = team.words.length === 0;

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor={borderColor}
      paddingX={1}
      width={width}
      marginRight={1}
    >
      <Box justifyContent="center">
        <Text bold color={borderColor}>
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

// Full teams roster panel — shown via :t / :3 swap.
import React from "react";
import { Box, Text } from "ink";
import { Team } from "../contract.js";

interface TeamsPanelProps {
  teams: Team[];
  playersTeams: Record<string, number>;
  myTeamId: number | null;
}

export function TeamsPanel({ teams, playersTeams, myTeamId }: TeamsPanelProps) {
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
          TEAMS
        </Text>
      </Box>
      {teams.map((team) => {
        const members = Object.entries(playersTeams)
          .filter(([_, tid]) => tid === team.id)
          .map(([name]) => name);
        const isMine = team.id === myTeamId;
        return (
          <Box key={team.id} flexDirection="column" marginTop={1}>
            <Text bold color={isMine ? "cyan" : "white"}>
              {isMine ? "▶ " : "  "}
              {team.name} ({members.length})
            </Text>
            <Text>   {members.length > 0 ? members.join(", ") : "—"}</Text>
          </Box>
        );
      })}
    </Box>
  );
}

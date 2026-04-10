// Read-only spectator view. Reuses some of the playing layout but has no
// input box and no commands except :q to leave.

import React from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import { GameState } from "../contract.js";
import { Center } from "../components/Center.js";
import { TeamPanel } from "../components/TeamPanel.js";
import { ActivityFeed } from "../components/ActivityFeed.js";
import { RecentPane } from "../components/RecentPane.js";
import { ChallengePanel } from "../components/ChallengePanel.js";
import { StatusBar } from "../components/StatusBar.js";
import { useGame } from "../game-provider.js";
import { computeChallengeableHistory, teamHasActivePlayers } from "../derived.js";

interface WatchProps {
  state: GameState;
}

export function Watch({ state }: WatchProps) {
  const game = useGame();
  const challengeable = computeChallengeableHistory(state);
  const challengeOpen = state.challenges.length > 0;

  useInkInput((rawInput, key) => {
    if (rawInput === "q" || rawInput === "Q" || key.escape) {
      game.tearDownSession();
    }
  });

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE — WATCH MODE
        </Text>
      </Box>

      {challengeOpen ? (
        <ChallengePanel
          challenge={state.challenges[0]!}
          myName=""
          challengeTimeoutMs={120000}
          firstSeenAt={Date.now()}
        />
      ) : (
        <Center center={state.center} />
      )}

      <Box marginY={1}>
        {state.teams.map((team) => (
          <TeamPanel
            key={team.id}
            team={team}
            isMyTeam={false}
            hasActivePlayers={teamHasActivePlayers(state, team.id)}
          />
        ))}
      </Box>

      <Box flexGrow={1}>
        <ActivityFeed entries={state.activity_feed} />
        <Box marginLeft={1}>
          <RecentPane history={state.history} challengeable={challengeable} />
        </Box>
      </Box>

      <Box marginTop={1}>
        <Text dimColor>watching · q to leave</Text>
      </Box>

      <StatusBar
        state={state}
        turnTimeoutMs={60000}
        challengeOpen={challengeOpen}
      />
    </Box>
  );
}

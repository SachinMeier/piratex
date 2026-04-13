// Read-only spectator view. Reuses some of the playing layout but has no
// input box and no commands except :q to leave.

import React, { useEffect, useRef } from "react";
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
import { useBottomCommand } from "../hooks/useBottomCommand.js";
import { useQuitApp } from "../hooks/useQuitApp.js";
import { BottomCommandBar } from "../components/BottomCommandBar.js";

interface WatchProps {
  state: GameState;
}

export function Watch({ state }: WatchProps) {
  const game = useGame();
  const challengeable = computeChallengeableHistory(state);
  const challengeOpen = state.challenges.length > 0;
  const quitApp = useQuitApp();
  const challengeTimeoutMs =
    game.session?.config.challenge_timeout_ms ?? 120_000;

  // Track when each challenge was first seen so the countdown doesn't
  // reset on every render.
  const challengeSeenAt = useRef<Map<number, number>>(new Map());
  useEffect(() => {
    const seen = challengeSeenAt.current;
    for (const c of state.challenges) {
      if (!seen.has(c.id)) seen.set(c.id, Date.now());
    }
    const liveIds = new Set(state.challenges.map((c) => c.id));
    for (const id of seen.keys()) {
      if (!liveIds.has(id)) seen.delete(id);
    }
  }, [state.challenges]);
  const leave = () => game.tearDownSession();
  const bottom = useBottomCommand({
    q: quitApp,
    qa: quitApp,
    b: leave,
    back: leave,
  });

  useInkInput((rawInput, key) => {
    if (bottom.commandMode) return;
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
        <Text dimColor>{"   "}</Text>
        <Text dimColor>game: {state.id}</Text>
      </Box>

      {challengeOpen ? (
        <ChallengePanel
          challenge={state.challenges[0]!}
          myName=""
          challengeTimeoutMs={challengeTimeoutMs}
          firstSeenAt={challengeSeenAt.current.get(state.challenges[0]!.id) ?? Date.now()}
        />
      ) : (
        <Center center={state.center} />
      )}

      <Box marginY={1}>
        {state.teams.map((team, idx) => (
          <TeamPanel
            key={team.id}
            team={team}
            teamIndex={idx}
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

      <StatusBar state={state} challengeOpen={challengeOpen} />

      <BottomCommandBar
        commandMode={bottom.commandMode}
        buffer={bottom.buffer}
        hint=":b back  ·  :q quit  ·  :? help"
      />
    </Box>
  );
}

// Bottom status bar — letter pool progress, current turn, hints.
// Claude Code style: all volatile state lives here, top bar is just the
// brand name.
//
// Deliberately does NOT run a live turn-timer countdown. That would
// re-render the entire Playing screen ~4 times per second while the
// game is idle, for no real player benefit — the server still enforces
// the turn timeout. The status bar shows only whose turn it is; the
// timer lives on the server.
import React from "react";
import { Box, Text } from "ink";
import { GameState } from "../contract.js";
import { poolProgress } from "../derived.js";
import { teamColor } from "./TeamPanel.js";

// 12-cell progress bar keeps the whole status line under 80 columns even
// with the game id, turn timer, and hint segment all present.
const BAR_CELLS = 12;

interface StatusBarProps {
  state: GameState;
  challengeOpen: boolean;
}

export function StatusBar({ state, challengeOpen }: StatusBarProps) {
  const used = state.initial_letter_count - state.letter_pool_count;
  const filled = Math.round(poolProgress(state) * BAR_CELLS);
  const empty = BAR_CELLS - filled;

  const barColor: string =
    state.letter_pool_count <= state.initial_letter_count * 0.1
      ? "red"
      : state.letter_pool_count <= state.initial_letter_count * 0.25
        ? "yellow"
        : "green";

  return (
    <Box>
      <Text color={barColor}>{"▰".repeat(filled)}</Text>
      <Text dimColor>{"▱".repeat(empty)}</Text>
      <Text>{` ${used}/${state.initial_letter_count} `}</Text>
      <TurnSegment state={state} />
      <Text>{"  "}</Text>
      <Hints challengeOpen={challengeOpen} state={state} />
    </Box>
  );
}

function TurnSegment({ state }: { state: GameState }) {
  if (state.status !== "playing") {
    return <Text dimColor>{state.status}</Text>;
  }
  if (state.letter_pool_count === 0) {
    return <Text color="yellow">end-game vote [space]</Text>;
  }
  const player = state.players[state.turn];
  const name = player?.name ?? "?";
  // Color the current player's name in their team's color, so the
  // status bar matches the team panel borders above.
  const teamId = player ? state.players_teams[player.name] : undefined;
  const teamIndex =
    teamId !== undefined
      ? state.teams.findIndex((t) => t.id === teamId)
      : -1;
  return (
    <Text>
      <Text dimColor>turn: </Text>
      <Text bold color={teamColor(teamIndex)}>
        {name}
      </Text>
    </Text>
  );
}

function Hints({
  challengeOpen,
  state,
}: {
  challengeOpen: boolean;
  state: GameState;
}) {
  if (challengeOpen) {
    return <Text dimColor>:y valid · :n invalid · :? help</Text>;
  }
  if (state.status !== "playing") {
    return <Text dimColor>:? help</Text>;
  }
  return (
    <Text dimColor>space flip · :c chal · / chat · :? help</Text>
  );
}

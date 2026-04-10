// Bottom status bar — letter pool progress, game id, current turn, hints.
// Claude Code style: all volatile state lives here, top bar is just the
// brand name.
import React from "react";
import { Box, Text } from "ink";
import { GameState } from "../contract.js";
import { poolProgress, showTurnTimer } from "../derived.js";
import { formatCountdown, useCountdown } from "../hooks/useCountdown.js";

const BAR_CELLS = 20;

interface StatusBarProps {
  state: GameState;
  turnTimeoutMs: number;
  challengeOpen: boolean;
}

export function StatusBar({
  state,
  turnTimeoutMs,
  challengeOpen,
}: StatusBarProps) {
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
      <Text>{` ${used}/${state.initial_letter_count} · `}</Text>
      <Text dimColor>{state.id} · </Text>
      <TurnSegment state={state} turnTimeoutMs={turnTimeoutMs} />
      <Text>{"   "}</Text>
      <Hints challengeOpen={challengeOpen} state={state} />
    </Box>
  );
}

function TurnSegment({
  state,
  turnTimeoutMs,
}: {
  state: GameState;
  turnTimeoutMs: number;
}) {
  if (state.status !== "playing") {
    return <Text dimColor>{state.status}</Text>;
  }
  if (state.letter_pool_count === 0) {
    return <Text color="yellow">end-game vote [space]</Text>;
  }
  const player = state.players[state.turn];
  const name = player?.name ?? "?";
  if (!showTurnTimer(state)) {
    return <Text>{name}</Text>;
  }
  return <TimedTurn name={name} turnTimeoutMs={turnTimeoutMs} epoch={state.total_turn} />;
}

function TimedTurn({
  name,
  turnTimeoutMs,
  epoch,
}: {
  name: string;
  turnTimeoutMs: number;
  epoch: number;
}) {
  // useCountdown depends on epoch (total_turn) so it resets every turn
  // automatically — startedAt changes whenever the turn changes.
  const startedAt = React.useMemo(() => Date.now(), [epoch]);
  const { remainingMs } = useCountdown(startedAt, turnTimeoutMs);
  return (
    <Text>
      {name} <Text dimColor>{formatCountdown(remainingMs)}</Text>
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
    return (
      <Text dimColor>
        :y valid · :n invalid · :?
      </Text>
    );
  }
  if (state.status !== "playing") {
    return <Text dimColor>:?  help</Text>;
  }
  return (
    <Text dimColor>space flip · :c1 chal · / chat · :? help</Text>
  );
}

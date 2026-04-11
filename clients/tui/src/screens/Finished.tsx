// End-of-game stats screen. Shows team scores in a small ASCII bar chart.
import React from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import { GameState } from "../contract.js";
import { useGame } from "../game-provider.js";
import { useBottomCommand } from "../hooks/useBottomCommand.js";
import { useQuitApp } from "../hooks/useQuitApp.js";
import { BottomCommandBar } from "../components/BottomCommandBar.js";

interface FinishedProps {
  state: GameState;
}

const BAR_WIDTH = 30;

export function Finished({ state }: FinishedProps) {
  const game = useGame();
  const quitApp = useQuitApp();
  const leave = () => game.tearDownSession();
  const bottom = useBottomCommand({
    q: quitApp,
    qa: quitApp,
    b: leave,
    back: leave,
  });

  useInkInput((_input, key) => {
    if (bottom.commandMode) return;
    if (key.return || key.escape) {
      game.tearDownSession();
    }
  });

  const sorted = [...state.teams].sort((a, b) => b.score - a.score);
  const maxScore = Math.max(1, ...sorted.map((t) => t.score));
  const winner = sorted[0];
  const stats = state.game_stats;

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE
        </Text>
      </Box>

      <Box justifyContent="center" marginY={1}>
        <Text bold color="yellow">
          GAME OVER
        </Text>
      </Box>

      {winner && (
        <Box justifyContent="center" marginBottom={1}>
          <Text>
            🏆 <Text bold color="cyan">{winner.name}</Text> wins with{" "}
            <Text bold>{winner.score}</Text> points
          </Text>
        </Box>
      )}

      <Box flexDirection="column" paddingX={4}>
        {sorted.map((team) => {
          const filled = Math.round((team.score / maxScore) * BAR_WIDTH);
          return (
            <Text key={team.id}>
              <Text color="cyan" bold>
                {team.name.padEnd(15)}
              </Text>
              <Text>{` ${"█".repeat(Math.max(0, filled))}${".".repeat(BAR_WIDTH - filled)} `}</Text>
              <Text bold>{team.score}</Text>
            </Text>
          );
        })}
      </Box>

      {stats && (
        <Box flexDirection="column" paddingX={4} marginTop={1}>
          <Text dimColor>—</Text>
          {typeof stats.total_steals === "number" && (
            <Text>total word steals: {stats.total_steals}</Text>
          )}
          {stats.longest_word && (
            <Text>longest word: {stats.longest_word.toUpperCase()}</Text>
          )}
          {stats.best_steal && (
            <Text>
              best steal:{" "}
              <Text color="cyan">
                {stats.best_steal.victim_word
                  ? `${stats.best_steal.victim_word.toUpperCase()} → ${stats.best_steal.thief_word.toUpperCase()}`
                  : stats.best_steal.thief_word.toUpperCase()}
              </Text>
            </Text>
          )}
          {typeof stats.game_duration === "number" && (
            <Text>duration: {formatDuration(stats.game_duration)}</Text>
          )}
          {stats.team_stats?.margin_of_victory != null && (
            <Text>margin: {stats.team_stats.margin_of_victory}</Text>
          )}
        </Box>
      )}

      <Box flexGrow={1} />

      <BottomCommandBar
        commandMode={bottom.commandMode}
        buffer={bottom.buffer}
        hint=":b back  ·  :q quit"
      />
    </Box>
  );
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}m ${s.toString().padStart(2, "0")}s`;
}

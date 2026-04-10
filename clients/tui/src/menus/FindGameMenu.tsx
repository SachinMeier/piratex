import React, { useEffect, useState } from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import TextInput from "ink-text-input";
import { GameSummary } from "../contract.js";
import { useGame } from "../game-provider.js";

interface FindGameMenuProps {
  onPick(gameId: string): void;
  onCancel(): void;
}

export function FindGameMenu({ onPick, onCancel }: FindGameMenuProps) {
  const game = useGame();
  const [games, setGames] = useState<GameSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [gameId, setGameId] = useState("");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await game.api.listGames(1);
        if (!cancelled) {
          setGames(res.games);
          setLoading(false);
        }
      } catch (err) {
        if (!cancelled) {
          setLoadError(reasonOf(err));
          setLoading(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [game.api]);

  useInkInput((_input, key) => {
    if (key.escape) onCancel();
  });

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE — JOIN GAME
        </Text>
      </Box>

      <Box flexGrow={1} />

      <Box justifyContent="center">
        <Box flexDirection="column" paddingX={4}>
          <Text>game id:</Text>
          <Box>
            <Text>› </Text>
            <TextInput
              value={gameId}
              onChange={(value: string) => setGameId(value.toUpperCase())}
              onSubmit={() => {
                if (gameId.trim().length > 0) onPick(gameId.trim());
              }}
            />
          </Box>

          <Box marginTop={1} flexDirection="column">
            <Text bold dimColor>
              waiting games:
            </Text>
            {loading ? (
              <Text dimColor>loading…</Text>
            ) : loadError ? (
              <Text color="red">⚠ {loadError}</Text>
            ) : games.length === 0 ? (
              <Text dimColor>(none)</Text>
            ) : (
              games.slice(0, 5).map((g) => (
                <Text key={g.id}>
                  <Text color="cyan">{g.id}</Text>{" "}
                  <Text dimColor>({g.player_count} players)</Text>
                </Text>
              ))
            )}
          </Box>
        </Box>
      </Box>

      <Box flexGrow={1} />

      <Box justifyContent="center">
        <Text dimColor>type a game id and press enter, esc to cancel</Text>
      </Box>
    </Box>
  );
}

function reasonOf(err: unknown): string {
  if (err instanceof Error) return err.message.replace(/_/g, " ");
  return "error";
}

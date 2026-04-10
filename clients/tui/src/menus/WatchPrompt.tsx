import React, { useState } from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import TextInput from "ink-text-input";
import { useGame } from "../game-provider.js";

interface WatchPromptProps {
  onCancel(): void;
}

export function WatchPrompt({ onCancel }: WatchPromptProps) {
  const game = useGame();
  const [gameId, setGameId] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useInkInput((_input, key) => {
    if (key.escape) onCancel();
  });

  const submit = async () => {
    const trimmed = gameId.trim();
    if (trimmed.length === 0) {
      setError("game id required");
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await game.startSession({ kind: "watch", gameId: trimmed });
    } catch (err) {
      setError(reasonOf(err));
      setSubmitting(false);
    }
  };

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE — WATCH GAME
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
              onSubmit={submit}
            />
          </Box>
          {error && <Text color="red">⚠ {error}</Text>}
          {submitting && <Text dimColor>connecting…</Text>}
        </Box>
      </Box>

      <Box flexGrow={1} />

      <Box justifyContent="center">
        <Text dimColor>esc to cancel</Text>
      </Box>
    </Box>
  );
}

function reasonOf(err: unknown): string {
  if (err instanceof Error) return err.message.replace(/_/g, " ");
  return "error";
}

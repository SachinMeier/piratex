import React, { useState } from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import TextInput from "ink-text-input";
import { useGame } from "../game-provider.js";

interface JoinPromptProps {
  gameId: string;
  onCancel(): void;
}

export function JoinPrompt({ gameId, onCancel }: JoinPromptProps) {
  const game = useGame();
  const [playerName, setPlayerName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useInkInput((_input, key) => {
    if (key.escape) onCancel();
  });

  const submit = async () => {
    const trimmed = playerName.trim();
    if (trimmed.length === 0) {
      setError("name required");
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await game.startSession({ kind: "join", gameId, playerName: trimmed });
    } catch (err) {
      setError(reasonOf(err));
      setSubmitting(false);
    }
  };

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE — JOIN {gameId}
        </Text>
      </Box>

      <Box flexGrow={1} />

      <Box justifyContent="center">
        <Box flexDirection="column" paddingX={4}>
          <Text>your name:</Text>
          <Box>
            <Text>› </Text>
            <TextInput
              value={playerName}
              onChange={setPlayerName}
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

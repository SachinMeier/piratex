import React, { useState } from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import TextInput from "ink-text-input";
import SelectInput from "ink-select-input";
import { LetterPoolType } from "../contract.js";
import { useGame } from "../game-provider.js";

interface CreateGameMenuProps {
  onCancel(): void;
}

const POOLS = [
  { label: "Standard (144 letters)", value: "bananagrams" as const },
  { label: "Half (79 letters)", value: "bananagrams_half" as const },
];

type Step = "pool" | "name" | "creating";

export function CreateGameMenu({ onCancel }: CreateGameMenuProps) {
  const game = useGame();
  const [step, setStep] = useState<Step>("pool");
  const [pool, setPool] = useState<LetterPoolType>("bananagrams");
  const [playerName, setPlayerName] = useState("");
  const [error, setError] = useState<string | null>(null);

  useInkInput((_input, key) => {
    if (key.escape) onCancel();
  });

  const submitName = async () => {
    const trimmed = playerName.trim();
    if (trimmed.length === 0) {
      setError("name required");
      return;
    }
    setStep("creating");
    setError(null);
    try {
      await game.startSession({ kind: "create", pool, playerName: trimmed });
    } catch (err) {
      setError(reasonOf(err));
      setStep("name");
    }
  };

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE — CREATE GAME
        </Text>
      </Box>

      <Box flexGrow={1} />

      <Box justifyContent="center">
        <Box flexDirection="column" paddingX={4}>
          {step === "pool" && (
            <>
              <Text>letter pool:</Text>
              <SelectInput
                items={POOLS as any}
                onSelect={(item: { value: LetterPoolType }) => {
                  setPool(item.value);
                  setStep("name");
                }}
              />
            </>
          )}
          {step === "name" && (
            <>
              <Text>your name:</Text>
              <Box>
                <Text>› </Text>
                <TextInput
                  value={playerName}
                  onChange={setPlayerName}
                  onSubmit={submitName}
                />
              </Box>
              {error && <Text color="red">⚠ {error}</Text>}
            </>
          )}
          {step === "creating" && <Text dimColor>creating game…</Text>}
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

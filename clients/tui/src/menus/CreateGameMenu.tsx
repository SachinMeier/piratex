import React, { useState } from "react";
import { Box, Text } from "ink";
import TextInput from "ink-text-input";
import { LetterPoolType } from "../contract.js";
import { useDefaultUsername } from "../app.js";
import { useGame } from "../game-provider.js";
import { VimSelect, VimSelectItem } from "../components/VimSelect.js";
import { TitleBar } from "../components/TitleBar.js";
import { CenteredScreen } from "../components/CenteredScreen.js";
import { HelpPopup } from "../components/HelpPopup.js";
import {
  hintWithHelp,
  useScreenCommand,
} from "../hooks/useScreenCommand.js";
import { useQuitApp } from "../hooks/useQuitApp.js";

interface CreateGameMenuProps {
  onCancel(): void;
}

const POOLS: readonly VimSelectItem<LetterPoolType>[] = [
  { label: "[N]ormal Game  (144 letters)", value: "bananagrams" },
  { label: "[M]ini Game    (79 letters)", value: "bananagrams_half" },
];

type Step = "pool" | "name" | "creating";

export function CreateGameMenu({ onCancel }: CreateGameMenuProps) {
  const game = useGame();
  const quitApp = useQuitApp();
  const defaultUsername = useDefaultUsername();
  const [step, setStep] = useState<Step>("pool");
  const [pool, setPool] = useState<LetterPoolType>("bananagrams");
  const [playerName, setPlayerName] = useState("");
  const [error, setError] = useState<string | null>(null);

  // Tries to create the game with the given name. On failure, drops the
  // user into the manual name-entry step with the server error shown, so
  // they can fix it (e.g., name too short) without losing the pool choice.
  const createWith = async (selectedPool: LetterPoolType, name: string) => {
    setStep("creating");
    setError(null);
    try {
      await game.startSession({
        kind: "create",
        pool: selectedPool,
        playerName: name,
      });
    } catch (err) {
      setError(reasonOf(err));
      setStep("name");
    }
  };

  const handlePoolSelected = (selectedPool: LetterPoolType) => {
    setPool(selectedPool);
    // If PIRATEX_USERNAME is set, skip the name step entirely. The
    // server is the authority on name validity — a rejection falls
    // through to the normal manual-entry flow with the reason shown.
    if (defaultUsername) {
      void createWith(selectedPool, defaultUsername);
    } else {
      setStep("name");
    }
  };

  const screen = useScreenCommand({
    onQuit: quitApp,
    onBack: onCancel,
    extra: {
      n: () => {
        if (step === "pool") handlePoolSelected("bananagrams");
      },
      m: () => {
        if (step === "pool") handlePoolSelected("bananagrams_half");
      },
    },
  });

  const handleMainChange = (nv: string) => {
    if (playerName === "" && nv === ":") {
      screen.enterCommandMode();
      setPlayerName("");
      return;
    }
    setPlayerName(nv);
  };

  const submitName = async () => {
    const trimmed = playerName.trim();
    if (trimmed.length === 0) {
      setError("name required");
      return;
    }
    await createWith(pool, trimmed);
  };

  const hint = (() => {
    if (step === "pool") {
      return hintWithHelp(
        "↑↓/jk navigate  ·  l/enter or :n/:m select  ·  :b back  ·  :q quit",
        screen.showHelp,
      );
    }
    return "type your name  ·  :b back  ·  :q quit";
  })();

  return (
    <CenteredScreen
      title={<TitleBar text="PIRATE SCRABBLE — CREATE GAME" />}
      commandMode={screen.commandMode}
      buffer={screen.buffer}
      showHelp={screen.showHelp && step === "pool"}
      hint={hint}
      helpPopup={
        <HelpPopup title="LETTER POOLS">
          <Text>
            <Text bold color="cyan">Normal Game</Text> uses the full
            144-letter pool — the standard experience.
          </Text>
          <Text>
            Select <Text bold color="cyan">Mini Game</Text> for a shorter
            version of the exact same game.
          </Text>
        </HelpPopup>
      }
    >
      {step === "pool" && (
        <Box flexDirection="column" paddingX={2}>
          <VimSelect
            items={POOLS}
            isActive={!screen.commandMode}
            onSelect={(item) => handlePoolSelected(item.value)}
          />
        </Box>
      )}
      {step === "name" && (
        <Box flexDirection="column" paddingX={4}>
          <Text>your name:</Text>
          <Box>
            <Text>› </Text>
            <TextInput
              focus={!screen.commandMode}
              value={playerName}
              onChange={handleMainChange}
              onSubmit={submitName}
            />
          </Box>
          {error && <Text color="red">⚠ {error}</Text>}
        </Box>
      )}
      {step === "creating" && (
        <Box paddingX={4}>
          <Text dimColor>creating game…</Text>
        </Box>
      )}
    </CenteredScreen>
  );
}

function reasonOf(err: unknown): string {
  if (err instanceof Error) return err.message.replace(/_/g, " ");
  return "error";
}

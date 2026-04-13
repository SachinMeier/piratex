import React, { useState } from "react";
import { Box, Text } from "ink";
import TextInput from "ink-text-input";
import { useGame } from "../game-provider.js";
import { TitleBar } from "../components/TitleBar.js";
import { CenteredScreen } from "../components/CenteredScreen.js";
import { HelpPopup } from "../components/HelpPopup.js";
import {
  hintWithHelp,
  useScreenCommand,
} from "../hooks/useScreenCommand.js";
import { useQuitApp } from "../hooks/useQuitApp.js";

interface WatchPromptProps {
  onCancel(): void;
}

export function WatchPrompt({ onCancel }: WatchPromptProps) {
  const game = useGame();
  const quitApp = useQuitApp();
  const [gameId, setGameId] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const screen = useScreenCommand({
    onQuit: quitApp,
    onBack: onCancel,
  });

  const handleMainChange = (nv: string) => {
    if (gameId === "" && nv === ":") {
      screen.enterCommandMode();
      setGameId("");
      return;
    }
    setGameId(nv.toUpperCase());
  };

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
    <CenteredScreen
      title={<TitleBar text="PIRATE SCRABBLE — WATCH GAME" />}
      commandMode={screen.commandMode}
      buffer={screen.buffer}
      showHelp={screen.showHelp}
      hint={hintWithHelp(
        "type a game id  ·  :b back  ·  :q quit",
        screen.showHelp,
      )}
      helpPopup={
        <HelpPopup title="SPECTATING A GAME">
          <Text>
            Enter a <Text bold color="cyan">game id</Text> to watch
            without playing.
          </Text>
          <Text>
            You see the words, tiles, and challenges in real time.
          </Text>
          <Text>
            You cannot make moves — use{" "}
            <Text bold color="cyan">Join</Text> for that.
          </Text>
        </HelpPopup>
      }
    >
      <Box flexDirection="column" paddingX={4}>
        <Text>game id:</Text>
        <Box>
          <Text>› </Text>
          <TextInput
            focus={!screen.commandMode}
            value={gameId}
            onChange={handleMainChange}
            onSubmit={submit}
          />
        </Box>
        {error && <Text color="red">⚠ {error}</Text>}
        {submitting && <Text dimColor>connecting…</Text>}
      </Box>
    </CenteredScreen>
  );
}

function reasonOf(err: unknown): string {
  if (err instanceof Error) return err.message.replace(/_/g, " ");
  return "error";
}

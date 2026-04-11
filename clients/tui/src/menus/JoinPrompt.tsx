import React, { useEffect, useRef, useState } from "react";
import { Box, Text } from "ink";
import TextInput from "ink-text-input";
import { useDefaultUsername } from "../app.js";
import { useGame } from "../game-provider.js";
import { TitleBar } from "../components/TitleBar.js";
import { CenteredScreen } from "../components/CenteredScreen.js";
import { HelpPopup } from "../components/HelpPopup.js";
import {
  hintWithHelp,
  useScreenCommand,
} from "../hooks/useScreenCommand.js";
import { useQuitApp } from "../hooks/useQuitApp.js";

interface JoinPromptProps {
  gameId: string;
  onCancel(): void;
}

export function JoinPrompt({ gameId, onCancel }: JoinPromptProps) {
  const game = useGame();
  const quitApp = useQuitApp();
  const defaultUsername = useDefaultUsername();
  const [playerName, setPlayerName] = useState("");
  // If PIRATEX_USERNAME was set, start in the submitting state so the
  // user sees "connecting as X..." instead of a flash of the empty input.
  const [submittingName, setSubmittingName] = useState<string | null>(
    defaultUsername,
  );
  const [error, setError] = useState<string | null>(null);
  const autoJoinFiredRef = useRef(false);

  const screen = useScreenCommand({
    onQuit: quitApp,
    onBack: onCancel,
  });

  const handleMainChange = (nv: string) => {
    if (playerName === "" && nv === ":") {
      screen.enterCommandMode();
      setPlayerName("");
      return;
    }
    setPlayerName(nv);
  };

  const submit = async () => {
    const trimmed = playerName.trim();
    if (trimmed.length === 0) {
      setError("name required");
      return;
    }
    setSubmittingName(trimmed);
    setError(null);
    try {
      await game.startSession({ kind: "join", gameId, playerName: trimmed });
    } catch (err) {
      setError(reasonOf(err));
      setSubmittingName(null);
    }
  };

  // Auto-join once on mount when PIRATEX_USERNAME is set. Only non-empty
  // check on the client — server rejections surface as errors and drop
  // the user into the normal manual-entry flow.
  useEffect(() => {
    if (autoJoinFiredRef.current) return;
    if (!defaultUsername) return;
    autoJoinFiredRef.current = true;
    (async () => {
      try {
        await game.startSession({
          kind: "join",
          gameId,
          playerName: defaultUsername,
        });
      } catch (err) {
        setError(reasonOf(err));
        setSubmittingName(null);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <CenteredScreen
      title={<TitleBar text={`PIRATE SCRABBLE — JOIN ${gameId}`} />}
      commandMode={screen.commandMode}
      buffer={screen.buffer}
      showHelp={screen.showHelp}
      hint={hintWithHelp(
        "type your name  ·  :b back  ·  :q quit",
        screen.showHelp,
      )}
      helpPopup={
        <HelpPopup title="JOINING A GAME">
          <Text>
            Enter the name you want other players to see.
          </Text>
          <Text>
            The server rejects names that are too short, too long, or
            already taken — you'll see the reason if it does.
          </Text>
        </HelpPopup>
      }
    >
      <Box flexDirection="column" paddingX={4}>
        {submittingName !== null ? (
          <Text dimColor>connecting as {submittingName}…</Text>
        ) : (
          <>
            <Text>your name:</Text>
            <Box>
              <Text>› </Text>
              <TextInput
                focus={!screen.commandMode}
                value={playerName}
                onChange={handleMainChange}
                onSubmit={submit}
              />
            </Box>
            {error && <Text color="red">⚠ {error}</Text>}
          </>
        )}
      </Box>
    </CenteredScreen>
  );
}

function reasonOf(err: unknown): string {
  if (err instanceof Error) return err.message.replace(/_/g, " ");
  return "error";
}

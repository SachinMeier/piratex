import React, { useEffect, useState } from "react";
import { Box, Text } from "ink";
import TextInput from "ink-text-input";
import { GameSummary } from "../contract.js";
import { useGame } from "../game-provider.js";
import { TitleBar } from "../components/TitleBar.js";
import { CenteredScreen } from "../components/CenteredScreen.js";
import { HelpPopup } from "../components/HelpPopup.js";
import {
  hintWithHelp,
  useScreenCommand,
} from "../hooks/useScreenCommand.js";
import { useQuitApp } from "../hooks/useQuitApp.js";

interface FindGameMenuProps {
  onPick(gameId: string): void;
  onCancel(): void;
}

export function FindGameMenu({ onPick, onCancel }: FindGameMenuProps) {
  const game = useGame();
  const quitApp = useQuitApp();
  const [games, setGames] = useState<GameSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [gameId, setGameId] = useState("");

  const screen = useScreenCommand({
    onQuit: quitApp,
    onBack: onCancel,
  });

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

  const handleMainChange = (nv: string) => {
    if (gameId === "" && nv === ":") {
      screen.enterCommandMode();
      setGameId("");
      return;
    }
    setGameId(nv.toUpperCase());
  };

  return (
    <CenteredScreen
      title={<TitleBar text="PIRATE SCRABBLE — JOIN GAME" />}
      commandMode={screen.commandMode}
      buffer={screen.buffer}
      showHelp={screen.showHelp}
      hint={hintWithHelp(
        "type a game id  ·  :b back  ·  :q quit",
        screen.showHelp,
      )}
      helpPopup={
        <HelpPopup title="JOINING A GAME">
          <Text>
            Type a <Text bold color="cyan">game id</Text> (e.g. ABC1234)
            and press enter to join. Ask a friend who made the game for
            the id.
          </Text>
          <Text>
            If waiting games appear in the list above, you can type one
            of their ids to join it.
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
            onSubmit={() => {
              const trimmed = gameId.trim();
              if (trimmed.length > 0) onPick(trimmed);
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
    </CenteredScreen>
  );
}

function reasonOf(err: unknown): string {
  if (err instanceof Error) return err.message.replace(/_/g, " ");
  return "error";
}

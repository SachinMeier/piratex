// Top-level router state machine. Reads route from local state when
// out-of-game, derives route from gameState.status when in-game.

import React, {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { Box, Text, useApp, useInput as useInkInput } from "ink";

import { useGame, GameProvider } from "./game-provider.js";
import { ApiClient, ApiClientError } from "./api.js";
import {
  MIN_TERMINAL_COLUMNS,
  MIN_TERMINAL_ROWS,
  useTerminalSize,
} from "./hooks/useTerminalSize.js";

import { HomeMenu } from "./menus/HomeMenu.js";
import { CreateGameMenu } from "./menus/CreateGameMenu.js";
import { FindGameMenu } from "./menus/FindGameMenu.js";
import { JoinPrompt } from "./menus/JoinPrompt.js";
import { WatchPrompt } from "./menus/WatchPrompt.js";
import { RulesText } from "./menus/RulesText.js";
import { AboutText } from "./menus/AboutText.js";
import { UpgradePrompt } from "./menus/UpgradePrompt.js";
import { WaitingRoom } from "./screens/WaitingRoom.js";
import { Playing } from "./screens/Playing.js";
import { Finished } from "./screens/Finished.js";
import { Watch } from "./screens/Watch.js";

/** Read-only context exposing the username set via PIRATEX_USERNAME, if any.
 * When non-null, menus auto-fill it and skip name-entry steps. The server is
 * still the authority on name validity — if an auto-join fails, menus fall
 * back to the normal manual-entry flow. */
const DefaultUsernameContext = createContext<string | null>(null);

export function useDefaultUsername(): string | null {
  return useContext(DefaultUsernameContext);
}

type Route =
  | { kind: "home" }
  | { kind: "create" }
  | { kind: "find" }
  | { kind: "join_prompt"; gameId: string }
  | { kind: "watch_prompt" }
  | { kind: "rules" }
  | { kind: "about" }
  | { kind: "upgrade"; serverVersion: string; clientVersion: string; upgradeUrl?: string };

interface AppRootProps {
  api: ApiClient;
  socketUrl: string;
  initialGameId?: string | null;
  defaultUsername?: string | null;
}

export function AppRoot({
  api,
  socketUrl,
  initialGameId,
  defaultUsername,
}: AppRootProps) {
  return (
    <DefaultUsernameContext.Provider value={defaultUsername ?? null}>
      <GameProvider api={api} socketUrl={socketUrl}>
        <App initialGameId={initialGameId ?? null} />
      </GameProvider>
    </DefaultUsernameContext.Provider>
  );
}

interface AppProps {
  initialGameId: string | null;
}

function App({ initialGameId }: AppProps) {
  const game = useGame();
  const { exit } = useApp();
  const size = useTerminalSize();
  // If the user passed a game id as a positional CLI arg, skip the home
  // menu and route straight to the JoinPrompt for that game.
  const [route, setRoute] = useState<Route>(() =>
    initialGameId
      ? { kind: "join_prompt", gameId: initialGameId }
      : { kind: "home" },
  );

  // Ctrl+C confirm flow (Claude Code-style). The first Ctrl+C arms a
  // 3-second window and shows a toast; a second Ctrl+C within that
  // window actually exits. Any other key interaction cancels the pending
  // exit via the toast's TTL.
  const pendingExit = useRef(false);
  const pendingExitTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useInkInput((input, key) => {
    if (key.ctrl && input === "c") {
      if (pendingExit.current) {
        if (pendingExitTimer.current) clearTimeout(pendingExitTimer.current);
        exit();
        return;
      }
      pendingExit.current = true;
      game.showToast("info", "press Ctrl+C again to quit", 3000);
      if (pendingExitTimer.current) clearTimeout(pendingExitTimer.current);
      pendingExitTimer.current = setTimeout(() => {
        pendingExit.current = false;
        pendingExitTimer.current = null;
      }, 3000);
    }
  });

  useEffect(() => {
    return () => {
      if (pendingExitTimer.current) clearTimeout(pendingExitTimer.current);
    };
  }, []);

  // Reserved hook for future global error handling. Menus surface their
  // own errors via the toast slot; HTTP 426 routes to the UpgradePrompt
  // explicitly when caught.
  void ApiClientError;

  // When a session is torn down (quit, end-of-game exit, "join different
  // game"), snap the router back to home regardless of whatever pre-session
  // route was in local state. Without this the user returns to whatever
  // menu they were on when they started the session — e.g. the letter-pool
  // selector after pressing enter on the finished screen.
  useEffect(() => {
    if (!game.session && route.kind !== "home" && route.kind !== "upgrade") {
      setRoute({ kind: "home" });
    }
    // We intentionally only react to game.session transitioning, not to
    // route — the routes listed above are allowed to coexist with null
    // session (upgrade screen) or are the destination itself (home).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [game.session]);

  // Wrap every screen in a root Box with an explicit height/width tied to
  // the terminal size. Without this, Ink renders at the cursor and flex
  // children have no fixed viewport to grow into, so flexGrow=1 collapses
  // to content size. Setting height here makes the UI always occupy the
  // full terminal viewport — so the input bar and status line are always
  // pinned to the true floor of the screen.
  const screen = renderScreen();

  return (
    <Box
      flexDirection="column"
      width={size.columns}
      height={size.rows}
    >
      {screen}
    </Box>
  );

  function renderScreen(): React.ReactElement {
    if (size.tooSmall) {
      return (
        <Box flexDirection="column" justifyContent="center" flexGrow={1}>
          <Box justifyContent="center">
            <Text color="yellow">terminal too small</Text>
          </Box>
          <Box justifyContent="center">
            <Text dimColor>
              need at least {MIN_TERMINAL_COLUMNS}×{MIN_TERMINAL_ROWS}
            </Text>
          </Box>
          <Box justifyContent="center">
            <Text dimColor>
              current: {size.columns}×{size.rows}
            </Text>
          </Box>
        </Box>
      );
    }

    // If we have an active session, route from gameState.
    if (game.session && game.gameState) {
      if (game.session.intent === "watch") {
        return <Watch state={game.gameState} />;
      }
      switch (game.gameState.status) {
        case "waiting":
          return <WaitingRoom state={game.gameState} />;
        case "playing":
          return <Playing state={game.gameState} />;
        case "finished":
          return <Finished state={game.gameState} />;
      }
    }

    // No session — route from local state.
    switch (route.kind) {
      case "home":
        return (
          <HomeMenu
            onChoice={(choice) => {
              switch (choice) {
                case "create":
                  setRoute({ kind: "create" });
                  return;
                case "find":
                  setRoute({ kind: "find" });
                  return;
                case "watch":
                  setRoute({ kind: "watch_prompt" });
                  return;
                case "rules":
                  setRoute({ kind: "rules" });
                  return;
                case "about":
                  setRoute({ kind: "about" });
                  return;
              }
            }}
          />
        );
      case "create":
        return <CreateGameMenu onCancel={() => setRoute({ kind: "home" })} />;
      case "find":
        return (
          <FindGameMenu
            onPick={(gameId) => setRoute({ kind: "join_prompt", gameId })}
            onCancel={() => setRoute({ kind: "home" })}
          />
        );
      case "join_prompt":
        return (
          <JoinPrompt
            gameId={route.gameId}
            onCancel={() => setRoute({ kind: "home" })}
          />
        );
      case "watch_prompt":
        return <WatchPrompt onCancel={() => setRoute({ kind: "home" })} />;
      case "rules":
        return <RulesText onCancel={() => setRoute({ kind: "home" })} />;
      case "about":
        return <AboutText onCancel={() => setRoute({ kind: "home" })} />;
      case "upgrade":
        return (
          <UpgradePrompt
            serverVersion={route.serverVersion}
            clientVersion={route.clientVersion}
            upgradeUrl={route.upgradeUrl}
          />
        );
    }
  }
}

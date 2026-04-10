// Top-level router state machine. Reads route from local state when
// out-of-game, derives route from gameState.status when in-game.

import React, { useEffect, useState } from "react";
import { Box, Text } from "ink";

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
}

export function AppRoot({ api, socketUrl }: AppRootProps) {
  return (
    <GameProvider api={api} socketUrl={socketUrl}>
      <App />
    </GameProvider>
  );
}

function App() {
  const game = useGame();
  const size = useTerminalSize();
  const [route, setRoute] = useState<Route>({ kind: "home" });

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

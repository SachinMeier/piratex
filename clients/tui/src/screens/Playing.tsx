// The main playing screen. Composes the layout, runs the input engine,
// dispatches commands, and manages the panel-swap state.

import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Box, Text, useInput as useInkInput } from "ink";

import { GameState } from "../contract.js";
import { Center } from "../components/Center.js";
import { TeamPanel } from "../components/TeamPanel.js";
import { TeamsPanel } from "../components/TeamsPanel.js";
import { ActivityFeed } from "../components/ActivityFeed.js";
import { RecentPane } from "../components/RecentPane.js";
import { HistoryPanel } from "../components/HistoryPanel.js";
import { ChallengePanel } from "../components/ChallengePanel.js";
import { HotkeysPanel } from "../components/HotkeysPanel.js";
import { StatusBar } from "../components/StatusBar.js";
import { useGame } from "../game-provider.js";
import {
  computeChallengeableHistory,
  findMyTeamId,
  findMyTurnIdx,
  isMyTurn,
  teamHasActivePlayers,
} from "../derived.js";
import {
  Key,
  promptPrefix,
  reduceInput,
  INITIAL_INPUT_STATE,
  InputEffect,
  InputState,
} from "../hooks/useInput.js";
import {
  parseCommand,
  pickReactionPhrase,
} from "../hooks/useCommandParser.js";

type ActivePanel = "none" | "teams" | "hotkeys" | "history";

interface PlayingProps {
  state: GameState;
}

export function Playing({ state }: PlayingProps) {
  const game = useGame();
  const myName = game.session?.playerName ?? "";

  const [input, setInput] = useState<InputState>(INITIAL_INPUT_STATE);
  const [activePanel, setActivePanel] = useState<ActivePanel>("none");
  const [zenMode, setZenMode] = useState(false);
  const [pendingQuit, setPendingQuit] = useState(false);

  // Track when each open challenge id was first seen so we can run a local
  // countdown without a server timestamp.
  const challengeStartedAt = useRef<Map<number, number>>(new Map());
  useEffect(() => {
    const seen = challengeStartedAt.current;
    state.challenges.forEach((c) => {
      if (!seen.has(c.id)) seen.set(c.id, Date.now());
    });
    // Drop entries for closed challenges
    const liveIds = new Set(state.challenges.map((c) => c.id));
    Array.from(seen.keys()).forEach((id) => {
      if (!liveIds.has(id)) seen.delete(id);
    });
  }, [state.challenges]);

  const challengeable = useMemo(
    () => computeChallengeableHistory(state),
    [state],
  );
  const myTeamId = findMyTeamId(state, myName);
  const myTurn = isMyTurn(state, myName);
  const myTurnIdx = findMyTurnIdx(state, myName);
  const challengeOpen = state.challenges.length > 0;

  const handleEffect = useCallback(
    async (effect: InputEffect) => {
      if (effect.kind === "submit_word") {
        try {
          await game.push("claim_word", { word: effect.word });
        } catch (err) {
          game.showToast("error", reasonOf(err));
        }
      } else if (effect.kind === "flip_letter") {
        try {
          if (state.letter_pool_count === 0) {
            await game.push("end_game_vote", {});
          } else {
            await game.push("flip_letter", {});
          }
        } catch (err) {
          game.showToast("error", reasonOf(err));
        }
      } else if (effect.kind === "send_chat") {
        try {
          await game.push("send_chat_message", { message: effect.message });
        } catch (err) {
          game.showToast("error", reasonOf(err));
        }
      } else if (effect.kind === "panel_close") {
        setActivePanel("none");
      } else if (effect.kind === "run_command") {
        runCommand(effect.buffer);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [game, state.letter_pool_count, state, challengeable],
  );

  const runCommand = useCallback(
    async (buffer: string) => {
      const action = parseCommand(buffer);
      switch (action.kind) {
        case "challenge": {
          const entry = state.history[action.index];
          if (!entry) {
            game.showToast("error", "no such word");
            return;
          }
          if (!challengeable[action.index]) {
            game.showToast("error", "already challenged");
            return;
          }
          try {
            await game.push("challenge_word", { word: entry.thief_word });
          } catch (err) {
            game.showToast("error", reasonOf(err));
          }
          return;
        }

        case "vote": {
          const challenge = state.challenges[0];
          if (!challenge) {
            game.showToast("error", "no open challenge");
            return;
          }
          try {
            await game.push("challenge_vote", {
              challenge_id: challenge.id,
              vote: action.vote,
            });
          } catch (err) {
            game.showToast("error", reasonOf(err));
          }
          return;
        }

        case "toggle_panel":
          setActivePanel((prev) => (prev === action.panel ? "none" : action.panel));
          return;

        case "toggle_zen":
          setZenMode((z) => !z);
          return;

        case "react_pirate":
          try {
            await game.push("send_chat_message", {
              message: pickReactionPhrase(),
            });
          } catch (err) {
            game.showToast("error", reasonOf(err));
          }
          return;

        case "react_argh":
          try {
            await game.push("send_chat_message", { message: "argh!" });
          } catch (err) {
            game.showToast("error", reasonOf(err));
          }
          return;

        case "quit_confirm":
          setPendingQuit(true);
          return;

        case "quit_immediate":
          await game.quitSession();
          return;

        case "unknown":
          game.showToast("error", `unknown command: :${action.raw}`);
          return;
      }
    },
    [challengeable, game, state.challenges, state.history],
  );

  useInkInput((rawInput, key) => {
    if (pendingQuit) {
      if (rawInput === "y" || rawInput === "Y") {
        setPendingQuit(false);
        void game.quitSession();
      } else if (rawInput === "n" || rawInput === "N" || key.escape) {
        setPendingQuit(false);
      }
      return;
    }

    const k = translateKey(rawInput, key);
    if (!k) return;
    const { state: next, effect } = reduceInput(input, k);
    setInput(next);
    if (effect) void handleEffect(effect);
  });

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Header />
      {challengeOpen ? (
        <ChallengePanel
          challenge={state.challenges[0]!}
          myName={myName}
          challengeTimeoutMs={game.session?.config.challenge_timeout_ms ?? 120000}
          firstSeenAt={
            challengeStartedAt.current.get(state.challenges[0]!.id) ?? Date.now()
          }
        />
      ) : (
        <Center center={state.center} />
      )}

      {!zenMode && (
        <Box marginY={1}>
          {state.teams.map((team) => (
            <TeamPanel
              key={team.id}
              team={team}
              isMyTeam={team.id === myTeamId}
              hasActivePlayers={teamHasActivePlayers(state, team.id)}
            />
          ))}
        </Box>
      )}

      {!zenMode && (
        <Box>
          {activePanel === "teams" ? (
            <TeamsPanel
              teams={state.teams}
              playersTeams={state.players_teams}
              myTeamId={myTeamId}
            />
          ) : activePanel === "hotkeys" ? (
            <HotkeysPanel />
          ) : activePanel === "history" ? (
            <HistoryPanel
              history={state.history}
              teams={state.teams}
              players={state.players}
            />
          ) : (
            <Box flexGrow={1}>
              <ActivityFeed entries={state.activity_feed} />
              <Box marginLeft={1}>
                <RecentPane
                  history={state.history}
                  challengeable={challengeable}
                />
              </Box>
            </Box>
          )}
        </Box>
      )}

      <Box marginTop={1}>
        <Text dimColor={!myTurn} color={myTurn ? "cyan" : undefined}>
          {promptPrefix(input.mode)}
        </Text>
        <Text>{input.buffer}</Text>
        <Text inverse> </Text>
      </Box>

      {pendingQuit ? (
        <Box>
          <Text color="yellow">Quit game? [y/N] </Text>
        </Box>
      ) : (
        <ToastSlot />
      )}

      <StatusBar
        state={state}
        turnTimeoutMs={game.session?.config.turn_timeout_ms ?? 60000}
        challengeOpen={challengeOpen}
      />
    </Box>
  );

  // unused but kept for clarity / future
  void myTurnIdx;
}

function Header() {
  return (
    <Box justifyContent="center" borderStyle="round" borderColor="gray">
      <Text bold color="cyan">
        PIRATE SCRABBLE
      </Text>
    </Box>
  );
}

function ToastSlot() {
  const { toast } = useGame();
  if (!toast) return <Box minHeight={1} />;
  const color = toast.kind === "error" ? "red" : "cyan";
  return (
    <Box minHeight={1}>
      <Text color={color}>
        {toast.kind === "error" ? "⚠" : "ℹ"} {toast.message}
      </Text>
    </Box>
  );
}

function translateKey(rawInput: string, key: { [k: string]: boolean }): Key | null {
  if (key.return) return { kind: "enter" };
  if (key.escape) return { kind: "escape" };
  if (key.backspace || key.delete) return { kind: "backspace" };
  if (rawInput === " ") return { kind: "space" };
  if (rawInput && rawInput.length === 1 && !key.ctrl && !key.meta) {
    return { kind: "char", value: rawInput };
  }
  return null;
}

function reasonOf(err: unknown): string {
  if (err instanceof Error) return err.message.replace(/_/g, " ");
  return "error";
}

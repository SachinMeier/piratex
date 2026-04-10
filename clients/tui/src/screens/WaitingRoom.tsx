// Waiting room: vim-style commands. Type a team name and press enter to
// create or join; use :j N to join by index, :s to start, :q to leave.

import React, { useCallback, useMemo, useState } from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import { GameState, Team } from "../contract.js";
import { useGame } from "../game-provider.js";
import { findMyTeamId } from "../derived.js";

interface WaitingRoomProps {
  state: GameState;
}

type Mode = "normal" | "command";

export function WaitingRoom({ state }: WaitingRoomProps) {
  const game = useGame();
  const myName = game.session?.playerName ?? "";
  const myTeamId = findMyTeamId(state, myName);

  const [mode, setMode] = useState<Mode>("normal");
  const [buffer, setBuffer] = useState("");
  const [pendingQuit, setPendingQuit] = useState(false);

  const config = game.session?.config;
  const minTeam = config?.min_team_name ?? 1;
  const maxTeam = config?.max_team_name ?? 15;

  const teamByName = useMemo<Map<string, Team>>(() => {
    return new Map(state.teams.map((t) => [t.name.toLowerCase(), t]));
  }, [state.teams]);

  const exactMatch = teamByName.get(buffer.trim().toLowerCase()) ?? null;
  const trimmedLen = buffer.trim().length;

  const enterHint = useMemo(() => {
    if (mode === "command") return "[enter] run";
    if (trimmedLen === 0) return ":j N · :s · :q · :?";
    if (trimmedLen < minTeam) return "[enter] too short";
    if (trimmedLen > maxTeam) return "[enter] too long";
    if (exactMatch) {
      if (exactMatch.id === myTeamId)
        return `[enter] already on "${exactMatch.name}"`;
      return `[enter] join "${exactMatch.name}"`;
    }
    return `[enter] create "${buffer.trim()}"`;
  }, [buffer, mode, exactMatch, myTeamId, minTeam, maxTeam, trimmedLen]);

  const submitNormal = useCallback(async () => {
    const trimmed = buffer.trim();
    if (trimmed.length < minTeam || trimmed.length > maxTeam) {
      game.showToast("error", "team name length");
      return;
    }
    setBuffer("");
    if (exactMatch) {
      if (exactMatch.id === myTeamId) return;
      try {
        await game.push("join_team", { team_id: exactMatch.id });
      } catch (err) {
        game.showToast("error", reasonOf(err));
      }
      return;
    }
    try {
      await game.push("create_team", { team_name: trimmed });
    } catch (err) {
      game.showToast("error", reasonOf(err));
    }
  }, [buffer, exactMatch, game, maxTeam, minTeam, myTeamId]);

  const runCommand = useCallback(
    async (raw: string) => {
      const trimmed = raw.trim();
      if (trimmed === "s") {
        try {
          await game.push("start_game", {});
        } catch (err) {
          game.showToast("error", reasonOf(err));
        }
        return;
      }
      if (trimmed === "q") {
        setPendingQuit(true);
        return;
      }
      if (trimmed === "qa") {
        await game.quitSession();
        return;
      }
      if (trimmed === "?" || trimmed === "0") {
        game.showToast(
          "info",
          "type a name to create/join · :j N · :s start · :q quit",
        );
        return;
      }
      const joinByIdx = trimmed.match(/^j\s+(\d+)$/);
      if (joinByIdx) {
        const idx = parseInt(joinByIdx[1]!, 10) - 1;
        const team = state.teams[idx];
        if (!team) {
          game.showToast("error", `no team ${idx + 1}`);
          return;
        }
        try {
          await game.push("join_team", { team_id: team.id });
        } catch (err) {
          game.showToast("error", reasonOf(err));
        }
        return;
      }
      const joinByName = trimmed.match(/^j\s+(.+)$/);
      if (joinByName) {
        const name = joinByName[1]!.trim().toLowerCase();
        const team = teamByName.get(name);
        if (!team) {
          game.showToast("error", `no team named "${joinByName[1]}"`);
          return;
        }
        try {
          await game.push("join_team", { team_id: team.id });
        } catch (err) {
          game.showToast("error", reasonOf(err));
        }
        return;
      }
      game.showToast("error", `unknown command: :${trimmed}`);
    },
    [game, state.teams, teamByName],
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

    if (key.return) {
      if (mode === "command") {
        const cmd = buffer;
        setBuffer("");
        setMode("normal");
        void runCommand(cmd);
      } else {
        void submitNormal();
      }
      return;
    }

    if (key.escape) {
      setBuffer("");
      setMode("normal");
      return;
    }

    if (key.backspace || key.delete) {
      if (buffer.length === 0 && mode === "command") {
        setMode("normal");
      } else {
        setBuffer((b) => b.slice(0, -1));
      }
      return;
    }

    if (rawInput && rawInput.length === 1 && !key.ctrl && !key.meta) {
      if (mode === "normal" && rawInput === ":" && buffer.length === 0) {
        setMode("command");
        return;
      }
      setBuffer((b) => b + rawInput);
    }
  });

  const prompt = mode === "command" ? "> :" : "> ";

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE
        </Text>
      </Box>

      <Box justifyContent="center" marginY={1}>
        <Text bold color="cyan">
          T E A M S
        </Text>
      </Box>

      <Box flexDirection="column" paddingX={4}>
        {state.teams.length === 0 ? (
          <Text dimColor>(no teams yet — type a name and press enter)</Text>
        ) : (
          state.teams.map((team, idx) => {
            const members = Object.entries(state.players_teams)
              .filter(([_, tid]) => tid === team.id)
              .map(([name]) => name);
            const isMine = team.id === myTeamId;
            return (
              <Text key={team.id}>
                <Text color={isMine ? "cyan" : "white"} bold={isMine}>
                  {`${idx + 1}. ${team.name}`.padEnd(22)}
                </Text>
                <Text dimColor>
                  {members.map((m) => (m === myName ? `${m} (me)` : m)).join(", ")}
                </Text>
              </Text>
            );
          })
        )}
      </Box>

      <Box flexGrow={1} />

      <Box paddingX={4}>
        <Text>{prompt}</Text>
        <Text>{buffer}</Text>
        <Text inverse> </Text>
        <Text>{"   "}</Text>
        <Text dimColor>{enterHint}</Text>
      </Box>

      {pendingQuit ? (
        <Box paddingX={4}>
          <Text color="yellow">Leave game? [y/N] </Text>
        </Box>
      ) : (
        <ToastSlot />
      )}
    </Box>
  );
}

function ToastSlot() {
  const { toast } = useGame();
  if (!toast) return <Box minHeight={1} />;
  const color = toast.kind === "error" ? "red" : "cyan";
  return (
    <Box minHeight={1} paddingX={4}>
      <Text color={color}>
        {toast.kind === "error" ? "⚠" : "ℹ"} {toast.message}
      </Text>
    </Box>
  );
}

function reasonOf(err: unknown): string {
  if (err instanceof Error) return err.message.replace(/_/g, " ");
  return "error";
}

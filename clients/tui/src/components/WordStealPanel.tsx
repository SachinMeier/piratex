// Word steal detail panel — used as a panel-swap when the user wants to
// see the breakdown of a specific steal.
import React from "react";
import { Box, Text } from "ink";
import { PlayerSummary, Team, WordSteal } from "../contract.js";

interface WordStealPanelProps {
  wordSteal: WordSteal;
  teams: Team[];
  players: PlayerSummary[];
}

export function WordStealPanel({ wordSteal, teams, players }: WordStealPanelProps) {
  const thiefTeam = teams[wordSteal.thief_team_idx]?.name ?? "?";
  const thiefPlayer = players[wordSteal.thief_player_idx]?.name ?? "?";
  const victimTeam =
    wordSteal.victim_team_idx != null
      ? (teams[wordSteal.victim_team_idx]?.name ?? "?")
      : null;

  const lettersAdded = computeLettersAdded(
    wordSteal.thief_word,
    wordSteal.victim_word,
  );

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor="cyan"
      paddingX={2}
      paddingY={1}
      flexGrow={1}
    >
      <Box justifyContent="center">
        <Text bold color="cyan">
          WORD STEAL
        </Text>
      </Box>

      <Box marginTop={1} justifyContent="center">
        <Text>
          {wordSteal.victim_word ? (
            <>
              <Text color="white">{wordSteal.victim_word.toUpperCase()}</Text>
              <Text dimColor>
                {" "}
                ({victimTeam ?? "?"})
              </Text>
            </>
          ) : (
            <Text dimColor>(from center)</Text>
          )}
          <Text> + </Text>
          <Text bold color="yellow">
            {lettersAdded.map((l) => l.toUpperCase()).join(" ")}
          </Text>
          <Text> → </Text>
          <Text bold color="cyan">
            {wordSteal.thief_word.toUpperCase()}
          </Text>
        </Text>
      </Box>

      <Box marginTop={1} justifyContent="center">
        <Text dimColor>
          stolen by {thiefPlayer} ({thiefTeam}) at letter {wordSteal.letter_count}
        </Text>
      </Box>
    </Box>
  );
}

function computeLettersAdded(thief: string, victim: string | null): string[] {
  if (!victim) return thief.split("");
  const counts: Record<string, number> = {};
  for (const c of victim) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  const added: string[] = [];
  for (const c of thief) {
    if ((counts[c] ?? 0) > 0) {
      counts[c]!--;
    } else {
      added.push(c);
    }
  }
  return added;
}

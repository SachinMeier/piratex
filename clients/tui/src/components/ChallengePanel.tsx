// Open-challenge vote panel. Replaces the center area while a challenge
// is open. Shows the contested steal, the vote tally, and a countdown.
import React from "react";
import { Box, Text } from "ink";
import { Challenge } from "../contract.js";
import { formatCountdown, useCountdown } from "../hooks/useCountdown.js";

interface ChallengePanelProps {
  challenge: Challenge;
  myName: string;
  challengeTimeoutMs: number;
  firstSeenAt: number;
}

export function ChallengePanel({
  challenge,
  myName,
  challengeTimeoutMs,
  firstSeenAt,
}: ChallengePanelProps) {
  const { remainingMs } = useCountdown(firstSeenAt, challengeTimeoutMs);
  const ws = challenge.word_steal;

  let validCt = 0;
  let invalidCt = 0;
  Object.values(challenge.votes).forEach((v) => {
    if (v) validCt++;
    else invalidCt++;
  });
  const myVote = challenge.votes[myName];

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor="yellow"
      paddingX={2}
      paddingY={1}
    >
      <Box justifyContent="center">
        <Text bold color="yellow">
          ⚠ CHALLENGE
        </Text>
      </Box>
      <Box justifyContent="center" marginTop={1}>
        <Text>
          <Text color="white">
            {ws.victim_word ? ws.victim_word.toUpperCase() : "(center)"}
          </Text>
          <Text> → </Text>
          <Text bold color="cyan">
            {ws.thief_word.toUpperCase()}
          </Text>
        </Text>
      </Box>
      <Box justifyContent="center" marginTop={1}>
        <Text>
          <Text color="green">{validCt} valid</Text>
          <Text dimColor> · </Text>
          <Text color="red">{invalidCt} invalid</Text>
          <Text dimColor> · </Text>
          <Text dimColor>{formatCountdown(remainingMs)} left</Text>
        </Text>
      </Box>
      <Box justifyContent="center" marginTop={1}>
        {myVote === undefined ? (
          <Text dimColor>:y valid · :n invalid</Text>
        ) : (
          <Text dimColor>you voted: {myVote ? "valid" : "invalid"}</Text>
        )}
      </Box>
    </Box>
  );
}

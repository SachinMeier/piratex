// Static rules text, paginated. No scrolling.
import React from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import { usePagedText } from "../hooks/usePagedText.js";

interface RulesTextProps {
  onCancel(): void;
}

const PAGES: string[][] = [
  [
    "OVERVIEW",
    "",
    "Pirate Scrabble is an online multiplayer word game. Players take turns",
    "flipping letters into the center. When you see a word, you steal it.",
    "",
    "The object is to make more and longer words than your opponents.",
    "When all letters have been flipped, the player with the highest score wins.",
    "",
    "RULES (1 of 2)",
    "",
    "1. All words must be at least 3 letters long.",
    "2. Stealing requires using all letters of an existing word plus at least",
    "   one new letter from the center.",
    "3. The same word cannot be in play twice at the same time.",
  ],
  [
    "RULES (2 of 2)",
    "",
    "4. A new word cannot share an English root with the word it was made from.",
    "   For example, CAT → CATS is invalid (same root), but CAT → ACTS is valid.",
    "5. If a steal violates rule 4, players can challenge it. A majority vote",
    "   decides whether the steal stands.",
    "",
    "SCORING",
    "",
    "Each team's score is: (total letters across all words) − (number of words).",
    "Longer words are worth more than many short words.",
    "",
    "WINNING",
    "",
    "The game ends shortly after all letters have been flipped, or when all",
    "players vote to end. The team with the highest score wins.",
  ],
  [
    "EXAMPLE",
    "",
    "The center has letters: R A T S N E I L P O D",
    "",
    "Alice types CAT (after a 'c' is flipped). She owns CAT.",
    "Then a 'P' is flipped. Bob types PACT — he steals CAT and adds P.",
    "Bob now owns PACT, Alice loses CAT.",
    "",
    "INVALID: CAT + S → CATS (shares root with CAT)",
    "VALID:   CAT + S → ACTS (different root)",
    "",
    "Players can challenge any word steal at any time. The voting period is",
    "two minutes. Tie goes to the thief.",
  ],
];

export function RulesText({ onCancel }: RulesTextProps) {
  const paged = usePagedText(PAGES);

  useInkInput((rawInput, key) => {
    if (key.escape || rawInput === "q" || rawInput === "Q") {
      onCancel();
      return;
    }
    if (rawInput === "j" || key.rightArrow || key.downArrow) {
      paged.next();
      return;
    }
    if (rawInput === "k" || key.leftArrow || key.upArrow) {
      paged.prev();
      return;
    }
  });

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Box justifyContent="center" borderStyle="round" borderColor="gray">
        <Text bold color="cyan">
          PIRATE SCRABBLE — RULES
        </Text>
      </Box>

      <Box flexGrow={1} flexDirection="column" paddingX={4} paddingY={1}>
        {paged.current.map((line, i) => (
          <Text key={i}>{line}</Text>
        ))}
      </Box>

      <Box justifyContent="space-between" paddingX={4}>
        <Text dimColor>esc to return</Text>
        <Text dimColor>
          {paged.pageNum}/{paged.totalPages} · j/k or arrows to page
        </Text>
      </Box>
    </Box>
  );
}

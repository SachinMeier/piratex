// Static rules text, paginated. No scrolling.
import React from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import { usePagedText } from "../hooks/usePagedText.js";

interface RulesTextProps {
  onCancel(): void;
}

// Four pages, one section per page: Overview, Rules, Scoring & Winning,
// Examples. Each page must fit in a 100x30 terminal without scrolling.
const PAGES: string[][] = [
  [
    "OVERVIEW",
    "",
    "Pirate Scrabble is an online multiplayer word game.",
    "",
    "Players take turns flipping letters from a shared pool into the center.",
    "When you see a word in the center, you type it and it becomes yours.",
    "You can also steal words from other players by adding a letter or more",
    "from the center and rearranging.",
    "",
    "The object is to make more and longer words than your opponents. When",
    "all letters have been flipped, the player with the highest score wins.",
  ],
  [
    "RULES",
    "",
    "1. All words must be at least 3 letters long.",
    "",
    "2. Stealing a word requires using all the letters of the existing word",
    "   plus at least one new letter from the center.",
    "",
    "3. The same word cannot be in play twice at the same time.",
    "",
    "4. A new word cannot share an English root with the word it was made",
    "   from. For example, CAT → CATS is invalid (same root), but CAT → ACTS",
    "   is valid.",
    "",
    "5. If a steal looks like it violates rule 4, any player can challenge",
    "   it. A majority vote decides whether the steal stands. Tie goes to",
    "   the thief. The voting window is two minutes.",
  ],
  [
    "SCORING & WINNING",
    "",
    "Each team's score is calculated as:",
    "",
    "    (total letters across all words) − (number of words)",
    "",
    "Longer words are worth far more than many short words. A single",
    "eight-letter word beats four three-letter words.",
    "",
    "The game ends shortly after all letters have been flipped, or when all",
    "players vote to end. The team with the highest score wins.",
  ],
  [
    "EXAMPLES",
    "",
    "The center has letters: R A T S N E I L P O D",
    "",
    "Alice types CAT after a 'c' is flipped. She owns CAT.",
    "A 'P' is flipped. Bob types PACT — he steals CAT and adds P.",
    "Bob now owns PACT. Alice loses CAT.",
    "",
    "Sample steals:",
    "",
    "  INVALID: CAT + S → CATS  (shares root with CAT)",
    "  VALID:   CAT + S → ACTS  (different root)",
    "",
    "Any player can challenge a word steal at any time. If a majority",
    "votes it invalid, the steal is reversed.",
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

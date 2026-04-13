// Static rules text, paginated. No scrolling.
import React, { useState } from "react";
import { Box, Text, useInput as useInkInput } from "ink";
import { usePagedText } from "../hooks/usePagedText.js";
import { useBottomCommand } from "../hooks/useBottomCommand.js";
import { useQuitApp } from "../hooks/useQuitApp.js";
import { BottomCommandBar } from "../components/BottomCommandBar.js";
import { RulesExample } from "../components/RulesExample.js";

interface RulesTextProps {
  onCancel(): void;
}

// Four pages, one section per page: Overview, Rules, Scoring & Winning,
// Examples. Each page must fit in an 80x30 terminal without scrolling. The
// Examples page renders via <RulesExample /> below, so its entry here is an
// empty placeholder that still counts toward pagination.
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
    "4. A new word cannot share an English root with its source. For",
    "   example, CAT → CATS is invalid; CAT → ACTS is valid.",
    "",
    "5. Any suspected violation of rule 4 can be challenged. Majority",
    "   vote decides; tie goes to the thief. Two-minute voting window.",
  ],
  [
    "SCORING & WINNING",
    "",
    "Each team's score is calculated as:",
    "",
    "    (total letters across all words) − (number of words)",
    "",
    "Longer words are worth far more than many short words.",
    "",
    "The game ends shortly after all letters have been flipped. The team",
    "with the highest score wins.",
  ],
  // Examples page — rendered via <RulesExample /> below.
  [],
];

export function RulesText({ onCancel }: RulesTextProps) {
  const paged = usePagedText(PAGES);
  const quitApp = useQuitApp();
  const [showHelp, setShowHelp] = useState(false);
  const bottom = useBottomCommand({
    q: quitApp,
    qa: quitApp,
    b: onCancel,
    back: onCancel,
    "?": () => setShowHelp((s) => !s),
  });

  useInkInput((rawInput, key) => {
    if (bottom.commandMode) return;
    // When the help popup is open, Esc closes it instead of leaving the page.
    if (key.escape && showHelp) {
      setShowHelp(false);
      return;
    }
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

      <Box flexGrow={1} flexDirection="column" paddingX={4}>
        {paged.pageNum === 4 ? (
          <RulesExample />
        ) : (
          <>
            {/* First line of each page is the section title — render it
                centered and bold-cyan to match the "TEAMS" header style
                in the waiting room. */}
            {paged.current[0] && (
              <Box justifyContent="center" marginBottom={1}>
                <Text bold color="cyan">
                  {paged.current[0]}
                </Text>
              </Box>
            )}
            {paged.current.slice(1).map((line, i) => (
              <Text key={i}>{line}</Text>
            ))}
          </>
        )}
      </Box>

      <Box
        height={10}
        flexDirection="column"
        justifyContent="flex-end"
        alignItems="center"
      >
        {showHelp && (
          <Box
            flexDirection="column"
            borderStyle="round"
            borderColor="gray"
            paddingX={2}
            width={56}
            marginBottom={1}
          >
            <Box justifyContent="center" marginBottom={1}>
              <Text bold color="cyan">
                READING THE RULES
              </Text>
            </Box>
            <Text>
              Read through every page — the rules are short and the game
              goes faster when everyone knows them.
            </Text>
            <Text>
              Press <Text bold color="cyan">j</Text> or{" "}
              <Text bold color="cyan">↓</Text> for next,{" "}
              <Text bold color="cyan">k</Text> or{" "}
              <Text bold color="cyan">↑</Text> for previous.
            </Text>
            <Text>
              Type <Text bold color="cyan">:b</Text> to go back to the main
              menu.
            </Text>
          </Box>
        )}
      </Box>

      <BottomCommandBar
        commandMode={bottom.commandMode}
        buffer={bottom.buffer}
        hint={
          showHelp
            ? `page ${paged.pageNum}/${paged.totalPages}  ·  j/k page  ·  :b back  ·  esc/:? close help  ·  :q quit`
            : `page ${paged.pageNum}/${paged.totalPages}  ·  j/k page  ·  :b back  ·  :? help  ·  :q quit`
        }
      />
    </Box>
  );
}

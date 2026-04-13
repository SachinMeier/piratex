// Rules "Examples" page content — uses real Tile graphics to show the
// CAT → PACT steal and the CATS/ACTS validity contrast. Mirrors the
// worked example on the web client's /rules page.
import React from "react";
import { Box, Text } from "ink";
import { Tile } from "./Tile.js";

interface RowProps {
  letters: string[];
  dim?: boolean;
}

function TileRow({ letters, dim = false }: RowProps) {
  return (
    <Box flexWrap="wrap">
      {letters.map((l, i) => (
        <Box
          key={i}
          borderStyle="round"
          borderColor={dim ? "gray" : "cyan"}
          paddingX={1}
          marginRight={1}
        >
          <Text bold color={dim ? "gray" : "white"} dimColor={dim}>
            {l.toUpperCase()}
          </Text>
        </Box>
      ))}
    </Box>
  );
}

// Plus/Arrow are 3 lines tall so the glyph lands on the middle row,
// vertically aligned with the letter row of the adjacent tiles (which
// have top/bottom borders).
function Arrow() {
  return (
    <Box flexDirection="column" marginRight={1} paddingX={1}>
      <Text> </Text>
      <Text>→</Text>
      <Text> </Text>
    </Box>
  );
}

function Plus() {
  return (
    <Box flexDirection="column" marginRight={1} paddingX={1}>
      <Text> </Text>
      <Text>+</Text>
      <Text> </Text>
    </Box>
  );
}

function Label({ text, color }: { text: string; color?: string }) {
  return (
    <Box flexDirection="column" marginRight={1} paddingX={1}>
      <Text> </Text>
      <Text bold color={color}>
        {text}
      </Text>
      <Text> </Text>
    </Box>
  );
}

export function RulesExample() {
  return (
    <Box flexDirection="column">
      <Box justifyContent="center">
        <Text bold color="cyan">EXAMPLES</Text>
      </Box>

      <Text>Alice owns CAT. A P is flipped. Bob steals CAT to make PACT:</Text>
      <Box>
        <TileRow letters={["c", "a", "t"]} />
        <Plus />
        <TileRow letters={["p"]} />
        <Arrow />
        <TileRow letters={["p", "a", "c", "t"]} />
      </Box>

      <Text>A steal that shares an English root is INVALID:</Text>
      <Box>
        <Label text="INVALID" color="red" />
        <TileRow letters={["c", "a", "t"]} dim />
        <Plus />
        <TileRow letters={["s"]} />
        <Arrow />
        <TileRow letters={["c", "a", "t", "s"]} dim />
      </Box>

      <Text>Rearranging to a different root makes it VALID:</Text>
      <Box>
        <Label text="VALID" color="green" />
        <TileRow letters={["c", "a", "t"]} />
        <Plus />
        <TileRow letters={["s"]} />
        <Arrow />
        <TileRow letters={["a", "c", "t", "s"]} />
      </Box>

      <Text>
        Type :b and hit enter to go back to the main menu and start or
        join a game. Good luck!
      </Text>
    </Box>
  );
}

// Silence unused import warning for Tile; we use box-drawn tiles inline
// here to support the `dim` variant cleanly without modifying the shared
// Tile component. Exported to keep the module structure clean.
void Tile;

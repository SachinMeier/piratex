import React from "react";
import { Box, Text, useApp } from "ink";
import { VimSelect, VimSelectItem } from "../components/VimSelect.js";
import { TitleTiles } from "../components/TitleTiles.js";
import { CenteredScreen } from "../components/CenteredScreen.js";
import { HelpPopup } from "../components/HelpPopup.js";
import {
  hintWithHelp,
  useScreenCommand,
} from "../hooks/useScreenCommand.js";
import { useQuitApp } from "../hooks/useQuitApp.js";

type HomeChoice = "create" | "find" | "watch" | "rules" | "about" | "quit";

interface HomeMenuProps {
  onChoice(choice: Exclude<HomeChoice, "quit">): void;
}

const ITEMS: readonly VimSelectItem<HomeChoice>[] = [
  { label: "[N]ew", value: "create" },
  { label: "[J]oin", value: "find" },
  { label: "[W]atch", value: "watch" },
  { label: "[R]ules", value: "rules" },
  { label: "[A]bout", value: "about" },
  { label: "[Q]uit", value: "quit" },
];

export function HomeMenu({ onChoice }: HomeMenuProps) {
  const { exit } = useApp();
  const quitApp = useQuitApp();

  const screen = useScreenCommand({
    onQuit: quitApp,
    extra: {
      n: () => onChoice("create"),
      j: () => onChoice("find"),
      w: () => onChoice("watch"),
      r: () => onChoice("rules"),
      a: () => onChoice("about"),
    },
  });

  return (
    <CenteredScreen
      title={
        <Box justifyContent="center">
          <TitleTiles text="PIRATE SCRABBLE" />
        </Box>
      }
      commandMode={screen.commandMode}
      buffer={screen.buffer}
      showHelp={screen.showHelp}
      hint={hintWithHelp(
        "↑↓/jk navigate  ·  l/enter select  ·  :q quit",
        screen.showHelp,
      )}
      helpPopup={
        <HelpPopup title="GETTING STARTED">
          <Text>
            Select <Text bold color="cyan">New</Text> to start a new game.
          </Text>
          <Text>
            Never played before? Read the{" "}
            <Text bold color="cyan">Rules</Text>.
          </Text>
          <Text>
            Use <Text bold color="cyan">Join</Text> to enter a friend's game.
          </Text>
          <Text>
            Use <Text bold color="cyan">Watch</Text> to spectate a game.
          </Text>
        </HelpPopup>
      }
    >
      <Box flexDirection="column" paddingX={2}>
        <VimSelect
          items={ITEMS}
          isActive={!screen.commandMode}
          onSelect={(item) => {
            if (item.value === "quit") {
              exit();
              return;
            }
            onChoice(item.value);
          }}
        />
      </Box>
    </CenteredScreen>
  );
}

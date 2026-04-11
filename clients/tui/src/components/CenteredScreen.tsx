// Shared layout for every non-playing screen that has centered content
// plus a `:?` help popup. Handles the title, top flex spacer, centered
// content, bottom flex spacer hosting the popup, and the command bar —
// all in one place so every screen behaves consistently.
//
// Layout:
//
//   ┌────────────────────┐
//   │ title              │  title prop
//   ├────────────────────┤
//   │                    │  top flex spacer (flexGrow=1)
//   │     children       │  centered content
//   │                    │  bottom flex spacer (flexGrow=1), hosts popup
//   │                    │  via justifyContent=flex-end
//   ├────────────────────┤
//   │ BottomCommandBar   │  hint
//   └────────────────────┘
//
// When `showHelp` is false, the bottom spacer is empty — the flex
// distribution is unchanged, so the centered content stays put. When
// `showHelp` is true, the popup renders at the bottom of the bottom
// spacer without pushing the content (as long as the popup fits within
// the spacer's flex-computed height, which it does at 80×30 and larger).

import React from "react";
import { Box } from "ink";
import { BottomCommandBar } from "./BottomCommandBar.js";

interface CenteredScreenProps {
  title: React.ReactNode;
  children: React.ReactNode;
  hint: string;
  commandMode: boolean;
  buffer: string;
  showHelp?: boolean;
  helpPopup?: React.ReactNode;
}

export function CenteredScreen({
  title,
  children,
  hint,
  commandMode,
  buffer,
  showHelp = false,
  helpPopup,
}: CenteredScreenProps) {
  return (
    <Box flexDirection="column" flexGrow={1}>
      {title}

      {/* Top and bottom spacers both use flexBasis={0} + minHeight={0}
          so they always split remaining space evenly regardless of the
          popup's content size. Without flexBasis={0}, the bottom
          spacer's auto basis becomes the popup's intrinsic height,
          causing the top spacer to shrink and the centered content to
          jump when the popup toggles. */}
      <Box flexGrow={1} flexBasis={0} minHeight={0} />

      <Box justifyContent="center">{children}</Box>

      <Box
        flexGrow={1}
        flexBasis={0}
        minHeight={0}
        flexDirection="column"
        justifyContent="flex-end"
        alignItems="center"
      >
        {showHelp && helpPopup}
      </Box>

      <BottomCommandBar
        commandMode={commandMode}
        buffer={buffer}
        hint={hint}
      />
    </Box>
  );
}

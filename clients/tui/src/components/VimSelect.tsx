// A minimal vim-style selectable list.
//
// Bindings:
//   j / down-arrow → next
//   k / up-arrow   → previous
//   enter / l      → select current
//
// Replaces ink-select-input in menus so the navigation matches the rest of
// the TUI's neovim-inspired input model.

import React, { useState } from "react";
import { Box, Text, useInput as useInkInput } from "ink";

export interface VimSelectItem<V extends string = string> {
  label: string;
  value: V;
}

interface VimSelectProps<V extends string> {
  items: readonly VimSelectItem<V>[];
  onSelect(item: VimSelectItem<V>): void;
  initialIndex?: number;
  /** When false, the component stops listening to keystrokes entirely. Used
   * to prevent Enter from leaking into onSelect while the bottom command
   * bar is capturing input (e.g. during `:?`, `:q`, etc.). */
  isActive?: boolean;
}

export function VimSelect<V extends string>({
  items,
  onSelect,
  initialIndex = 0,
  isActive = true,
}: VimSelectProps<V>) {
  const [index, setIndex] = useState(
    Math.max(0, Math.min(initialIndex, items.length - 1)),
  );

  useInkInput(
    (rawInput, key) => {
      if (key.downArrow || rawInput === "j") {
        setIndex((i) => Math.min(items.length - 1, i + 1));
        return;
      }
      if (key.upArrow || rawInput === "k") {
        setIndex((i) => Math.max(0, i - 1));
        return;
      }
      if (key.return || rawInput === "l") {
        const picked = items[index];
        if (picked) onSelect(picked);
        return;
      }
    },
    { isActive },
  );

  return (
    <Box flexDirection="column">
      {items.map((item, i) => {
        const selected = i === index;
        return (
          <Text key={item.value}>
            <Text color={selected ? "cyan" : undefined}>
              {selected ? "› " : "  "}
            </Text>
            <Text
              color={selected ? "cyan" : "white"}
              bold={selected}
              inverse={false}
            >
              {item.label}
            </Text>
          </Text>
        );
      })}
    </Box>
  );
}

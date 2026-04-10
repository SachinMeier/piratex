// Single-line toast notification, pinned above the input area.
import React from "react";
import { Box, Text } from "ink";
import type { Toast as ToastT } from "../game-provider.js";

interface ToastProps {
  toast: ToastT | null;
}

export function Toast({ toast }: ToastProps) {
  if (!toast) {
    return <Box minHeight={1} />;
  }
  const color = toast.kind === "error" ? "red" : "cyan";
  const icon = toast.kind === "error" ? "⚠" : "ℹ";
  return (
    <Box minHeight={1}>
      <Text color={color}>
        {icon} {toast.message}
      </Text>
    </Box>
  );
}

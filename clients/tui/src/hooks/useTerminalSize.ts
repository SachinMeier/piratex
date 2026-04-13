// Reads stdout columns/rows and re-renders on SIGWINCH.

import { useEffect, useState } from "react";

export interface TerminalSize {
  columns: number;
  rows: number;
  tooSmall: boolean;
}

const MIN_COLUMNS = 80;
const MIN_ROWS = 30;

function readSize(): TerminalSize {
  const columns = (process.stdout.columns ?? 80) as number;
  const rows = (process.stdout.rows ?? 24) as number;
  return {
    columns,
    rows,
    tooSmall: columns < MIN_COLUMNS || rows < MIN_ROWS,
  };
}

export function useTerminalSize(): TerminalSize {
  const [size, setSize] = useState<TerminalSize>(() => readSize());

  useEffect(() => {
    const onResize = () => setSize(readSize());
    process.stdout.on("resize", onResize);
    return () => {
      process.stdout.off("resize", onResize);
    };
  }, []);

  return size;
}

export const MIN_TERMINAL_COLUMNS = MIN_COLUMNS;
export const MIN_TERMINAL_ROWS = MIN_ROWS;

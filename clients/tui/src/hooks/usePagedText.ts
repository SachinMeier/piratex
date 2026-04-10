// Static-page navigation. No scrolling. Each page is a list of lines that
// fit on one screen.

import { useCallback, useState } from "react";

export interface PagedTextState {
  current: string[];
  pageNum: number;
  totalPages: number;
  next(): void;
  prev(): void;
}

export function usePagedText(pages: string[][]): PagedTextState {
  const [pageIdx, setPageIdx] = useState(0);

  const next = useCallback(() => {
    setPageIdx((idx) => Math.min(pages.length - 1, idx + 1));
  }, [pages.length]);

  const prev = useCallback(() => {
    setPageIdx((idx) => Math.max(0, idx - 1));
  }, []);

  return {
    current: pages[pageIdx] ?? [],
    pageNum: pageIdx + 1,
    totalPages: pages.length,
    next,
    prev,
  };
}

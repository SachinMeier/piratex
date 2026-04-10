import { describe, expect, test } from "vitest";
import {
  computeChallengeableHistory,
  findMyTeamId,
  findMyTurnIdx,
  isMyTurn,
  poolProgress,
  recentSteals,
  showTurnTimer,
  votedToEndGame,
  wordInPlay,
} from "../derived.js";
import { GameState } from "../contract.js";

function baseState(): GameState {
  return {
    id: "ABC1234",
    status: "playing",
    turn: 1,
    total_turn: 5,
    teams: [
      { id: 100, name: "Pirates", words: ["whales"], score: 0 },
      { id: 200, name: "Sailors", words: ["anchor", "reef"], score: 0 },
    ],
    players: [
      { name: "alice", status: "playing", team_id: 100 },
      { name: "bob", status: "playing", team_id: 200 },
      { name: "carol", status: "quit", team_id: 100 },
    ],
    players_teams: { alice: 100, bob: 200, carol: 100 },
    active_player_count: 2,
    initial_letter_count: 144,
    letter_pool_count: 100,
    center: ["a", "b"],
    history: [
      {
        victim_team_idx: null,
        victim_word: null,
        thief_team_idx: 0,
        thief_player_idx: 0,
        thief_word: "whales",
        letter_count: 12,
      },
      {
        victim_team_idx: null,
        victim_word: null,
        thief_team_idx: 1,
        thief_player_idx: 1,
        thief_word: "anchor",
        letter_count: 8,
      },
      {
        victim_team_idx: null,
        victim_word: null,
        thief_team_idx: 1,
        thief_player_idx: 1,
        thief_word: "reef",
        letter_count: 4,
      },
    ],
    activity_feed: [],
    challenges: [],
    end_game_votes: {},
    challenged_words: [],
    game_stats: null,
  };
}

describe("findMyTurnIdx / isMyTurn", () => {
  test("locates current player by name", () => {
    expect(findMyTurnIdx(baseState(), "alice")).toBe(0);
    expect(findMyTurnIdx(baseState(), "bob")).toBe(1);
  });

  test("isMyTurn matches state.turn", () => {
    const s = baseState();
    expect(isMyTurn(s, "alice")).toBe(false); // turn is 1
    expect(isMyTurn(s, "bob")).toBe(true);
  });

  test("empty name is never my turn", () => {
    expect(isMyTurn(baseState(), "")).toBe(false);
  });
});

describe("findMyTeamId", () => {
  test("returns team id for known player", () => {
    expect(findMyTeamId(baseState(), "alice")).toBe(100);
  });

  test("returns null for unknown player", () => {
    expect(findMyTeamId(baseState(), "ghost")).toBe(null);
  });
});

describe("wordInPlay", () => {
  test("true if a team owns the word", () => {
    expect(wordInPlay(baseState(), "whales")).toBe(true);
    expect(wordInPlay(baseState(), "anchor")).toBe(true);
  });

  test("false otherwise", () => {
    expect(wordInPlay(baseState(), "missing")).toBe(false);
  });
});

describe("computeChallengeableHistory", () => {
  test("all entries challengeable when no challenges yet", () => {
    expect(computeChallengeableHistory(baseState())).toEqual([true, true, true]);
  });

  test("non-in-play words are not challengeable", () => {
    const s = baseState();
    s.history[0]!.thief_word = "removed";
    expect(computeChallengeableHistory(s)).toEqual([false, true, true]);
  });

  test("already-challenged pairs are not challengeable", () => {
    const s = baseState();
    s.challenged_words = [[null as unknown as string, "whales"]];
    expect(computeChallengeableHistory(s)).toEqual([false, true, true]);
  });
});

describe("votedToEndGame", () => {
  test("true if name in end_game_votes", () => {
    const s = baseState();
    s.end_game_votes = { alice: true };
    expect(votedToEndGame(s, "alice")).toBe(true);
    expect(votedToEndGame(s, "bob")).toBe(false);
  });
});

describe("showTurnTimer", () => {
  test("false in single-player game", () => {
    const s = baseState();
    s.active_player_count = 1;
    expect(showTurnTimer(s)).toBe(false);
  });

  test("false when pool empty", () => {
    const s = baseState();
    s.letter_pool_count = 0;
    expect(showTurnTimer(s)).toBe(false);
  });

  test("true otherwise", () => {
    expect(showTurnTimer(baseState())).toBe(true);
  });
});

describe("poolProgress", () => {
  test("0 when no letters used", () => {
    const s = baseState();
    s.letter_pool_count = 144;
    expect(poolProgress(s)).toBe(0);
  });

  test("1 when all letters used", () => {
    const s = baseState();
    s.letter_pool_count = 0;
    expect(poolProgress(s)).toBe(1);
  });

  test("fraction when partial", () => {
    expect(poolProgress(baseState())).toBeCloseTo(44 / 144);
  });
});

describe("recentSteals", () => {
  test("returns first 3 by default", () => {
    expect(recentSteals(baseState())).toHaveLength(3);
  });

  test("respects custom n", () => {
    expect(recentSteals(baseState(), 2)).toHaveLength(2);
  });
});

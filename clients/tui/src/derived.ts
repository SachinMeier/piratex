// Pure derivations from GameState. No side effects, no React.
// All used by the playing screen — kept here so they can be unit-tested in isolation.

import { GameState, PlayerSummary, Team, WordSteal } from "./contract.js";

export function findMyTurnIdx(state: GameState, myName: string): number {
  return state.players.findIndex((p) => p.name === myName);
}

export function isMyTurn(state: GameState, myName: string): boolean {
  if (myName === "") return false;
  return findMyTurnIdx(state, myName) === state.turn;
}

export function findMyTeamId(state: GameState, myName: string): number | null {
  if (myName === "") return null;
  return state.players_teams[myName] ?? null;
}

/** True iff some team's words contains `word`. */
export function wordInPlay(state: GameState, word: string): boolean {
  return state.teams.some((t) => t.words.includes(word));
}

/**
 * For each entry in state.history, returns whether it can still be challenged.
 * A history entry is challengeable iff (a) the thief_word is still in play AND
 * (b) the (victim_word, thief_word) pair is NOT in state.challenged_words.
 *
 * Mirrors lib/piratex_web/live/helpers.ex `precompute_challengeable_history/1`.
 */
export function computeChallengeableHistory(state: GameState): boolean[] {
  const challenged = new Set(
    state.challenged_words.map(([v, t]) => challengeKey(v, t)),
  );

  return state.history.map((ws) => {
    if (!wordInPlay(state, ws.thief_word)) return false;
    if (challenged.has(challengeKey(ws.victim_word, ws.thief_word))) return false;
    return true;
  });
}

function challengeKey(victim: string | null, thief: string): string {
  return `${victim ?? ""}->${thief}`;
}

/** Whether the local player has voted to end the game. */
export function votedToEndGame(state: GameState, myName: string): boolean {
  return Boolean(state.end_game_votes[myName]);
}

/** Whether the turn timer should be visible (multi-player AND letters remain). */
export function showTurnTimer(state: GameState): boolean {
  return state.active_player_count > 1 && state.letter_pool_count > 0;
}

/** Letter pool progress as a 0..1 fraction representing letters used. */
export function poolProgress(state: GameState): number {
  if (state.initial_letter_count === 0) return 0;
  const used = state.initial_letter_count - state.letter_pool_count;
  return used / state.initial_letter_count;
}

/** Find the player by name (or null). */
export function findPlayer(
  state: GameState,
  name: string,
): PlayerSummary | null {
  return state.players.find((p) => p.name === name) ?? null;
}

/** Look up a team by id. */
export function findTeamById(state: GameState, teamId: number): Team | null {
  return state.teams.find((t) => t.id === teamId) ?? null;
}

/** Look up the team a player belongs to. */
export function findTeamByPlayer(
  state: GameState,
  playerName: string,
): Team | null {
  const teamId = findMyTeamId(state, playerName);
  if (teamId == null) return null;
  return findTeamById(state, teamId);
}

/** Returns whether a team has at least one currently-playing player. */
export function teamHasActivePlayers(state: GameState, teamId: number): boolean {
  return state.players.some(
    (p) => p.team_id === teamId && p.status === "playing",
  );
}

/** The N most recent word steals (default 3). */
export function recentSteals(state: GameState, n = 3): WordSteal[] {
  return state.history.slice(0, n);
}

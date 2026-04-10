// Wire contract shared between the Piratex server and the TUI client.
// Mirrors Piratex.Helpers.state_for_player/1 exactly.
// Single source of truth for the shape of data on the wire.

export const PROTOCOL_VERSION = { major: 1, minor: 0 } as const;

export type GameStatus = "waiting" | "playing" | "finished";

export type PlayerStatus = "playing" | "quit";

export interface PlayerSummary {
  name: string;
  status: PlayerStatus;
  team_id: number | null;
}

export interface Team {
  id: number;
  name: string;
  words: string[];
  score: number;
}

export interface WordSteal {
  victim_team_idx: number | null;
  victim_word: string | null;
  thief_team_idx: number;
  thief_player_idx: number;
  thief_word: string;
  letter_count: number;
}

export type ActivityEntryType = "player_message" | "event";
export type ActivityEventKind =
  | "word_stolen"
  | "challenge_resolved"
  | "player_quit";

export interface ActivityEntry {
  id: number;
  type: ActivityEntryType;
  body: string;
  player_name: string | null;
  event_kind: ActivityEventKind | null;
  inserted_at: string;
  metadata: Record<string, unknown>;
}

export interface Challenge {
  id: number;
  word_steal: WordSteal;
  votes: Record<string, boolean>;
  result: boolean | null;
}

export interface RawPlayerStats {
  points: number;
  words: string[];
  steals: number;
  points_per_steal: number;
}

export interface TeamStats {
  total_letters: number;
  total_score: number;
  word_count: number;
  word_length_distribution: Record<string, number>;
  avg_points_per_word: Record<string, number>;
  margin_of_victory: number;
  avg_word_length: number;
}

export interface ChallengeStats {
  count: number;
  valid_ct: number;
  player_stats: Record<string, unknown>;
  invalid_word_steals: WordSteal[];
}

export interface RawMVP {
  player_idx: number;
  points: number;
  words: string[];
  steals: number;
  points_per_steal: number;
}

// Only the fields the TUI v1 actually reads. Extras are allowed (forward-compat).
export interface GameStats {
  total_score?: number;
  total_steals?: number;
  game_duration?: number;
  longest_word?: string;
  longest_word_length?: number;
  best_steal?: WordSteal | null;
  best_steal_score?: number;
  team_stats?: Partial<TeamStats>;
  challenge_stats?: Partial<ChallengeStats>;
  raw_mvp?: Partial<RawMVP>;
  // Not consumed by v1 UI but may be present in wire payload:
  heatmap?: Record<string, number>;
  heatmap_max?: number;
  score_timeline?: Record<string, Array<[number, number]>>;
  score_timeline_max?: number;
  raw_player_stats?: Record<string, RawPlayerStats>;
}

export interface GameState {
  id: string;
  status: GameStatus;
  turn: number;
  total_turn: number;
  teams: Team[];
  players: PlayerSummary[];
  players_teams: Record<string, number>;
  active_player_count: number;
  initial_letter_count: number;
  letter_pool_count: number;
  center: string[];
  history: WordSteal[];
  activity_feed: ActivityEntry[];
  challenges: Challenge[];
  end_game_votes: Record<string, true>;
  challenged_words: Array<[string, string]>;
  game_stats: GameStats | null;
}

export interface GameConfig {
  turn_timeout_ms: number;
  challenge_timeout_ms: number;
  min_word_length: number;
  max_chat_message_length: number;
  min_player_name: number;
  max_player_name: number;
  min_team_name: number;
  max_team_name: number;
}

export interface JoinReply {
  game_id: string;
  protocol: { major: number; minor: number };
  upgrade_available: boolean;
  config: GameConfig;
}

export type LetterPoolType = "bananagrams" | "bananagrams_half";

export type SessionIntent = "join" | "rejoin" | "watch";

export interface CreateGameResponse {
  game_id: string;
}

export interface JoinGameResponse {
  game_id: string;
  player_name: string;
  player_token: string;
}

export interface GameSummary {
  id: string;
  status: GameStatus;
  player_count: number;
}

export interface GamesListResponse {
  games: GameSummary[];
  page: number;
  has_next: boolean;
}

export interface ApiError {
  error: string;
  message?: string;
  server_version?: string;
  client_version?: string;
  upgrade_url?: string;
}

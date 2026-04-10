# Piratex TUI — Technical Specification

## 1. Overview

A terminal client for Piratex that achieves page parity with the LiveView web client
(except the admin `/controls` page). Additive, does not replace the web client. Shares
no code with LiveView; communicates with the server via a new Phoenix Channel and a
small JSON HTTP API.

**Goals**

- Full-fidelity play: discover/create/join, waiting room, playing, finished, watch,
  rules, about.
- End-user install = download one binary. No Elixir, Node, or bun runtime on the
  player's machine.
- Backend stays frontend-agnostic: zero changes to `lib/piratex/` except
  `@derive Jason.Encoder` on five structs and one MapSet→list conversion.
- Channel design leaves room for an LLM bot in v2 without requiring any server
  changes — see §10 for the design note. Not a v1 deliverable.

**Non-Goals (v1)**

- Speech recognition, sound effects, score graphs, heatmaps.
- Code sharing between LiveView and TUI clients.
- Crash recovery (credentials are in-memory only).
- Single-session anti-collusion enforcement (deferred).

## 2. Architecture

    ┌─────────────────────────────────────────────────────────────────┐
    │  lib/piratex/  (UNTOUCHED — game logic, services, structs)      │
    │                                                                 │
    │  Game GenServer  ◄── Piratex.Game.* public API                  │
    │  PubSub topic game-events:<id>  (broadcast on every state)      │
    │                                                                 │
    ├─────────────────────────────────────────────────────────────────┤
    │  lib/piratex_web/  (adapters — two in parallel)                 │
    │                                                                 │
    │  ┌──────────────────┐          ┌──────────────────────┐         │
    │  │  LiveView         │          │  GameChannel  (NEW)  │         │
    │  │  Live.Game        │          │  UserSocket   (NEW)  │         │
    │  │  GameSession      │          │  GameAPICtrl  (NEW)  │         │
    │  │  GameController   │          └──────────┬───────────┘         │
    │  └──────────┬───────┘                     │                     │
    │             │ both call Piratex.Game.*    │                     │
    │             │ both subscribe to PubSub    │                     │
    │             └─────────────────────────────┘                     │
    │                                                                 │
    │  The two adapters share nothing. LiveView is not modified.      │
    └─────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────────┐
    │  clients/tui/  (new Node/TS project — NOT Elixir)              │
    │  Speaks Phoenix Channel protocol over /socket                   │
    │  Speaks JSON HTTP to /api/*                                     │
    │  Zero knowledge of LiveView, HEEX, or Elixir internals          │
    └─────────────────────────────────────────────────────────────────┘

## 3. Wire Contracts

These are frozen as soon as Phase 1 is merged. Both sides of the wire must agree; any
change is a single coordinated PR.

### 3.1 HTTP API (`/api/*`)

| Method | Path | Request | Success |
|---|---|---|---|
| `POST` | `/api/games` | `{ "letter_pool": "bananagrams" \| "bananagrams_half" }` (field optional; omitted or `null` defaults to `"bananagrams"`) | `201 Created` + `{ "game_id": string }` |
| `GET` | `/api/games` | query: `?page=N` (default 1) | `200 OK` + `{ "games": [...], "page": int, "has_next": bool }` |
| `GET` | `/api/games/:id` | — | `200 OK` + sanitized state (same shape as channel `state` push) |
| `POST` | `/api/games/:id/players` | `{ "player_name": string }` | `201 Created` + `{ "game_id", "player_name", "player_token" }` |

**Error response shape** is uniform across all endpoints:

    { "error": "<reason_atom>", "message": "<human-readable>" }

The `reason` is an atom-string from the Game GenServer's existing error set. The
`message` is optional human-readable text.

**HTTP status codes by error reason:**

| Reason | Status | Where it fires |
|---|---|---|
| `:not_found` | `404 Not Found` | `GET /api/games/:id`, `POST /api/games/:id/players` (game doesn't exist) |
| `:game_full` | `409 Conflict` | `POST /api/games/:id/players` |
| `:game_already_started` | `409 Conflict` | `POST /api/games/:id/players` (join after start) |
| `:duplicate_player` | `409 Conflict` | `POST /api/games/:id/players` |
| `:team_name_taken` | `409 Conflict` | `POST /api/games/:id/players` (name collides with team) |
| `:player_name_too_short` | `400 Bad Request` | `POST /api/games/:id/players` |
| `:player_name_too_long` | `400 Bad Request` | `POST /api/games/:id/players` |
| `:invalid_pool` | `400 Bad Request` | `POST /api/games` (unknown `letter_pool` value) |
| `:invalid_body` | `400 Bad Request` | Malformed JSON / missing required field |
| `:client_outdated` | `426 Upgrade Required` | Any endpoint, major protocol mismatch |
| `:server_outdated` | `426 Upgrade Required` | Any endpoint, client major ahead of server |
| Unhandled | `500 Internal Server Error` | Any unexpected GenServer crash |

Defaults: `POST /api/games` with an empty body, missing `letter_pool`, or explicit
`null` all create a game with `"bananagrams"`. Any other value for `letter_pool`
returns `400 :invalid_pool`.

### 3.2 Socket Connect

    new Socket("wss://piratescrabble.com/socket", {
      params: {
        player_token: "<base64 token>",  // required for "join"/"rejoin", omitted for "watch"
        client: "piratex-tui/0.1.0"       // free-form, for telemetry
      }
    })

### 3.3 Channel Join

Topic: `"game:<id>"`. Join payload:

    { player_name: string, intent: "join" | "rejoin" | "watch" }

Join reply (success):

    {
      game_id: string,
      config: {
        turn_timeout_ms: int,
        challenge_timeout_ms: int,
        min_word_length: int,
        max_chat_message_length: int,
        min_player_name: int,
        max_player_name: int,
        min_team_name: int,
        max_team_name: int
      }
    }

Join reply (error): `{ reason: "<atom>" }` where reason is one of `:not_found`,
`:game_full`, `:duplicate_player`, `:game_already_started`, `:player_not_found`.

### 3.4 Inbound Commands (`handle_in`)

Every command is a one-to-one map to `Piratex.Game.*`. Watch-intent clients get
`{:error, :watch_only}` for all of these.

| Event | Payload | Game API | Reply on success |
|---|---|---|---|
| `start_game` | `{}` | `Game.start_game/2` | `:ok` |
| `create_team` | `{ "team_name": string }` | `Game.create_team/3` | `:ok` |
| `join_team` | `{ "team_id": int }` | `Game.join_team/3` | `:ok` |
| `set_letter_pool_type` | `{ "pool_type": string }` | `Game.set_letter_pool_type/2` | `:ok` |
| `flip_letter` | `{}` | `Game.flip_letter/2` | `:ok` |
| `claim_word` | `{ "word": string }` | `Game.claim_word/3` | `:ok` |
| `challenge_word` | `{ "word": string }` | `Game.challenge_word/3` | `:ok` |
| `challenge_vote` | `{ "challenge_id": int, "vote": bool }` | `Game.challenge_vote/4` | `:ok` |
| `send_chat_message` | `{ "message": string }` | `Game.send_chat_message/3` | `:ok` |
| `end_game_vote` | `{}` | `Game.end_game_vote/2` | `:ok` |
| `leave_waiting_game` | `{}` | `Game.leave_waiting_game/2` | `:ok` |
| `quit_game` | `{}` | `Game.quit_game/2` | `:ok` |

Errors reply `{:error, %{reason: "<atom>"}}`. Reasons are the atoms the GenServer
already returns (`:invalid_word`, `:not_your_turn`, `:word_in_play`,
`:cannot_make_word`, `:challenge_open`, `:no_more_letters`, `:already_voted`, etc.).

### 3.5 Outbound Pushes

| Event | Payload | When |
|---|---|---|
| `state` | sanitized `GameState` (see §3.6) | On every PubSub `:new_state` broadcast, and as the first push after join |

**Only one server→client event.** `game_stats` is **not** a separate push — it lives
at `state.game_stats`, which is `null` while the game is in progress and becomes a
populated map when the game transitions to `:finished`. The TUI reads
`state.game_stats` from the same `state` push it already subscribes to. The
existing `broadcast_game_stats/1` helper in `lib/piratex/game.ex` is unused
production code and should stay untouched — the channel simply doesn't subscribe
to or forward it.

### 3.6 GameState (TypeScript contract)

Mirrors `Piratex.Helpers.state_for_player/1` exactly. Lives at
`clients/tui/src/contract.ts` and is the single source of truth for the wire shape.

    type GameStatus = "waiting" | "playing" | "finished";

    interface GameState {
      id: string;
      status: GameStatus;
      turn: number;                     // current player index
      total_turn: number;               // monotonic turn counter (resets countdown timer)
      teams: Team[];
      players: PlayerSummary[];         // no tokens
      players_teams: Record<string, number>; // player_name → team_id
      active_player_count: number;
      initial_letter_count: number;
      letter_pool_count: number;
      center: string[];                 // single-letter strings, chronological
      history: WordSteal[];             // most recent first
      activity_feed: ActivityEntry[];
      challenges: Challenge[];          // 0 or 1 open
      end_game_votes: Record<string, true>;
      challenged_words: [string, string][]; // (victim, thief) pairs — MapSet serialized to list
      game_stats: GameStats | null;
    }

    interface Team {
      id: number;
      name: string;
      words: string[];
      score: number;                    // only meaningful when status = "finished"
    }

    interface PlayerSummary {
      name: string;
      status: "playing" | "quit";
      team_id: number | null;
    }

    interface WordSteal {
      victim_team_idx: number | null;
      victim_word: string | null;
      thief_team_idx: number;
      thief_player_idx: number;
      thief_word: string;
      letter_count: number;             // letters flipped at time of steal
    }

    interface ActivityEntry {
      id: number;
      type: "player_message" | "event";
      body: string;
      player_name: string | null;
      event_kind: "word_stolen" | "challenge_resolved" | "player_quit" | null;
      inserted_at: string;              // ISO8601
      metadata: Record<string, unknown>;
    }

    interface Challenge {
      id: number;
      word_steal: WordSteal;
      votes: Record<string, boolean>;   // player_name → vote
      result: boolean | null;
    }

    // Mirrors ScoreService.calculate_game_stats/1. The server produces more
    // fields than the TUI consumes; extras are ignored (forward-compat for
    // score graphs, heatmaps, etc. in v2). The fields below are the ones the
    // FinishedScreen actually renders.
    interface GameStats {
      total_score: number;          // sum of all team scores
      total_steals: number;         // count of all valid word steals
      game_duration: number;        // seconds
      longest_word: string;
      longest_word_length: number;
      best_steal: WordSteal | null;
      best_steal_score: number;
      team_stats: {
        margin_of_victory: number;  // first - second place score delta
        avg_word_length: number;
      };
      challenge_stats: {
        count: number;              // total challenges issued
        valid_ct: number;           // how many were upheld (word stayed)
      };
      raw_mvp: {
        player_idx: number;         // index into state.players
        points: number;
        words: string[];
        steals: number;
        points_per_steal: number;
      };
      // Present in the wire but ignored by v1 TUI:
      // heatmap, heatmap_max, score_timeline, score_timeline_max, raw_player_stats
    }

### 3.7 Protocol Versioning & Upgrade Prompts

An installed TUI binary can outlive several server deployments. Once the wire
contract drifts, the TUI needs to detect the mismatch and tell the user what to
do — not crash, not silently corrupt game state.

**Design: two integers, `major.minor`, checked at connect time.** Major is a
hard compatibility gate. Minor is a soft "upgrade available" hint.

#### 3.7.1 Semantics

| Change | Bump |
|---|---|
| Breaking change to wire contract: removed/renamed event, removed/renamed field, changed field type, changed required payload shape | **Major** |
| Additive, backward-compatible change: new optional server→client field, new server-only event the client can ignore, new error reason atom | **Minor** |
| Internal refactor, TUI UI change, new menu, bug fix | **neither** |

**Rule of thumb:** if an old client connecting to the new server would
misinterpret any data or fail to execute any command it thinks it should be
able to execute → **major**. If it would simply miss out on new features but
play correctly → **minor**. If it wouldn't even notice → **neither**.

Both numbers live in one place on each side:

- Server: `@protocol_version {1, 0}` in `PiratexWeb.GameChannel` (or a small
  `PiratexWeb.Protocol` module shared with the API controller).
- Client: `export const PROTOCOL_VERSION = { major: 1, minor: 0 }` in
  `clients/tui/src/contract.ts`.

**Bump policy:**

- Major bumps are rare and deliberate — they require a coordinated release: new
  server deploy + new TUI binary + GitHub release + updated install script. Any
  player on an old binary is locked out until they upgrade.
- Minor bumps happen any time the server adds something useful that the TUI
  would benefit from knowing about. Old clients keep working.
- Each TUI binary release carries its own semver (`tui-v1.4.0`, etc.) — the
  TUI semver and the protocol semver are independent. A TUI release might bump
  TUI semver without touching protocol semver (pure UI changes).

#### 3.7.2 Where it's checked

**At channel join.** The client passes `protocol_major` and `protocol_minor` as
join params. The server compares:

    def join("game:" <> game_id, params, socket) do
      client_major = Map.get(params, "protocol_major", 0)
      client_minor = Map.get(params, "protocol_minor", 0)
      {server_major, server_minor} = @protocol_version

      cond do
        client_major < server_major ->
          {:error, %{
            reason: :client_outdated,
            severity: :hard,
            server_version: "#{server_major}.#{server_minor}",
            client_version: "#{client_major}.#{client_minor}",
            upgrade_url: "https://github.com/SachinMeier/piratex/releases/latest"
          }}

        client_major > server_major ->
          {:error, %{
            reason: :server_outdated,
            severity: :hard,
            server_version: "#{server_major}.#{server_minor}",
            client_version: "#{client_major}.#{client_minor}"
          }}

        true ->
          # same major: proceed
          socket = assign(socket, :minor_mismatch, client_minor < server_minor)
          do_join(game_id, params, socket)
      end
    end

The successful-join reply carries an `upgrade_available` field when the client's
minor is behind:

    {
      game_id: "ABC1234",
      config: { ... },
      upgrade_available: true | false,      // set if client_minor < server_minor
      latest_version: "1.4.0"                // latest known TUI semver
    }

**Also at HTTP API level.** Every `/api/*` request inspects two headers:

    X-Piratex-Protocol-Major: 1
    X-Piratex-Protocol-Minor: 3

Same three-way comparison. Major mismatch → HTTP 426. Minor behind → the
response body gains an `upgrade_available: true` field (alongside the normal
payload) and a `latest_version` string. Minor ahead of server → treated as a
match (the server ignores unknown capabilities).

    HTTP/1.1 426 Upgrade Required

    {
      "error": "client_outdated",
      "severity": "hard",
      "server_version": "2.0",
      "client_version": "1.3",
      "upgrade_url": "https://github.com/SachinMeier/piratex/releases/latest"
    }

Missing headers are treated as `0.0`, failing any non-trivial compatibility
check.

#### 3.7.3 Client behavior

**Hard mismatch (different major):**

1. Abort the connection attempt. Do not retry.
2. Tear down any partial session.
3. Route to the `<UpgradePrompt />` screen (below). Only `q` exits.

**Soft mismatch (same major, server minor is ahead):**

1. The session connects normally; the user can play.
2. A non-intrusive status-line badge appears in the header of the playing
   screen: `⤴ update available (1.4.0)`.
3. Pressing `:u` opens a full-screen info panel showing the install command and
   a `[enter] keep playing` / `[q] quit and upgrade` choice.
4. The badge is suppressed if the user has dismissed it this session (`esc`
   from the info panel).

Soft upgrades never interrupt gameplay — the user is in the middle of a 40-
minute game, and a prompt mid-word would be actively harmful.

#### 3.7.4 Upgrade Prompt Screen (hard mismatch)

    ┌─ piratex ─────────────────────────────────────────────┐
    │                                                        │
    │             ⚠  piratex needs to be upgraded            │
    │                                                        │
    │     your version: 1.3                                  │
    │     server version: 2.0                                │
    │                                                        │
    │     the protocol changed in a way that requires a      │
    │     new binary. one command to install the latest:     │
    │                                                        │
    │     curl -fsSL https://raw.githubusercontent.com/      │
    │       SachinMeier/piratex/main/clients/tui/install.sh  │
    │       | sh                                             │
    │                                                        │
    │     or download directly:                              │
    │     https://github.com/SachinMeier/piratex/releases    │
    │                                                        │
    │     [q] quit                                           │
    └────────────────────────────────────────────────────────┘

The TUI cannot proceed without an upgrade, on purpose — further interaction
risks confused state.

#### 3.7.5 Schema drift as a secondary safety net

Version gating catches known changes. A secondary check catches a developer
forgetting to bump the major version when they should have:

**The TUI validates every `state` push against the known `GameState` shape.**
A small hand-rolled validator in `clients/tui/src/validate.ts` checks that the
fields the TUI reads are present and of the right type. On failure:

1. Log the specific mismatch to stderr (for bug reports).
2. Show a toast: `⚠ unexpected state from server — you may need to upgrade`.
3. Do **not** tear down the session. The user is mid-game; advisory only.

The validator deliberately **ignores unknown extra fields** — that's how
additive minor bumps stay forward-compatible. New fields from a future server
are silently dropped by the old TUI, which is exactly what we want.

No Zod or similar. Ten lines of hand-rolled checks covering the fields the TUI
actually reads. The validator runs once per state push and is cheap.

#### 3.7.6 Server-side logging

Every version-gate rejection emits a Logger warning with `client_version`,
`client` socket param (`piratex-tui/0.3.1`), remote IP, and reason. The
`/api/*` middleware emits the same on HTTP 426 responses. Visible in
standard server logs — no separate telemetry pipeline required.

#### 3.7.7 What this is not

- **Not auto-update.** The TUI does not download and replace itself. Too much
  blast radius, too much security surface. The user runs the install script.
- **Not a deprecation window.** A major bump locks out old binaries
  immediately on next connect. The bar for bumping major is therefore high.
- **Not a capability negotiation.** One pair of integers. No feature lists.

#### 3.7.8 Release discipline

To make this work, TUI releases follow strict semver:

- **Tag format:** `tui-v<major>.<minor>.<patch>`, e.g. `tui-v1.0.0`, `tui-v1.3.2`.
- **Binary embeds its own semver.** `piratex --version` prints
  `piratex 1.3.2 (protocol 1.0)`.
- **CHANGELOG.md** at `clients/tui/CHANGELOG.md` lists every release with the
  protocol version it speaks.
- **Release-note template** includes a mandatory "Protocol changes" section. An
  entry there implies a minor or major bump.
- **Server deploys that bump the major version require a coordinated TUI
  release.** The server deploy PR description must link the TUI release PR.

Both parts of the protocol version are part of the server's compile-time
constants, not runtime config. You can't flip them without a deploy, and a
deploy with a major bump should flag itself in CI (a small test asserting the
`@protocol_version` matches an expected value in a snapshot file).

## 4. Phase 1 — Backend Adapter

**Goal:** any client speaking the Phoenix Channel protocol + the JSON HTTP API can
play a full game end-to-end.

**Prerequisite:** freeze §3 (wire contracts).

### 4.1 Deliverables

| # | File | Purpose |
|---|---|---|
| 1.1 | `lib/piratex_web/user_socket.ex` | `Phoenix.Socket` at `/socket`; pulls `player_token` from params |
| 1.2 | `lib/piratex_web/channels/game_channel.ex` | Channel on `"game:<id>"` — join, handle_in, handle_info |
| 1.3 | `lib/piratex_web/controllers/game_api_controller.ex` | Four JSON endpoints (§3.1) |
| 1.4 | `lib/piratex_web/controllers/game_api_json.ex` | Jason views for API responses |
| 1.5 | `lib/piratex_web/endpoint.ex` | Mount `UserSocket` at `/socket` (additive) |
| 1.6 | `lib/piratex_web/router.ex` | Add `:api` pipeline + `/api` scope (additive) |
| 1.7 | Multiple struct files | `@derive Jason.Encoder` on `%WordSteal{}`, `%Team{}`, `%Player{}`, `%ActivityFeed.Entry{}`, `%ChallengeService.Challenge{}` (with explicit `only:` exclusions — `%Challenge{}` must exclude `:timeout_ref`, which is a reference that Jason cannot encode) |
| 1.8 | `lib/piratex_web/channels/game_channel.ex` | The channel also converts `state.challenged_words` from MapSet to a list of `[victim, thief]` pairs right before pushing — no change to `Piratex.Helpers` needed, leaves LiveView untouched |
| 1.9 | `test/piratex_web/channels/game_channel_test.exs` | One test per `handle_in` clause + join/rejoin/watch flows + protocol-version gate + JSON-encoding round trip |
| 1.10 | `test/piratex_web/controllers/game_api_controller_test.exs` | Integration tests for all four endpoints, all error reasons, all status codes |
| 1.11 | `test/piratex_web/protocol_version_test.exs` | Pinned snapshot of the server's `@protocol_version` — see §7.9.4 |

### 4.2 `UserSocket` Details

    defmodule PiratexWeb.UserSocket do
      use Phoenix.Socket
      channel "game:*", PiratexWeb.GameChannel

      def connect(params, socket, _connect_info) do
        token = Map.get(params, "player_token", "")
        client = Map.get(params, "client", "unknown")
        {:ok, assign(socket, player_token: token, client: client)}
      end

      def id(%{assigns: %{player_token: ""}}), do: nil
      def id(%{assigns: %{player_token: t}}), do: "users_socket:#{t}"
    end

The empty-token case exists to support watch-intent clients that never authenticated.

### 4.3 `GameChannel` Details

**`join/3` logic:**

    def join("game:" <> game_id, params, socket) do
      case Piratex.Game.find_by_id(game_id) do
        {:error, :not_found} ->
          {:error, %{reason: :not_found}}

        {:ok, _} ->
          intent = Map.get(params, "intent", "join")
          player_name = Map.get(params, "player_name", "")
          token = socket.assigns.player_token

          with :ok <- handle_intent(intent, game_id, player_name, token) do
            Phoenix.PubSub.subscribe(Piratex.PubSub, Piratex.Game.events_topic(game_id))
            send(self(), :after_join)

            socket =
              socket
              |> assign(:game_id, game_id)
              |> assign(:player_name, player_name)
              |> assign(:intent, intent)

            {:ok, %{game_id: game_id, config: game_config()}, socket}
          end
      end
    end

    defp handle_intent("join", game_id, name, token),
      do: Piratex.Game.join_game(game_id, name, token)
    defp handle_intent("rejoin", game_id, name, token),
      do: Piratex.Game.rejoin_game(game_id, name, token)
    defp handle_intent("watch", _game_id, _name, _token), do: :ok
    defp handle_intent(_, _, _, _), do: {:error, :invalid_intent}

**`:after_join` handler:** fetches current state via `Piratex.Game.get_state/1` and
pushes it as `"state"`. This ensures mid-game joiners and watchers see the current
board immediately.

**`handle_info({:new_state, state}, socket)`:** push `"state"` with `state` as-is.

**`handle_info({:game_stats, stats}, socket)`:** push `"game_stats"`.

**`handle_in`:** 12 clauses (one per §3.4 event). Each is three lines: pattern match,
call the Game API, reply with the result. Watch-intent clients get
`{:reply, {:error, %{reason: :watch_only}}, socket}` from a catch-all clause.

**`terminate/2`:** `Phoenix.PubSub.unsubscribe/2`. Do not send `quit_game` — player can
reconnect.

**`game_config/0`:** reads values from `Piratex.Config` once at join time and builds the
config map (see §3.3 join reply).

### 4.4 `GameAPIController` Details

Four actions — `:create`, `:index`, `:show`, `:join`. Thin wrappers around existing
`Piratex.DynamicSupervisor` / `Piratex.Game` / `Piratex.PlayerService` functions. No
session cookies, no CSRF, no auth — token possession is the entire auth model.

`:join` calls `Piratex.Game.join_game/3` with a freshly minted token. The subsequent
channel join from the TUI uses `intent: "rejoin"` since the player is now registered.

### 4.5 Jason Encoding

Use explicit `@derive {Jason.Encoder, only: [...]}` on each struct. The `only:`
form ensures non-encodable fields (like process references) are excluded and
prevents accidental token leakage if someone adds a new struct field later.

    @derive {Jason.Encoder, only: [:victim_team_idx, :victim_word, :thief_team_idx,
                                    :thief_player_idx, :thief_word, :letter_count]}
    defstruct [...]  # Piratex.WordSteal

    @derive {Jason.Encoder, only: [:id, :name, :words, :score]}
    defstruct [...]  # Piratex.Team (excludes :players — already nested separately)

    @derive {Jason.Encoder, only: [:name, :status, :team_id]}
    defstruct [...]  # Piratex.Player (excludes :token)

    @derive {Jason.Encoder, only: [:id, :type, :body, :player_name,
                                    :event_kind, :inserted_at, :metadata]}
    defstruct [...]  # Piratex.ActivityFeed.Entry

    @derive {Jason.Encoder, only: [:id, :word_steal, :votes, :result]}
    defstruct [...]  # Piratex.ChallengeService.Challenge
                     # :timeout_ref is a reference(), must be excluded

The existing `drop_internal_state/1` and `sanitize_players_teams/1` in
`Piratex.Helpers` continue to strip tokens before encoding. That's already
correct for the LiveView and the channel uses the same `state_for_player/1`
output.

**MapSet conversion is a channel-layer concern, not a helpers change.** The
channel's `handle_info({:new_state, state}, socket)` receives the sanitized
state with `challenged_words` as a `MapSet` of `{victim, thief}` tuples. Before
pushing, the channel runs:

    def handle_info({:new_state, state}, socket) do
      payload = Map.update!(state, :challenged_words, fn mapset ->
        mapset
        |> Enum.to_list()
        |> Enum.map(fn {v, t} -> [v, t] end)  # tuples → 2-element arrays
      end)
      push(socket, "state", payload)
      {:noreply, socket}
    end

The `:after_join` handler and `GameAPIController.show/2` run the same
transformation via a shared helper (`GameChannel.encode_state/1`).
`Piratex.Helpers.state_for_player/1` stays untouched, the LiveView continues to
receive the MapSet form it expects, and the JSON-encoded form is only produced
at the wire boundary.

### 4.6 Tests

**`game_channel_test.exs`** — uses `Phoenix.ChannelTest`:

- `join/3` — each intent, each success and failure case
- `handle_in` — one happy-path test per command, plus one error case per command
- Pub/sub — assert that a `:new_state` broadcast becomes a `"state"` push
- Watch intent — all commands rejected with `:watch_only`

**`game_api_controller_test.exs`**:

- `POST /api/games` — success and invalid pool
- `GET /api/games` — pagination
- `GET /api/games/:id` — success and `:not_found`
- `POST /api/games/:id/players` — success, duplicate player, game full

### 4.7 Acceptance Criteria

- `mix test` passes with all new tests.
- `mix format --check-formatted` clean.
- A hand-driven Node script at `scripts/smoke/channel_smoke.ts` (not committed;
  throwaway) can create a game, join as two players, play a short game to completion.
- Zero changes in `git diff lib/piratex/` except the five `@derive Jason.Encoder`
  annotations. No other `lib/piratex/` files touched.

## 5. Phase 2 — TUI Foundation

**Goal:** a minimal Ink app that connects to the channel, joins a game, and renders
raw state. Proves the wire and the toolchain.

**Prerequisite:** Phase 1 merged.

### 5.1 Deliverables

| # | File | Purpose |
|---|---|---|
| 2.1 | `clients/tui/package.json` | Dependencies: `ink`, `react`, `phoenix`, `ws`, `tsup`, `typescript`, `vitest`, `ink-testing-library` |
| 2.2 | `clients/tui/tsconfig.json` | TS config targeting Node 18, strict mode |
| 2.3 | `clients/tui/src/contract.ts` | Types from §3.6 + channel message types |
| 2.4 | `clients/tui/src/config.ts` | Server URL handling (`--server` flag, default to prod wss) |
| 2.5 | `clients/tui/src/api.ts` | HTTP client wrapping the four `/api/*` endpoints |
| 2.6 | `clients/tui/src/socket.ts` | `createGameConnection()` — builds Socket, joins channel, returns typed wrappers |
| 2.7 | `clients/tui/src/game-provider.tsx` | `GameProvider` + `useGame()` hook |
| 2.8 | `clients/tui/src/app.tsx` | Top-level `<App />` with router state machine |
| 2.9 | `clients/tui/src/index.tsx` | Ink entry point |
| 2.10 | `clients/tui/src/menus/HomeMenu.tsx` | Select-input: new / join / watch / rules / about / quit |
| 2.11 | `clients/tui/src/menus/CreateGameMenu.tsx` | Pool selection → `POST /api/games` → JoinPrompt |
| 2.12 | `clients/tui/src/menus/FindGameMenu.tsx` | Game ID input + game list |
| 2.13 | `clients/tui/src/menus/JoinPrompt.tsx` | Player name input → `POST /api/games/:id/players` → connect channel |
| 2.14 | `clients/tui/src/screens/RawStateScreen.tsx` | Temporary — dumps `JSON.stringify(state)` to prove wire works |
| 2.15 | `Makefile` | `make tui`, `make tui-dev`, `make tui-clean`, `make install` targets |

### 5.2 `GameProvider` Contract

    type CurrentSession = {
      gameId: string;
      playerName: string;             // empty string for watch sessions
      playerToken: string;             // empty string for watch sessions
      intent: "player" | "watch";
      socket: Socket;
      channel: Channel;
      config: GameConfig;              // from channel join reply
    } | null;

    type StartSessionParams =
      | { kind: "create"; pool: "bananagrams" | "bananagrams_half"; playerName: string }
      | { kind: "join";   gameId: string; playerName: string }
      | { kind: "watch";  gameId: string };

    interface GameContext {
      session: CurrentSession;
      gameState: GameState | null;
      toast: { kind: "info" | "error"; message: string } | null;

      // Session lifecycle — the only way to create or destroy a session
      startSession(params: StartSessionParams): Promise<void>;
      quitSession(): Promise<void>;    // sends quit_game (player only), tears down, clears
      tearDownSession(): void;          // just tears down, no quit_game

      // Commands — thin wrappers over channel.push
      push<T = Record<string, unknown>>(event: string, payload?: unknown): Promise<T>;

      // Toast
      showToast(kind: "info" | "error", message: string, ttlMs?: number): void;
    }

`session` is either `null` (home screen) or a fully connected record. There is
never an intermediate state — connect errors reject the `startSession` promise
and leave `session` null.

`gameStats` does not have its own field — read `gameState.game_stats` once the
game is finished (see §3.5).

**`startSession` dispatch:**

| `kind` | Sequence |
|---|---|
| `create` | `POST /api/games` (with `pool`) → `POST /api/games/:id/players` (with `playerName`) → `new Socket(...)` with returned token → channel join with `intent: "rejoin"` |
| `join` | `POST /api/games/:id/players` → `new Socket(...)` with returned token → channel join with `intent: "rejoin"` |
| `watch` | `new Socket(...)` with empty token → channel join with `intent: "watch"` (no HTTP call, no player registration) |

Note the subtlety: the HTTP API endpoint is what actually calls
`Piratex.Game.join_game/3` and registers the player. By the time the channel
connects, the player already exists in the GenServer, so the channel join uses
`intent: "rejoin"` — not `"join"`. This avoids a double-join race.

**Push → Promise wrapper** (lives in `src/socket.ts`, used by `useGame().push`):

    function pushAsync<T = Record<string, unknown>>(
      channel: Channel,
      event: string,
      payload: unknown = {},
      timeoutMs = 5000
    ): Promise<T> {
      return new Promise((resolve, reject) => {
        channel.push(event, payload, timeoutMs)
          .receive("ok", (reply) => resolve(reply as T))
          .receive("error", (reply) => {
            const reason =
              typeof reply === "object" && reply && "reason" in reply
                ? String((reply as { reason: unknown }).reason)
                : "unknown_error";
            reject(new Error(reason));
          })
          .receive("timeout", () => reject(new Error("timeout")));
      });
    }

Callers in screens await this and `.catch` to surface the rejection as a toast.
The `.message` of the rejected error is the reason atom from the server, ready
to display.

### 5.3 Router

Simple React state, not a URL-based router:

    type Route =
      | { kind: "home" }
      | { kind: "find" }
      | { kind: "create" }
      | { kind: "join_prompt"; gameId: string }
      | { kind: "watch_prompt" }
      | { kind: "waiting" }           // reads from GameProvider
      | { kind: "playing" }
      | { kind: "finished" }
      | { kind: "watching" }          // reads from GameProvider, watch session
      | { kind: "rules" }
      | { kind: "about" }
      | { kind: "upgrade_prompt"; serverVersion: string; clientVersion: string };

The route for `waiting`/`playing`/`finished` is **derived** from
`gameState.status`, so transitions between those three are automatic when state
pushes arrive. The other routes are explicit navigations.

**Transition table:**

| From | Trigger | To |
|---|---|---|
| home | select "new" | create |
| home | select "join" | find |
| home | select "watch" | watch_prompt |
| home | select "rules" | rules |
| home | select "about" | about |
| home | select "quit" | exit process (clean shutdown) |
| find | submit game id or pick from list | join_prompt |
| find | esc | home |
| create | submit pool selection | (calls startSession kind=create) |
| create | esc | home |
| join_prompt | submit player name | (calls startSession kind=join) |
| join_prompt | esc | home |
| watch_prompt | submit game id | (calls startSession kind=watch) |
| watch_prompt | esc | home |
| (after startSession success) | channel state push | waiting / playing / watching (derived from status + intent) |
| (after startSession rejected with protocol mismatch) | — | upgrade_prompt |
| waiting | `:s` sent + state update | playing (derived from status) |
| waiting | `:q` confirmed | (quitSession) home |
| playing | `:q` confirmed | (quitSession) home |
| playing | state.status = finished | finished (derived) |
| finished | `enter` or `esc` | (tearDownSession) home |
| watching | `:q` | (tearDownSession) home |
| watching | state.status = finished | finished (derived) |
| rules | `j` / `k` | next / prev page |
| rules | `esc` | home |
| about | `j` / `k` | next / prev page |
| about | `esc` | home |
| upgrade_prompt | `q` | exit process |

**Finished screen exit keys:** both `enter` and `esc` exit to home. No "press any
key" — exactly two keys, predictable.

### 5.4 Acceptance Criteria

- `make tui` produces a runnable binary at `bin/piratex`.
- `bin/piratex --server http://localhost:4000` boots to `HomeMenu`.
- Selecting "New Game" → selecting a pool → typing a player name → submitting
  ends on a `RawStateScreen` displaying the current sanitized state as JSON.
- Flipping a letter from the web client causes the raw state screen to re-render.
- Ctrl+C exits cleanly without crash.
- `cd clients/tui && bun vitest` passes (tests are minimal in this phase — one
  snapshot test of `HomeMenu`).

## 6. Phase 3 — Full TUI Feature Set

**Goal:** feature parity with the LiveView web client (excluding §1 non-goals).

**Prerequisite:** Phase 2 merged. **Parallelizable across streams** — once Phase 2 is
in, the five streams below can run concurrently on non-overlapping files.

### 6.1 Stream A — Input Engine

**Owner files:** `src/hooks/useInput.ts`, `src/hooks/useCommandParser.ts`

Implements the three-mode input model.

    type InputMode = "normal" | "command" | "chat";

    interface InputState {
      mode: InputMode;
      buffer: string;  // does NOT include the leading : or / prefix
    }

**Normal mode rules** (prompt `> _`):
- **Letter keys `a-z` / `A-Z`** → **auto-lowercased** and appended to buffer. Shift
  and Caps Lock have no effect on what's stored. The buffer is guaranteed to be
  `[a-z]*` at all times. Displayed lowercase in the prompt (`> whales_`), never
  mixed case. These are the only characters that go into the word buffer.
- **Space** → `flip_letter()` (or `end_game_vote()` if pool empty). **Never
  appended**, regardless of buffer state. Words never contain spaces.
- **Enter** → `claim_word(buffer)` if non-empty, then clear.
- **`:` with empty buffer** → switch to command mode.
- **`/` with empty buffer** → switch to chat mode.
- **Numbers, punctuation, symbols, other non-letter characters** → ignored silently.
  Words don't contain them, so there's no reason to display them in the buffer.
- **Esc** → clear buffer / close panel swap.
- **Backspace** → delete last character.

The word buffer is therefore guaranteed to match `[a-z]*` at all times — always
lowercase, always only letters, no spaces, no digits, no punctuation. This makes
`claim_word` submissions trivially valid in shape; the server still validates
dictionary membership, length, and recidivism.

`:` and `/` with a **non-empty** buffer are ignored — you can't mode-switch mid-word.
If you want to abandon a word and start a command, press esc first.

**Command mode rules** (prompt `> :_`):
- Any printable ASCII character → append to buffer. Command buffer may contain any
  characters since we match against known patterns.
- Enter → parse the buffer against the dispatch table, execute, return to normal mode
- Esc → cancel, return to normal mode
- Backspace on empty buffer → return to normal mode

**Command dispatch table** — `parseCommand(buffer: string) → Action`:

| Buffer | Action |
|---|---|
| `c` or `c1` or `1` | `challenge_word(history[0].thief_word)` |
| `c2` | `challenge_word(history[1].thief_word)` |
| `c3` | `challenge_word(history[2].thief_word)` |
| `y` or `2` | `challenge_vote(current_challenge_id, true)` |
| `n` or `7` | `challenge_vote(current_challenge_id, false)` |
| `t` or `3` | Toggle teams panel |
| `h` | Toggle full history feed panel (all word steals, not just recent) |
| `?` or `0` | Toggle hotkeys panel |
| `z` or `8` | Toggle zen mode |
| `o` | Random react: `send_chat_message(random pick of ["nice steal!", "well done!", "slick!", "yarrr!"])` |
| `!` | `send_chat_message("argh!")` |
| `q` | Open quit confirm dialog; on `y`, call `quit_game()` |
| `qa` | `quit_game()` immediately, no confirm |
| anything else | Toast: `"unknown command: :<buffer>"`, return to normal mode |

"Unknown command" means: the buffer did not match any row above. Example: the user
types `:asdf` + enter. No row matches. The TUI shows a transient toast reading
`unknown command: :asdf` and returns to normal mode. Same idea as vim's `E492: Not
an editor command`.

**Command edge cases** (each toasts a user-friendly error and returns to normal mode):
- `:c` / `:c1` / `:1` when `history.length === 0` → `"no word to challenge"`
- `:c2` when `history.length < 2` → `"no such word"`
- `:c3` when `history.length < 3` → `"no such word"`
- `:y` / `:n` / `:2` / `:7` when `challenges.length === 0` → `"no open challenge"`
- `:o` / `:!` when `status !== "playing"` → `"chat unavailable"`

**Chat mode rules** (prompt `> /_`):
- **Any printable character** → append to buffer. This is **unconditional**:
  letters, digits, spaces, punctuation, symbols, `:`, `/`, `!`, `?`, emoji, and
  any Unicode character Ink can render. Chat messages are free-form text, so
  nothing is filtered.
- Space → literal space in the buffer (does **not** trigger flip). Flip is a
  normal-mode action; chat mode has no hotkeys.
- Numbers → literal digits.
- `:` → literal colon (does not re-enter command mode).
- `/` → literal slash.
- **Enter** → `send_chat_message(buffer)`, clear buffer, return to normal mode.
  Server will trim and enforce `@max_chat_message_length`.
- **Esc** → cancel (discard buffer), return to normal mode.
- **Backspace** on empty buffer → return to normal mode.
- **Backspace** with content → delete last character.

Chat mode is **one-shot**, not sticky: enter sends and exits. If you want to send
multiple messages, press `/` each time. This matches game-chat conventions (Discord,
Slack `/` slash commands) and keeps you from getting stuck in a mode during
gameplay.

**Contrast with normal mode:** the word buffer only accepts letters and rejects
everything else silently. The chat buffer accepts everything unconditionally. The
single-character flag `mode === "chat"` toggles the entire filter.

**Mode transitions summary:**

    normal ──:──► command ──enter/esc──► normal
       │
       ╰──/──► chat ──enter/esc──► normal
       │
       ╰──(letters/space/enter)──► normal (stays)

**Deliverable:** `useInput` hook returning `{ buffer, mode, handleKey }`. `handleKey`
is called from an Ink `useInput` parent. Pure state machine, fully unit-testable with
no Ink dependency.

**Tests:** `clients/tui/src/hooks/__tests__/useInput.test.ts` — every row of the
dispatch table, every mode transition, edge cases (empty buffer + esc, backspace out of
command mode into normal, etc.).

### 6.2 Stream B — Game Panels (Components)

**Owner files:** `src/components/*.tsx`

Panels are **pure props → JSX**. No context, no hooks beyond `useMemo`. They consume
the GameState slice they need and render.

| File | Props | Notes |
|---|---|---|
| `Tile.tsx` | `letter: string` | Box-drawn single letter, with optional highlight |
| `Center.tsx` | `center: string[]` | Flex wrap of tiles, chronological order (matches web) |
| `TeamPanel.tsx` | `team: Team`, `isMyTeam: boolean`, `hasActivePlayers: boolean` | Team name header + word list |
| `TeamsPanel.tsx` | `teams: Team[]`, `playersTeams`, `myTeamId` | The `:t`/`:3` panel-swap content |
| `ActivityFeed.tsx` | `entries: ActivityEntry[]` | Rolling 20 entries, auto-scrolled to bottom |
| `HistoryFeed.tsx` | `history: WordSteal[]`, `challengeableHistory: boolean[]` | Most recent first; marks entries that can be challenged with `:c1`/`:c2`/`:c3`. Compact 3-line version used in the regular layout. |
| `HistoryPanel.tsx` | `history: WordSteal[]`, `teams: Team[]`, `players: PlayerSummary[]` | Full-panel version showing every word steal in the game with thief, victim, and letters used. Triggered by `:h` panel swap. |
| `ChallengePanel.tsx` | `challenge: Challenge`, `myName: string`, `timeoutMs: int`, `firstSeenAt: number` | Countdown + vote tally, replaces center area when open. `firstSeenAt` is the TUI-local timestamp (`Date.now()`) of the first state push containing this challenge ID — not a server timestamp. Clock drift is acceptable for a 120s timeout and avoids adding a `created_at` field to the server-side `%Challenge{}` struct. The enclosing `Playing.tsx` screen keeps a `Map<challengeId, firstSeenAt>` to persist the start time across state pushes. |
| `HotkeysPanel.tsx` | — | Static reference; panel-swap content |
| `WordStealPanel.tsx` | `wordSteal: WordSteal`, `teams`, `players` | Panel-swap content for "show me this steal" |
| `Toast.tsx` | `toast: {kind, message} \| null` | Auto-dismiss after 3s via `useToast` |

**Tests:** `ink-testing-library` snapshot tests per component against a fixture state.
No behavior, just rendering. Fixtures live at
`clients/tui/src/components/__fixtures__/`.

### 6.3 Stream C — Full Screens

**Owner files:** `src/screens/*.tsx`

Each screen composes Stream B panels, subscribes to `useGame()`, and wires Stream A
input.

| File | Source of truth | Behavior |
|---|---|---|
| `WaitingRoom.tsx` | `gameState` (status=waiting) | Team selector, new team form, start button |
| `Playing.tsx` | `gameState` (status=playing) | Full game layout from §9.1, panel swap state, input bar |
| `Finished.tsx` | `gameState` (status=finished) | Team scores, ASCII bar chart, `enter` or `esc` to exit to home. Reads `state.game_stats` (not a separate field). |
| `Watch.tsx` | `gameState` (any status) | Read-only — no input bar, no `:` commands except `:q` |

**Derived state** (all computed inside the screens, not in GameProvider):

    const myTurnIdx = useMemo(
      () => state.players.findIndex(p => p.name === myName),
      [state.players, myName]
    );
    const isTurn = myTurnIdx === state.turn;
    const myTeamId = state.players_teams[myName];
    const challengeableHistory = useMemo(
      () => computeChallengeableHistory(state),
      [state.history, state.challenged_words, state.teams]
    );

`computeChallengeableHistory` is a pure function in `src/derived.ts`, unit-tested. See
`lib/piratex_web/live/helpers.ex` `precompute_challengeable_history/1` for the
reference logic — the port is mechanical.

**Panel swap state** is local to `Playing.tsx`:

    type ActivePanel = "none" | "teams" | "hotkeys" | "history" | "word_steal";
    const [activePanel, setActivePanel] = useState<ActivePanel>("none");

The Activity+History area renders either the feeds (`"none"`) or the corresponding
panel. `esc` sets `"none"`. The Challenge panel is independent — it replaces the
Center area automatically when `state.challenges.length > 0`.

**Tests:** one snapshot test per screen against a fixture state for each game status.
No interaction tests — those are Stream A's responsibility.

### 6.4 Stream D — Static Content Screens

**Owner files:** `src/menus/RulesText.tsx`, `src/menus/AboutText.tsx`,
`src/hooks/usePagedText.ts`.

Port the rules text from `lib/piratex_web/live/rules.ex` and about text from
`lib/piratex_web/live/about.ex`. Split each into **2–3 static pages** sized to fit
the 100×30 minimum terminal. **No scrolling** (see §12.5). Pages cycle via `j`/`k`
or arrow keys; page indicator at the bottom (`1/3`, `2/3`, `3/3`). Esc returns to
home.

`usePagedText(pages: string[][])` returns `{ current: string[], pageNum: number,
totalPages: number, next(), prev() }`.

**Tests:** snapshot each page of each screen.

### 6.5 Stream E — Error & Toast Plumbing

**Owner files:** `src/hooks/useToast.ts`, wires into `GameProvider`.

Single toast slot. New toasts replace old. Default 5-second auto-dismiss via
`setTimeout`, cleared on unmount. The `useToast` hook also supports dismissing
on the next `enter` press (used for command-validity hints).

**Toasts surface from:**

- Channel push errors — `{:error, %{reason: ...}}` from any `handle_in` reply.
- Channel transport errors — `channel.onError` (debounced during reconnect
  attempts; see below).
- HTTP API errors — `fetch` rejection or a response with an `error` field.
- Invalid command explainers — see below.

**No client-side word validation.** The TUI sends `claim_word` for whatever the
user types (as long as the normal-mode buffer is non-empty). The server
validates length, dictionary membership, and recidivism. Any invalid word comes
back as an `:error` toast. Rationale: the server is already the source of
truth, and duplicating its checks client-side doubles the surface area for
bugs.

**Invalid command explainers.** When the user types a command that's unusable
in the current state (e.g., `:c` with empty history, `:y` with no open
challenge), the TUI shows a brief inline explainer — same `useToast` slot as
error toasts — with text like:

| Command | Context | Explainer |
|---|---|---|
| `:c` / `:c1` | No history | `no word to challenge` |
| `:c2` / `:c3` | Fewer than 2/3 history entries | `no such word` |
| `:y` / `:n` / `:2` / `:7` | No open challenge | `no open challenge` |
| `:o` / `:!` | Not playing | `chat unavailable` |
| `:1`, `:cN` | Word already challenged | `already challenged` |
| `:asdf` | Unknown command | `unknown command: :asdf` |

The explainer auto-dismisses after 5 seconds OR on the next `enter` press —
whichever comes first. Pressing enter to clear the explainer lets the user
retype without waiting out the timer. Multiple rapid commands replace each
other's explainer (no stacking).

**Format:** `⚠ <reason>` where reason is the atom with underscores replaced by
spaces (for server errors) or the explainer string from the table above (for
client-side command hints). No translation layer — atoms are already
descriptive and match what `put_flash` shows in the web client.

**Reconnect error debouncing.** `channel.onError` fires on every reconnect
attempt during a flaky connection, which would spam the toast slot. The
GameProvider keeps a `reconnectAttempts` counter: the first error fires a
toast (`connection lost, retrying…`); subsequent errors within 10 seconds are
suppressed. On successful reconnect, the counter resets and a brief info toast
appears (`reconnected`).

**Tests:** hook unit tests for auto-dismiss, replacement, explicit dismiss.

### 6.6 Phase 3 Acceptance

- A TUI player can play a full multi-player game against a web player, end-to-end:
  create game → join as TUI → another player joins as web → both create/join teams
  → start → play until letters exhausted → end game vote → finished screen.
- Every panel swap (`:t`, `:?`, history selection) works and can be dismissed.
- Challenge flow works: TUI player challenges a word, both clients see the challenge
  panel, both vote, result settles.
- Watch mode: a third TUI instance can watch without a player name or token.
- Rules and About screens render with scrollable content.
- All five streams' tests pass.

## 7. Phase 4 — Distribution

**Goal:** a user goes from "I heard about this game" to "I'm playing it" in under a
minute, on macOS or Linux, with zero dependencies and zero Elixir/Node/bun
installed. Binary is called `piratex`. No `-tui`, no `-darwin-arm64` suffix in the
installed name. Windows is out of scope for v1.

**Prerequisite:** Phase 3 merged.

### 7.1 Deliverables

| # | File | Purpose |
|---|---|---|
| 4.1 | `.github/workflows/tui.yaml` | PR lint + test: `bun install && tsc --noEmit && bun vitest` |
| 4.2 | `.github/workflows/tui-release.yaml` | On tag `tui-v*`: cross-compile → tarball → GitHub Release |
| 4.3 | `clients/tui/install.sh` | One-line curl-install script (detects OS/arch, downloads latest release, installs to `~/.local/bin/piratex`) |
| 4.4 | `clients/tui/README.md` | Install & usage |
| 4.5 | Root `README.md` | Link to the TUI install instructions |

### 7.2 Install Methods (user-facing)

Three supported paths, in order of ease:

**Method 1: One-line install (recommended)**

    curl -fsSL https://raw.githubusercontent.com/SachinMeier/piratex/main/clients/tui/install.sh | sh

The script detects the user's OS and architecture, downloads the matching tarball
from the latest GitHub Release, extracts the binary to `~/.local/bin/piratex`,
runs `chmod +x`, strips the macOS quarantine attribute if present, and prints a
PATH reminder. Override the install directory with `PIRATEX_INSTALL=/some/path`.

**Method 2: Manual download**

1. Visit `https://github.com/SachinMeier/piratex/releases/latest`
2. Download the tarball for your platform:
   - macOS (Apple Silicon): `piratex-darwin-arm64.tar.gz`
   - macOS (Intel): `piratex-darwin-x64.tar.gz`
   - Linux (x86_64): `piratex-linux-x64.tar.gz`
   - Linux (arm64): `piratex-linux-arm64.tar.gz`
3. Extract and install:

        tar -xzf piratex-darwin-arm64.tar.gz
        mv piratex ~/.local/bin/piratex
        chmod +x ~/.local/bin/piratex
        # macOS only, if Gatekeeper complains:
        xattr -d com.apple.quarantine ~/.local/bin/piratex

The tarball contains exactly one file named `piratex`. No subdirectories, no
platform suffix in the file itself. The user ends up with a binary named
`piratex` in their PATH regardless of which platform they downloaded.

**Method 3: Build from source**

    git clone https://github.com/SachinMeier/piratex.git
    cd piratex
    make install

Requires `bun` at build time. `make install` builds the binary and copies it to
`$INSTALL_DIR` (default `~/.local/bin`). No Elixir needed for the TUI build.
Override with `make install INSTALL_DIR=/usr/local/bin`.

After any of the three methods, the user runs `piratex` and the game starts.

### 7.3 Makefile Targets

    TUI_DIR := clients/tui
    TUI_BIN := bin/piratex
    INSTALL_DIR ?= $(HOME)/.local/bin

    .PHONY: tui tui-dev tui-test tui-clean install uninstall
    tui:
    	cd $(TUI_DIR) && bun install && bun build --compile src/index.tsx --outfile ../../$(TUI_BIN)

    tui-dev:
    	cd $(TUI_DIR) && bun install && bun --watch src/index.tsx

    tui-test:
    	cd $(TUI_DIR) && bun install && bun vitest run

    tui-clean:
    	rm -f $(TUI_BIN)

    install: tui
    	mkdir -p $(INSTALL_DIR)
    	install -m 755 $(TUI_BIN) $(INSTALL_DIR)/piratex
    	@echo ""
    	@echo "✓ piratex installed to $(INSTALL_DIR)/piratex"
    	@echo ""
    	@case ":$$PATH:" in *":$(INSTALL_DIR):"*) ;; \
    	  *) echo "⚠ $(INSTALL_DIR) is not in your PATH."; \
    	     echo "  add this to your shell profile:"; \
    	     echo "    export PATH=\"$(INSTALL_DIR):\$$PATH\"" ;; \
    	esac

    uninstall:
    	rm -f $(INSTALL_DIR)/piratex

### 7.4 Release Workflow (`tui-release.yaml`)

Triggered on tags matching `tui-v*`. Matrix builds four binaries, each wrapped in a
tarball containing a single file named `piratex`:

    strategy:
      matrix:
        include:
          - target: bun-darwin-arm64
            asset:  piratex-darwin-arm64.tar.gz
          - target: bun-darwin-x64
            asset:  piratex-darwin-x64.tar.gz
          - target: bun-linux-x64
            asset:  piratex-linux-x64.tar.gz
          - target: bun-linux-arm64
            asset:  piratex-linux-arm64.tar.gz

    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - name: Build
        run: |
          cd clients/tui
          bun install
          bun build --compile --target=${{ matrix.target }} src/index.tsx --outfile piratex
      - name: Package
        run: |
          cd clients/tui
          tar -czf ../../${{ matrix.asset }} piratex
      - name: Upload to release
        uses: softprops/action-gh-release@v2
        with:
          files: ${{ matrix.asset }}

The critical bit: inside every tarball, the file is named `piratex`. The tarball
itself is named with the platform so GitHub Releases can host all four, but once
extracted the user has a clean `piratex` binary.

### 7.5 `install.sh` (sketch)

    #!/bin/sh
    set -eu

    REPO="SachinMeier/piratex"
    INSTALL_DIR="${PIRATEX_INSTALL:-$HOME/.local/bin}"

    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    case "$os-$arch" in
      darwin-arm64|darwin-aarch64) asset="piratex-darwin-arm64.tar.gz" ;;
      darwin-x86_64)               asset="piratex-darwin-x64.tar.gz"   ;;
      linux-x86_64)                asset="piratex-linux-x64.tar.gz"    ;;
      linux-aarch64|linux-arm64)   asset="piratex-linux-arm64.tar.gz"  ;;
      *) echo "unsupported platform: $os-$arch"; exit 1 ;;
    esac

    url="https://github.com/$REPO/releases/latest/download/$asset"
    echo "downloading $asset..."

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL "$url" -o "$tmp/$asset"
    tar -xzf "$tmp/$asset" -C "$tmp"

    mkdir -p "$INSTALL_DIR"
    install -m 755 "$tmp/piratex" "$INSTALL_DIR/piratex"

    # macOS: strip quarantine so Gatekeeper doesn't block first run
    if [ "$os" = "darwin" ] && command -v xattr >/dev/null 2>&1; then
      xattr -d com.apple.quarantine "$INSTALL_DIR/piratex" 2>/dev/null || true
    fi

    echo "✓ piratex installed to $INSTALL_DIR/piratex"
    case ":$PATH:" in
      *":$INSTALL_DIR:"*) ;;
      *) echo ""
         echo "⚠ $INSTALL_DIR is not in your PATH."
         echo "  add this to your shell profile:"
         echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
         ;;
    esac

### 7.6 PATH Discussion

`~/.local/bin` is the default install location. Reasoning:

- **User-writable.** No `sudo` needed, which is a requirement for a one-line curl
  install to be non-scary.
- **XDG-standard.** Matches the XDG Base Directory Specification and is widely
  recognized by distro tools.
- **In the default PATH on most Linux distros.** Debian, Ubuntu, Fedora, Arch all
  add `~/.local/bin` to the default PATH when it exists.
- **Not in the default PATH on macOS.** The install script and `make install`
  detect this and print the exact `export PATH=...` line to add to the user's
  shell profile. One-time setup per machine.

Alternatives considered: `/usr/local/bin` (needs sudo, scary); `/opt/piratex/bin`
(requires a PATH entry anyway); `~/bin` (pre-XDG convention, less standard).

### 7.7 macOS Gatekeeper

Unsigned binaries downloaded from the internet are quarantined on macOS. First run
without handling produces:

> "piratex" cannot be opened because the developer cannot be verified.

Both `install.sh` and the manual-download instructions strip the quarantine
attribute with `xattr -d com.apple.quarantine piratex`, which lets the binary run
without the Gatekeeper prompt. This is safe for binaries the user just downloaded
intentionally — it's the same mechanism the user would use via "right-click → Open"
in Finder.

Code signing and notarization are deferred past v1. They would require an Apple
Developer account and meaningful CI changes. Not worth it for a hobby game.

### 7.8 Acceptance

- Push a `tui-v0.1.0` tag → GitHub Actions builds four tarballs and publishes the
  release with all four attached.
- On a fresh macOS machine with no Node/bun/Elixir installed:

        curl -fsSL https://raw.githubusercontent.com/SachinMeier/piratex/main/clients/tui/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"   # if macOS, once
        piratex

  The TUI boots, connects to prod, and the user can play a full game.
- On a fresh Linux machine with no Node/bun/Elixir installed: same flow, no PATH
  tweak needed on most distros.
- `git clone && make install && piratex` also works, requires only `bun` at build
  time.
- `make uninstall` removes the binary cleanly.

### 7.9 Release Process

The existing deploy pipeline only handles the Elixir server (`master.yaml` →
`deploy.yaml` to Gigalixir on push to `master`). The TUI adds a parallel release
pipeline that is entirely independent except for the one case where a major
protocol bump requires coordinated rollout.

#### 7.9.1 Existing server deploy (unchanged)

Every merge to `master`:

1. `.github/workflows/branch.yaml` → `test.yaml` runs mix test + format check.
2. On pass, `master.yaml` → `deploy.yaml` pushes to Gigalixir.

No versioning. The server is a continuous-deployment target. This stays.

#### 7.9.2 TUI release (new)

TUI releases are **explicit, tag-driven, and independent from the server deploy**.
The tag `tui-vX.Y.Z` triggers the release workflow. No auto-release on merge.

**Day-to-day workflow (no version change):**

1. PR to `master` that touches only TUI code.
2. `.github/workflows/tui.yaml` runs: `tsc --noEmit` + `bun vitest` + fixture
   contract check.
3. Merge. No release. The next tagged release will roll it up.

**Cutting a release (minor or patch):**

1. Bump `clients/tui/package.json` version and `clients/tui/src/contract.ts`'s
   `PROTOCOL_VERSION.minor` if the protocol changed minor.
2. Update `clients/tui/CHANGELOG.md` with the new version and changes.
3. Merge.
4. Tag and push: `git tag tui-v1.3.0 && git push origin tui-v1.3.0`.
5. `.github/workflows/tui-release.yaml` fires:
   - Checks out the tag.
   - Runs the full TUI test suite.
   - Cross-compiles four binaries.
   - Packages each as `piratex-<os>-<arch>.tar.gz`.
   - Creates a GitHub Release with the tag name, auto-generated release notes
     from the CHANGELOG section, and the four tarballs attached.
6. The install script and "latest" release link update automatically — nothing
   to do.

Rollback: delete the tag and the release. The previous release becomes "latest"
again. Users on the broken version will see the minor-mismatch badge but will
keep working (since minor is soft).

**Cutting a release (major, breaking protocol):**

This is the coordinated case and it's the whole reason we version.

1. **Branch the server change.** Merge to `master` is blocked until the TUI
   release is ready.
2. On the server PR:
   - Bump `@protocol_version` in `PiratexWeb.GameChannel` from `{1, N}` to
     `{2, 0}`.
   - Update the protocol snapshot test (see §7.9.4) so CI asserts the new
     value.
   - Write the PR description with a link to the corresponding TUI PR.
3. On the TUI PR (on a branch, not merged yet):
   - Bump `PROTOCOL_VERSION.major` in `contract.ts` to `2`.
   - Bump `PROTOCOL_VERSION.minor` to `0`.
   - Bump `package.json` to a new major, e.g. `2.0.0`.
   - Update CHANGELOG with the breaking changes.
4. **Coordinated merge & deploy:**
   - Merge the TUI PR first.
   - Tag `tui-v2.0.0` and push.
   - Wait for the release workflow to publish the binaries.
   - Verify a downloaded `tui-v2.0.0` binary speaks protocol `2.0` via
     `piratex --version`.
   - Merge the server PR.
   - `master.yaml` deploys the server.
   - The moment the server is live, all `tui-v1.x.x` binaries start returning
     `:client_outdated` on connect. Users see the upgrade prompt.
5. Announce in the README and on any community channels.

This is the only part of the lifecycle where the two streams have to
synchronize. Everything else is independent.

#### 7.9.3 New GitHub Actions workflows

`.github/workflows/tui.yaml` — runs on PRs that touch `clients/tui/**`:

    name: TUI CI
    on:
      pull_request:
        paths:
          - "clients/tui/**"
          - ".github/workflows/tui.yaml"
      push:
        branches: [master]
        paths:
          - "clients/tui/**"
    jobs:
      test:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - uses: oven-sh/setup-bun@v2
          - name: Install
            run: cd clients/tui && bun install --frozen-lockfile
          - name: Typecheck
            run: cd clients/tui && bun x tsc --noEmit
          - name: Test
            run: cd clients/tui && bun vitest run

`.github/workflows/tui-release.yaml` — runs on tags matching `tui-v*`:

    name: TUI Release
    on:
      push:
        tags: ["tui-v*"]
    jobs:
      build:
        strategy:
          fail-fast: false
          matrix:
            include:
              - target: bun-darwin-arm64
                asset:  piratex-darwin-arm64.tar.gz
              - target: bun-darwin-x64
                asset:  piratex-darwin-x64.tar.gz
              - target: bun-linux-x64
                asset:  piratex-linux-x64.tar.gz
              - target: bun-linux-arm64
                asset:  piratex-linux-arm64.tar.gz
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - uses: oven-sh/setup-bun@v2
          - name: Install
            run: cd clients/tui && bun install --frozen-lockfile
          - name: Typecheck
            run: cd clients/tui && bun x tsc --noEmit
          - name: Test
            run: cd clients/tui && bun vitest run
          - name: Build
            run: |
              cd clients/tui
              bun build --compile \
                --target=${{ matrix.target }} \
                src/index.tsx --outfile piratex
          - name: Package
            run: |
              cd clients/tui
              tar -czf ../../${{ matrix.asset }} piratex
          - name: Upload asset
            uses: softprops/action-gh-release@v2
            with:
              files: ${{ matrix.asset }}
              generate_release_notes: true
              fail_on_unmatched_files: true

The release job runs in parallel across the four targets. Any target failure
stops that binary but not the others, so you can still publish three-of-four in
the event of a single-platform build bug (rare, but possible).

The `generate_release_notes: true` flag uses GitHub's auto-generated notes from
commit messages since the previous tag. For curated notes, add a `body_path:`
pointing to a section extracted from CHANGELOG.md — optional polish, not
required for v1.

**Server deploys do not trigger TUI releases** and vice versa. The two pipelines
share no jobs and no artifacts.

#### 7.9.4 Protocol snapshot test

To prevent an accidental major bump slipping through review, add a pinned
snapshot test in `test/piratex_web/protocol_version_test.exs`:

    defmodule PiratexWeb.ProtocolVersionTest do
      use ExUnit.Case, async: true

      # If you intentionally bump this, update it in BOTH places:
      # 1. lib/piratex_web/channels/game_channel.ex (@protocol_version)
      # 2. clients/tui/src/contract.ts (PROTOCOL_VERSION)
      # 3. This test.
      @expected_version {1, 0}

      test "protocol version is pinned" do
        assert PiratexWeb.GameChannel.protocol_version() == @expected_version
      end
    end

A server PR that bumps the constant has to also bump this assertion, which
surfaces the change in code review.

Same idea on the TUI side: `clients/tui/src/__tests__/protocol_version.test.ts`
pins `PROTOCOL_VERSION` against a constant declared in the test file. Divergence
between the Elixir constant and the TypeScript constant is visible across the
two PR descriptions in the coordinated-release flow.

#### 7.9.5 Checklist for a major bump

A printable checklist developers follow when doing a coordinated major release:

    [ ] Server: bump @protocol_version in game_channel.ex
    [ ] Server: update protocol_version_test.exs snapshot
    [ ] Server: merge to master is HELD until TUI is ready
    [ ] TUI: bump PROTOCOL_VERSION.major in contract.ts (reset minor to 0)
    [ ] TUI: bump package.json semver
    [ ] TUI: update clients/tui/CHANGELOG.md
    [ ] TUI: update protocol_version.test.ts snapshot
    [ ] TUI: merge to master
    [ ] TUI: git tag tui-vX.0.0 && git push origin tui-vX.0.0
    [ ] TUI: verify tui-release.yaml completes, all four binaries published
    [ ] TUI: download tui-vX.0.0 locally, run `piratex --version`, confirm major
    [ ] Server: merge protocol bump PR to master
    [ ] Server: verify deploy.yaml completes
    [ ] Verify: old binary gets UpgradePrompt on connect attempt
    [ ] Verify: new binary connects and plays normally
    [ ] Announce in README and any community channels

Stored at `clients/tui/RELEASE.md` for reference.

## 8. Parallelization Matrix

    Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4
     (seq)       (seq)      (5 streams)   (seq)

    Phase 1 internal parallelism:
      UserSocket + GameChannel      ──┐
      GameAPIController             ──┼─► Tests (depend on all above)
      Jason @derive annotations     ──┘

    Phase 3 streams (fully parallel after Phase 2):
      A. Input engine       (useInput, useCommandParser)
      B. Game panels        (src/components/*)
      C. Full screens       (src/screens/*)
      D. Static content     (Rules, About)
      E. Error/toast        (useToast + GameProvider wiring)

    Phase 3 integration points:
      Screens (C) depend on Panels (B) and Input (A).
      Toast (E) is consumed by all screens but its interface is frozen early.
      Static (D) depends on nothing else.

    Recommended assignment for a 3-dev team in Phase 3:
      dev-1: A + E  (input engine + toast plumbing)
      dev-2: B      (all game panels)
      dev-3: C + D  (screens + rules/about)

    Recommended assignment for a solo dev:
      A → B → C → D → E, in order.

## 9. Testing Strategy

### 9.1 Backend

- **Unit:** `Phoenix.ChannelTest` for every `handle_in`, every `handle_info`, every
  join intent, every error path.
- **Integration:** one end-to-end test that drives a full game through the channel
  (join → start → flip several → claim → challenge → vote → flip → end) and asserts
  state pushes.
- **Contract:** a fixture file of the exact JSON shape of a sanitized state is checked
  in at `test/fixtures/sanitized_state.json`. Any change to `state_for_player/1` that
  alters the shape must update the fixture; this keeps the TypeScript contract and
  the Elixir state aligned.

### 9.2 Frontend Unit

- **Input engine (Stream A):** 100% branch coverage of the command dispatch table and
  mode transitions. Pure functions, trivial to test.
- **Panels (Stream B):** `ink-testing-library` snapshot per component per fixture.
- **Derived state:** `computeChallengeableHistory` test with fixture histories.

### 9.3 Frontend E2E

- **Fake Phoenix server:** a `ws` server in-process that speaks the Channel protocol.
  The TUI connects, plays a scripted game, snapshots at each step.
- **Smoke test:** one `bin/piratex` subprocess driven over a pty with `expect`,
  verifying it can connect to a real dev server and reach the playing screen.

### 9.4 Regression Bot

**Not in scope for v1.** Deferred to v2 along with the bot itself (§10). When we
eventually build a bot, a manual `workflow_dispatch`-triggered GitHub Actions job
is the right place to wire up bot-vs-bot regression runs — never on every PR, too
heavy.

## 10. Bot Capability — v2, Design Note Only

**Not in scope for v1.** This section exists only to confirm that the channel design
can support an LLM bot later without server changes. No code, tests, workflows,
files, or CI for a bot ships with v1.

The relevant properties that make the channel future-ready:

- Every player action is already a one-to-one mapping to `Piratex.Game.*`, exposed
  as channel `handle_in` events. A bot calling `claim_word`, `challenge_word`, etc.
  goes through the exact same code path as a human using the TUI.
- The sanitized state pushed on every change (`state_for_player/1` with MapSet
  converted at the channel) already contains everything a bot needs to reason about
  a game: center, team words, turn, history, open challenges, activity feed.
- Tokens are minted by `POST /api/games/:id/players` with no authentication beyond
  possession — a bot registering as a player uses the same endpoint a TUI does.
- The server never distinguishes client types. Adding a bot is literally "write
  another client" — no server policy changes, no new endpoints, no new events.

If/when bots are built in v2, they'll live at `clients/bot/` and share
`clients/tui/src/contract.ts` for types. Until then, nothing in this spec depends
on them.

## 11. Open Questions & Deferred

1. **Single-session anti-collusion.** Deferred. In-memory credentials remove the
   casual vector; a `PlayerSession` registry can be added in v2 if needed. If built,
   use Elixir `Registry` so entries auto-clean on process death.
2. **Crash recovery.** Deferred. A crashed TUI cannot resume — user rejoins under a
   new name. Upgrade path: persist one record at `~/.config/piratex/current.json`
   with atomic write+rename. ~30 LOC, zero other changes.
3. **GenServer death mid-session.** Accepted. PubSub goes silent; next command returns
   `:not_found`; the TUI surfaces a toast and navigates home. No automatic detection
   of a dead GenServer while idle — acceptable.
4. **Wire size.** Full sanitized state on every push (~few KB for busy games). Delta
   encoding is a v2 optimization at the channel layer.
5. **Spectator inactivity.** A watch-only TUI doesn't advance `last_action_at`. Matches
   web behavior, no change.
6. **Homebrew tap.** Nice to have; not blocking.
7. **Homebrew tap / `npx`.** Not planned; install script covers the use case.

## 12. UI Reference

### 12.1 Playing Layout

Borrows from Claude Code: the **top bar is pure identity** (`PIRATE SCRABBLE`, nothing
else) and the **bottom is a dynamic status bar** with the letter pool progress bar,
turn info, game ID, and command hints. All volatile, time-sensitive information lives
at the bottom next to where the user is typing.

    ┌── PIRATE SCRABBLE ───────────────────────────────────────────────────────────┐
    │                                                                              │
    │  ╭─╮ ╭─╮ ╭─╮ ╭─╮ ╭─╮ ╭─╮ ╭─╮ ╭─╮ ╭─╮ ╭─╮ ╭─╮                                 │
    │  │R│ │A│ │T│ │S│ │N│ │E│ │I│ │L│ │P│ │O│ │D│                                 │
    │  ╰─╯ ╰─╯ ╰─╯ ╰─╯ ╰─╯ ╰─╯ ╰─╯ ╰─╯ ╰─╯ ╰─╯ ╰─╯                                 │
    │                                                                              │
    │  ┌── Pirates (12) ────────┐  ┌── Sailors (8) ────┐  ┌── Krakens (5) ────┐   │
    │  │ WHALES        SHIPS    │  │ ANCHOR    REEF    │  │ KRAKEN            │   │
    │  │ TREASURE      ISLAND   │  │ SAILOR            │  │                   │   │
    │  └────────────────────────┘  └───────────────────┘  └───────────────────┘   │
    │                                                                              │
    │  ┌── activity ─────────────────────────────────────┐  ┌─ recent ─────┐      │
    │  │ 19:24 alice: anyone got K?                      │  │ :c1  WHALES  │      │
    │  │ 19:24 bob made SHIPS                            │  │ :c2  MUTINY  │      │
    │  │ 19:23 challenge: WHALES VALID                   │  │ :c3  TREASU… │      │
    │  └─────────────────────────────────────────────────┘  └──────────────┘      │
    │                                                                              │
    │  > _                                                                         │
    │  ▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱ 57/144 · ABC1234 · bob 0:42   space flip · :c1 · / · :? │
    └──────────────────────────────────────────────────────────────────────────────┘

**Top bar** — single line, contains only the literal text `PIRATE SCRABBLE`. No game
ID, no pool count, no turn indicator. Clean brand marker.

**Center** — unchanged. Box-drawn tiles in chronological flip order.

**Team panels** — unchanged. Current player's team is highlighted.

**Activity feed + Recent pane** — the activity feed is widened and the old detailed
history pane is replaced with a compact **Recent** panel (see §12.2).

**Input line** (`> _`) — single-line text input, the one thing the user types into.
Mode indicator appears as the prompt prefix (`>` normal, `>:` command, `>/` chat).

**Status bar** — single line below the input, left-to-right:

    ▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱ 57/144 · ABC1234 · bob 0:42      space flip · :c1 · / · :?

| Segment | Contents |
|---|---|
| Progress bar | 20-cell bar, filled cells (`▰`) = letters flipped, empty cells (`▱`) = remaining |
| Pool count | `flipped/total`, e.g. `57/144` |
| Game ID | The 7-char game identifier for quick reference / sharing |
| Turn + timer | Current player's name and countdown to `turn_timeout_ms` |
| Hints (right-aligned) | The common commands: `space` flip, `:c1` challenge, `/` chat, `:?` help |

When pool is empty, `57/144` becomes `144/144 ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰` and the turn-timer
segment shows `end game vote [space]` instead of a player timer.

When a challenge is open, the center tiles are replaced by the challenge-vote panel
(§6.3), and the status bar hint segment changes to `:y valid · :n invalid · :?`.

**Color** (8-color palette):
- Status bar progress bar: green while above 50% remaining, yellow below 25%, red below 10%.
- Turn indicator: cyan if it's your turn, default otherwise.
- Mode indicator (`>`, `>:`, `>/`): default, dim, and dim respectively.
- Recent pane `:c*` labels: default when challengeable, dim when already challenged.

### 12.2 Recent Pane (replaces compact history)

The old compact history pane rendered full forensic detail for each word steal
(thief word, victim word, stealer name). That's overkill for the always-on view —
the user's only question at this position on screen is "what can I challenge?"

The Recent pane answers exactly that: three rows, most recent first, each showing
the challenge command and the thief word. Nothing else.

    ┌─ recent ─────┐
    │ :c1  WHALES  │
    │ :c2  MUTINY  │
    │ :c3  TREASU… │
    └──────────────┘

Rules:

- **Three rows, always.** If history has fewer than 3 entries, empty rows are blank
  (not omitted, because row count is fixed to keep the layout stable).
- **Thief word only**, uppercased. No arrow, no victim word, no player name, no
  "from center" annotation. If the word exceeds the pane width, it's ellipsized
  with `…`, not wrapped.
- **Challenge label** `:c1` / `:c2` / `:c3` always matches history position, so the
  labels are stable even as words scroll. `:c1` is always "the most recent word",
  regardless of what that word is.
- **Already-challenged entries are dimmed.** The word is still shown but the `:c*`
  label renders in a dim color to indicate pressing it will toast `already
  challenged`. Derivation: check `state.challenged_words` for the `(victim_word,
  thief_word)` pair per §7.6 derived state.
- **No colors for player ownership.** The Recent pane is purpose-neutral about
  which team made the word. The full-history `:h` panel shows ownership.

The detailed "who stole what from whom with which letters" breakdown moves to the
`:h` HistoryPanel swap (§6.2), which is invoked on demand. Most players will
never need it; the compact Recent pane is what they interact with during play.

### 12.2 Waiting Room Layout

    ┌─ piratex ──────────────────────────── game: ABC1234 ─────────────────────────┐
    │                                                                              │
    │                              T E A M S                                       │
    │                                                                              │
    │   ┌── Pirates ──────────┐  ┌── Sailors ─────────┐  ┌── Krakens ──────────┐  │
    │   │ > alice             │  │   bob               │  │   charlie           │  │
    │   │   dave              │  │   eve               │  │                     │  │
    │   └─────────────────────┘  └────────────────────┘  └─────────────────────┘  │
    │                                                                              │
    │   [1] Join Pirates   [2] Join Sailors   [3] Join Krakens                     │
    │                                                                              │
    │   New team: ________     [enter] Create                                      │
    │                                                                              │
    │   [s] Start Game    [q] Leave                                                │
    └──────────────────────────────────────────────────────────────────────────────┘

### 12.3 Input Model Summary

**Normal mode** (prompt `> _`):
- Letters → build word
- Enter → submit word
- Space → flip / end-game vote
- `:` → command mode
- `/` → chat mode
- Esc → clear / close panel swap

**Command mode** (prompt `> :_`):

| Command | Action |
|---|---|
| `:c` / `:c1` / `:1` | Challenge most recent word |
| `:c2`, `:c3` | Challenge 2nd / 3rd most recent word |
| `:y` / `:2` | Vote valid on challenge |
| `:n` / `:7` | Vote invalid on challenge |
| `:t` / `:3` | Toggle teams panel |
| `:h` | Toggle full history panel |
| `:?` / `:0` | Toggle hotkeys / help panel |
| `:z` / `:8` | Zen mode |
| `:o` | Quick react (random "nice steal!" / "well done!") |
| `:!` | Send "argh!" to chat |
| `:q` | Quit (with confirm) |
| `:qa` | Quit (skip confirm) |

Unknown commands (`:asdf`, `:1337`, etc.) show a toast `unknown command: :<buffer>`
and return to normal mode.

**Chat mode** (prompt `> /_`):
- Everything typed is literal (space, numbers, `:`, `/` — all literal text)
- Enter → send, **return to normal mode** (one-shot, not sticky)
- Esc → cancel, return to normal mode

### 12.4 Modals as Panel Swaps

No z-index layering. The activity+history area is replaced in place by teams,
hotkeys, full history, or word-steal detail panels. Press the command again or `esc`
to swap back. The challenge panel replaces the center area automatically when
`state.challenges` is non-empty.

### 12.5 No Scrolling

The TUI is a **fixed-viewport application**. Every screen fits in the terminal and
does not scroll. Scrolling is actively disabled:

- Ink is rendered in **alternate screen mode** (`ink.render(<App/>, { patchConsole:
  false, exitOnCtrlC: true, experimental: true })` + emitting the `\x1b[?1049h`
  terminfo escape on boot and `\x1b[?1049l` on exit). Alternate screen mode prevents
  output from accumulating in the scrollback buffer and restores the user's terminal
  on exit.
- Mouse scroll events are swallowed by enabling raw mode on stdin (`process.stdin
  .setRawMode(true)`) and ignoring all mouse escape sequences.
- No component produces output larger than its allotted region. The activity feed is
  capped at `@feed_limit` (20) entries server-side; the history view is a fixed
  number of rows and older entries are simply not shown. The rules and about screens
  render a single page of text — if the text exceeds the screen, the spec says to
  split it into multiple screens navigated by `j`/`k`, **not** to scroll.
- The terminal size is checked at boot and on `SIGWINCH`. If it's smaller than the
  minimum (100×30), render a "terminal too small" message instead of the game until
  it's resized.

**Rules and About pages** — since there's no scroll, the text must fit on one screen
or be paginated. Recommend: paginate with `j`/`k` or arrow keys cycling through
2–3 static pages of content. Each page is a full render; no scroll buffer.

This matches how vim, htop, less, fzf, and every other curses-style TUI work:
alternate screen, fixed regions, paged navigation, clean exit. It also sidesteps the
common Ink-in-a-real-terminal bug where React re-renders produce stacked output in
the scrollback because something resizes mid-render.

**Implementation note:** Ink supports alternate screen mode via its `patchConsole`
and direct stdout control. The rules and about screens use `usePagedText` with
`j`/`k` navigation; no line-buffer scroll hook exists anywhere in the codebase.

## 13. Repo Layout

    clients/
      tui/
        package.json
        tsconfig.json
        vitest.config.ts
        README.md
        src/
          index.tsx
          app.tsx
          contract.ts
          config.ts
          derived.ts
          api.ts
          socket.ts
          game-provider.tsx
          menus/
            HomeMenu.tsx
            FindGameMenu.tsx
            CreateGameMenu.tsx
            JoinPrompt.tsx
            RulesText.tsx
            AboutText.tsx
          screens/
            WaitingRoom.tsx
            Playing.tsx
            Finished.tsx
            Watch.tsx
          components/
            Tile.tsx
            Center.tsx
            TeamPanel.tsx
            TeamsPanel.tsx
            ActivityFeed.tsx
            HistoryFeed.tsx
            HistoryPanel.tsx
            ChallengePanel.tsx
            HotkeysPanel.tsx
            WordStealPanel.tsx
            Toast.tsx
            __fixtures__/
              playing-state.json
              waiting-state.json
              finished-state.json
          hooks/
            useGame.ts
            useInput.ts
            useCommandParser.ts
            useCountdown.ts
            useToast.ts
            usePagedText.ts
            useTerminalSize.ts
            __tests__/
              useInput.test.ts
              useCommandParser.test.ts

## 14. Summary by Numbers

| Area | LOC estimate | New files |
|---|---|---|
| Backend adapter (Phase 1) | 250–350 | 4 Elixir files + 2 test files + annotations |
| TUI foundation (Phase 2) | 500–800 | ~15 TS files + Makefile targets |
| TUI features (Phase 3) | 1000–2000 | ~25 TS files + tests |
| Distribution (Phase 4) | ~100 YAML + ~50 docs | 2 workflow files + install.sh + READMEs |
| **Total** | **~2000–3300 LOC** | |

Game logic untouched. LiveView untouched. Single source of wire truth
(`state_for_player/1`) untouched except the MapSet→list conversion at the channel
layer.

Bot capability and bot regression testing are deferred to v2 — the channel design
supports them without future server changes, but no bot code ships in v1.

## 15. Decisions Made During Spec Finalization

This section records the micro-decisions made at the end of spec work, so the
implementation PRs can cite them rather than re-litigating.

1. **Default letter pool** when `POST /api/games` omits `letter_pool`: `bananagrams`.
2. **HTTP status code mapping:** pinned in §3.1 (404 not_found, 409 conflicts,
   400 validation/malformed, 426 protocol mismatch, 500 unhandled).
3. **`game_stats` push** is not a separate server→client event. Consumers read
   `state.game_stats`, which is `null` until `status == :finished`.
4. **`StartSessionParams`** has three kinds: `create`, `join`, `watch`. Each
   maps to a specific HTTP + channel sequence in §5.2.
5. **Push → Promise wrapper** is defined inline in §5.2 as `pushAsync`.
6. **Router transitions** are fully enumerated in §5.3 (table).
7. **Finished screen exit:** `enter` or `esc`, no "press any key".
8. **`GameStats` interface** enumerates only the fields the TUI v1 actually
   reads. Extras are tolerated for forward-compat with v2 graphs.
9. **Challenge panel countdown** starts from TUI-local `Date.now()` when the
   challenge ID is first seen. No `created_at` added to the server struct.
10. **No client-side word validation.** Server is the source of truth; all
    invalid-word errors come from the channel reply.
11. **Invalid command explainers** reuse the toast slot, auto-dismiss after
    5 seconds or on the next `enter` press. Full text table in §6.5.
12. **Reconnect toast debouncing:** first error fires a toast, subsequent
    errors within 10 seconds are suppressed, successful reconnect clears and
    shows a brief `reconnected` info toast.
13. **MapSet → list conversion** happens in the channel's `handle_info` /
    `after_join` / `GameAPIController.show`, not in `Piratex.Helpers`. Leaves
    LiveView untouched.
14. **Jason encoding** uses explicit `only:` field lists on all five structs.
    `%Challenge{}` must exclude `:timeout_ref` (process reference, not
    encodable).
15. **No telemetry or dashboards.** Protocol-mismatch rejections are logged via
    `Logger`; no separate Phoenix Telemetry events or metrics dashboard.
16. **Waiting room input model** is not yet finalized — the original §8.2
    bracketed-hotkey design (`[1]`, `[2]`, `[s]`) is still in the spec. The
    vim-style design discussed in chat (normal-mode team name typing, `:j N`,
    `:s`, `:q`) is not yet folded in. **This is the one remaining open
    question before Phase 3 streams can start.** Phase 1 and Phase 2 can
    proceed without resolving it because the waiting room is a Phase 3 Stream C
    deliverable.
17. **No `game_stats` field on `GameContext`** — removed, use
    `gameState.game_stats` instead.

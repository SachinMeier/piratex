# Piratex Performance Audit

Comprehensive audit of performance, bandwidth, memory, and responsiveness across the entire codebase. Findings from 5 parallel analysis passes: GenServer/state, LiveView/bandwidth, frontend/client, infrastructure/config, and algorithms/data flow.

---

## Critical

### 1. Full Game State Broadcast on Every Mutation

**Files:** `lib/piratex/game.ex:706-709`, `lib/piratex/helpers.ex:92-120`

`broadcast_new_state/1` is called on virtually every state mutation (flip letter, claim word, chat message, challenge vote, join team, turn timeout, etc.). Each call builds a full `state_for_player` map and broadcasts it via PubSub to all connected clients.

The payload includes: all team word lists, the full center (up to 144 tiles), the full letter pool list, full history of all word steals, activity feed (20 entries), all challenges + past challenges, all players, rebuilt `players_teams` map, end-game votes, and game stats.

The code acknowledges this (`game.ex:699-704`):
> "We currently don't send updates, just the entire new state. Might be inefficient data-wise, but it prevents having to implement game logic on the LiveView."

As a game progresses, this payload grows substantially. Every player action sends all accumulated data to every connected socket.

**Fix:** Implement granular event broadcasting (`{:letter_flipped, letter}`, `{:word_claimed, ...}`, `{:chat_message, ...}`, etc.) so the LiveView can apply incremental updates to its existing assigns. At minimum, split into frequently-changing fields (turn, center, letter_pool_count) and rarely-changing fields (teams composition, player list).

**Impact:** Major bandwidth reduction. Late-game payloads could shrink by 80%+ for most events. Also reduces GenServer blocking time since `state_for_player` does non-trivial work on every call.

---

### 2. Double GenServer Call on Every Player Action

**File:** `lib/piratex/game.ex:721-901`

Nearly every public API function (`flip_letter`, `claim_word`, `challenge_word`, `send_chat_message`, `start_game`, `create_team`, `join_team`, `join_game`, etc.) follows this pattern:

```elixir
def flip_letter(game_id, player_token) do
  case find_by_id(game_id) do          # GenServer.call #1: :get_state
    {:ok, %{status: :playing} = _state} ->
      genserver_call(game_id, {:flip_letter, player_token})  # GenServer.call #2
    ...
  end
end
```

`find_by_id/1` does `GenServer.call(pid, :get_state)` which constructs the full sanitized state via `state_for_player` — just to pattern match on `:status`. The state is then discarded. The `handle_call` callbacks already have proper guards for status, making the pre-check entirely redundant. There's also a TOCTOU race: state could change between the two calls.

**Fix:** Remove the `find_by_id` pre-check from all API functions. Call the GenServer directly via `safe_genserver_call/2` (which already exists at line 910-913). The `handle_call` clauses already return appropriate error tuples for invalid states.

**Impact:** Halves latency for every player action. Eliminates redundant `state_for_player` construction on every call. This is likely the most noticeable "sluggishness" source for flash messages and WebSocket response times.

---

### 3. `{assigns}` Splat Passes All Assigns to Child Components

**File:** `lib/piratex_web/live/game.ex:103-112`, `lib/piratex_web/live/watch.ex:57-67`, `lib/piratex_web/components/game/playing.ex:94`

```elixir
<.waiting {assigns} />
<.playing {assigns} />
<.finished {assigns} />
```

The render function passes all ~30 socket assigns to every phase component. LiveView's diff tracking works at the assign level — when all assigns are splatted, **any** assign change triggers re-evaluation of the entire component tree.

**Assigns waste by component:**

| Component | Used | Received | Waste |
|---|---|---|---|
| `.finished` | **1** (`game_state`) | ~30 | 97% |
| `.waiting` | **5** (`game_state`, `my_team_id`, `max_name_length`, `valid_team_name`, `watch_only`) | ~30 | 83% |
| `render_modal` (nested splat in `playing.ex:94`) | **5** (`visible_word_steal`, `game_state`, `show_teams_modal`, `my_team_id`, `show_hotkeys_modal`) | ~30 | 83% |
| `.playing` (incl. render_modal) | **17** | ~30 | 43% |

The worst offenders are `.finished` (receives 30 assigns for 1) and the nested `<.render_modal {assigns} />`. `.playing` itself is close to needing everything it gets.

Additional issues found during this analysis:
- **`letter_pool_size`** is assigned on mount but never referenced in any template — dead assign
- **`speech_results`** is set/reset in handlers but never appears in any HEEx template — likely leftover from in-progress work
- **`player_token`** (secret auth token) leaks into every component via splat despite no component using it

**Fix:** Pass only specific assigns. The high-value fixes are `.finished` (trivial — just pass `game_state`) and `render_modal` (just 5 assigns). `.playing` is lower priority since it uses most of what it gets.

**Impact:** `.finished` and `.waiting` stop re-rendering on every keystroke/modal toggle/turn change. The nested `render_modal` splat fix prevents modal-irrelevant changes from re-diffing modal content.

---

### 4. `game_state` as a Single Monolithic Assign

**File:** `lib/piratex_web/live/game.ex:37`

The entire game state is stored as a single `game_state` assign. When any part changes (e.g., a chat message in the activity feed), the **entire** `game_state` assign is marked dirty, triggering re-diff of every template referencing `@game_state`.

Every component accesses sub-fields: `@game_state.center`, `@game_state.teams`, `@game_state.history`, `@game_state.challenges`, `@game_state.activity_feed`, etc.

LiveView cannot do sub-map diffing. A chat message causes center tiles, team word areas, history, challenge panel, and action area to all be re-diffed.

**Fix:** Decompose `game_state` into individual assigns in `handle_info({:new_state, state}, socket)`:
```elixir
|> assign(center: state.center, teams: state.teams, history: state.history, ...)
```

**Impact:** When only the activity feed changes, only components referencing `@activity_feed` re-evaluate. LiveView's diff engine skips unchanged assigns entirely. Large reduction in server-side rendering work and bytes-over-the-wire.

---

### 5. No `phx-debounce` on Any Form Input

**Files:** `lib/piratex_web/components/game/playing.ex:253`, `lib/piratex_web/components/partials/activity_feed_component.ex:41`, `lib/piratex_web/components/game/waiting.ex:53`

Zero forms use `phx-debounce` or `phx-throttle`. Every keystroke in the word input (`phx-change="word_change"`), chat input (`phx-change="chat_change"`), and team name input (`phx-change="validate_new_team_name"`) generates a full WebSocket round-trip to the server. A fast typist generates 5-10 events per second per input.

**Fix:** Add `phx-debounce="300"` to all text inputs.

**Impact:** Reduces form-related server events from one-per-keystroke to ~3/second. Immediate perceived responsiveness improvement since the browser isn't waiting on server acks between keystrokes.

---

## High

### 6. Static Asset Gzip Disabled in Production

**File:** `lib/piratex_web/endpoint.ex:33`

```elixir
gzip: false,
```

The deploy pipeline runs `phx.digest` which generates `.gz` files, but `gzip: false` means Plug.Static never serves them. The dev build of `app.js` is 930KB but that includes a 664KB inline sourcemap — the production build (`mix assets.deploy` with `--minify`) should be ~130-150KB unminified, ~50KB gzipped. `app.css` is 63KB (~15KB gzipped). (The 2MB dictionary file is in `priv/static/` but is only loaded server-side into ETS — the browser never requests it.)

No `cache_control_for_etags` header is set either, so fingerprinted assets aren't cached aggressively by browsers.

**Fix:** Change to `gzip: true`. Add `cache_control_for_etags: "public, max-age=31536000, immutable"`.

**Impact:** Meaningful reduction on initial page load (especially `app.css`). Every returning visitor saves the full asset transfer with proper caching.

---

### 7. No WebSocket Compression

**File:** `lib/piratex_web/endpoint.ex:15-17`

```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [session: @session_options]],
  longpoll: [connect_info: [session: @session_options]]
```

No `compress: true` on the WebSocket config. All those full-state payloads are sent uncompressed over the wire.

**Fix:** Add `compress: true` to websocket options.

**Impact:** Per-message deflate typically achieves 60-80% compression. Immediate bandwidth reduction with a one-line change. This is the single easiest win.

---

### 8. `state_for_player` Recomputes Expensive Derived Values on Every Broadcast

**File:** `lib/piratex/helpers.ex:92-120`

Each broadcast recomputes synchronously inside the GenServer:
- `sanitize_players_teams/1` — O(P^2): for each player token, does a linear scan of the players list (`PlayerService.find_player`)
- `drop_internal_states/1` — maps over all players
- `Enum.count(state.players, &Player.is_playing?/1)` — linear scan
- `length(state.letter_pool)` — O(N) traversal of up to 144 items
- `ActivityFeed.entries(state)` — converts `:queue` to list

All of this blocks the GenServer from processing the next message.

**Fix:** Cache `letter_pool_count`, `active_player_count`, and the token-to-name map on the state struct. Update them only when the underlying data actually changes.

**Impact:** Removes ~5 linear/quadratic scans from every broadcast. With 20 max players, `sanitize_players_teams` alone does up to 400 list scans per state change.

---

### 9. Letter Pool: O(N) Random Access on Every Flip

**File:** `lib/piratex/services/turn_service.ex:26-39`

```elixir
defp pick_letter(letter_pool) do
  rand_idx = :rand.uniform(length(letter_pool)) - 1     # O(N)
  {Enum.at(letter_pool, rand_idx), rand_idx}             # O(N)
end
# then List.delete_at(letter_pool, idx)                  # O(N)
```

Three O(N) operations on every flip. However, N is at most 144 — in-memory iteration of a short list is fast in practice.

**Fix:** Shuffle the letter pool at game start and pop from the head:
```elixir
def update_state_flip_letter(%{letter_pool: [new_letter | rest]} = state) do
  state |> Helpers.add_letters_to_center([new_letter]) |> next_turn() |> Map.put(:letter_pool, rest)
end
```

**Impact:** Low priority. Cleaner code and technically O(1) vs O(144), but the actual time savings are negligible for a 144-element list.

---

### 10. No Use of `stream` or `temporary_assigns`

**Files:** All LiveView modules under `lib/piratex_web/live/`

Zero usage of `stream` or `temporary_assigns` anywhere. Growing data structures held permanently in each LiveView process:

- `game_state.history` — all word steals ever, but only 3 displayed
- `game_state.center` — up to 144 tiles
- `game_state.activity_feed` — 20 entries, fully replaced on each broadcast
- `game_state.past_challenges` — all past challenges, unbounded

**Fix:** Use `stream` for activity feed (each new entry streamed in, incremental DOM update). Use `stream` for center tiles (each flip adds one tile). Use `temporary_assigns` for `game_stats` (only needed on finished screen).

**Impact:** Reduces per-connection memory. Enables incremental DOM updates instead of full list replacement on the most frequently changing UI elements.

---

### 11. Hotkey Server Round-Trips for Client-Only Actions

**File:** `assets/js/hooks/hotkeys.js:1-46`

The hook's own comment admits: `"NOTE: this setup hits the server every time a key in the hotkeys set is pressed."` Keys like `0` (hotkeys modal), `3` (teams modal), `8` (zen mode), and `Escape` (close modal) only toggle boolean assigns — purely client-side UI state. No debouncing or throttling is present.

**Fix:** Handle client-only toggles with Phoenix LiveView JS commands (`JS.toggle`, `JS.show`, `JS.hide`) executed entirely on the client. Only send server events for game actions (flip, challenge, vote). Add throttling (200ms) to game-action hotkeys.

**Impact:** Eliminates unnecessary server round-trips for UI toggles. Prevents rapid key presses from hammering the server.

---

### 12. `list_games_page` Calls Every Game GenServer Sequentially

**File:** `lib/piratex/dynamic_supervisor.ex:85-122`

For pagination, calls `GenServer.call(pid, :get_state)` on every registered game sequentially. Copies the full state from each, blocking each game's GenServer.

**Fix:** Store game metadata (status, player count, game name) in an ETS table or Registry metadata. Update on status changes. Listing reads from ETS without blocking any game process.

**Impact:** Game listing becomes O(1) per game instead of blocking each GenServer. Prevents lobby browsing from impacting active game performance.

---

### 13. Duplicate Desktop/Mobile DOM Trees

**File:** `lib/piratex_web/components/game/playing.ex:102-117, 126-178`

The `center` component renders every tile twice — once for desktop (`hidden sm:block`) and once for mobile (`block sm:hidden`). For 144 center tiles, that means 288 DOM elements. Same pattern in `team_word_area`.

**Fix:** Use a single DOM structure with responsive Tailwind classes for sizing (`w-6 h-6 sm:w-8 sm:h-8 text-lg sm:text-2xl`).

**Impact:** Halves the DOM node count for tiles — the most numerous elements on screen. Reduces both memory and diffing work.

---

## Medium — Memory

### 14. Unbounded `history` List (Memory Leak)

**File:** `lib/piratex/game.ex:59`

The `history` field (list of WordSteals) is never trimmed. Only 3 items are displayed (`history_component.ex:21`), but the full list is kept in state, broadcast to all clients, and held in each LiveView process's assigns.

**Fix:** Cap history to a reasonable window (e.g., 20 entries) in the GenServer. Keep full history only server-side for end-game stats.

**Impact:** Prevents unbounded memory growth in both GenServer and all connected LiveView processes. Also reduces broadcast payload size.

---

### 15. Unbounded `past_challenges` (Memory Leak)

**File:** `lib/piratex/game.ex` state struct

`past_challenges` accumulates all resolved challenges and is never cleaned up. Broadcast to every client on every state change but only used server-side for `word_already_challenged?` checks.

**Fix:** Don't include `past_challenges` in the broadcast payload. If clients need to know a word was already challenged, send a flag per word instead.

**Impact:** Reduces payload size and per-connection memory, especially in contentious games.

---

### 16. Timer References Never Cancelled

**File:** `lib/piratex/services/turn_service.ex:71-73`

Turn timer references are never stored or cancelled. Each uncancelled timer sits in the process message queue until it fires. With 60s timeouts and 144 letters, a fast game accumulates ~144 pending timer messages. The `handle_info` correctly ignores stale ones, but they consume memory.

**Fix:** Store the timer reference and cancel it when the turn advances.

**Impact:** Minor memory hygiene. Prevents accumulation of stale timer messages.

---

### 17. Finished Games Linger 5 Minutes

**File:** Config `finished_game_shutdown_ms: 300_000`

Finished games stay in memory for 5 minutes. Each holds the complete game state including all history, challenges, teams, and stats.

**Fix:** Consider reducing to 2-3 minutes, or clear heavy state fields (history, letter pool) once game stats are computed, keeping only what's needed for the finished screen.

**Impact:** Reduces peak memory usage when many games finish in bursts.

---

## Medium — Algorithms

### 18. `word_in_play?` Scans All Teams' Word Lists

**File:** `lib/piratex/helpers.ex:39-41`

Linear scan of every team's word list on every word claim and challenge.

**Fix:** Maintain a `MapSet` of all in-play words on the state struct. O(1) lookup.

**Impact:** Converts O(total_words) to O(1) per claim attempt.

---

### 19. Steal Attempt Complexity: O(W * C)

**File:** `lib/piratex/services/word_claim_service.ex:173-258`

For each steal attempt, iterates all teams × all words, and for each word recomputes `calculate_word_product` and scans all `past_challenges` via `is_recidivist_word_claim?`.

**Fix:** Cache prime products when words are claimed. Index `past_challenges` by `{old_word, new_word}` pair for O(1) recidivist lookup.

**Impact:** Reduces steal computation from O(W × C) to O(W). More important in late-game.

---

### 20. `center_sorted` Maintained via Linear Insertion

**File:** `lib/piratex/helpers.ex:55-70`

`insert_sorted_letter` is O(N) per insertion. The `--` operator for center removal is O(N×M).

**Fix:** Evaluate whether `center_sorted` is needed — the prime product approach doesn't require sorted input for correctness, only for the early-exit optimization. If needed, consider `:gb_sets` for O(log N).

**Impact:** Moderate. Center grows to 144 max.

---

### 21. `next_turn` Recursion Recomputes Player Count

**File:** `lib/piratex/services/turn_service.ex:45-66`

`next_turn/1` recursively skips quit players, calling `Enum.count(players, ...)` on each recursion. If many players quit, this is O(P²).

**Fix:** Move the `Enum.count` call outside the recursion, or use the cached `active_player_count`.

**Impact:** Minor — bounded by max 20 players, but easy fix.

---

## Medium — Frontend

### 22. `team_has_active_players?` Computed in Template Loop

**File:** `lib/piratex_web/components/game/playing.ex:50-55, 380-384`

Linear scan of all players for each team, executed inside the render loop on every state change.

**Fix:** Precompute a MapSet of team IDs with active players in `handle_info`.

**Impact:** Moves computation out of the render path.

---

### 23. Components Receive Full `game_state` When They Need Subfields

**File:** `lib/piratex_web/components/partials/history_component.ex:9`, and others

Components declare `attr :game_state, :map` and access sub-fields. Any change to any sub-field triggers re-evaluation.

**Fix:** Pass only needed data: `history={@history}`, `challenges={@challenges}`.

**Impact:** Enables LiveView to skip re-rendering components whose data hasn't changed. Best combined with #4.

---

### 24. HistoryComponent Calls Expensive Functions in Template

**File:** `lib/piratex_web/components/partials/history_component.ex:30-33`

For each of the 3 displayed history items, calls `Helpers.word_in_play?` (O(T×W)) and `ChallengeService.word_already_challenged?` (O(Ch+PCh)) inside the template during rendering.

**Fix:** Precompute these flags in `handle_info` and pass as assigns.

**Impact:** Removes O(T×W) + O(Ch+PCh) work from the render path, per history item, on every state change.

---

### 25. Pirates Theme Heavy Compositing

**File:** `assets/css/themes.css:158-293`

The pirates theme `.tile` uses 6 stacked box-shadows, a 3-layer gradient, and a `::after` pseudo-element with `mix-blend-mode: multiply`. With 144+ tiles on screen, each creates a separate compositing layer.

**Fix:** Simplify shadows for small/medium tiles when many are on screen. Replace `mix-blend-mode: multiply` with a simpler semi-transparent overlay.

**Impact:** Reduces GPU compositing work. Most noticeable on lower-end devices.

---

### 26. AutoScrollFeed Missing Passive Scroll Listener

**File:** `assets/js/hooks/auto_scroll_feed.js:8`

The scroll handler reads `scrollHeight`, `scrollTop`, `clientHeight` on every scroll pixel — forces layout recalculation each time.

**Fix:** Add `{ passive: true }` to the scroll event listener.

**Impact:** Prevents scroll blocking during rapid scrolling.

---

### 27. TabSwitcher Runs on Every LiveView Update

**File:** `assets/js/hooks/tab_switcher.js:9`

`restoreTabState` runs on every LiveView `updated()` callback, re-walking the DOM and flipping classes even when the tab hasn't changed.

**Fix:** Guard with early return if active tab hasn't changed. Or replace the entire hook with LiveView JS commands.

**Impact:** Reduces unnecessary DOM manipulation on every server push.

---

## Medium — Infrastructure

### 28. Gzip Disabled + No Cache Headers (Static Assets)

**File:** `lib/piratex_web/endpoint.ex:28-33`

Already covered in #6, but additionally: no `cache_control_for_etags` means browsers re-request fingerprinted assets on every visit. Adding `"public, max-age=31536000, immutable"` for digested assets would eliminate repeat downloads.

---

### 29. `IO.puts` in Production Code

**File:** `lib/piratex_web/live/game.ex:489`

```elixir
IO.puts("Speech recognition error: #{error}")
```

Bypasses Logger, cannot be filtered by log level, and writes to stdout with no metadata.

**Fix:** Replace with `Logger.warning("Speech recognition error", error: error)`.

**Impact:** Code quality. Prevents noisy stdout in production.

---

### 30. `Phoenix.LiveDashboard.RequestLogger` Runs in All Environments

**File:** `lib/piratex_web/endpoint.ex:44`

This plug runs on every request in production even though LiveDashboard routes are only enabled in dev.

**Fix:** Guard with `if Application.compile_env(:piratex, :dev_routes)`.

**Impact:** Minor — the plug is lightweight, but it's dead code in production.

---

### 31. Finch Dependency Unused

**File:** `mix.exs`

Finch (HTTP client) is started in the supervision tree but never used — no outbound HTTP calls, no email sending.

**Fix:** Remove from `mix.exs` and `application.ex`.

**Impact:** Small memory savings and faster startup.

---

### 32. Registry Uses Single Partition

**File:** `lib/piratex/application.ex:18`

The Registry uses default 1 partition. Under load with many concurrent games, this creates lock contention.

**Fix:** Add `partitions: System.schedulers_online()`.

**Impact:** Better concurrency for game lookups under load.

---

### 33. K8s Probes Use TCP Instead of HTTP

**File:** `k8s/deployment.yaml:32-46`

Probes use `tcpSocket` but the app has a proper `/healthz` endpoint. TCP probes only confirm the port is open, not that the app is healthy.

**Fix:** Switch to `httpGet` probes pointing at `/healthz`. Add a `startupProbe` with generous timing for BEAM startup (ETS dictionary load, etc.).

**Impact:** More meaningful health signals. Prevents premature pod kills during startup.

---

### 34. No Docker Layer Caching in CI

**File:** `.github/workflows/master.yaml`

The `docker/build-push-action@v6` step doesn't use BuildKit cache (`cache-from`/`cache-to`). Every build reinstalls esbuild, tailwind, and all deps.

**Fix:** Add `docker/setup-buildx-action@v3` and GHA cache.

**Impact:** Faster CI builds (minutes saved per deploy).

---

### 35. Elixir/OTP Version Drift

`.tool-versions` specifies Elixir 1.18.3/Erlang 27.3.3, but the Dockerfile uses 1.17/OTP-27 and CI uses 1.17.2/27.0.1. Vestigial `elixir_buildpack.config` references 1.17.2/27.0.1.

**Fix:** Align all version references. Remove `elixir_buildpack.config`.

**Impact:** Prevents subtle behavior differences between dev and production.

---

### 36. No BEAM VM Tuning for Containers

No `rel/env.sh.eex` exists. The BEAM uses default scheduler settings which may be suboptimal for the K8s resource limits (250m CPU).

**Fix:** Create `rel/env.sh.eex` with tuning flags (`+S 1:1`, `+JMsingle true`, etc.).

**Impact:** Better CPU utilization in resource-constrained containers.

---

## Low

### 37. `Application.get_env` on Every Config Access

**File:** `lib/piratex/services/config.ex`

Every config function calls `Application.get_env(:piratex, ...)` in hot paths.

**Fix:** Use `Application.compile_env/3` for values that don't change at runtime.

**Impact:** Marginal. `get_env` is already ETS-backed.

---

### 38. Letter Pool Regenerated on Every Call

**File:** `lib/piratex/services/letter_pool_service.ex:17-22`

`counts_to_letter_pool` builds the pool from scratch each time.

**Fix:** Precompute as a module attribute.

**Impact:** Negligible — only called at game start.

---

### 39. `find_challenge_with_index` Double-Traverses List

**File:** `lib/piratex/services/challenge_service.ex:296-300`

Same pattern in `PlayerService` and `TeamService`.

**Fix:** Use `Enum.with_index |> Enum.find` for single-pass lookup.

**Impact:** Negligible — lists are typically 0-1 items.

---

### 40. `String.graphemes` Called at Render Time

**File:** `lib/piratex_web/components/piratex_components.ex:17, 56`

`String.graphemes(String.upcase(@word))` in tile templates. With 100+ tiles, this runs on every render.

**Fix:** Precompute graphemes when words are created, or accept as negligible.

**Impact:** Minor.

---

### 41. `transition-all` on Buttons

**File:** `lib/piratex_web/components/piratex_components.ex:195`

`transition-all duration-75` transitions every CSS property, not just `transform`.

**Fix:** Use `transition-transform duration-75`.

**Impact:** Prevents unintended animations on property changes.

---

### 42. Watch LiveView Sets Irrelevant Assigns

**File:** `lib/piratex_web/live/watch.ex:23-45`

Watchers get assigns for `speech_recording`, `speech_results`, `auto_flip`, `zen_mode`, modal booleans (some set twice).

**Fix:** Remove unnecessary assigns from watcher mount.

**Impact:** Minor per-connection memory savings.

---

### 43. `longpoll` Transport Enabled

**File:** `lib/piratex_web/endpoint.ex:16`

The longpoll transport is included alongside WebSocket but likely unused.

**Fix:** Remove if not needed.

**Impact:** Negligible. Reduces attack surface.

---

### 44. Dictionary File Publicly Accessible

**File:** `priv/static/dictionary.txt` (2MB)

The dictionary is in `priv/static/` making it downloadable. It's only used server-side for ETS.

**Fix:** Move to `priv/` (not `priv/static/`).

**Impact:** Prevents unnecessary public exposure. Reduces Plug.Static file checking.

---

### 45. Theme Management Code Duplication

**File:** `assets/js/app.js:64-130`

Theme initialization logic is duplicated across inline `<script>` in `root.html.heex`, the IIFE in `app.js`, and the `ThemeSelector` hook.

**Fix:** Keep inline script (prevents FOUC) + hook only. Remove redundant IIFE and event listeners.

**Impact:** Code quality.

---

### 46. Activity Feed Loop Without Keys

**File:** `lib/piratex_web/components/partials/activity_feed_component.ex:30`

The `for` loop doesn't use unique keys. LiveView uses positional matching, which is suboptimal when entries shift.

**Fix:** Add unique IDs to feed entries and use them as keys.

**Impact:** Minor diffing efficiency improvement.

---

## Summary: Top 10 by Expected Impact

| # | Finding | Effort | Impact |
|---|---------|--------|--------|
| 7 | Enable WebSocket compression | 1 line | High — 60-80% bandwidth reduction on every message |
| 6 | Enable gzip + cache headers for static assets | 3 lines | High — meaningful savings on initial load + proper browser caching |
| 5 | Add `phx-debounce` to form inputs | 3 lines | High — eliminates per-keystroke server round-trips |
| 2 | Eliminate double GenServer call | Moderate | Critical — halves latency on every player action |
| 1 | Granular broadcasts instead of full state | Large | Critical — 80%+ bandwidth reduction mid-game |
| 4 | Decompose `game_state` into individual assigns | Moderate | Critical — enables granular LiveView diffing |
| 3 | Fix assigns splat (esp. `.finished`, `.waiting`, `render_modal`) | Small | High — stops 83-97% wasted re-renders in those components |
| 8 | Cache derived values in GenServer state | Moderate | High — removes O(P²) work from every broadcast |
| 11 | Client-side hotkey handling | Moderate | High — eliminates server round-trips for UI toggles |
| 13 | Eliminate duplicate mobile/desktop DOM | Moderate | High — halves tile DOM node count |

# Piratex Codebase Audit

Audit date: March 7, 2026

Scope:
- I inventoried the full repository, including Elixir app code, LiveViews, components, JS hooks, config, tests, docs, and static/generated files.
- Generated digests, fonts, compressed dictionary/static assets, and duplicated image outputs were checked as inventory but do not have code-level findings of their own.
- Verification run: `mix test` passed with `409 tests, 0 failures`.

## TODO Inventory

| # | Source | Issue Slug / Name | Description | Impact / Benefit |
| --- | --- | --- | --- | --- |
| 1 | README | turn-timer-ui-stale | The README still lists turn timer UI as missing, but the countdown already exists in the playing screen. This should be removed or reframed as timer polish and reconnect-test work. | Reduces stale backlog noise and keeps product planning accurate. |
| 2 | README | challenge-timer-ui-stale | The README still lists challenge timer UI as missing, but the challenge modal already contains a countdown timer. The remaining work is correctness, not feature creation. | Prevents duplicate work and redirects effort to the real rendering bug. |
| 3 | README | hotkeys-on-start-hint | Add a flash or inline waiting-room hint that tells players to press `0` for hotkeys after game start. | Improves discoverability of core controls with low implementation cost. |
| 4 | README | turn-delight-polish | There is already a turn chime; this item is now about animation/feedback polish rather than greenfield work. | Clarifies scope and avoids treating existing UX as missing. |
| 5 | README | word-claim-delight | Add a specific client-side animation or event feedback when a word is successfully claimed. | Makes the central game action feel more responsive and legible. |
| 6 | README | challenge-resolution-delight | Add explicit accept/reject resolution feedback when a challenge closes. | Reduces ambiguity during challenge flow and improves perceived polish. |
| ~~7~~ | ~~README~~ | ~~waiting-games-list~~ | ~~Improve the `/find` waiting game list with better sorting, labels, and scale handling.~~ | ~~Better join flow and less confusion when multiple games exist.~~ |
| ~~8~~ | ~~README~~ | ~~score-graph-missing-backend~~ | ~~The score graph UI exists, but backend stats never compute `score_timeline` or `score_timeline_max`. This TODO has become a live bug.~~ | ~~Required to prevent the finished-game stats tab from breaking.~~ |
| 9 | README | server-to-client-flash-events | Add structured server events for start, invalid claim, challenge resolution, timeout, and endgame states so the client can show human messages. | Improves UX clarity without duplicating rules in the UI. |
| ~~10~~ | ~~README~~ | ~~join-error-flash~~ | ~~Joining with a taken name still degrades poorly. Errors should be translated into friendly flashes and stay within the join flow.~~ | ~~Improves conversion and reduces avoidable frustration during join.~~ |
| ~~11~~ | ~~README~~ | ~~humanize-errors~~ | ~~Error atoms and `inspect(err)` output should be translated to readable messages.~~ | ~~Better UX and less leakage of internal implementation detail.~~ |
| 12 | README | ci-cache-uncertain | The README suspects CI dependency caching is not working, but no CI files exist in this repo. This cannot be closed from local code alone. | Identifies an external follow-up rather than a code change. |
| 13 | README | duplicate-nice-to-haves | The README repeats delight items and mixes active TODOs with nice-to-haves. It needs cleanup. | Keeps the roadmap readable and less contradictory. |
| 14 | README | stats-page-games-in-progress | There is no dedicated stats page for in-progress games. Scope and placement are still undefined. | Potential observer/admin value if formalized. |
| 15 | README | token-copy-open-question | Session tokens can be reused across multiple clients; the README correctly flags this as unresolved. | Important fairness/security issue for multiplayer integrity. |
| ~~16~~ | ~~Inline TODO~~ | ~~liveview-version-bump~~ | ~~`mix.exs` still pins `phoenix_live_view` to `1.0.0-rc.1` with a TODO to upgrade.~~ | ~~Reduces upgrade risk and dependency drift.~~ |
| ~~17~~ | ~~Inline TODO~~ | ~~speech-homophone-biasing~~ | ~~Speech recognition mentions adding homophone/context support. This is optional feature work, not a correctness blocker.~~ | ~~Improves speech UX for edge cases if prioritized.~~ |
| 18 | Inline TODO | error-page-tests | `test/controllers/error_html_test.exs` still lacks 404/500 coverage. | Improves confidence in production error handling. |
| 19 | Inline TODO | cancel-stale-turn-timers | `TurnService` hints at canceling stale timers instead of letting old timeout messages arrive. | Would reduce timer noise and make timeout behavior easier to reason about. |
| ~~20~~ | ~~Inline TODO~~ | ~~list-games-scaling~~ | ~~`DynamicSupervisor.list_games/0` notes that `which_children` may not scale well.~~ | ~~Important if the app starts hosting many concurrent games.~~ |
| ~~21~~ | ~~Inline TODO~~ | ~~dictionary-membership-structure~~ | ~~`Dictionary.is_word?/1` has a TODO for binary search, but the better fix is using `MapSet` or direct ETS membership instead of linear list scans.~~ | ~~Large performance win on every claim validation.~~ |
| ~~22~~ | ~~Inline TODO~~ | ~~center-insert-efficiency~~ | ~~`Helpers.add_letters_to_center/2` resorts the center repeatedly.~~ | ~~Small but frequent algorithm cleanup opportunity.~~ |
| 23 | Inline TODO | word-claim-short-circuits | `WordClaimService` has multiple TODOs for prechecks and fewer passes through mutation logic. | Improves performance and maintainability in the most complex rule path. |
| ~~24~~ | ~~Inline TODO~~ | ~~stale-clear-players-comment~~ | ~~`Game` still contains a TODO claiming `players` are unassigned waiting players to clear on start, which is no longer true.~~ | ~~Removes misleading documentation inside the core state model.~~ |
| 25 | Inline TODO | prevent-token-duplication | `Game.rejoin` explicitly notes that copied tokens are not prevented. | Important fairness and identity-control work. |
| 26 | Inline TODO | host-only-start | `Game.start_game` still allows any player to start the game. | Fixes rules/ownership ambiguity in multiplayer flow. |
| 27 | Inline TODO | invalid-claim-rate-limit | Invalid word claims are not rate-limited. | Protects the server and game UX from spammy clients. |
| 28 | Inline TODO | overflow-team-assignment-policy | Overflow players are deterministically assigned to the first team, with a TODO questioning fairness. | Could improve fairness or at least document policy explicitly. |
| ~~29~~ | ~~Inline TODO~~ | ~~broad-rescue-cleanup~~ | ~~`Game.quit_game/2` contains a TODO noting its broad rescue likely does not solve the real crash problem.~~ | ~~Improves correctness and debuggability of process lifecycle handling.~~ |
| 30 | Inline TODO | split-state-and-side-effects | `watch.ex` and `game.ex` both note that side effects should be separated from raw state broadcasts. | Cleaner event architecture and less UI drift. |
| 31 | Inline TODO | controls-real-auth | `controls.ex` admits the auth is rudimentary and should be replaced. | Important if the route remains public. |
| 32 | Inline TODO | controls-persist-session | `controls.ex` also notes admin auth should survive refreshes via a real session. | Better admin UX and less improvised logic. |
| 33 | Inline TODO | heatmap-color-scaling | The heatmap component still has a TODO for value-based coloring. | Visual polish only. |
| ~~34~~ | ~~Inline TODO~~ | ~~empty-team-playing-state~~ | ~~`playing.ex` notes that teams with no active players should show a message.~~ | ~~Clarifies game state after quits.~~ |
| ~~35~~ | ~~Inline TODO~~ | ~~stats-player-lookup-cleanup~~ | ~~`stats_component.ex` labels its player/team lookup as unideal.~~ | ~~Good refactor target before stats grow further.~~ |
| 36 | Inline TODO | game-liveview-pid-and-name-lookups | `game.ex` contains TODOs for PID storage, team-name validation, start hotkeys, and name-based lookup cleanup. | Reduces fragility in the main gameplay LiveView. |

## Bugs And Crash / Page-Break Risks

| # | Source | Issue Slug / Name | Description | Impact / Benefit |
| --- | --- | --- | --- | --- |
| ~~37~~ | ~~Agent identified~~ | ~~finished-stats-score-timeline-crash~~ | ~~The finished-game stats UI renders `game_stats.score_timeline` and `score_timeline_max`, but `ScoreService.calculate_game_stats/1` never populates them.~~ | ~~High impact production breakage in the finished-game stats tab.~~ |
| ~~38~~ | ~~Agent identified~~ | ~~challenge-modal-wrong-assign~~ | ~~`playing.ex` passes `@player_name` into the challenge component, but the actual LiveView assign is `my_name`. Watch mode also lacks that assign.~~ | ~~High impact runtime crash when a challenge modal opens.~~ |
| ~~39~~ | ~~Agent identified~~ | ~~quitter-vote-return-shape-bug~~ | ~~`ChallengeService.remove_quitter_vote/2` returns `{idx, state}` from `Enum.reduce`, and `Game.handle_call/3` treats it like plain state.~~ | ~~High impact crash/corruption path when a player quits during an open challenge.~~ |
| ~~40~~ | ~~Agent identified~~ | ~~invalid-team-id-corrupts-waiting-state~~ | ~~`TeamService.add_player_to_team/3` does not verify the target team exists before mutating `players_teams`, and `remove_empty_teams/1` can then remove all valid teams.~~ | ~~High impact state corruption from malformed client input.~~ |
| ~~41~~ | ~~Agent identified~~ | ~~invalid-letter-pool-500~~ | ~~`LetterPoolService.letter_pool_from_string/1` uses `String.to_existing_atom/1`, so a bad `letter_pool` param in `POST /game/new` raises.~~ | ~~High impact public request crash instead of clean validation.~~ |
| ~~42~~ | ~~Agent identified~~ | ~~hotkeys-listener-leak~~ | ~~The Hotkeys hook registers a global `keydown` listener on mount and never unregisters it.~~ | ~~Medium impact duplicate actions and hard-to-debug client behavior after remounts.~~ |
| ~~43~~ | ~~Agent identified~~ | ~~hotkeys-enter-null-focus~~ | ~~The Hotkeys hook calls `.focus()` on `#new_word_input` without checking whether the element exists.~~ | ~~Medium impact client-side JS error on non-playing screens.~~ |
| ~~44~~ | ~~Agent identified~~ | ~~stats-zero-division~~ | ~~`stats_component.ex` divides by `@max_avg_points`, which can be `0` if every team has zero words or zero average points.~~ | ~~Medium impact finished-page rendering failure on low-activity games.~~ |
| ~~45~~ | ~~Agent identified~~ | ~~loss-stats-broken-fields~~ | ~~`loss_stats/1` references stat keys in the wrong place and dereferences `best_steal` without a nil guard.~~ | ~~Medium impact latent crash if the component is ever used.~~ |
| 46 | Agent identified | any-player-can-start | `Game.start_game/2` does not check whether the caller is the game owner or intended starter. | Medium impact rules/permission bug in multiplayer sessions. |
| 47 | Agent identified | turn-service-unsafe-pattern-match | `TurnService.is_player_turn?/2` pattern matches on `Enum.at(players, turn)` as if it always returns a player. | Medium impact crash if state gets inconsistent or empty. |
| ~~48~~ | ~~Agent identified~~ | ~~tab-switcher-global-dom-scope~~ | ~~`TabSwitcher` manipulates `document.querySelectorAll(".tab-panel")` instead of scoping to its own root.~~ | ~~Medium impact UI interference if another tab switcher appears later.~~ |
| ~~49~~ | ~~Agent identified~~ | ~~controls-config-atom-raise~~ | ~~`controls.ex` uses `String.to_existing_atom/1` on event input without guarding against bad values.~~ | ~~Medium impact forged event can crash the admin LiveView.~~ |
| ~~50~~ | ~~Agent identified~~ | ~~raw-join-error-inspect~~ | ~~`GameController.join_game/2` shows `inspect(err)` to users.~~ | ~~Low-to-medium impact poor UX and leakage of internal error atoms.~~ |

## Scoring And Statistics Audit

| # | Source | Issue Slug / Name | Description | Impact / Benefit |
| --- | --- | --- | --- | --- |
| 51 | Agent identified | team-score-formula-correct | Team score is consistently implemented as total letters across owned words minus word count. | Confirms the core game scoring rule is implemented correctly. |
| 52 | Agent identified | avg-word-length-formula-correct | `avg_word_length` is indirectly computed from score plus word count, but the math is still correct. | Confirms one key displayed stat is numerically sound. |
| ~~53~~ | ~~Agent identified~~ | ~~total-letters-never-accumulated~~ | ~~`calculate_team_stats/1` initializes `total_letters` to `0` and never increments it.~~ | ~~Confirmed stats bug that makes one aggregate metric invalid.~~ |
| 54 | Agent identified | steals-counts-all-claims | `calculate_history_stats/2` treats every history item as a steal, including words built entirely from the center. | Mislabels summary stats and player achievement data. |
| 55 | Agent identified | points-per-steal-misnamed | `points_per_steal` divides by total history entries attributed to the player, not actual steals. | Misleading derived stat that can significantly skew interpretations. |
| ~~56~~ | ~~Agent identified~~ | ~~invalid-challenge-filter-too-broad~~ | ~~Invalidated history entries are removed by `thief_word` alone, so one failed challenge can suppress multiple unrelated occurrences of the same resulting word.~~ | ~~Undercounts history-derived stats and distorts MVP/steal numbers.~~ |
| 57 | Agent identified | mvp-tie-break-unstable | `raw_mvp` is selected from a map using `Enum.max_by/3`, so tie behavior is effectively arbitrary. | Produces nondeterministic winner labeling in tied or no-action games. |
| ~~58~~ | ~~Agent identified~~ | ~~score-timeline-not-implemented~~ | ~~The UI expects score timeline stats, but the backend never computes them.~~ | ~~Both a missing feature and a direct stats/rendering bug.~~ |
| 59 | Agent identified | self-steal-points-consistent | Self-steals only award points for newly added letters. | Confirms the intended self-steal scoring rule is internally consistent. |
| 60 | Agent identified | cross-team-steal-points-consistent | Cross-team steals award full word points. | Confirms the intended non-self-steal scoring rule is internally consistent. |
| 61 | Agent identified | margin-of-victory-correct | Margin of victory is computed correctly from sorted team scores. | Confirms a key summary stat is safe. |
| 62 | Agent identified | challenge-counting-mostly-correct | Overall challenge counts and valid counts are accumulated correctly in the normal path. | Indicates challenge summary logic is mostly solid apart from identity/index fragility. |
| ~~63~~ | ~~Agent identified~~ | ~~missing-finished-ui-stats-tests~~ | ~~There is no test that renders the finished stats UI end-to-end.~~ | ~~Important test gap that would have caught the missing timeline and zero-division issues.~~ |
| ~~64~~ | ~~Agent identified~~ | ~~missing-zero-word-game-test~~ | ~~There is no test for a finished game with zero claimed words.~~ | ~~Leaves divide-by-zero and nil-state stats paths unprotected.~~ |
| ~~65~~ | ~~Agent identified~~ | ~~missing-duplicate-thief-word-test~~ | ~~There is no test covering repeated identical `thief_word` values with one invalid challenge.~~ | ~~Leaves the invalid-history-filter bug untested.~~ |
| 66 | Agent identified | missing-center-vs-steal-stats-test | There is no test verifying that center claims and actual steals are counted separately in statistics. | Would catch the current mislabeled steal counters. |

## Cleanup / DRY / Modularity / Readability

| # | Source | Issue Slug / Name | Description | Impact / Benefit |
| --- | --- | --- | --- | --- |
| 67 | Agent identified | game-genserver-too-large | `lib/piratex/game.ex` mixes process orchestration, validation, domain rules, PubSub, timers, and public API wrappers. | Splitting pure state transitions from the GenServer shell would materially improve maintainability. |
| 68 | Agent identified | team-membership-source-of-truth | Team membership is spread across `Team.players`, `players_teams`, and later `player.team_id`, but only some of those are actually authoritative. | A single source of truth would reduce bugs and mental overhead. |
| 69 | Agent identified | word-claim-service-too-dense | `WordClaimService` combines search, validation, recidivist checks, and mutation in one dense flow. | Refactoring into smaller pure helpers would improve correctness reviewability. |
| 70 | Agent identified | challenge-service-inconsistent-returns | `ChallengeService` returns a mix of plain state, tuples, and errors in ways that are easy to misuse. | Clearer contracts would prevent bugs like the quitter-vote shape issue. |
| 71 | Agent identified | game-and-watch-liveview-duplication | `game.ex` and `watch.ex` duplicate mount/update/modal/event handling patterns. | Shared helpers would reduce drift and make gameplay/UI fixes cheaper. |
| 72 | Agent identified | stats-component-does-data-shaping | `stats_component.ex` performs lookups, calculations, and formatting inside render functions. | Moving shaping logic upstream would simplify templates and cut render fragility. |
| 73 | Agent identified | playing-component-assign-coupling | `playing.ex` relies on many implicit assigns and already contains a broken assign reference. | Explicit attr contracts or view models would make the component safer. |
| 74 | Agent identified | piratex-components-too-broad | `piratex_components.ex` bundles generic controls and app-specific widgets into one large file. | Splitting primitives from game widgets would improve reuse and discoverability. |
| 75 | Agent identified | speech-hook-debug-noise | `speech_recognition.js` still contains a large amount of inline debug logging and browser API orchestration detail. | Extracting a small wrapper would make the hook easier to maintain. |
| ~~76~~ | ~~Agent identified~~ | ~~hotkeys-hook-lifecycle-cleanup~~ | ~~The Hotkeys hook should manage its listener lifecycle and null checks explicitly.~~ | ~~Cleaner client code and fewer remount bugs.~~ |
| 77 | Agent identified | duplicated-theme-sync-logic | Theme synchronization lives in both `assets/js/app.js` and `assets/js/hooks/theme_selector.js`. | Eliminates duplication and reduces theme drift bugs. |
| 78 | Agent identified | config-accessor-boilerplate | `Piratex.Config` is repetitive one-function-per-key boilerplate. | A table-driven or macro-based approach would shrink maintenance surface. |
| ~~79~~ | ~~Agent identified~~ | ~~dictionary-linear-membership~~ | ~~`Dictionary.is_word?/1` linearly scans a list loaded from ETS.~~ | ~~Cleaner and much faster if replaced with membership-oriented storage.~~ |
| 80 | Agent identified | public-admin-controls-route | `controls.ex` is admin functionality exposed as a normal public LiveView with improvised password handling. | Better isolation or real auth would reduce operational risk. |
| 81 | Agent identified | stale-readme-and-comments | The repo contains stale TODOs, duplicated roadmap items, and misleading comments in core modules. | Improves trustworthiness of the code and planning docs. |

## Priority Order

| # | Source | Issue Slug / Name | Description | Impact / Benefit |
| --- | --- | --- | --- | --- |
| ~~82~~ | ~~Agent identified~~ | ~~priority-finished-stats~~ | ~~Implement `score_timeline` or guard the graph UI so the finished-game stats page cannot break.~~ | ~~Highest-value fix because it is a direct production rendering failure.~~ |
| ~~83~~ | ~~Agent identified~~ | ~~priority-challenge-flow~~ | ~~Fix the challenge modal assign mismatch and the quitter-vote return-shape bug.~~ | ~~Removes the most dangerous challenge-related crash paths.~~ |
| ~~84~~ | ~~Agent identified~~ | ~~priority-input-validation~~ | ~~Validate team joins and `letter_pool` params instead of trusting the client.~~ | ~~Prevents malformed input from corrupting state or crashing requests.~~ |
| 85 | Agent identified | priority-stats-corrections | Correct `total_letters`, steal labeling, `points_per_steal`, and invalid-history filtering. | Makes finished-game statistics trustworthy. |
| ~~86~~ | ~~Agent identified~~ | ~~priority-test-gaps~~ | ~~Add end-to-end tests for finished-game rendering, zero-word games, malformed inputs, and open-challenge quits.~~ | ~~Keeps the same category of regressions from returning.~~ |

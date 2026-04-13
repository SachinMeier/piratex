# TUI Release Process

The Piratex TUI is released independently from the server. Tags follow
`tui-v<major>.<minor>.<patch>`. The release workflow at
`.github/workflows/tui-release.yaml` builds four binaries (darwin-arm64,
darwin-x64, linux-x64, linux-arm64) and attaches them to a GitHub Release.

## Day-to-day release (minor or patch)

1. Update `clients/tui/package.json` version.
2. If the protocol changed compatibly, bump
   `PROTOCOL_VERSION.minor` in `clients/tui/src/contract.ts` and
   `@protocol_version` (the minor element) in `lib/piratex_web/protocol.ex`.
3. Update `clients/tui/CHANGELOG.md` with the new version and changes.
4. Merge to master.
5. Tag and push: `git tag tui-v1.3.0 && git push origin tui-v1.3.0`.
6. The release workflow builds all four binaries and publishes the release.

Rollback: delete the tag and the release. The previous release becomes
"latest" again. Users on the broken version see the minor-mismatch badge
but keep working.

## Major release (breaking protocol)

This is the only case where the server deploy and TUI release synchronize.

```
[ ] Server: bump @protocol_version major in lib/piratex_web/protocol.ex
[ ] Server: update test/piratex_web/protocol_version_test.exs snapshot
[ ] Server: open PR, merge held until TUI is ready
[ ] TUI:    bump PROTOCOL_VERSION.major in clients/tui/src/contract.ts
[ ] TUI:    reset PROTOCOL_VERSION.minor to 0
[ ] TUI:    bump clients/tui/package.json semver
[ ] TUI:    update clients/tui/CHANGELOG.md
[ ] TUI:    merge to master
[ ] TUI:    git tag tui-vX.0.0 && git push origin tui-vX.0.0
[ ] TUI:    verify tui-release.yaml completes, all four binaries published
[ ] TUI:    download tui-vX.0.0 locally, run `piratex --version`, confirm major
[ ] Server: merge protocol bump PR to master
[ ] Server: verify deploy.yaml completes
[ ] Verify: old binary gets UpgradePrompt on connect attempt
[ ] Verify: new binary connects and plays normally
[ ] Announce in README and any community channels
```

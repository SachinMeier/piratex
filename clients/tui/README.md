# piratex — terminal client for Pirate Scrabble

Play Pirate Scrabble in your terminal. Single self-contained binary, no Node
or bun required to run, no Elixir on the user's machine.

## Install

### Method 1 — one-line installer (recommended)

```sh
curl -fsSL https://raw.githubusercontent.com/SachinMeier/piratex/main/clients/tui/install.sh | sh
```

The script detects your OS and architecture, downloads the matching tarball
from the latest GitHub release, places the binary at `~/.local/bin/piratex`,
strips the macOS quarantine attribute, and prints a PATH reminder.

To install elsewhere:

```sh
PIRATEX_INSTALL=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/SachinMeier/piratex/main/clients/tui/install.sh | sh
```

### Method 2 — manual download

1. Visit <https://github.com/SachinMeier/piratex/releases/latest>
2. Download the tarball for your platform:
   - macOS Apple Silicon: `piratex-darwin-arm64.tar.gz`
   - macOS Intel: `piratex-darwin-x64.tar.gz`
   - Linux x86_64: `piratex-linux-x64.tar.gz`
   - Linux arm64: `piratex-linux-arm64.tar.gz`
3. Extract and install:

   ```sh
   tar -xzf piratex-darwin-arm64.tar.gz
   mv piratex ~/.local/bin/piratex
   chmod +x ~/.local/bin/piratex
   # macOS only:
   xattr -d com.apple.quarantine ~/.local/bin/piratex 2>/dev/null || true
   ```

The tarball contains exactly one file named `piratex`. Same name on every
platform.

### Method 3 — build from source

Requires [bun](https://bun.sh) at build time. End users do not need bun;
the binary is self-contained.

```sh
git clone https://github.com/SachinMeier/piratex.git
cd piratex
make install
```

`make install` builds and copies the binary to `$INSTALL_DIR` (default
`~/.local/bin`). Override with `make install INSTALL_DIR=/usr/local/bin`.

## Run

```sh
piratex                                       # connects to wss://piratescrabble.com
piratex --server http://localhost:4001        # local dev
piratex --version
piratex --help
```

## Controls

The TUI uses a neovim-inspired three-mode input model:

- **Normal mode** (default): type letters to build a word, press enter to
  submit. Press space to flip a letter.
- **Command mode** (`:`): vim-style commands. See below.
- **Chat mode** (`/`): type a message and press enter to send.

### Commands

| Command        | Action                                |
|----------------|---------------------------------------|
| `:c` / `:c1`   | Challenge most recent word            |
| `:c2` / `:c3`  | Challenge 2nd / 3rd most recent       |
| `:y` / `:2`    | Vote valid on the open challenge      |
| `:n` / `:7`    | Vote invalid on the open challenge    |
| `:t` / `:3`    | Toggle teams panel                    |
| `:h`           | Toggle full history panel             |
| `:?` / `:0`    | Toggle hotkeys help                   |
| `:z` / `:8`    | Toggle zen mode                       |
| `:o`           | Send a quick reaction                 |
| `:!`           | Send "argh!" to chat                  |
| `:q`           | Quit (with confirm)                   |
| `:qa`          | Quit immediately, no confirm          |

### Waiting room

In the waiting room, type a team name and press enter to create or join.
`:j N` joins team number N. `:s` starts the game. `:q` leaves.

## Uninstall

```sh
make uninstall                       # removes ~/.local/bin/piratex
# or
rm ~/.local/bin/piratex
```

## Development

```sh
cd clients/tui
bun install
bun run dev          # hot-reload
bun run typecheck
bun run test
bun run build        # → ../../bin/piratex
```

The TUI talks to the Phoenix server via a Phoenix Channel on `/socket` and
JSON HTTP at `/api/*`. See `../../TUI_PLAN.md` for the full design spec.

## Platform support

- macOS (Apple Silicon and Intel)
- Linux (x86_64 and arm64)

Windows is not supported in v1.

## Troubleshooting

**macOS: "cannot be opened because the developer cannot be verified"**

The install script handles this automatically. If you downloaded the
binary manually:

```sh
xattr -d com.apple.quarantine ~/.local/bin/piratex
```

**`~/.local/bin` not in PATH**

Add this to your shell profile:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

**"protocol mismatch" / upgrade prompt**

Your binary is older than the server. Re-run the installer to get the
latest release.

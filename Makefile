.PHONY: run
run:
	iex -S mix phx.server

.PHONY: digest
digest:
	rm -f priv/static/dictionary-*.txt*
	rm -f priv/static/robots-*
	rm -f priv/static/test-*.txt*
	mix phx.digest

############################################################
# TUI client (Node + Ink)
############################################################

TUI_DIR := clients/tui
TUI_BIN := bin/piratex
INSTALL_DIR ?= $(HOME)/.local/bin

# bun is typically installed at ~/.bun/bin via the official installer.
# Prepend it to PATH inside recipes so users don't have to source their
# shell profile in the same shell as `make`.
TUI_PATH := $(HOME)/.bun/bin:$(PATH)

.PHONY: tui tui-dev tui-test tui-clean install uninstall

## Build the TUI binary at bin/piratex (requires bun).
tui:
	@command -v bun >/dev/null 2>&1 || PATH=$(TUI_PATH) command -v bun >/dev/null 2>&1 || \
	  { echo "✗ bun not found. install: curl -fsSL https://bun.sh/install | bash"; exit 1; }
	cd $(TUI_DIR) && PATH=$(TUI_PATH) bun install --frozen-lockfile && \
	  PATH=$(TUI_PATH) bun build --compile src/index.tsx --outfile ../../$(TUI_BIN)
	@if [ "$$(uname -s)" = "Darwin" ] && command -v codesign >/dev/null 2>&1; then \
	  codesign --remove-signature $(TUI_BIN) >/dev/null 2>&1 || true; \
	  codesign -s - --force $(TUI_BIN) >/dev/null 2>&1 || true; \
	fi
	@echo ""
	@echo "✓ piratex built at $(TUI_BIN)"
	@echo "  run: $(TUI_BIN) --server http://localhost:4001"

## Run the TUI in dev mode (hot reload via bun --watch).
tui-dev:
	cd $(TUI_DIR) && PATH=$(TUI_PATH) bun install && PATH=$(TUI_PATH) bun --watch src/index.tsx

## Typecheck and run the TUI test suite.
tui-test:
	cd $(TUI_DIR) && PATH=$(TUI_PATH) bun install && \
	  PATH=$(TUI_PATH) bun x tsc --noEmit && \
	  PATH=$(TUI_PATH) bun vitest run

## Remove the built binary.
tui-clean:
	rm -f $(TUI_BIN)

## Build, sign, and copy the TUI binary into INSTALL_DIR (default ~/.local/bin).
install: tui
	mkdir -p $(INSTALL_DIR)
	install -m 755 $(TUI_BIN) $(INSTALL_DIR)/piratex
	@echo ""
	@echo "✓ piratex installed to $(INSTALL_DIR)/piratex"
	@case ":$$PATH:" in \
	  *":$(INSTALL_DIR):"*) ;; \
	  *) echo ""; \
	     echo "⚠ $(INSTALL_DIR) is not in your PATH."; \
	     echo "  add this to your shell profile:"; \
	     echo "    export PATH=\"$(INSTALL_DIR):\$$PATH\"" ;; \
	esac

## Remove the installed TUI binary.
uninstall:
	rm -f $(INSTALL_DIR)/piratex

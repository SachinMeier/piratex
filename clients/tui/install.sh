#!/bin/sh
# install.sh — one-line installer for the Piratex TUI.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/SachinMeier/piratex/main/clients/tui/install.sh | sh
#
# Override the install directory:
#   PIRATEX_INSTALL=/usr/local/bin curl -fsSL ... | sh
#
# Detects OS and architecture, downloads the matching tarball from the latest
# GitHub release, extracts the binary to ${PIRATEX_INSTALL:-$HOME/.local/bin},
# strips the macOS quarantine attribute, and prints a PATH reminder.

set -eu

REPO="SachinMeier/piratex"
INSTALL_DIR="${PIRATEX_INSTALL:-$HOME/.local/bin}"
BIN_NAME="piratex"

red()    { printf '\033[31m%s\033[0m\n' "$1"; }
green()  { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

abort() {
  red "✗ $1"
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || abort "missing required tool: $1"
}

require curl
require tar
require uname

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)

case "$os-$arch" in
  darwin-arm64|darwin-aarch64) asset="piratex-darwin-arm64.tar.gz" ;;
  darwin-x86_64)               asset="piratex-darwin-x64.tar.gz"   ;;
  linux-x86_64)                asset="piratex-linux-x64.tar.gz"    ;;
  linux-aarch64|linux-arm64)   asset="piratex-linux-arm64.tar.gz"  ;;
  *) abort "unsupported platform: $os-$arch" ;;
esac

url="https://github.com/$REPO/releases/latest/download/$asset"

echo "→ downloading $asset"
echo "  from $url"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if ! curl -fsSL "$url" -o "$tmp/$asset"; then
  abort "download failed (no release available?)"
fi

echo "→ extracting"
tar -xzf "$tmp/$asset" -C "$tmp"

if [ ! -f "$tmp/$BIN_NAME" ]; then
  abort "tarball did not contain expected binary '$BIN_NAME'"
fi

mkdir -p "$INSTALL_DIR"
echo "→ installing to $INSTALL_DIR/$BIN_NAME"
install -m 755 "$tmp/$BIN_NAME" "$INSTALL_DIR/$BIN_NAME"

# macOS Gatekeeper: strip quarantine so the binary runs without prompts.
if [ "$os" = "darwin" ] && command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$INSTALL_DIR/$BIN_NAME" 2>/dev/null || true
fi

green "✓ piratex installed to $INSTALL_DIR/$BIN_NAME"

case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    echo ""
    echo "  run:  piratex"
    ;;
  *)
    echo ""
    yellow "⚠ $INSTALL_DIR is not in your PATH."
    echo "  add this to your shell profile (.zshrc, .bashrc, etc):"
    echo ""
    echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
    echo "  then run:  piratex"
    ;;
esac

#!/usr/bin/env sh
set -eu

# Installs Bun system-wide on Debian/Ubuntu for use by systemd services.
# Usage:
#   sudo sh scripts/install-bun-debian.sh [/opt/bun]
# Default install dir:
#   /opt/bun

BUN_INSTALL_DIR=${1:-/opt/bun}

if [ "$(id -u)" -ne 0 ]; then
  echo "[bun] Please run as root (sudo)." >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "[bun] apt-get not found. This script is for Debian/Ubuntu." >&2
  exit 1
fi

echo "[bun] Installing prerequisites"
apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl unzip

if [ ! -d "$BUN_INSTALL_DIR" ]; then
  mkdir -p "$BUN_INSTALL_DIR"
fi
chown root:root "$BUN_INSTALL_DIR"

echo "[bun] Installing Bun into $BUN_INSTALL_DIR"
# Bun install script respects BUN_INSTALL.
BUN_INSTALL="$BUN_INSTALL_DIR" \
  sh -c 'curl -fsSL https://bun.sh/install | bash'

echo "[bun] Linking bun into /usr/local/bin"
mkdir -p /usr/local/bin
ln -sf "$BUN_INSTALL_DIR/bin/bun" /usr/local/bin/bun
if [ -x "$BUN_INSTALL_DIR/bin/bunx" ]; then
  ln -sf "$BUN_INSTALL_DIR/bin/bunx" /usr/local/bin/bunx
fi

echo "[bun] Verifying"
/usr/local/bin/bun --version

echo "[bun] Done. bun is at: /usr/local/bin/bun"

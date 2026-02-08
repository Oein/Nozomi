#!/usr/bin/env sh
set -eu

# Registers link-shorten as an OpenRC service on Alpine.
# Usage:
#   sudo sh scripts/register-alpine-openrc.sh /opt/link-shorten linkshorten
# Defaults:
#   APP_DIR=/opt/link-shorten
#   APP_USER=linkshorten

APP_DIR=${1:-/opt/link-shorten}
APP_USER=${2:-linkshorten}

if [ "$(id -u)" -ne 0 ]; then
  echo "[register] Please run as root (sudo)." >&2
  exit 1
fi

if ! command -v rc-update >/dev/null 2>&1; then
  echo "[register] OpenRC not found (rc-update missing)." >&2
  exit 1
fi

if ! command -v bun >/dev/null 2>&1; then
  echo "[register] bun not found in PATH. Install Bun first." >&2
  exit 1
fi

BUN_BIN=$(command -v bun)
TEMPLATE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/openrc/link-shorten.init"
TARGET="/etc/init.d/link-shorten"

if [ ! -d "$APP_DIR" ]; then
  echo "[register] APP_DIR does not exist: $APP_DIR" >&2
  exit 1
fi

# Create a dedicated user if missing
if ! id "$APP_USER" >/dev/null 2>&1; then
  echo "[register] Creating user: $APP_USER"
  adduser -D -H -s /sbin/nologin "$APP_USER"
fi

echo "[register] Installing service to $TARGET"
# Substitute placeholders
sed \
  -e "s|__BUN__|$BUN_BIN|g" \
  -e "s|__APP_DIR__|$APP_DIR|g" \
  -e "s|__APP_USER__|$APP_USER|g" \
  "$TEMPLATE" > "$TARGET"
chmod +x "$TARGET"

echo "[register] Enabling service on boot"
rc-update add link-shorten default

echo "[register] Done. Start with: rc-service link-shorten start"

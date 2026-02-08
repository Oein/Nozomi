#!/usr/bin/env sh
set -eu

# Registers link-shorten as an OpenRC service on Alpine.
# Usage:
#   sudo sh scripts/register-alpine-openrc.sh /opt/link-shorten linkshorten [bun_path]
# Defaults:
#   APP_DIR=/opt/link-shorten
#   APP_USER=linkshorten

APP_DIR=${1:-/opt/link-shorten}
APP_USER=${2:-linkshorten}
BUN_BIN_OVERRIDE=${3:-}

if [ "$(id -u)" -ne 0 ]; then
  echo "[register] Please run as root (sudo)." >&2
  exit 1
fi

if ! command -v rc-update >/dev/null 2>&1; then
  echo "[register] OpenRC not found (rc-update missing)." >&2
  exit 1
fi

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

resolve_bun_bin() {
  if [ -n "$BUN_BIN_OVERRIDE" ]; then
    echo "$BUN_BIN_OVERRIDE"
    return 0
  fi

  # Prefer Bun from the service user's PATH (common when Bun is installed per-user).
  if command -v su >/dev/null 2>&1; then
    if su -s /bin/sh -c 'command -v bun' "$APP_USER" >/dev/null 2>&1; then
      su -s /bin/sh -c 'command -v bun' "$APP_USER"
      return 0
    fi
  fi

  # Fallback to the root PATH.
  command -v bun 2>/dev/null || true
}

BUN_BIN="$(resolve_bun_bin)"
if [ -z "$BUN_BIN" ]; then
  echo "[register] bun not found. Install Bun system-wide or pass bun_path as 3rd arg." >&2
  exit 1
fi

if command -v su >/dev/null 2>&1; then
  if ! su -s /bin/sh -c "test -x \"$BUN_BIN\"" "$APP_USER"; then
    echo "[register] bun is not executable by user '$APP_USER': $BUN_BIN" >&2
    echo "[register] Install Bun system-wide (e.g. in /usr/local/bin) or pass a different bun_path." >&2
    exit 1
  fi
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

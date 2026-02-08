#!/usr/bin/env sh
set -eu

# Registers link-shorten as a systemd service on Debian/Ubuntu.
# Usage:
#   sudo sh scripts/register-debian-systemd.sh /opt/link-shorten linkshorten [/usr/local/bin/bun]
# Defaults:
#   APP_DIR=/opt/link-shorten
#   APP_USER=linkshorten

APP_DIR=${1:-/opt/link-shorten}
APP_USER=${2:-linkshorten}
BUN_BIN=${3:-}

if [ "$(id -u)" -ne 0 ]; then
  echo "[register] Please run as root (sudo)." >&2
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "[register] systemd not found (systemctl missing)." >&2
  exit 1
fi

if [ ! -d "$APP_DIR" ]; then
  echo "[register] APP_DIR does not exist: $APP_DIR" >&2
  exit 1
fi

resolve_bun_bin() {
  if [ -n "$BUN_BIN" ]; then
    echo "$BUN_BIN"
    return 0
  fi

  # Prefer stable, system-wide locations.
  if [ -x /usr/local/bin/bun ]; then
    echo /usr/local/bin/bun
    return 0
  fi
  if [ -x /opt/bun/bin/bun ]; then
    echo /opt/bun/bin/bun
    return 0
  fi

  # Fallback to PATH.
  command -v bun 2>/dev/null || true
}

BUN_BIN="$(resolve_bun_bin)"

if [ -z "$BUN_BIN" ]; then
  echo "[register] bun not found. Install Bun system-wide or pass bun_path as 3rd arg." >&2
  exit 1
fi

# systemd can't rely on ephemeral /tmp paths. If bun resolves to /tmp, re-install bun system-wide.
case "$BUN_BIN" in
  /tmp/*)
    echo "[register] bun path looks ephemeral: $BUN_BIN" >&2
    echo "[register] Install Bun system-wide (e.g. scripts/install-bun-debian.sh) and re-run." >&2
    exit 1
    ;;
esac

# If bun is a symlink, ensure it doesn't resolve into /tmp.
if command -v readlink >/dev/null 2>&1; then
  BUN_REAL=$(readlink -f "$BUN_BIN" 2>/dev/null || true)
  case "$BUN_REAL" in
    /tmp/*)
      echo "[register] bun resolves into /tmp: $BUN_BIN -> $BUN_REAL" >&2
      echo "[register] Install Bun system-wide (e.g. scripts/install-bun-debian.sh) and re-run." >&2
      exit 1
      ;;
  esac
fi

if [ ! -x "$BUN_BIN" ]; then
  echo "[register] bun is not executable: $BUN_BIN" >&2
  exit 1
fi

TEMPLATE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/systemd/link-shorten.service"
TARGET="/etc/systemd/system/link-shorten.service"

# Create a dedicated system user if missing
if ! id "$APP_USER" >/dev/null 2>&1; then
  echo "[register] Creating user: $APP_USER"
  if command -v useradd >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "$APP_USER"
  else
    adduser --system --no-create-home --disabled-login --shell /usr/sbin/nologin "$APP_USER"
  fi
fi

# Ensure app dir is accessible
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo "[register] Installing unit to $TARGET"
# Substitute placeholders
sed \
  -e "s|__BUN__|$BUN_BIN|g" \
  -e "s|__APP_DIR__|$APP_DIR|g" \
  -e "s|__APP_USER__|$APP_USER|g" \
  "$TEMPLATE" > "$TARGET"

echo "[register] Reloading systemd daemon"
systemctl daemon-reload

echo "[register] Enabling service on boot"
systemctl enable link-shorten

echo "[register] Done. Start with: systemctl start link-shorten"

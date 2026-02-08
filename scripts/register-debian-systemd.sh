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

if [ -z "$BUN_BIN" ]; then
  if command -v bun >/dev/null 2>&1; then
    BUN_BIN=$(command -v bun)
  fi
fi

if [ -z "$BUN_BIN" ]; then
  echo "[register] bun not found. Install Bun system-wide or pass bun_path as 3rd arg." >&2
  exit 1
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

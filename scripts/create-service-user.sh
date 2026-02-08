#!/usr/bin/env sh
set -eu

# Creates a dedicated service user (system account, no login shell).
# Usage:
#   sudo sh scripts/create-service-user.sh [username]
# Default:
#   linkshorten

APP_USER=${1:-linkshorten}

if [ "$(id -u)" -ne 0 ]; then
  echo "[user] Please run as root (sudo)." >&2
  exit 1
fi

if id "$APP_USER" >/dev/null 2>&1; then
  echo "[user] User already exists: $APP_USER"
  exit 0
fi

echo "[user] Creating user: $APP_USER"

# Prefer useradd if present (common on Debian).
if command -v useradd >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin "$APP_USER"
  exit 0
fi

# Fallback to adduser (also works on Debian/Ubuntu).
if command -v adduser >/dev/null 2>&1; then
  adduser --system --no-create-home --disabled-login --shell /usr/sbin/nologin "$APP_USER"
  exit 0
fi

echo "[user] No useradd/adduser found." >&2
exit 1

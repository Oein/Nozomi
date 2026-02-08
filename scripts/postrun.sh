#!/usr/bin/env sh
set -eu

# Runs Prisma setup steps that should happen on deploy/start.
# - Applies existing migrations (does not create new ones)
# - Regenerates Prisma Client

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

if [ ! -f ".env" ]; then
  echo "[postrun] .env not found in $ROOT_DIR" >&2
  echo "[postrun] Continuing anyway (dotenv will be skipped)." >&2
fi

echo "[postrun] prisma migrate deploy"
bunx prisma migrate deploy

echo "[postrun] prisma generate"
bunx prisma generate

echo "[postrun] done"

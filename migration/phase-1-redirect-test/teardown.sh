#!/bin/bash
# Teardown the Phase -1 test environment
# Removes all containers and volumes (clean slate for rerun)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
if command -v docker-compose.exe >/dev/null 2>&1; then
  DOCKER_BIN="docker-compose.exe"
  DOCKER_ARGS=()
elif command -v docker-compose >/dev/null 2>&1; then
  DOCKER_BIN="docker-compose"
  DOCKER_ARGS=()
elif command -v docker.exe >/dev/null 2>&1; then
  DOCKER_BIN="docker.exe"
  DOCKER_ARGS=(compose)
elif command -v docker >/dev/null 2>&1; then
  DOCKER_BIN="docker"
  DOCKER_ARGS=(compose)
else
  DOCKER_BIN="cmd.exe"
  DOCKER_ARGS=(/c docker compose)
fi

echo "Stopping and removing Phase -1 test environment..."
"$DOCKER_BIN" "${DOCKER_ARGS[@]}" down -v

echo "Done. Environment cleaned up."

#!/bin/bash
# Teardown the Phase -1 test environment
# Removes all containers and volumes (clean slate for rerun)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping and removing Phase -1 test environment..."
docker compose down -v

echo "Done. Environment cleaned up."

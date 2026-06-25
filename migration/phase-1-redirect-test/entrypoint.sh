#!/bin/bash
set -euo pipefail

# Execute original entrypoint
exec /usr/local/bin/docker-entrypoint.sh "$@"

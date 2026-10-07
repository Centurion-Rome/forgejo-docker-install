#!/usr/bin/env bash
set -euo pipefail

echo "Updating docker images..."
docker compose pull

echo "Stopping containers..."
docker compose down

echo "Recreating containers..."
docker compose up -d --force-recreate --remove-orphans

echo "Done."

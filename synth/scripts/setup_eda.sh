#!/usr/bin/env bash
# synth/scripts/setup_eda.sh
# Sets up the AFTxAI EDA container environment from scratch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASE_IMAGE="openroad/orfs:latest"
TARGET_IMAGE="aftxai_eda:latest"

echo "============================================================"
echo " AFTxAI: EDA Container Image Setup"
echo "============================================================"

# Check Docker CLI
if ! command -v docker &> /dev/null; then
    echo "[FAIL] Docker is not installed or not in PATH."
    echo "       Please install Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

echo "==> Step 1: Pulling base OpenROAD Flow Scripts image ($BASE_IMAGE)..."
docker pull "$BASE_IMAGE"

echo "==> Step 2: Building extended AFTxAI EDA image ($TARGET_IMAGE) with Verilator..."
docker build -t "$TARGET_IMAGE" -f "$REPO_ROOT/synth/docker/Dockerfile" "$REPO_ROOT/synth/docker"

echo "==> Step 3: Verifying newly built image..."
bash "$REPO_ROOT/synth/scripts/check_environment.sh"

echo "============================================================"
echo "[SUCCESS] AFTxAI EDA environment setup completed successfully!"
echo "============================================================"

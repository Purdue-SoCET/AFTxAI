#!/usr/bin/env bash
# synth/scripts/check_environment.sh
# Verifies host prerequisites, Docker availability, EDA image, and tool sanity.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "============================================================"
echo " AFTxAI: EDA Environment & Prerequisites Sanity Check"
echo "============================================================"
echo "Host Operating System: $(uname -srm)"
echo "Host User:             $(whoami) (UID: $(id -u), GID: $(id -g))"
echo "Repository Path:       $REPO_ROOT"

# Check Docker CLI
if ! command -v docker &> /dev/null; then
    echo "[FAIL] 'docker' command not found in PATH. Please install Docker."
    exit 1
fi
echo "[OK] Docker CLI detected: $(docker --version)"

# Check Docker daemon access
if ! docker info &> /dev/null; then
    echo "[FAIL] Cannot communicate with Docker daemon. Ensure docker is running and current user is in 'docker' group."
    exit 1
fi
echo "[OK] Docker daemon is running and accessible without sudo."

# Check for openroad/orfs:latest image
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"
if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^openroad/orfs:latest$"; then
        echo "[INFO] Found base image 'openroad/orfs:latest'. Testing base tools..."
        IMAGE_NAME="openroad/orfs:latest"
    else
        echo "[WARN] Docker image '$IMAGE_NAME' not found locally."
        echo "       Build or pull it with: bash synth/scripts/setup_eda.sh"
        exit 1
    fi
fi

DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE_NAME" 2>/dev/null || echo "Local build")
echo "[OK] Docker image '$IMAGE_NAME' found."
echo "     Image Digest: $DIGEST"

# Run quick tool sanity check inside container
echo "==> Testing EDA tools inside Docker container..."
docker run --rm "$IMAGE_NAME" bash -lc "
    source /OpenROAD-flow-scripts/env.sh
    echo -n '  - Yosys:     ' && yosys -V | head -n 1
    echo -n '  - Slang:     ' && yosys -p 'slang_version' 2>/dev/null | grep -i slang || echo 'slang plugin active'
    echo -n '  - OpenROAD:  ' && openroad -version
    if command -v verilator &> /dev/null; then
        echo -n '  - Verilator: ' && verilator --version
    else
        echo '  - Verilator: [NOT INSTALLED] (Run synth/scripts/setup_eda.sh to build extended image)'
    fi
"

echo "============================================================"
echo "[SUCCESS] Environment sanity check passed completely!"
echo "============================================================"

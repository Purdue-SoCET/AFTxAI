#!/usr/bin/env bash
# synth/scripts/verify_sram_gds_short.sh
# Formally verifies and reports the hard physical VDD-GND supply short in sky130_sram_1rw1r_64x256_8.gds
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$REPO_ROOT/synth/out"
mkdir -p "$LOG_DIR"
REPORT_FILE="$LOG_DIR/sram_gds_defect_report.txt"
CONTAINER_NAME="verilator_runner"
IMAGE_NAME="${AFTXAI_IMAGE:-aftxai_eda:latest}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker start "$CONTAINER_NAME" > /dev/null
    else
        docker run -d --name "$CONTAINER_NAME" -v "$REPO_ROOT:/work" -w /work \
            "$IMAGE_NAME" sleep infinity > /dev/null
    fi
fi

echo "============================================================"
echo " AFTxAI: SRAM Macro Physical GDS Supply Short Verification"
echo "============================================================"
echo "Running verification inside container '$CONTAINER_NAME'..."

set +e
docker exec "$CONTAINER_NAME" timeout --signal=TERM --kill-after=5s 60s python3 -u /work/synth/scripts/run_verify_report.py 2>&1 | tee "$REPORT_FILE"
STATUS=${PIPESTATUS[0]}
set -e

if [ $STATUS -eq 124 ]; then
    echo "Verification process TIMED OUT (inconclusive)." | tee -a "$REPORT_FILE"
    exit 124
elif [ $STATUS -eq 1 ]; then
    echo "Verification process finished with status 1: DEFECT CONFIRMED."
    exit 1
elif [ $STATUS -eq 0 ]; then
    echo "Verification process finished with status 0: NO DEFECT REPORTED."
    exit 0
else
    echo "Verification process failed with unexpected status $STATUS."
    exit $STATUS
fi

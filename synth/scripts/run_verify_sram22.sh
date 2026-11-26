#!/usr/bin/env bash
# synth/scripts/run_verify_sram22.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$REPO_ROOT/synth/out"
mkdir -p "$LOG_DIR"
REPORT_FILE="$LOG_DIR/sram22_gds_audit_report.txt"
CONTAINER_NAME="verilator_runner"

set +e
docker exec "$CONTAINER_NAME" timeout --signal=TERM --kill-after=5s 60s python3 -u /work/synth/scripts/verify_sram22_gds.py 2>&1 | tee "$REPORT_FILE"
STATUS=${PIPESTATUS[0]}
set -e

if [ $STATUS -eq 124 ]; then
    echo "Verification process TIMED OUT (inconclusive)." | tee -a "$REPORT_FILE"
    exit 124
elif [ $STATUS -eq 0 ]; then
    echo "Verification process finished with status 0: CLEAN (NO SHORT REPORTED)."
    exit 0
elif [ $STATUS -eq 1 ]; then
    echo "Verification process finished with status 1: DEFECT DETECTED."
    exit 1
elif [ $STATUS -eq 2 ]; then
    echo "Verification process finished with status 2: MISSING LABELS / SETUP ERROR."
    exit 2
else
    echo "Verification process failed with unexpected status $STATUS."
    exit $STATUS
fi

#!/bin/bash
#
# test/validate.sh — Regression test suite for helm-serve
#
# This script renders all example values files and compares them against
# golden outputs stored in test/golden/. Use this before committing changes
# that could affect template rendering (ingress, metrics, probes, etc).
#
# Usage:
#   ./test/validate.sh [--update]
#
# Arguments:
#   --update    Update golden outputs (use after intentional changes)
#   (no args)   Compare current renders against golden outputs
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN_DIR="${SCRIPT_DIR}/golden"
TEST_DIR="${SCRIPT_DIR}"
CHART_DIR="${SCRIPT_DIR}/../chart"

UPDATE_MODE=false
if [[ "${1:-}" == "--update" ]]; then
    UPDATE_MODE=true
fi

# Create golden directory if it doesn't exist
mkdir -p "${GOLDEN_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Helm-Serve Regression Test Suite"
echo "======================================"
echo ""

# Find all values-*.yaml files in test/
VALUES_FILES=($(find "${TEST_DIR}" -maxdepth 1 -name "values-*.yaml" | sort))

if [[ ${#VALUES_FILES[@]} -eq 0 ]]; then
    echo "❌ No values files found in ${TEST_DIR}"
    exit 1
fi

PASSED=0
FAILED=0
UPDATED=0

for VALUES_FILE in "${VALUES_FILES[@]}"; do
    BASENAME=$(basename "${VALUES_FILE}")
    GOLDEN_FILE="${GOLDEN_DIR}/${BASENAME%.yaml}.golden.yaml"

    echo -n "Testing ${BASENAME}... "

    # Render the template
    RENDER_OUTPUT=$(helm template smoke "${TEST_DIR}" -f "${VALUES_FILE}" 2>&1) || {
        echo -e "${RED}FAILED${NC} (template error)"
        echo "  Error output:"
        echo "${RENDER_OUTPUT}" | sed 's/^/    /'
        ((FAILED++))
        continue
    }

    if [[ "${UPDATE_MODE}" == true ]]; then
        # Update mode: save current output as golden
        echo "${RENDER_OUTPUT}" > "${GOLDEN_FILE}"
        echo -e "${YELLOW}UPDATED${NC}"
        ((UPDATED++))
    else
        # Compare mode: check against golden
        if [[ ! -f "${GOLDEN_FILE}" ]]; then
            echo -e "${YELLOW}NEW${NC} (no golden file yet; run with --update to create)"
            ((PASSED++))
        else
            DIFF_OUTPUT=$(diff -u "${GOLDEN_FILE}" <(echo "${RENDER_OUTPUT}") || true)
            if [[ -z "${DIFF_OUTPUT}" ]]; then
                echo -e "${GREEN}PASSED${NC}"
                ((PASSED++))
            else
                echo -e "${RED}FAILED${NC} (output differs)"
                echo "  Diff:"
                echo "${DIFF_OUTPUT}" | sed 's/^/    /'
                ((FAILED++))
            fi
        fi
    fi
done

echo ""
echo "======================================"

if [[ "${UPDATE_MODE}" == true ]]; then
    echo -e "✅ Updated ${UPDATED} golden output(s)"
    echo "   Commit these changes along with your template modifications."
else
    echo "Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"

    if [[ ${FAILED} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Regression detected!${NC}"
        echo "If changes are intentional, run: ./test/validate.sh --update"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
    fi
fi

#!/bin/bash

set -euo pipefail

# get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR"/*.md "$SCRIPT_DIR/chart/"

# package the chart
pushd "$SCRIPT_DIR/chart"
{
    helm package .
    helm repo index .
} || {
    popd
    echo "Error: Failed to package the chart" >&2
    exit 1
}

#!/bin/bash

set -euo pipefail

# get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR"/*.md "$SCRIPT_DIR/chart/"

# package the chart
pushd "$SCRIPT_DIR/chart"
{
    rm -rf *.tgz
    rm -rf index.yaml
    helm package .
    # get tgz file name
    TGZ_FILE=$(ls *.tgz)
    helm repo index .
    helm push "$TGZ_FILE" oci://ghcr.io/btungut
} || {
    popd
    echo "Error: Failed to package the chart" >&2
    exit 1
}

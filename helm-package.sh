#!/bin/bash

set -euo pipefail

# get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR"/*.md "$SCRIPT_DIR/chart/"

# package the chart
helm package "$SCRIPT_DIR/chart" --destination "$SCRIPT_DIR/.output"

helm index "$SCRIPT_DIR/.output"

#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=""
WORKSPACE_DIR=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --workspace) WORKSPACE_DIR="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

echo "Config file   : ${CONFIG_FILE}"
echo "Workspace dir : ${WORKSPACE_DIR}"
echo "Output dir    : ${OUTPUT_DIR}"

# TODO:
# 1. parse module-config.yaml
# 2. loop modules
# 3. checkout repo
# 4. run install/build/copy
# 5. collect output
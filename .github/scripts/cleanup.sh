#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# cleanup.sh
# ------------------------------------------------------------
# Cleanup temporary workspace after Job 1
# ============================================================

WORKSPACE_DIR="${1:-}"

echo "============================================================"
echo "[INFO] Cleanup started"
echo "[INFO] Workspace dir: ${WORKSPACE_DIR}"
echo "============================================================"

# -------------------------
# Validate input
# -------------------------
if [[ -z "${WORKSPACE_DIR}" ]]; then
  echo "[WARN] No workspace directory provided. Skip cleanup."
  exit 0
fi

# Prevent dangerous paths
case "${WORKSPACE_DIR}" in
  "/"|"."|"./"|"$HOME"|"/home"*)
    echo "[ERROR] Refusing to cleanup unsafe path: ${WORKSPACE_DIR}"
    exit 1
    ;;
esac

# -------------------------
# Cleanup workspace
# -------------------------
if [[ -d "${WORKSPACE_DIR}" ]]; then
  echo "[INFO] Removing workspace directory: ${WORKSPACE_DIR}"
  rm -rf "${WORKSPACE_DIR}"
else
  echo "[INFO] Workspace directory not found. Nothing to clean."
fi

echo "============================================================"
echo "[INFO] Cleanup completed"
echo "============================================================"
``

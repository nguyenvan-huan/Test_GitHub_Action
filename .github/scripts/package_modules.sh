#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# package_modules.sh
# ------------------------------------------------------------
# Run module-local package scripts based on module-config.yaml
# ============================================================

ROOT_DIR="$(pwd)"
CONFIG_FILE=""
WORKSPACE_DIR=""

# -------------------------
# Parse arguments
# -------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --workspace)
      WORKSPACE_DIR="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Unknown argument: $1"
      exit 1
      ;;
  esac
done

# -------------------------
# Validate input
# -------------------------
if [[ -z "${CONFIG_FILE}" || -z "${WORKSPACE_DIR}" ]]; then
  echo "[ERROR] Usage:"
  echo "  package_modules.sh --config <module-config.yaml> --workspace <workspace_dir>"
  exit 1
fi

CONFIG_FILE="$(realpath "${CONFIG_FILE}")"
WORKSPACE_DIR="$(realpath "${WORKSPACE_DIR}")"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "[ERROR] Config file not found: ${CONFIG_FILE}"
  exit 1
fi

if [[ ! -d "${WORKSPACE_DIR}" ]]; then
  echo "[ERROR] Workspace directory not found: ${WORKSPACE_DIR}"
  exit 1
fi

command -v yq >/dev/null 2>&1 || {
  echo "[ERROR] yq is required but not installed"
  exit 1
}

echo "============================================================"
echo "[INFO] Module packaging started"
echo "[INFO] Config file   : ${CONFIG_FILE}"
echo "[INFO] Workspace dir : ${WORKSPACE_DIR}"
echo "============================================================"

# -------------------------
# Iterate modules
# -------------------------
MODULE_COUNT=$(yq '.modules | length' "${CONFIG_FILE}")

for ((i=0; i<MODULE_COUNT; i++)); do
  NAME=$(yq -r ".modules[$i].name" "${CONFIG_FILE}")
  ENABLED=$(yq -r ".modules[$i].enabled" "${CONFIG_FILE}")

  if [[ "${ENABLED}" != "true" ]]; then
    echo "[INFO] Skip disabled module: ${NAME}"
    continue
  fi

  REPO=$(yq -r ".modules[$i].repo" "${CONFIG_FILE}")
  WORK_DIR=$(yq -r ".modules[$i].execution.working_directory // \".\"" "${CONFIG_FILE}")
  MODULE_PACKAGE_SCRIPT=$(yq -r ".modules[$i].execution.module_package_script // \"\"" "${CONFIG_FILE}")
  PACKAGE_OUTPUT_PATH=$(yq -r ".modules[$i].output.package_output_path // \"\"" "${CONFIG_FILE}")

  MODULE_DIR="${WORKSPACE_DIR}/${NAME}"
  MODULE_WORK_DIR="${MODULE_DIR}/${WORK_DIR}"

  echo "------------------------------------------------------------"
  echo "[INFO] Module              : ${NAME}"
  echo "[INFO] Repo                : ${REPO}"
  echo "[INFO] Working directory   : ${MODULE_WORK_DIR}"
  echo "[INFO] Package script      : ${MODULE_PACKAGE_SCRIPT}"
  echo "[INFO] Package output path : ${PACKAGE_OUTPUT_PATH}"
  echo "------------------------------------------------------------"

  # -------------------------
  # Validate module workspace
  # -------------------------
  if [[ ! -d "${MODULE_DIR}" ]]; then
    echo "[ERROR] Module workspace not found: ${MODULE_DIR}"
    echo "[ERROR] Make sure build_all.sh has already checked out and built this module"
    exit 1
  fi

  if [[ ! -d "${MODULE_WORK_DIR}" ]]; then
    echo "[ERROR] Module working directory not found: ${MODULE_WORK_DIR}"
    exit 1
  fi

  if [[ -z "${MODULE_PACKAGE_SCRIPT}" ]]; then
    echo "[ERROR] module_package_script is empty for module ${NAME}"
    exit 1
  fi

  if [[ -z "${PACKAGE_OUTPUT_PATH}" ]]; then
    echo "[ERROR] package_output_path is empty for module ${NAME}"
    exit 1
  fi

  cd "${MODULE_WORK_DIR}"

  # -------------------------
  # Run module package script
  # -------------------------
  if [[ ! -f "${MODULE_PACKAGE_SCRIPT}" ]]; then
    echo "[ERROR] Module package script not found: ${MODULE_WORK_DIR}/${MODULE_PACKAGE_SCRIPT}"
    exit 1
  fi

  chmod +x "${MODULE_PACKAGE_SCRIPT}"

  echo "[INFO] Running module package script..."
  bash "${MODULE_PACKAGE_SCRIPT}"

  # -------------------------
  # Validate module package output
  # -------------------------
  if [[ ! -e "${PACKAGE_OUTPUT_PATH}" ]]; then
    echo "[ERROR] Packaged output not found for module ${NAME}: ${MODULE_WORK_DIR}/${PACKAGE_OUTPUT_PATH}"
    exit 1
  fi

  echo "[INFO] Packaged output verified for module ${NAME}"

  # Optional: show packaged content
  echo "[INFO] Packaged output content:"
  if command -v tree >/dev/null 2>&1; then
    tree "${PACKAGE_OUTPUT_PATH}" || true
  else
    find "${PACKAGE_OUTPUT_PATH}" | sed "s|^|  |" || true
  fi

  echo "[INFO] Module ${NAME} packaging completed"

  cd "${ROOT_DIR}"
done

echo "============================================================"
echo "[INFO] All module packaging steps completed successfully"
echo "============================================================"

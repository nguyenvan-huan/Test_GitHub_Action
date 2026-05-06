#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# package.sh
# ------------------------------------------------------------
# Collect packaged outputs from module repos and create
# final release package in trigger repo.
# ============================================================

CONFIG_FILE=""
WORKSPACE_DIR=""
OUTPUT_DIR=""
PACKAGE_NAME="PARETTE_System.zip"

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
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --package-name)
      PACKAGE_NAME="$2"
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
if [[ -z "${CONFIG_FILE}" || -z "${WORKSPACE_DIR}" || -z "${OUTPUT_DIR}" ]]; then
  echo "[ERROR] Usage:"
  echo "  package.sh --config <module-config.yaml> --workspace <workspace_dir> --output-dir <dir> [--package-name name.zip]"
  exit 1
fi

CONFIG_FILE="$(realpath "${CONFIG_FILE}")"
WORKSPACE_DIR="$(realpath "${WORKSPACE_DIR}")"

mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(realpath "${OUTPUT_DIR}")"

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
echo "[INFO] Packaging release"
echo "[INFO] Config file   : ${CONFIG_FILE}"
echo "[INFO] Workspace dir : ${WORKSPACE_DIR}"
echo "[INFO] Output dir    : ${OUTPUT_DIR}"
echo "[INFO] Package name  : ${PACKAGE_NAME}"
echo "============================================================"

# -------------------------
# Clean previous collected outputs
# Keep old final package only until new one is created
# -------------------------
find "${OUTPUT_DIR}" -mindepth 1 -maxdepth 1 ! -name "${PACKAGE_NAME}" -exec rm -rf {} +

MODULE_COUNT=$(yq -r '.modules | length' "${CONFIG_FILE}")

if [[ "${MODULE_COUNT}" == "0" ]]; then
  echo "[ERROR] No modules found in config"
  exit 1
fi

# -------------------------
# Collect packaged outputs from each module
# -------------------------
for ((i=0; i<MODULE_COUNT; i++)); do
  NAME=$(yq -r ".modules[$i].name" "${CONFIG_FILE}")
  ENABLED=$(yq -r ".modules[$i].enabled" "${CONFIG_FILE}")

  if [[ "${ENABLED}" != "true" ]]; then
    echo "[INFO] Skip disabled module: ${NAME}"
    continue
  fi

  WORK_DIR=$(yq -r ".modules[$i].execution.working_directory // \".\"" "${CONFIG_FILE}")
  PACKAGE_OUTPUT_PATH=$(yq -r ".modules[$i].output.package_output_path // \"\"" "${CONFIG_FILE}")
  COLLECT_TO=$(yq -r ".modules[$i].output.collect_to // \"\"" "${CONFIG_FILE}")

  if [[ -z "${PACKAGE_OUTPUT_PATH}" || "${PACKAGE_OUTPUT_PATH}" == "null" ]]; then
    echo "[ERROR] package_output_path is missing for module ${NAME}"
    exit 1
  fi

  if [[ -z "${COLLECT_TO}" || "${COLLECT_TO}" == "null" ]]; then
    echo "[ERROR] collect_to is missing for module ${NAME}"
    exit 1
  fi

  MODULE_DIR="${WORKSPACE_DIR}/${NAME}"
  MODULE_WORK_DIR="${MODULE_DIR}/${WORK_DIR}"
  SOURCE_PATH="${MODULE_WORK_DIR}/${PACKAGE_OUTPUT_PATH}"
  TARGET_DIR="${OUTPUT_DIR}/${COLLECT_TO}"

  echo "------------------------------------------------------------"
  echo "[INFO] Collect module : ${NAME}"
  echo "[INFO] Source         : ${SOURCE_PATH}"
  echo "[INFO] Target         : ${TARGET_DIR}"
  echo "------------------------------------------------------------"

  if [[ ! -d "${MODULE_DIR}" ]]; then
    echo "[ERROR] Module workspace not found: ${MODULE_DIR}"
    exit 1
  fi

  if [[ ! -d "${MODULE_WORK_DIR}" ]]; then
    echo "[ERROR] Module working directory not found: ${MODULE_WORK_DIR}"
    exit 1
  fi

  if [[ ! -e "${SOURCE_PATH}" ]]; then
    echo "[ERROR] Packaged output not found for module ${NAME}: ${SOURCE_PATH}"
    exit 1
  fi

  mkdir -p "${TARGET_DIR}"

  if [[ -d "${SOURCE_PATH}" ]]; then
    cp -r "${SOURCE_PATH}/." "${TARGET_DIR}/"
  else
    cp -f "${SOURCE_PATH}" "${TARGET_DIR}/"
  fi

  echo "[INFO] Collected module ${NAME}"
done

# -------------------------
# Verify collected content before zip
# -------------------------
COLLECTED_COUNT=$(find "${OUTPUT_DIR}" -mindepth 1 -maxdepth 1 ! -name "${PACKAGE_NAME}" | wc -l | tr -d ' ')

if [[ "${COLLECTED_COUNT}" == "0" ]]; then
  echo "[ERROR] No collected outputs found in ${OUTPUT_DIR}"
  exit 1
fi

echo "[INFO] Release content (full tree):"
if command -v tree >/dev/null 2>&1; then
  tree "${OUTPUT_DIR}"
else
  find "${OUTPUT_DIR}" | sed "s|^|  |"
fi

# -------------------------
# Create final zip
# -------------------------
PACKAGE_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}"

if [[ -f "${PACKAGE_PATH}" ]]; then
  echo "[INFO] Remove existing package: ${PACKAGE_PATH}"
  rm -f "${PACKAGE_PATH}"
fi

(
  cd "${OUTPUT_DIR}"
  echo "[INFO] Creating zip package: ${PACKAGE_NAME}"
  zip -r "${PACKAGE_NAME}" . \
    -x "*.git*" \
    -x "__MACOSX*" \
    -x "*.DS_Store" \
    -x "${PACKAGE_NAME}"
)

if [[ ! -f "${PACKAGE_PATH}" ]]; then
  echo "[ERROR] Package was not created: ${PACKAGE_PATH}"
  exit 1
fi

echo "============================================================"
echo "[INFO] Package created successfully"
echo "[INFO] Output file : ${PACKAGE_PATH}"
echo "[INFO] Size        : $(du -h "${PACKAGE_PATH}" | cut -f1)"
echo "============================================================"

#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=""
WORKSPACE_DIR=""
OUTPUT_DIR=""
PACKAGE_NAME="PARETTE_System.zip"

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

command -v yq >/dev/null 2>&1 || {
  echo "[ERROR] yq is required but not installed"
  exit 1
}

echo "============================================================"
echo "[INFO] Packaging release"
echo "[INFO] Config file   : ${CONFIG_FILE}"
echo "[INFO] Workspace dir : ${WORKSPACE_DIR}"
echo "[INFO] Output dir    : ${OUTPUT_DIR}"
echo "============================================================"

# Clean previous collected outputs, but keep final zip if exists
find "${OUTPUT_DIR}" -mindepth 1 -maxdepth 1 ! -name "${PACKAGE_NAME}" -exec rm -rf {} +

DEFAULT_REF=$(yq '.global.default_ref // "main"' "${CONFIG_FILE}")
MODULE_COUNT=$(yq '.modules | length' "${CONFIG_FILE}")

for ((i=0; i<MODULE_COUNT; i++)); do
  NAME=$(yq ".modules[$i].name" "${CONFIG_FILE}")
  ENABLED=$(yq ".modules[$i].enabled" "${CONFIG_FILE}")

  if [[ "${ENABLED}" != "true" ]]; then
    continue
  fi

  WORK_DIR=$(yq ".modules[$i].build.working_directory // \".\"" "${CONFIG_FILE}")
  OUTPUT_PATH=$(yq ".modules[$i].build.output_path // \"\"" "${CONFIG_FILE}")
  COLLECT_TO=$(yq ".modules[$i].artifact.collect_to" "${CONFIG_FILE}")

  MODULE_DIR="${WORKSPACE_DIR}/${NAME}"
  SOURCE_PATH="${MODULE_DIR}/${WORK_DIR}/${OUTPUT_PATH}"
  TARGET_DIR="${OUTPUT_DIR}/${COLLECT_TO}"

  echo "------------------------------------------------------------"
  echo "[INFO] Collect module : ${NAME}"
  echo "[INFO] Source         : ${SOURCE_PATH}"
  echo "[INFO] Target         : ${TARGET_DIR}"
  echo "------------------------------------------------------------"

  if [[ ! -e "${SOURCE_PATH}" ]]; then
    echo "[ERROR] Output path not found for module ${NAME}: ${SOURCE_PATH}"
    exit 1
  fi

  mkdir -p "${TARGET_DIR}"

  cp -r "${SOURCE_PATH}" "${TARGET_DIR}/"
done

PACKAGE_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}"

if [[ -f "${PACKAGE_PATH}" ]]; then
  rm -f "${PACKAGE_PATH}"
fi

echo "[INFO] Release content (full tree):"
if command -v tree >/dev/null 2>&1; then
  tree "${OUTPUT_DIR}"
else
  find "${OUTPUT_DIR}" | sed "s|^|  |"
fi

TMP_ZIP="${OUTPUT_DIR}/${PACKAGE_NAME}"

(
  cd "${OUTPUT_DIR}"
  echo "[INFO] Creating zip package: ${PACKAGE_NAME}"
  zip -r "${PACKAGE_NAME}" . \
    -x "*.git*" \
    -x "__MACOSX*" \
    -x "*.DS_Store" \
    -x "${PACKAGE_NAME}"
)

if [[ ! -f "${TMP_ZIP}" ]]; then
  echo "[ERROR] Package was not created"
  exit 1
fi

echo "============================================================"
echo "[INFO] Package created successfully"
echo "[INFO] Output file : ${TMP_ZIP}"
echo "[INFO] Size        : $(du -h "${TMP_ZIP}" | cut -f1)"
echo "============================================================"

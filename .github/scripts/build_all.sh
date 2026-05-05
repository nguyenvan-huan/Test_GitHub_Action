#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# build_all.sh
# ------------------------------------------------------------
# Orchestrate module builds based on module-config.yaml
# ============================================================

# -------------------------
# Arguments
# -------------------------
CONFIG_FILE=""
WORKSPACE_DIR=""
OUTPUT_DIR=""

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
    --output)
      OUTPUT_DIR="$2"
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
  echo "  build_all.sh --config <module-config.yaml> --workspace <workspace_dir> --output <output_dir>"
  exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "[ERROR] Config file not found: ${CONFIG_FILE}"
  exit 1
fi

command -v yq >/dev/null 2>&1 || {
  echo "[ERROR] yq is required but not installed"
  exit 1
}

mkdir -p "${WORKSPACE_DIR}"
mkdir -p "${OUTPUT_DIR}"

echo "============================================================"
echo "[INFO] Module config : ${CONFIG_FILE}"
echo "[INFO] Workspace     : ${WORKSPACE_DIR}"
echo "[INFO] Output dir    : ${OUTPUT_DIR}"
echo "============================================================"

# -------------------------
# Read global config
# -------------------------
DEFAULT_REF=$(yq '.global.default_ref // "main"' "${CONFIG_FILE}")

# -------------------------
# Iterate modules
# -------------------------
MODULE_COUNT=$(yq '.modules | length' "${CONFIG_FILE}")

for ((i=0; i<MODULE_COUNT; i++)); do
  NAME=$(yq ".modules[$i].name" "${CONFIG_FILE}")
  ENABLED=$(yq ".modules[$i].enabled" "${CONFIG_FILE}")

  if [[ "${ENABLED}" != "true" ]]; then
    echo "[INFO] Skip disabled module: ${NAME}"
    continue
  fi

  REPO=$(yq ".modules[$i].repo" "${CONFIG_FILE}")
  REF=$(yq ".modules[$i].ref // \"${DEFAULT_REF}\"" "${CONFIG_FILE}")

  BUILD_TYPE=$(yq ".modules[$i].build.type" "${CONFIG_FILE}")
  WORK_DIR=$(yq ".modules[$i].build.working_directory // \".\"" "${CONFIG_FILE}")
  INSTALL_SCRIPT=$(yq ".modules[$i].build.install_script // \"\"" "${CONFIG_FILE}")
  BUILD_SCRIPT=$(yq ".modules[$i].build.build_script // \"\"" "${CONFIG_FILE}")
  OUTPUT_PATH=$(yq ".modules[$i].build.output_path // \"\"" "${CONFIG_FILE}")

  COLLECT_TO=$(yq ".modules[$i].artifact.collect_to" "${CONFIG_FILE}")

  MODULE_DIR="${WORKSPACE_DIR}/${NAME}"
  COLLECT_DIR="${OUTPUT_DIR}/${COLLECT_TO}"

  echo "------------------------------------------------------------"
  echo "[INFO] Module      : ${NAME}"
  echo "[INFO] Repo        : ${REPO}"
  echo "[INFO] Ref         : ${REF}"
  echo "[INFO] Build type  : ${BUILD_TYPE}"
  echo "------------------------------------------------------------"

  # -------------------------
  # Checkout module repo
  # -------------------------
  rm -rf "${MODULE_DIR}"
  git clone --branch "${REF}" "https://github.com/${REPO}.git" "${MODULE_DIR}"

  cd "${MODULE_DIR}/${WORK_DIR}"

  # -------------------------
  # Install step (optional)
  # -------------------------
  if [[ -n "${INSTALL_SCRIPT}" && -f "${INSTALL_SCRIPT}" ]]; then
    echo "[INFO] Run install script: ${INSTALL_SCRIPT}"
    bash "${INSTALL_SCRIPT}"
  fi

  # -------------------------
  # Build / Copy logic
  # -------------------------
  case "${BUILD_TYPE}" in
    copy_source)
      echo "[INFO] Build type: copy_source"
      ;;
    build_binary)
      echo "[INFO] Build type: build_binary"
      if [[ -z "${BUILD_SCRIPT}" || ! -f "${BUILD_SCRIPT}" ]]; then
        echo "[ERROR] build_script not found for module ${NAME}"
        exit 1
      fi
      bash "${BUILD_SCRIPT}"
      ;;
    download_artifact)
      echo "[INFO] Build type: download_artifact"
      echo "[INFO] Artifact download must be handled inside build_script"
      if [[ -n "${BUILD_SCRIPT}" && -f "${BUILD_SCRIPT}" ]]; then
        bash "${BUILD_SCRIPT}"
      fi
      ;;
    *)
      echo "[ERROR] Unsupported build type: ${BUILD_TYPE}"
      exit 1
      ;;
  esac

  # -------------------------
  # Collect output
  # -------------------------
  if [[ -n "${OUTPUT_PATH}" ]]; then
    mkdir -p "${COLLECT_DIR}"
    echo "[INFO] Collect output: ${OUTPUT_PATH} -> ${COLLECT_DIR}"
    cp -r "${OUTPUT_PATH}" "${COLLECT_DIR}/"
  else
    echo "[WARN] No output_path defined for module ${NAME}"
  fi

  echo "[INFO] Module ${NAME} completed"

  cd ../../
done

echo "============================================================"
echo "[INFO] All modules built successfully"
echo "============================================================"

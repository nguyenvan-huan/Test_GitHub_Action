#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
CONFIG_FILE=""
WORKSPACE_DIR=""

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

if [[ -z "${CONFIG_FILE}" || -z "${WORKSPACE_DIR}" ]]; then
  echo "[ERROR] Usage:"
  echo "  build_all.sh --config <module-config.yaml> --workspace <workspace_dir>"
  exit 1
fi

CONFIG_FILE="$(realpath "${CONFIG_FILE}")"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "[ERROR] Config file not found: ${CONFIG_FILE}"
  exit 1
fi

command -v yq >/dev/null 2>&1 || {
  echo "[ERROR] yq is required but not installed"
  exit 1
}

mkdir -p "${WORKSPACE_DIR}"

echo "============================================================"
echo "[INFO] Module config : ${CONFIG_FILE}"
echo "[INFO] Workspace     : ${WORKSPACE_DIR}"
echo "============================================================"

DEFAULT_REF=$(yq '.global.default_ref // "main"' "${CONFIG_FILE}")
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

  MODULE_DIR="${WORKSPACE_DIR}/${NAME}"

  echo "------------------------------------------------------------"
  echo "[INFO] Module      : ${NAME}"
  echo "[INFO] Repo        : ${REPO}"
  echo "[INFO] Ref         : ${REF}"
  echo "[INFO] Build type  : ${BUILD_TYPE}"
  echo "------------------------------------------------------------"

  rm -rf "${MODULE_DIR}"
  git clone --branch "${REF}" "https://github.com/${REPO}.git" "${MODULE_DIR}"

  cd "${MODULE_DIR}/${WORK_DIR}"

  if [[ -n "${INSTALL_SCRIPT}" && -f "${INSTALL_SCRIPT}" ]]; then
    echo "[INFO] Run install script: ${INSTALL_SCRIPT}"
    bash "${INSTALL_SCRIPT}"
  fi

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
      if [[ -z "${BUILD_SCRIPT}" || ! -f "${BUILD_SCRIPT}" ]]; then
        echo "[ERROR] download script not found for module ${NAME}"
        exit 1
      fi
      bash "${BUILD_SCRIPT}"
      ;;
    *)
      echo "[ERROR] Unsupported build type: ${BUILD_TYPE}"
      exit 1
      ;;
  esac

  echo "[INFO] Module ${NAME} completed"
  cd "${ROOT_DIR}"
done

echo "============================================================"
echo "[INFO] All modules built successfully"
echo "============================================================"

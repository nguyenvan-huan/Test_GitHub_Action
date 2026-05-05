#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# package.sh
# ------------------------------------------------------------
# Package release-output into final release ZIP
# ============================================================

INPUT_DIR=""
OUTPUT_DIR=""
PACKAGE_NAME="PARETTE_System.zip"

# -------------------------
# Parse arguments
# -------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-dir)
      INPUT_DIR="$2"
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
if [[ -z "${INPUT_DIR}" || -z "${OUTPUT_DIR}" ]]; then
  echo "[ERROR] Usage:"
  echo "  package.sh --input-dir <dir> --output-dir <dir> [--package-name name.zip]"
  exit 1
fi

if [[ ! -d "${INPUT_DIR}" ]]; then
  echo "[ERROR] Input directory not found: ${INPUT_DIR}"
  exit 1
fi

# Ensure output dir exists
mkdir -p "${OUTPUT_DIR}"

PACKAGE_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}"

echo "============================================================"
echo "[INFO] Packaging release"
echo "[INFO] Input directory : ${INPUT_DIR}"
echo "[INFO] Output file     : ${PACKAGE_PATH}"
echo "============================================================"

# -------------------------
# Sanity check: input not empty
# -------------------------
if [[ -z "$(ls -A "${INPUT_DIR}")" ]]; then
  echo "[ERROR] Input directory is empty: ${INPUT_DIR}"
  exit 1
fi

# -------------------------
# Optional: print tree for debug
# -------------------------
echo "[INFO] Release content:"
find "${INPUT_DIR}" -maxdepth 2 -type d | sed "s|^|  |"

# -------------------------
# Remove old package if exists
# -------------------------
if [[ -f "${PACKAGE_PATH}" ]]; then
  echo "[INFO] Remove existing package: ${PACKAGE_PATH}"
  rm -f "${PACKAGE_PATH}"
fi

# -------------------------
# Create zip
# -------------------------
(
  cd "${INPUT_DIR}"
  echo "[INFO] Creating zip package..."
  zip -r "${PACKAGE_PATH}" . \
    -x "*.git*" \
    -x "__MACOSX*" \
    -x "*.DS_Store"
)

# -------------------------
# Verify output
# -------------------------
if [[ ! -f "${PACKAGE_PATH}" ]]; then
  echo "[ERROR] Package was not created"
  exit 1
fi

echo "============================================================"
echo "[INFO] Package created successfully"
echo "[INFO] Size: $(du -h "${PACKAGE_PATH}" | cut -f1)"
echo "============================================================"

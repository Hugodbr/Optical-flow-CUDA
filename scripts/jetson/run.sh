#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

BINARY="./build/optical_flow"
INPUT_DIR="video_input"

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: binary not found. Run scripts/jetson/build.sh first."
    exit 1
fi

if [ ! -d "${INPUT_DIR}" ]; then
    echo "ERROR: input folder '${INPUT_DIR}/' not found."
    echo "  Create it and place your videos inside: mkdir ${INPUT_DIR}"
    exit 1
fi

# ── Get current Jetson power mode ─────────────────────────────────────────────
POWER_MODE_LABEL="unknown"
POWER_MODE_NUM="0"
if command -v nvpmodel &>/dev/null; then
    NVP_OUT=$(sudo nvpmodel -q 2>/dev/null || true)
    MODE_NAME=$(echo "${NVP_OUT}" | grep "NV Power Mode" | sed 's/NV Power Mode: //' | tr -d '[:space:]')
    MODE_NUM=$(echo "${NVP_OUT}"  | tail -1 | tr -d '[:space:]')
    if [ -n "${MODE_NAME}" ]; then
        POWER_MODE_LABEL="${MODE_NAME} (mode ${MODE_NUM})"
        POWER_MODE_NUM="${MODE_NUM}"
    fi
fi

OUTPUT_DIR="video_output_${POWER_MODE_NUM}"
LOG_FILE="optical_flow_mode${POWER_MODE_NUM}.log"

mkdir -p "${OUTPUT_DIR}"

# ── Collect input videos ──────────────────────────────────────────────────────
shopt -s nullglob
VIDEO_FILES=("${INPUT_DIR}"/*.mp4 "${INPUT_DIR}"/*.avi \
             "${INPUT_DIR}"/*.mov "${INPUT_DIR}"/*.mkv)

if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
    echo "ERROR: No video files found in ${INPUT_DIR}/"
    exit 1
fi

echo ""
echo "=== Batch Lucas-Kanade optical flow (CUDA) ==="
echo "  Input folder:  ${INPUT_DIR}/"
echo "  Output folder: ${OUTPUT_DIR}/"
echo "  Log file:      ${LOG_FILE}"
echo "  Power mode:    ${POWER_MODE_LABEL}"
echo "  Videos found:  ${#VIDEO_FILES[@]}"
echo ""

# ── Process each video ────────────────────────────────────────────────────────
for INPUT_FILE in "${VIDEO_FILES[@]}"; do
    FILENAME=$(basename "${INPUT_FILE}")
    STEM="${FILENAME%.*}"

    # Replace first occurrence of "input" with "output" in the stem.
    # If the stem has no "input", prepend "output_".
    if [[ "${STEM}" == *input* ]]; then
        OUTPUT_STEM="${STEM/input/output}"
    else
        OUTPUT_STEM="output_${STEM}"
    fi

    OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_STEM}.avi"

    echo "--- ${FILENAME}  →  ${OUTPUT_FILE}"

    ${BINARY} \
        --input      "${INPUT_FILE}"       \
        --output     "${OUTPUT_FILE}"      \
        --log        "${LOG_FILE}"         \
        --power-mode "${POWER_MODE_LABEL}"

    echo ""
done

echo "=== All done ==="
echo "  Results: ${OUTPUT_DIR}/"
echo "  Log:     ${LOG_FILE}"

#!/usr/bin/env bash
set -euo pipefail

# Demucs v4 variants: htdemucs (Balanced), htdemucs_ft (Fine-Tuned), htdemucs_6s (Six-Stem)
VARIANT="${1:-htdemucs}"

case "${VARIANT}" in
  htdemucs)
    SOURCE_PACKAGE="HTDemucs_CoreML_FP16.mlpackage"
    REPO_ID="dexxdean/htdemucs-coreml"
    LEGACY_PACKAGE="HTDemucs_CoreML.mlpackage"
    LEGACY_COMPILED="HTDemucs_CoreML.mlmodelc"
    ;;
  htdemucs_ft|htdemucs_6s)
    echo "CoreML package for ${VARIANT} is not published yet."
    echo "Only htdemucs (Balanced) can be installed today."
    echo "Fine-Tuned and Six-Stem will use ONNX or future CoreML builds."
    exit 1
    ;;
  *)
    echo "Unknown variant: ${VARIANT}"
    echo "Usage: $0 [htdemucs|htdemucs_ft|htdemucs_6s]"
    exit 1
    ;;
esac

MODELS_DIR="${HOME}/Library/Application Support/JustSing/Models"
PACKAGE="${MODELS_DIR}/${VARIANT}.mlpackage"
COMPILED="${MODELS_DIR}/${VARIANT}.mlmodelc"
LEGACY_PACKAGE_PATH="${MODELS_DIR}/${LEGACY_PACKAGE}"
LEGACY_COMPILED_PATH="${MODELS_DIR}/${LEGACY_COMPILED}"

if [[ -d "${COMPILED}" ]] || [[ -d "${LEGACY_COMPILED_PATH}" ]]; then
    echo "Balanced model already installed."
    exit 0
fi

mkdir -p "${MODELS_DIR}"

if [[ ! -d "${PACKAGE}" ]] && [[ ! -d "${LEGACY_PACKAGE_PATH}" ]]; then
    TMP_DIR="$(mktemp -d)"
    cleanup() { rm -rf "${TMP_DIR}"; }
    trap cleanup EXIT

    VENV="${TMP_DIR}/venv"
    python3 -m venv "${VENV}"
    # shellcheck disable=SC1091
    source "${VENV}/bin/activate"
    pip install -q huggingface_hub

    echo "Downloading ${SOURCE_PACKAGE} from ${REPO_ID} (~200 MB)..."
    export TMP_DIR MODELS_DIR PACKAGE REPO_ID SOURCE_PACKAGE VARIANT
    python <<'PY'
import os
import shutil
from huggingface_hub import snapshot_download

tmp_dir = os.environ["TMP_DIR"]
target = os.environ["PACKAGE"]
repo_id = os.environ["REPO_ID"]
source_package = os.environ["SOURCE_PACKAGE"]
variant = os.environ["VARIANT"]

snapshot_download(
    repo_id=repo_id,
    allow_patterns=[f"{source_package}/**"],
    local_dir=tmp_dir,
)

source = os.path.join(tmp_dir, source_package)
if not os.path.isdir(source):
    raise SystemExit(f"Download failed: missing {source}")

if os.path.exists(target):
    shutil.rmtree(target)

shutil.move(source, target)
print(f"Installed {variant} package to {target}")
PY
fi

SOURCE_PACKAGE_PATH="${PACKAGE}"
if [[ ! -d "${SOURCE_PACKAGE_PATH}" ]]; then
    SOURCE_PACKAGE_PATH="${LEGACY_PACKAGE_PATH}"
fi

if [[ ! -d "${COMPILED}" ]]; then
    echo "Compiling CoreML model (~20 s, one-time)..."
    swift - <<SWIFT
import CoreML
import Foundation

let variant = "${VARIANT}"
let modelsDir = ("~/Library/Application Support/JustSing/Models" as NSString).expandingTildeInPath
let packagePath = "${SOURCE_PACKAGE_PATH}"
let compiledPath = (modelsDir as NSString).appendingPathComponent("\(variant).mlmodelc")
let packageURL = URL(fileURLWithPath: packagePath)
let compiledURL = URL(fileURLWithPath: compiledPath)

let compiled = try MLModel.compileModel(at: packageURL)
if FileManager.default.fileExists(atPath: compiledURL.path) {
    try FileManager.default.removeItem(at: compiledURL)
}
try FileManager.default.moveItem(at: compiled, to: compiledURL)
print("Compiled model saved to \(compiledURL.path)")
SWIFT
fi

echo "Done. Select Neural → Balanced in JustSing settings."

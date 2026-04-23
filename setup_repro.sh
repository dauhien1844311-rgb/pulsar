#!/usr/bin/env bash
set -euo pipefail

# Minimal environment bootstrap for Pulsar reproduction.
# Goal: reach one-shot encode/decode attempt readiness (NOT full benchmark run).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-.venv-repro}"
REQUIREMENTS_FILE="${REQUIREMENTS_FILE:-requirements.txt}"
PIN_TORCH="${PIN_TORCH:-torch==2.2.2}"
HF_CACHE_DIR="${HF_CACHE_DIR:-$ROOT_DIR/.cache/huggingface}"
HF_HOME_DIR="${HF_HOME_DIR:-$ROOT_DIR/.cache/huggingface}"
TRANSFORMERS_CACHE_DIR="${TRANSFORMERS_CACHE_DIR:-$ROOT_DIR/.cache/huggingface/transformers}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "[ERROR] Python not found: $PYTHON_BIN"
  exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

python - <<'PY'
import platform
print(f"[INFO] Python: {platform.python_version()}")
print(f"[INFO] Platform: {platform.platform()}")
PY

mkdir -p "$HF_CACHE_DIR" "$TRANSFORMERS_CACHE_DIR"
export HF_HOME="$HF_HOME_DIR"
export HUGGINGFACE_HUB_CACHE="$HF_CACHE_DIR/hub"
export TRANSFORMERS_CACHE="$TRANSFORMERS_CACHE_DIR"

TMP_REQ="$(mktemp)"
trap 'rm -f "$TMP_REQ"' EXIT

# requirements.txt includes appnope (macOS-only). Filter on Linux.
if [ "$(uname -s)" = "Linux" ]; then
  grep -v '^appnope==' "$REQUIREMENTS_FILE" > "$TMP_REQ"
else
  cp "$REQUIREMENTS_FILE" "$TMP_REQ"
fi

echo "[INFO] Installing torch baseline: $PIN_TORCH"
pip install "$PIN_TORCH"

echo "[INFO] Installing repo dependencies from filtered requirements"
pip install -r "$TMP_REQ"

# Prefetch default model used by Pulsar (can be skipped if network restricted).
python - <<'PY'
import os
from diffusers import UNet2DModel
repo = "google/ddpm-church-256"
cache_dir = os.environ.get("HUGGINGFACE_HUB_CACHE")
print(f"[INFO] Prefetch model: {repo}")
print(f"[INFO] Cache: {cache_dir}")
UNet2DModel.from_pretrained(repo, cache_dir=cache_dir)
print("[INFO] Model prefetch complete")
PY

cat <<'TXT'
[INFO] Setup complete.
[INFO] Next: attempt one-shot minimal encode/decode (no full benchmark).
TXT

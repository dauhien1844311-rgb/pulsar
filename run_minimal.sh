#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

MODEL_REPO="${MODEL_REPO:-google/ddpm-church-256}"
TEST_MESSAGE="${TEST_MESSAGE:-hello_pulsar}"
ARTIFACT_BASE="${ARTIFACT_BASE:-artifacts/minimal}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$ARTIFACT_BASE/$TIMESTAMP"
LATEST_LINK="$ARTIFACT_BASE/latest"

mkdir -p "$RUN_DIR"
mkdir -p "$ARTIFACT_BASE"
ln -sfn "$TIMESTAMP" "$LATEST_LINK"

printf "%s" "$TEST_MESSAGE" > "$RUN_DIR/input_message.txt"

echo "[INFO] run_dir=$RUN_DIR" | tee "$RUN_DIR/key.log"
echo "[INFO] model_repo=$MODEL_REPO" | tee -a "$RUN_DIR/key.log"
echo "[INFO] message=$TEST_MESSAGE" | tee -a "$RUN_DIR/key.log"

python3 - <<'PY' "$RUN_DIR" "$MODEL_REPO" "$TEST_MESSAGE"
import json
import os
import sys
import traceback

from pulsar import Pulsar

run_dir, model_repo, test_message = sys.argv[1], sys.argv[2], sys.argv[3]
status = {
    "model_repo": model_repo,
    "input_message": test_message,
    "output_image": os.path.join(run_dir, "stego.png"),
    "decoded_message": None,
    "exact_match": False,
    "stage": "init",
}

try:
    status["stage"] = "encode"
    sender = Pulsar(repo=model_repo, benchmarks=True)

    payload = test_message.encode("utf-8")
    generate_results = sender.generate(to_hide=payload, use_ecc=False)

    last = sender.scheduler.num_inference_steps - 1
    hidden_sample = generate_results["samples"][last]["hidden"]
    all0_sample = generate_results["samples"][last]["all0"]
    all1_sample = generate_results["samples"][last]["all1"]

    status["stage"] = "image save"
    stego_path = status["output_image"]
    sender.save_sample(hidden_sample, stego_path)

    status["stage"] = "decode"
    hidden_from_image = sender.load_sample(stego_path)
    reveal_results = sender.reveal(
        hidden_sample=hidden_from_image,
        all0_sample=all0_sample,
        all1_sample=all1_sample,
        use_ecc=False,
        return_bitarray=True,
        return_meta=True,
    )

    recovered_bytes = reveal_results["ecc"]["decoded"]
    recovered_prefix = recovered_bytes[: len(payload)]
    decoded_message = recovered_prefix.decode("utf-8", errors="replace")

    status["decoded_message"] = decoded_message
    status["exact_match"] = recovered_prefix == payload
    status["stage"] = "done"

    with open(os.path.join(run_dir, "decoded_message.txt"), "w", encoding="utf-8") as f:
        f.write(decoded_message)
    with open(os.path.join(run_dir, "decoded_message.hex"), "w", encoding="utf-8") as f:
        f.write(recovered_prefix.hex())

    with open(os.path.join(run_dir, "benchmarks.json"), "w", encoding="utf-8") as f:
        json.dump(sender.benchmarks, f, indent=2, default=str)

except Exception:
    status["exact_match"] = False
    status["traceback"] = traceback.format_exc()
    with open(os.path.join(run_dir, "error_traceback.log"), "w", encoding="utf-8") as f:
        f.write(status["traceback"])

finally:
    with open(os.path.join(run_dir, "status.json"), "w", encoding="utf-8") as f:
        json.dump(status, f, indent=2, ensure_ascii=False)

print(json.dumps(status, indent=2, ensure_ascii=False))
if status.get("stage") != "done" or not status.get("exact_match"):
    sys.exit(1)
PY

exit_code=$?
if [ $exit_code -eq 0 ]; then
  echo "[INFO] minimal encode/decode loop succeeded" | tee -a "$RUN_DIR/key.log"
else
  echo "[ERROR] minimal encode/decode loop failed" | tee -a "$RUN_DIR/key.log"
fi

exit $exit_code

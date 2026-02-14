#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE_BIN="/tmp/inkarc-live-qa"

LOOPS_PER_BATCH="${INKARC_LIVE_STRESS_LOOPS_PER_BATCH:-80}"
MAX_BATCHES="${INKARC_LIVE_STRESS_MAX_BATCHES:-0}" # 0 means unbounded

cd "$ROOT_DIR"

swiftc -module-name InkArcUILiveQATemp \
  -o "$LIVE_BIN" \
  QA/InkArcUILiveQARunner.swift \
  Sources/PlainMarkdownEditor.swift \
  -framework SwiftUI \
  -framework AppKit

batch=1
while true; do
  echo "SOAK BATCH ${batch} (loops=${LOOPS_PER_BATCH})"
  INKARC_LIVE_STRESS_LOOPS="$LOOPS_PER_BATCH" "$LIVE_BIN"
  if [[ "$MAX_BATCHES" -gt 0 && "$batch" -ge "$MAX_BATCHES" ]]; then
    break
  fi
  batch=$((batch + 1))
done

echo "SOAK RESULT: PASS (batches=${batch}, loops_per_batch=${LOOPS_PER_BATCH})"

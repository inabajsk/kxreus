#!/usr/bin/env bash
# Copy each run's LAST checkpoint into policies/<robot>_<mode>.pt -- the
# default path play.py and standwalk_eval.py look for.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p policies

# Sourced from kxr_rl.robots.DEFAULT_ROBOTS rather than listed here, so this
# script never needs editing again when that tuple grows.
mapfile -t ROBOTS < <(uv run python -c \
  "from kxr_rl.robots import DEFAULT_ROBOTS; print('\n'.join(DEFAULT_ROBOTS))")
for robot in "${ROBOTS[@]}"; do
  for mode in walk getup; do
    # Newest run directory for this task, whatever it was named.
    run_dir=$(ls -dt "logs/rsl_rl/${robot}_${mode}/"*/ 2>/dev/null | head -1 || true)
    if [ -z "${run_dir}" ]; then
      echo "SKIP ${robot} ${mode}: no run directory found"
      continue
    fi
    ckpt=$(ls -t "${run_dir}"/model_*.pt 2>/dev/null | head -1 || true)
    if [ -z "${ckpt}" ]; then
      echo "SKIP ${robot} ${mode}: no checkpoint in ${run_dir}"
      continue
    fi
    cp "${ckpt}" "policies/${robot}_${mode}.pt"
    echo "${robot} ${mode}: ${ckpt} -> policies/${robot}_${mode}.pt"
  done
done

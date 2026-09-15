#!/usr/bin/env bash
# Copy each run's LAST checkpoint into policies/<robot>_<mode>.pt -- the
# default path play.py and standwalk_eval.py look for.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p policies

ROBOTS=(kxrl4d kxrl4t kxrl2g kxrl6)
for robot in "${ROBOTS[@]}"; do
  for mode in walk getup; do
    run_dir=$(ls -dt "logs/rsl_rl/${robot}_${mode}/"*"${robot}-${mode}"* 2>/dev/null | head -1 || true)
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

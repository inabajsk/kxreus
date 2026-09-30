#!/usr/bin/env bash
# Train Walk then Getup for every robot in kxr_rl.robots.DEFAULT_ROBOTS,
# sequentially (one GPU, avoid contention), logging each run separately.
set -uo pipefail
cd "$(dirname "$0")/.."

ROBOTS=(kxrl4d kxrl4t kxrl2g kxrl6)
mkdir -p logs/train_all

for robot in "${ROBOTS[@]}"; do
  for mode in walk getup; do
    # What the shipped policies were trained with (see README section 3).
    iters=$([ "$mode" = "walk" ] && echo 1500 || echo 2000)
    log="logs/train_all/${robot}_${mode}.log"
    echo "=== $(date '+%H:%M:%S') training ${robot} ${mode} (${iters} iter) -> ${log} ==="
    uv run train.py "$robot" "$mode" --num-envs 4096 --iterations "$iters" \
      --run-name "${robot}-${mode}" > "$log" 2>&1
    status=$?
    echo "=== $(date '+%H:%M:%S') ${robot} ${mode} exit=${status} ==="
    tail -n 25 "$log"
  done
done
echo "=== all training runs finished ==="

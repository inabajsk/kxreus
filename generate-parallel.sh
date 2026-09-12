#!/bin/bash
#
# generate-parallel.sh -- generate robot models/<name>.l files in
# parallel, one OS process per robot. Each robot's construction is
# independent (writes only its own models/<name>.l), and the shared
# glbodies/ part/mesh/STL caches are written atomically, so this is
# safe to run with several processes at once.
#
# The parallelism level is NOT just nproc: this also has to run on
# resource-constrained machines (e.g. a Raspberry Pi 4 with 1-8GB of
# RAM), where launching one process per core could exhaust memory and
# make things slower (swapping) rather than faster. So the number of
# jobs is capped by both core count and available memory / a
# per-process budget.
#
# Usage:
#   ./generate-parallel.sh            # the ~36 "sample" robots (kxr-sample-robots's list)
#   ./generate-parallel.sh all        # all robots in rcb4robotconfig.l (several hundred)
#   ./generate-parallel.sh kxrl6 kxrl4t kxrl2makabelcw   # specific robot names
#
# Env overrides:
#   PER_PROC_MB=400   memory budget assumed per worker process (default 400)
#   JOBS=N            force the parallelism level instead of auto-sizing

set -eu
cd "$(dirname "$0")"

PER_PROC_MB=${PER_PROC_MB:-400}

CORES=$(nproc 2>/dev/null || echo 1)

if [ -n "${JOBS:-}" ]; then
  jobs=$JOBS
else
  if command -v free >/dev/null 2>&1; then
    avail_mb=$(free -m | awk '/^Mem:/{print $7}')
  else
    # no `free` available (e.g. some minimal images) -- assume there's
    # enough memory for one job per core rather than block progress.
    avail_mb=$((CORES * PER_PROC_MB))
  fi
  mem_jobs=$((avail_mb / PER_PROC_MB))
  [ "$mem_jobs" -lt 1 ] && mem_jobs=1
  jobs=$CORES
  [ "$mem_jobs" -lt "$jobs" ] && jobs=$mem_jobs
  [ "$jobs" -lt 1 ] && jobs=1
fi

echo ";; generate-parallel.sh: cores=$CORES avail_mem=${avail_mb:-n/a}MB per_proc_budget=${PER_PROC_MB}MB -> jobs=$jobs" >&2

mode=${1:-sample}
# irteusgl prints a startup banner (".eusrc executed!!", the
# "; (objects-kxr-robots)" usage hints, etc.) to stdout before our
# actual name list -- every one of those lines starts with ";", which
# no robot name ever does, so filter them out rather than accidentally
# treating banner text as a robot name to build.
case "$mode" in
  sample)
    names=$(KXR_LIST_NAMES=sample irteusgl kxr-generate-one.l 2>/dev/null | grep -v '^;')
    ;;
  all)
    names=$(KXR_LIST_NAMES=all irteusgl kxr-generate-one.l 2>/dev/null | grep -v '^;')
    ;;
  *)
    names=$(printf '%s\n' "$@")
    ;;
esac

n=$(echo "$names" | grep -c .)
echo ";; generating $n robot(s) with $jobs parallel worker(s)" >&2

echo "$names" | xargs -P "$jobs" -I{} env ROBOT_NAME={} irteusgl kxr-generate-one.l

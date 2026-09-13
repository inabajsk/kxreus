#!/bin/bash
#
# kxr-generate-one-safe.sh <robot-name> <timeout-seconds>
#
# Runs kxr-generate-one.l for exactly one robot, tolerating any
# failure (a crash from missing STL assets, a genuine hang killed by
# the timeout, any other error) by always exiting 0. This matters
# because xargs treats some child exit statuses specially (e.g. a
# child killed by a signal, or exiting 255) and can abort the *whole*
# remaining batch rather than just skipping that one item -- one
# broken robot config (there are a few in rcb4robotconfig.l that
# reference STL files not present in this checkout) must not stop
# generation of the other several hundred.
#
set -u
name="$1"
timeout_sec="$2"

ROBOT_NAME="$name" timeout "$timeout_sec" irteusgl kxr-generate-one.l
rc=$?
if [ "$rc" -ne 0 ]; then
  echo ";; GENERATE_FAILED $name (exit $rc)" >&2
fi
exit 0

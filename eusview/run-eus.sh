#!/bin/bash
# Run an EusLisp script with jskeus without the GUI (macOS).
#   usage: eusview/run-eus.sh script.l [args...]   (stdout/stderr -> console)
# - Default: ~/jskeus (inabajsk/jskeus built here; has irteus/irtstl.l = stl2eus, and
#   libirteusimg links the Homebrew libjpeg.10) -> runs bin/irteusgl as is.
#   EUSVIEW_JSKEUS=homebrew uses the old Homebrew jskeus 1.2.1 instead: the real binary
#   libexec/eusgl through the symlink eusview/bin/eusgl (irtext.l excludes that name, so the
#   irt libraries are loaded by eusview/irtload.l; libirteusimg would fail on libjpeg.9).
#   The scripts always (load "eusview/irtload.l"), which does nothing under irteusgl.
#   JSKEUS_DIR overrides ~/jskeus.
# - eus startup crashes randomly (Bus error / SIGSEGV) -> retry until the script
#   prints the marker line ";;EUSVIEW-DONE".
# - Each try is killed after $EUS_TIMEOUT seconds (default 300).
D="$(cd "$(dirname "$0")" && pwd)"
export EUSVIEW_DIR="$D"   # the scripts load eusview/*.l and write eusview/robots, eusview/cache from here
if [ "${EUSVIEW_JSKEUS:-}" = homebrew ]; then
  export EUSDIR=/usr/local/opt/jskeus/eus ARCHDIR=Darwin
  EUSBIN="$D/bin/eusgl"
else
  J=${JSKEUS_DIR:-$HOME/jskeus}
  export EUSDIR=$J/eus ARCHDIR=Darwin
  export PATH=$EUSDIR/$ARCHDIR/bin:$PATH
  EUSBIN="$EUSDIR/$ARCHDIR/bin/irteusgl"
fi
export LD_LIBRARY_PATH=$EUSDIR/$ARCHDIR/bin
T=${EUS_TIMEOUT:-300}
OUT=$(mktemp -t eusview)
for i in 1 2 3 4 5 6 7 8 9 10; do
  ( timeout $T "$EUSBIN" "$@" </dev/null >"$OUT" 2>&1 ) 2>/dev/null
  if grep -q ";;EUSVIEW-DONE" "$OUT"; then cat "$OUT"; rm -f "$OUT"; exit 0; fi
  if [ -s "$OUT" ] && grep -q "ERROR" "$OUT"; then cat "$OUT" | cut -c1-400 | head -60; rm -f "$OUT"; exit 1; fi
done
echo "run-eus.sh: failed after $i tries"; head -c 3000 "$OUT"; rm -f "$OUT"; exit 1

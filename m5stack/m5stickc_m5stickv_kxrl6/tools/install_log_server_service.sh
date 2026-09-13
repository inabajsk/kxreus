#!/bin/bash
# Installs log_server.py as a systemd service, so it keeps receiving phones'
# field-log uploads without a terminal open, and comes back on its own after
# a crash or a reboot -- see README_log_server.md. Same install.sh + sed
# pattern as radxa/daemon/install.sh, generating the real unit file from
# kxr-log-server.service's template.
#
# Needs sudo to write /etc/systemd/system/ (systemd unit files always do),
# but the SERVICE ITSELF is installed to run as the user who called sudo,
# not root: this is a plain HTTP server on an ordinary port, with none of
# atoms3-bridge.service's need for /dev/ttyACM0 or nmcli access.
#
# Usage: sudo ./install_log_server_service.sh
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "error: run with sudo (sudo ./install_log_server_service.sh)" >&2
  exit 1
fi

# SUDO_USER is who ran sudo; plain `logname` is the fallback for a root
# login shell with no sudo in the chain.
RUN_AS="${SUDO_USER:-$(logname)}"
RUN_HOME="$(getent passwd "$RUN_AS" | cut -d: -f6)"
if [ -z "$RUN_HOME" ]; then
  echo "error: could not resolve a home directory for user '$RUN_AS'" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$RUN_HOME/kxreus/atom_phone/field_logs"
UNIT_SRC="$DIR/kxr-log-server.service"
UNIT_DST="/etc/systemd/system/kxr-log-server.service"

echo "[install] generating $UNIT_DST (user=$RUN_AS, dir=$DIR, logs=$LOG_DIR)"
sed -e "s#__USER__#$RUN_AS#g" -e "s#__DIR__#$DIR#g" -e "s#__LOGDIR__#$LOG_DIR#g" \
  "$UNIT_SRC" > "$UNIT_DST"

mkdir -p "$LOG_DIR"
chown "$RUN_AS" "$LOG_DIR"

systemctl daemon-reload
systemctl enable --now kxr-log-server

echo "[install] done. logs: sudo journalctl -u kxr-log-server -f"
echo "[install] field logs written under: $LOG_DIR"

# log_server.py — running it as a systemd service

`log_server.py` receives the telemetry batches phones buffer from kWebPage
(see that file's own `FieldLog` module) and files them under
`~/kxreus/atom_phone/field_logs/<robot>/<date>/<session>.jsonl`. Running it by
hand (`python3 log_server.py`) works fine for a one-off test, but it stops
the moment that terminal closes. This installs it as a systemd service
instead, so it keeps running in the background, survives a reboot, and
restarts on its own if it ever crashes.

## Install

From this directory, on the PC that will run the server (the one whichever
robot's phone should be able to reach):

```
sudo ./install_log_server_service.sh
```

This generates `/etc/systemd/system/kxr-log-server.service` from
`kxr-log-server.service`'s own template (substituting the real path and the
user who ran `sudo`), then runs `systemctl daemon-reload` and
`systemctl enable --now kxr-log-server`. sudo is needed to write a systemd
unit file, but the **service itself** runs as your own user, not root --
this is a plain HTTP server on an ordinary port (8787 by default), with no
device access to justify anything more.

## Checking it

```
systemctl status kxr-log-server
sudo journalctl -u kxr-log-server -f      # live log; Ctrl-C to stop watching
curl http://localhost:8787/health         # {"ok":true}
```

## Telling a robot's phone about it

On the phone's control page (kWebPage), the "log server host:port" field
under the log status line wants this PC's LAN address and the port above,
e.g. `192.168.1.23:8787`. Find this PC's address with `ip addr` or
`hostname -I`. The phone and the robot both need to be on the same network
as this PC for the upload to reach it (see that page's own Wi-Fi setup flow
if the robot is still on its own access point).

## Changing the port or where logs are written

Edit `ExecStart=` in `/etc/systemd/system/kxr-log-server.service` directly
(its `--port`/`--dir` flags -- see `log_server.py --help`), then:

```
sudo systemctl daemon-reload
sudo systemctl restart kxr-log-server
```

Re-running `install_log_server_service.sh` regenerates the unit from the
template instead, which is only useful if you also edited the template
(`kxr-log-server.service` in this directory) -- for a one-off change,
editing the installed unit directly, above, is simpler.

## Stopping it

```
sudo systemctl stop kxr-log-server       # stop it now, but it comes back on reboot
sudo systemctl disable --now kxr-log-server   # stop it now AND keep it off on reboot
```

`enable`/`disable` alone (without `--now`) only changes whether it starts
**at the next boot** -- they do not touch whatever is running right now.
`--now` also stops (or starts) the currently running instance immediately,
which is almost always what you actually want.

## Manual run (no systemd, for a quick one-off test)

```
python3 log_server.py                       # listens on 0.0.0.0:8787
python3 log_server.py --port 8787 --dir ~/kxreus/atom_phone/field_logs
```

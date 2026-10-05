# M5Camera Wi-Fi viewer aliases.   source ~/kxreus/m5stack/m5camera/alias.bash
# Extra options can be appended to any of them, e.g.  m5cam --rotate 90 --host 192.168.1.61

M5CAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M5CAM_PY="$M5CAM_DIR/.venv/bin/python $M5CAM_DIR/m5camera_viewer.py"

# viewer
alias m5cam="$M5CAM_PY"                                           # all 8 processors
alias m5cam-kxr="$M5CAM_PY --rotate 90"                           # mounted upright on a KXR head
alias m5cam-tag="$M5CAM_PY --proc apriltag,yolo"                  # light: AprilTag + YOLO
alias m5cam-floor="$M5CAM_PY --proc depth,floor"                  # depth + floor plane + path
alias m5cam-mp="$M5CAM_PY --proc mediapipe,yolo --cols 2"         # skeleton / face / gaze
alias m5cam-rec="$M5CAM_PY --record $M5CAM_DIR/rec --duration 60" # record 60 s to rec/
alias m5cam-help="$M5CAM_PY --help"

# camera setup (USB serial)
alias m5cam-wifi="$M5CAM_DIR/provision_wifi.py /dev/ttyUSB1"      # m5cam-wifi JSK300 '<password>'
alias m5cam-flash="(cd $M5CAM_DIR/firmware && pio run -t upload --upload-port /dev/ttyUSB1)"
alias m5cam-serial="pio device monitor -p /dev/ttyUSB1 -b 115200" # type "info" to see the IP

alias m5cam-cd="cd $M5CAM_DIR"

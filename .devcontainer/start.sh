#!/usr/bin/env bash
set -euo pipefail

# Resolution can be overridden via the VNC_RESOLUTION env var.
RESOLUTION="${VNC_RESOLUTION:-1920x1080x24}"
export DISPLAY=:1

start_gui() {
  # Clean up stale X lock/socket from a previous run
  rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

  Xvfb :1 -screen 0 "$RESOLUTION" &

  # Wait for the X server to accept connections instead of a fixed sleep
  for _ in $(seq 1 50); do
    if xdpyinfo -display :1 >/dev/null 2>&1; then break; fi
    sleep 0.2
  done

  # Lightweight window manager so a launched GUI app gets decorations/focus
  # (no full desktop environment).
  openbox &

  # -localhost keeps the raw VNC protocol reachable only by the noVNC proxy on
  # this container; browser access goes through port 6080 (forwarded by VS Code).
  x11vnc -display :1 -localhost -forever -shared -bg -rfbport 5900 -nopw

  cd /opt/novnc
  nohup ./utils/novnc_proxy --vnc localhost:5900 --listen 6080 --web /opt/novnc \
    >/tmp/novnc.log 2>&1 &
}

# Best-effort: the GUI stack must never take the container down with it, so its
# failure is caught and logged rather than propagated (set -e is suppressed for
# this compound command).
start_gui || echo "start.sh: GUI stack failed to start, continuing without it" >&2

# Keep the container alive independently of the GUI: run the command passed by
# the orchestrator (docker-compose `command:`), or idle if none was given.
if [ "$#" -gt 0 ]; then
  exec "$@"
fi
exec sleep infinity

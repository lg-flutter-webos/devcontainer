#!/usr/bin/env bash
set -euo pipefail

# Resolution can be overridden via the VNC_RESOLUTION env var.
RESOLUTION="${VNC_RESOLUTION:-1920x1080x24}"
export DISPLAY=:1

start_gui() {
  # 1. Ensure /tmp/.X11-unix exists with proper permissions (1777) for non-root users
  if [ ! -d /tmp/.X11-unix ]; then
    sudo mkdir -p /tmp/.X11-unix 2>/dev/null || mkdir -p /tmp/.X11-unix
    sudo chmod 1777 /tmp/.X11-unix 2>/dev/null || true
  fi

  # Clean up stale X lock/socket from a previous run
  rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

  # 2. Start Xvfb in background
  Xvfb :1 -screen 0 "$RESOLUTION" &

  # Wait for the X server to accept connections instead of a fixed sleep
  for _ in $(seq 1 50); do
    if xdpyinfo -display :1 >/dev/null 2>&1; then break; fi
    sleep 0.2
  done

  # 3. Lightweight window manager in background
  if command -v openbox >/dev/null 2>&1; then
    openbox &
  elif command -v fluxbox >/dev/null 2>&1; then
    fluxbox &
  fi

  # 4. Start x11vnc with explicit -quiet flag to reduce stderr spam
  x11vnc -display :1 -localhost -forever -shared -bg -rfbport 5900 -nopw -quiet

  # 5. Start noVNC proxy completely detached in background
  cd /opt/novnc
  nohup ./utils/novnc_proxy --vnc localhost:5900 --listen 6080 --web /opt/novnc \
    >/tmp/novnc.log 2>&1 &
}

# Best-effort: the GUI stack must never take the container down with it
start_gui || echo "start.sh: GUI stack failed to start, continuing without it" >&2

# Keep the container alive independently of the GUI: run the command passed by
# the orchestrator (docker-compose `command:`), or idle if none was given.
if [ "$#" -gt 0 ]; then
  exec "$@"
fi
exec sleep infinity

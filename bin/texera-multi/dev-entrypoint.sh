#!/usr/bin/env bash
# PID 1 of a Texera dev box. Starts the inner Docker daemon (this container is
# run --privileged so dockerd has the caps it needs), waits until it answers,
# then idles so `texera` can exec commands into a live box.
#
# /var/lib/docker is a named volume (see texera box_up), so the inner
# daemon's images/volumes (postgres data, minio, etc.) persist across box
# restarts. `texera fresh` wipes them explicitly; a plain restart keeps
# them.
set -euo pipefail

echo "[dev-box] starting inner dockerd..."
# Clear stale pidfiles from a previous life of THIS container. A box runs with
# --restart unless-stopped, and a restart (host reboot / outer-daemon restart)
# preserves the container's /var/run, so last run's /var/run/docker.pid (and
# containerd's) survive. dockerd refuses to start if that recorded PID happens
# to be occupied by any live process on the new boot ("process with PID N is
# still running"), a race that hits some boxes and not others: that is why the
# first box comes up but follow-on boxes intermittently report the inner daemon
# unavailable. No dockerd runs yet at entrypoint time (we are PID 1), so
# removing the pidfiles is always safe.
rm -f /var/run/docker.pid /var/run/docker/containerd/containerd.pid 2>/dev/null || true
# overlay2 works because /var/lib/docker is a real volume, not the overlay
# rootfs. Log to a file so `texera box logs`/docker logs stay readable.
dockerd >/var/log/dockerd.log 2>&1 &

echo "[dev-box] waiting for inner docker to be ready..."
for i in $(seq 1 60); do
  if docker info >/dev/null 2>&1; then
    echo "[dev-box] inner docker ready."
    break
  fi
  [[ "$i" == 60 ]] && { echo "[dev-box] ERROR: inner dockerd did not come up; see /var/log/dockerd.log" >&2; tail -n 40 /var/log/dockerd.log >&2 || true; }
  sleep 1
done

# If given a command, run it; otherwise idle as a long-lived box.
if [[ $# -gt 0 ]]; then
  exec "$@"
fi
echo "[dev-box] ready. exec into me with: texera <target>  (or: box shell)"
exec sleep infinity

#!/bin/sh
PIDFILE="/tmp/reverse_ssh.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT
VPS_USER="root"
VPS_HOST="195.54.33.31"
VPS_PORT="10022"
KEY="/oemapp/etc/ssh_rsa"
REMOTE_BIND_ADDR="0.0.0.0"
REMOTE_PORT="2222"
LOCAL_TARGET="localhost"
LOCAL_PORT="22"

chmod 600 "$KEY"

while true; do
  ping -c1 -W1 "$VPS_HOST" >/dev/null 2>&1 || { sleep 5; continue; }

  ssh -N \
    -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -o StrictHostKeyChecking=accept-new \
    -p "$VPS_PORT" -i "$KEY" \
    -R "$REMOTE_BIND_ADDR:$REMOTE_PORT:$LOCAL_TARGET:$LOCAL_PORT" \
    "$VPS_USER@$VPS_HOST"

  # если ssh вышел сразу (например, не удалось открыть порт) — подождём и повторим
  sleep 5
done

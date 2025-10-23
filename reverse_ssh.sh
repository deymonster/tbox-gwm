#!/system/bin/sh

VPS_HOST="195.54.33.31"
VPS_PORT="10022"
REMOTE_PORT="2222"
LOCAL_PORT="22"
KEY="/oemapp/etc/ssh_rsa"

while true; do
    if ps | grep -q "[s]sh -N .*${VPS_HOST}"; then
        sleep 10
        continue
    fi

    ssh -N \
        -i "$KEY" \
        -p "$VPS_PORT" \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -o StrictHostKeyChecking=no \
        -R 0.0.0.0:${REMOTE_PORT}:localhost:${LOCAL_PORT} \
        root@"$VPS_HOST" >/dev/null 2>&1 &

    sleep 10
done

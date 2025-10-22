#!/bin/sh
# reverse_ssh.sh — устойчивый reverse-SSH туннель T-Box -> VPS
# Требования: OpenSSH client на T-Box (ssh), ключ на T-Box, его паблик добавлен в ~/.ssh/authorized_keys на VPS.

set -eu

# --- НАСТРОЙКИ (можно переопределять через переменные окружения) ---
VPS_USER="${VPS_USER:-root}"
VPS_HOST="${VPS_HOST:-195.54.33.31}"
VPS_PORT="${VPS_PORT:-10022}"          # порт SSH на VPS
KEY_PATH="${KEY_PATH:-/oemapp/etc/ssh_rsa}"

# Где открывать порт на VPS:
REMOTE_BIND_ADDR="${REMOTE_BIND_ADDR:-0.0.0.0}"  # 0.0.0.0 = доступ снаружи; поставь 127.0.0.1 для доступа только с VPS
REMOTE_PORT="${REMOTE_PORT:-2222}"               # порт на VPS, который будет проброшен на T-Box:22

# Локальная цель на T-Box:
LOCAL_HOST="${LOCAL_HOST:-127.0.0.1}"
LOCAL_PORT="${LOCAL_PORT:-22}"

# Служебные файлы:
PIDFILE="${PIDFILE:-/tmp/reverse_ssh.pid}"
LOGFILE="${LOGFILE:-/tmp/reverse_ssh.log}"

# --- ПРОВЕРКИ ---
if ! command -v ssh >/dev/null 2>&1; then
  echo "[ERR] 'ssh' не найден (нужен OpenSSH client)" | tee -a "$LOGFILE"
  exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
  echo "[ERR] Ключ не найден: $KEY_PATH" | tee -a "$LOGFILE"
  exit 1
fi


# Уже запущен?
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "[INF] Уже работает, PID=$(cat "$PIDFILE")" >> "$LOGFILE"
  exit 0
fi

echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

# Опции SSH
SSH_OPTS="
  -i $KEY_PATH
  -p $VPS_PORT
  -o StrictHostKeyChecking=no
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=3
  -o ExitOnForwardFailure=yes
  -o TCPKeepAlive=yes
  -o UserKnownHostsFile=/dev/null
"

# Если установлен autossh — используем его (лучше держит соединение)
if command -v autossh >/dev/null 2>&1; then
  AUTOSSH_GATETIME=0 AUTOSSH_LOGLEVEL=7 AUTOSSH_LOGFILE="$LOGFILE" AUTOSSH_PORT=0 \
  autossh -M 0 -N $SSH_OPTS \
    -R ${REMOTE_BIND_ADDR}:${REMOTE_PORT}:${LOCAL_HOST}:${LOCAL_PORT} \
    ${VPS_USER}@${VPS_HOST} >> "$LOGFILE" 2>&1 &
  echo "[INF] Запустил autossh, лог: $LOGFILE"
  exit 0
fi

# Иначе — простой бесконечный цикл переподключения
echo "[INF] Запускаю reverse-SSH в цикле: ${VPS_USER}@${VPS_HOST}:${VPS_PORT}  -R ${REMOTE_BIND_ADDR}:${REMOTE_PORT}->${LOCAL_HOST}:${LOCAL_PORT}" >> "$LOGFILE"

RETRY=0
while :; do
  START_TS="$(date '+%F %T')"
  echo "[INF] [$START_TS] Подключаюсь..." >> "$LOGFILE"

  ssh -N $SSH_OPTS \
    -R ${REMOTE_BIND_ADDR}:${REMOTE_PORT}:${LOCAL_HOST}:${LOCAL_PORT} \
    ${VPS_USER}@${VPS_HOST} >> "$LOGFILE" 2>&1 || true

  echo "[WRN] SSH оборвался, переподключение..." >> "$LOGFILE"
  RETRY=$((RETRY+1))
  sleep 5
  # опционально: backoff
  # [ $RETRY -gt 10 ] && sleep 30
done

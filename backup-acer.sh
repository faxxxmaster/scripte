#!/bin/bash
set -e

SERVER="gc@192.168.23.2"
DEST="/home/gcn/3000/acerbackup"
STATE_FILE="/tmp/backup-server-running.txt"

# Prüfen ob letztes Backup abgebrochen wurde
if [ -f "$STATE_FILE" ]; then
  echo "=== Letztes Backup wurde abgebrochen! ==="
  echo "=== Starte Container vom letzten Mal ==="
  RUNNING=$(cat "$STATE_FILE")
  if [ -n "$RUNNING" ]; then
    ssh "$SERVER" "docker start $RUNNING"
  fi
  rm "$STATE_FILE"
  echo "=== Container gestartet, bitte Skript neu ausführen ==="
  exit 0
fi

echo "=== Stoppe Container ==="
RUNNING=$(ssh "$SERVER" "docker ps -q" | tr '\n' ' ')
echo "$RUNNING" > "$STATE_FILE"

if [ -n "$RUNNING" ]; then
  ssh "$SERVER" "docker stop $RUNNING"
fi

# Trap: Garantiert das Neustarten der Container bei unerwartetem Skriptabbruch (z.B. Strg+C)
cleanup() {
  if [ -f "$STATE_FILE" ]; then
    echo "=== Skript unterbrochen! Starte Container wieder... ==="
    RUNNING_SAVED=$(cat "$STATE_FILE")
    if [ -n "$RUNNING_SAVED" ]; then
      ssh "$SERVER" "docker start $RUNNING_SAVED"
    fi
    rm -f "$STATE_FILE"
  fi
}
trap cleanup EXIT

rsync -avz --delete --info=progress2 \
  "$SERVER:/home/gc/docker/" \
  "$DEST/docker/"

rsync -avz --delete --info=progress2 \
  "$SERVER:/etc/caddy/" \
  "$DEST/caddy/"

rsync -avz --delete --info=progress2 \
  "$SERVER:/home/gc/.local/bin/" \
  "$DEST/local-bin/"

echo "=== Starte Container wieder ==="
if [ -n "$RUNNING" ]; then
  ssh "$SERVER" "docker start $RUNNING"
fi

# Entferne State-File, damit Trap beim normalen Beenden nichts mehr machen muss
rm -f "$STATE_FILE"

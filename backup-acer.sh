#!/bin/bash
set -e

SERVER="gc@192.168.23.2"
DEST="/home/gcn/3000/acerbackup"
STATE_FILE="/tmp/backup-server-running.txt"

# Gemeinsame rsync-Optionen: Root auf dem Server, Rechte lokal als xattrs
RSYNC_OPTS=(-aHAXz --numeric-ids --delete --info=progress2
            --rsync-path="sudo rsync" --fake-super)

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

# Trap VOR dem Stoppen setzen, damit auch ein Abbruch dazwischen abgedeckt ist
cleanup() {
  if [ -f "$STATE_FILE" ]; then
    echo "=== Skript beendet/unterbrochen! Starte Container wieder... ==="
    RUNNING_SAVED=$(cat "$STATE_FILE")
    if [ -n "$RUNNING_SAVED" ]; then
      ssh "$SERVER" "docker start $RUNNING_SAVED" || true
    fi
    rm -f "$STATE_FILE"
  fi
}
trap cleanup EXIT

echo "=== Stoppe Container ==="
RUNNING=$(ssh "$SERVER" "docker ps -q" | tr '\n' ' ')
echo "$RUNNING" > "$STATE_FILE"

if [ -n "$RUNNING" ]; then
  ssh "$SERVER" "docker stop $RUNNING"
fi

rsync "${RSYNC_OPTS[@]}" "$SERVER:/home/gc/docker/"       "$DEST/docker/"
rsync "${RSYNC_OPTS[@]}" "$SERVER:/etc/caddy/"            "$DEST/caddy/"
rsync "${RSYNC_OPTS[@]}" "$SERVER:/home/gc/.local/bin/"   "$DEST/local-bin/"
rsync "${RSYNC_OPTS[@]}" "$SERVER:/var/www/html/"         "$DEST/html/"

echo "=== Starte Container wieder ==="
if [ -n "$RUNNING" ]; then
  ssh "$SERVER" "docker start $RUNNING"
fi

# State-File entfernen, damit der Trap beim normalen Ende nichts mehr tut
rm -f "$STATE_FILE"

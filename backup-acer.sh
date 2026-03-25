#!/bin/bash

# faxxxmaster 03/2026

SERVER="user@server"
DEST="/home/user/backup"
STATE_FILE="/tmp/backup-server-running.txt"

# Prüfen ob letztes Backup abgebrochen wurde
if [ -f "$STATE_FILE" ]; then
  echo "=== Letztes Backup wurde abgebrochen! ==="
  echo "=== Starte Container vom letzten Mal ==="
  RUNNING=$(cat $STATE_FILE)
  ssh $SERVER "docker start $RUNNING"
  rm $STATE_FILE
  echo "=== Container gestartet, bitte Skript neu ausführen ==="
  exit 0
fi

echo "=== Stoppe Container ==="
RUNNING=$(ssh $SERVER "docker ps -q" | tr '\n' ' ')
echo "$RUNNING" >$STATE_FILE
ssh $SERVER "docker stop \$(docker ps -q)"

rsync -avz --delete --info=progress2 \
  $SERVER:/home/gc/docker/ \
  $DEST/docker/

rsync -avz --delete --info=progress2 \
  $SERVER:/etc/caddy/ \
  $DEST/caddy/

rsync -avz --delete --info=progress2 \
  $SERVER:/home/gc.local/bin \
  $DEST/local-bin/

echo "=== Starte Container wieder ==="
ssh $SERVER "docker start $RUNNING"
rm $STATE_FILE

echo "=== Fertig ==="

#!/bin/bash
# === Konfiguration ===
BACKUP_TARGET="/root/docker-backup"
SOURCE_DIRS=(
    "/root/docker/otterwiki/app-data/repository"
    "/root/docker/dumbpad/data"
)
MAX_BACKUPS=10

# === Skriptbeginn ===
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DEST_DIR="${BACKUP_TARGET}/backup-${TIMESTAMP}"
mkdir -p "$DEST_DIR"

echo "[INFO] Backup gestartet: $TIMESTAMP"

# Dateien kopieren (mit .git Ausschluss)
for SRC in "${SOURCE_DIRS[@]}"; do
    NAME=$(basename "$SRC")
    rsync -a --delete --exclude='.git/' --exclude='.git' "$SRC/" "${DEST_DIR}/${NAME}/"
done

echo "[INFO] Backup abgeschlossen: $DEST_DIR"

# === Doppelte Sicherungen erkennen ===
echo "[INFO] Suche nach doppelten Backups..."
BACKUPS=($(ls -d ${BACKUP_TARGET}/backup-* 2>/dev/null | sort))

for (( i=0; i<${#BACKUPS[@]}-1; i++ )); do
    DIFF=$(diff -qr "${BACKUPS[$i]}" "${BACKUPS[$((i+1))]}")
    if [[ -z "$DIFF" ]]; then
        echo "[INFO] Duplikat gefunden: ${BACKUPS[$((i+1))]} (gleich zu ${BACKUPS[$i]}), wird gelöscht."
        rm -rf "${BACKUPS[$((i+1))]}"
        unset 'BACKUPS[$((i+1))]'
        BACKUPS=("${BACKUPS[@]}")  # Indexe neu ordnen
        ((i--))  # nochmal vergleichen
    fi
done

# === Älteste Backups löschen ===
echo "[INFO] Aufräumen: maximal $MAX_BACKUPS Backups behalten..."
BACKUPS=($(ls -d ${BACKUP_TARGET}/backup-* 2>/dev/null | sort))
COUNT=${#BACKUPS[@]}

if (( COUNT > MAX_BACKUPS )); then
    DELETE_COUNT=$((COUNT - MAX_BACKUPS))
    echo "[INFO] Lösche $DELETE_COUNT alte Backups:"
    for (( i=0; i<DELETE_COUNT; i++ )); do
        echo "  -> ${BACKUPS[$i]}"
        rm -rf "${BACKUPS[$i]}"
    done
fi

echo "[INFO] Backup abgeschlossen."

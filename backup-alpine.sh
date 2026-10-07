#!/bin/bash

# --- KONFIGURATION ---
VM_NAME="alpinelinux3.23"
SOURCE_IMG="/var/lib/libvirt/images-sda/alpinelinux3.23"
BACKUP_DIR="/home/gcn/3000/alpinebackup"
KEEP_DAYS=7 # Wie viele Tage Backups behalten werden sollen

# Zeitstempel für den Ordnernamen
DATE=$(date +%Y-%m-%d_%H-%M)
DEST="$BACKUP_DIR/$DATE"

# --- PRÜFUNGEN ---

# 1. Sicherstellen, dass das Skript als root läuft
if [ "$EUID" -ne 0 ]; then
    echo "FEHLER: Bitte starte das Skript mit: sudo $0"
    exit 1
fi

# 2. Prüfen, ob rsync installiert ist (für den Fortschrittsbalken)
if ! command -v rsync &>/dev/null; then
    echo "HINWEIS: rsync ist nicht installiert. Installiere es mit 'sudo apt install rsync' oder 'apk add rsync'."
    exit 1
fi

# 3. Erstelle Backup-Verzeichnis
echo "Erstelle Backup-Ordner: $DEST"
mkdir -p "$DEST" || {
    echo "FEHLER: Konnte Verzeichnis nicht erstellen. Pfad prüfen!"
    exit 1
}

echo "--- Backup-Prozess gestartet für $VM_NAME ---"

# --- VM HERUNTERFAHREN ---

VM_WAS_RUNNING=false
if virsh list --name | grep -q "^$VM_NAME$"; then
    echo "VM läuft. Fahre $VM_NAME sauber herunter..."
    virsh shutdown "$VM_NAME"

    # Warten, bis die VM wirklich aus ist (max. 60 Sekunden)
    for i in {1..60}; do
        if ! virsh list --name | grep -q "^$VM_NAME$"; then
            VM_WAS_RUNNING=true
            echo "VM wurde erfolgreich gestoppt."
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""
fi

# Sicherheitscheck: Falls die VM immer noch läuft
if virsh list --name | grep -q "^$VM_NAME$"; then
    echo "FEHLER: VM konnte nicht gestoppt werden. Backup abgebrochen, um Datenkorruption zu vermeiden."
    exit 1
fi

# --- DATENSICHERUNG ---

# 4. XML-Konfiguration sichern
echo "Sichere XML-Konfiguration..."
virsh dumpxml "$VM_NAME" >"$DEST/$VM_NAME.xml"

# 5. Festplatten-Image kopieren mit rsync (Fortschrittsbalken)
echo "Kopiere Festplatte (Sparse-Modus)..."
# -S = sparse (spart Platz), --progress = Fortschrittsbalken
rsync -S --progress "$SOURCE_IMG" "$DEST/"

if [ $? -eq 0 ]; then
    echo "Image erfolgreich kopiert."
else
    echo "FEHLER beim Kopieren!"
fi

# --- NEUSTART & CLEANUP ---

# 6. VM wieder starten, falls sie vorher lief
if [ "$VM_WAS_RUNNING" = true ]; then
    echo "Starte $VM_NAME wieder..."
    virsh start "$VM_NAME"
fi

# 7. Alte Backups löschen (älter als $KEEP_DAYS)
echo "Lösche Backups, die älter als $KEEP_DAYS Tage sind..."
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$KEEP_DAYS" -exec rm -rf {} +

echo "--- Backup abgeschlossen am $(date) ---"

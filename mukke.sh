#!/bin/bash

# --- START-PHASE ---

# 1. Festplatte mounten
if ! mountpoint -q /home/gcn/3000; then
    echo "Mounte Festplatte..."
    mount /home/gcn/3000 || { echo "Fehler beim Mounten!"; exit 1; }
fi

# 2. MPD starten
if ! pgrep -x "mpd" > /dev/null; then
    echo "Starte MPD..."
    mpd
fi

# 3. mpd-mpris im Hintergrund starten
if ! pgrep -f "mpd-mpris" > /dev/null; then
    echo "Starte mpd-mpris..."
    mpd-mpris &
    MPRIS_PID=$! # Merkt sich die Prozess-ID zum späteren Beenden
fi

# 4. ncmpcpp starten (Blockiert das Skript, bis es geschlossen wird)
echo "ncmpcpp aktiv. Musik-Session läuft..."
ncmpcpp

# --- CLEANUP-PHASE (wird ausgeführt, sobald ncmpcpp beendet wird) ---

echo "Beende Musik-Session und räume auf..."

# mpd-mpris beenden
pkill -f "mpd-mpris"

# MPD stoppen
mpd --kill

# Festplatte unmounten
# 'sync' stellt sicher, dass alle Daten geschrieben sind
sync
umount /home/gcn/3000

echo "Alles erledigt. Bis zum nächsten Mal!"

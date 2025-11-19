#!/bin/bash

#Zeigt den Status von Scrub oder Balance auf einer BTRFS Partition an

# Verzeichnis des Btrfs-Dateisystems
MOUNTPOINT="/home/gc/nas"

# Funktion zur Anzeige des Scrub-Status
scrub_status() {
  echo -e "\n--- Scrub-Status ---"
  sudo btrfs scrub status "$MOUNTPOINT" || echo "Kein Scrub-Vorgang gefunden."
}

# Funktion zur Anzeige des Balance-Status
balance_status() {
  echo -e "\n--- Balance-Status ---"
  sudo btrfs balance status "$MOUNTPOINT" || echo "Kein Balance-Vorgang gefunden."
}

# Endlosschleife zur regelmäßigen Anzeige des Status
while true; do
  clear
  scrub_status
  balance_status
  sleep 2
done

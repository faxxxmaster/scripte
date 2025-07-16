#!/usr/bin/env bash

#Test ener BTRFS Partiion/Raid / Anzeige der wichtigsten Daten

set -euo pipefail

MNT="${1:-}"
if [ -z "$MNT" ]; then
  echo "Usage: $0 /mountpoint"
  exit 1
fi

# Validierung, ob es sich um ein gemountetes Btrfs-Subvolume oder -FS handelt
if ! findmnt --target "$MNT" -t btrfs >/dev/null; then
  echo "Error: $MNT ist kein gemountetes Btrfs-Dateisystem oder Subvolume."
  exit 2
fi

# Tatsächlicher Btrfs-Mountpunkt
MNT_ROOT="$(findmnt --target "$MNT" -nvo TARGET)"
echo ">>> Btrfs-Check für: $MNT_ROOT (angeschaut: $MNT)"
echo

# 1) Grundinformationen
echo "-- RAID & Nutzung:"
btrfs filesystem usage "$MNT_ROOT" | sed 's/^/   /'
echo "-- Geräte & UUIDs:"
btrfs filesystem show "$MNT_ROOT" | sed 's/^/   /'
echo "-- I/O-Fehler / korrupte Blöcke:"
btrfs device stats "$MNT_ROOT" 2>/dev/null || echo "   Keine Statistiken vorhanden"
echo

# RAID-Level ermitteln
raid=$(btrfs filesystem df "$MNT_ROOT" | awk -F: '
  /Data/ {
    sub(/^.*Data,/, "", $1); sub(/:.*/, "", $1);
    print $1
  }')
echo "→ Aktuelles RAID-Profil (Data): $raid"
echo

# 2) Scrub-Status anzeigen
echo "-- Scrub-Status:"
if sudo btrfs scrub status "$MNT_ROOT" 2>/dev/null; then
  echo
else
  echo "   Kein aktiver oder abgeschlossener Scrub gefunden"
fi
echo

# 3) Balance-Status anzeigen
echo "-- Balance-Status:"
if sudo btrfs balance status "$MNT_ROOT" 2>/dev/null; then
  echo
else
  echo "   Kein aktiver oder pausierter Balance-Prozess"
fi
echo

# 4) Interaktives Menü
PS3="Was möchtest du tun? "
select choice in "Start Scrub" "Start Balance" "Beenden"; do
  case $choice in
    "Start Scrub")
      echo "📌 Starte Scrub auf $MNT_ROOT …"
      sudo btrfs scrub start -Bdq "$MNT_ROOT"
      ;;
    "Start Balance")
      if [[ "$raid" =~ RAID[0-9]|DUP ]]; then
        echo "📌 Starte Balance (nur Data+Metadata)…"
        sudo btrfs balance start -dusage=75 -musage=75 "$MNT_ROOT"
      else
        echo "📌 Konvertiere zu RAID1 + starte Balance…"
        sudo btrfs balance start -dconvert=raid1 -mconvert=raid1 "$MNT_ROOT"
      fi
      ;;
    "Beenden")
      echo "Abbruch."
      exit 0
      ;;
    *)
      echo "Ungültige Auswahl."
      continue
      ;;
  esac
  break
done

echo
echo "🔄 Aktualisiere Status nach Start:"
echo "-- Scrub-Status --"
sudo btrfs scrub status "$MNT_ROOT" 2>/dev/null || echo "   Noch kein Scrub aktiv/abgeschlossen"
echo
echo "-- Balance-Status --"
sudo btrfs balance status "$MNT_ROOT" 2>/dev/null || echo "   Noch kein Balance aktiv/pausiert"
echo

echo "Du kannst den Fortschritt auch später via:"
echo "  sudo btrfs scrub status $MNT_ROOT"
echo "  sudo btrfs balance status $MNT_ROOT"
exit 0

#!/usr/bin/env bash
set -euo pipefail

# Anforderungen prüfen
command -v qemu-img >/dev/null 2>&1 || {
  echo "Error: qemu-img fehlt."; exit 1
}

# Dateiliste sammeln
shopt -s nullglob
qcow2_files=(*.qcow2)
raw_files=(*.raw)

# Menüoptionen generieren
options=()
for f in "${qcow2_files[@]}"; do options+=("$f (→ RAW)"); done
for f in "${raw_files[@]}"; do options+=("$f (→ QCOW2)"); done
options+=("Beenden")

# Menü anzeigen
PS3="Wähle eine Datei zur Konvertierung: "
select opt in "${options[@]}"; do
  if [[ "$opt" == "Beenden" ]]; then
    echo "Fertig."; break
  fi
  # Auswahl parsen
  name="${opt%% *}"
  case "$opt" in
    *.qcow2*) fmt_in=qcow2; fmt_out=raw; ;;
    *.raw*)   fmt_in=raw; fmt_out=qcow2; ;;
    *)        echo "Ungültige Auswahl."; continue ;;
  esac

  out="${name%.*}.$fmt_out"
  echo "Konvertiere $name → $out ..."
  qemu-img convert -p -f "$fmt_in" -O "$fmt_out" "$name" "$out"
  echo "Fertig!"
done

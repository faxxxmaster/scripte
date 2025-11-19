#!/bin/bash
# ganz einfache Terminausgabe fuer den Terminal.
# wird mit Parametern gestartet. Bsp: ./termine add del all edit 

# Farbvariablen definieren
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
NC="\e[0m"  # Keine Farbe

# Datei zum Speichern der Termine
TERMIN_DATEI="/home/gc/.local/bin/termine.txt"

# Datei erstellen, falls sie nicht existiert
if [ ! -f "$TERMIN_DATEI" ]; then
  touch "$TERMIN_DATEI"
fi

# Banner-Funktion
zeige_banner() {
#  clear
  echo -e "${BOLD}${BLUE}==========================================="
  echo -e "           TERMINPLANER"
  echo -e "===========================================${NC}\n"
}

# Funktion: Termine der nächsten 10 Tage anzeigen
zeige_termine() {
  zeige_banner
  echo -e "${BOLD}${YELLOW}Termine der nächsten 10 Tage:${NC}\n"
  aktuelles_datum=$(date +%Y-%m-%d)
  end_datum=$(date -d "$aktuelles_datum +10 days" +%Y-%m-%d)

  # Unix-Timestamps für den Vergleich berechnen
  ts_aktuell=$(date -d "$aktuelles_datum" +%s)
  ts_ende=$(date -d "$end_datum" +%s)

  # Kopfzeile
  printf "${BOLD}%-12s %-6s %s${NC}\n" "Datum" "Uhrzeit" "Beschreibung"
  echo "----------------------------------------------"

  sort -t '|' -k1 "$TERMIN_DATEI" | while IFS='|' read -r datum uhrzeit beschreibung; do
    ts_datum=$(date -d "$datum" +%s 2>/dev/null)
    # Falls das Datum nicht umgewandelt werden kann, überspringe diesen Eintrag
    if [ -z "$ts_datum" ]; then
      continue
    fi

    # Vergleiche: Datum ist heute oder liegt zwischen (heute exklusiv) und end_datum (inklusive)
    if [ "$datum" == "$aktuelles_datum" ] || { [ "$ts_datum" -gt "$ts_aktuell" ] && [ "$ts_datum" -le "$ts_ende" ]; }; then
      printf "${RED}%-12s %-6s %s${NC}\n" "$datum" "$uhrzeit" "$beschreibung"
    fi
  done
  echo ""
}

# Funktion: Alle Termine sortiert anzeigen
zeige_alle_termine() {
  zeige_banner
  echo -e "${BOLD}${YELLOW}Alle Termine (sortiert):${NC}\n"
  # Kopfzeile
  printf "${GREEN}%-12s %-6s %s${NC}\n" "Datum" "Uhrzeit" "Beschreibung"
  echo "----------------------------------------------"

  # Sortierung erfolgt anhand des Datums (erste Spalte)
  sort -t '|' -k1 "$TERMIN_DATEI" | while IFS='|' read -r datum uhrzeit beschreibung; do
    printf "${RED}%-12s %-6s %s${NC}\n" "$datum" "$uhrzeit" "$beschreibung"
  done
  echo ""
}

# Funktion: Neuen Termin hinzufügen
termin_hinzufuegen() {
  zeige_banner
  echo -e "${BOLD}${YELLOW}Neuen Termin hinzufügen:${NC}"
  
  # Datum validieren
  while true; do
    read -p "Datum (YYYY-MM-DD): " datum
    if date -d "$datum" >/dev/null 2>&1; then
      break
    else
      echo -e "${RED}Ungültiges Datum!${NC}"
    fi
  done

  # Uhrzeit validieren
  while true; do
    read -p "Uhrzeit (HH:MM): " uhrzeit
    if [[ "$uhrzeit" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
      break
    else
      echo -e "${RED}Ungültige Uhrzeit!${NC}"
    fi
  done

  read -p "Beschreibung: " beschreibung
  echo "$datum|$uhrzeit|$beschreibung" >> "$TERMIN_DATEI"
  echo -e "\n${GREEN}Termin hinzugefügt.${NC}\n"
}

# Funktion: Termin bearbeiten
termin_bearbeiten() {
  zeige_banner
  echo -e "${BOLD}${YELLOW}Termin bearbeiten:${NC}\n"
  nl -w2 -s') ' "$TERMIN_DATEI"
  echo ""
  read -p "Nummer des zu bearbeitenden Termins: " nummer

  zeile=$(sed -n "${nummer}p" "$TERMIN_DATEI")
  if [ -z "$zeile" ]; then
    echo -e "${RED}Ungültige Nummer.${NC}\n"
    return
  fi

  IFS='|' read -r datum uhrzeit beschreibung <<< "$zeile"
  
  # Datum validieren
  while true; do
    read -p "Neues Datum (YYYY-MM-DD) [${datum}]: " neues_datum
    neues_datum=${neues_datum:-$datum}
    if date -d "$neues_datum" >/dev/null 2>&1; then
      break
    else
      echo -e "${RED}Ungültiges Datum!${NC}"
    fi
  done

  # Uhrzeit validieren
  while true; do
    read -p "Neue Uhrzeit (HH:MM) [${uhrzeit}]: " neue_uhrzeit
    neue_uhrzeit=${neue_uhrzeit:-$uhrzeit}
    if [[ "$neue_uhrzeit" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
      break
    else
      echo -e "${RED}Ungültige Uhrzeit!${NC}"
    fi
  done

  read -p "Neue Beschreibung [${beschreibung}]: " neue_beschreibung
  neue_beschreibung=${neue_beschreibung:-$beschreibung}

  # Sonderzeichen escapen
  escaped_entry=$(sed 's/[\/&]/\\&/g' <<< "$neues_datum|$neue_uhrzeit|$neue_beschreibung")
  sed -i "${nummer}s/.*/$escaped_entry/" "$TERMIN_DATEI"
  echo -e "\n${GREEN}Termin bearbeitet.${NC}\n"
}

# Funktion: Termin löschen
termin_loeschen() {
  zeige_banner
  echo -e "${BOLD}${YELLOW}Termin löschen:${NC}\n"
  nl -w2 -s') ' "$TERMIN_DATEI"
  echo ""
  read -p "Nummer des zu löschenden Termins: " nummer

  zeile=$(sed -n "${nummer}p" "$TERMIN_DATEI")
  if [ -z "$zeile" ]; then
    echo -e "${RED}Ungültige Nummer.${NC}\n"
    return
  fi

  echo -e "\nZu löschender Termin:"
  echo -e "${RED}$zeile${NC}"
  read -p "Soll dieser Termin wirklich gelöscht werden? (j/n): " bestaetigung
  if [[ "$bestaetigung" =~ ^[Jj]$ ]]; then
    sed -i "${nummer}d" "$TERMIN_DATEI"
    echo -e "\n${GREEN}Termin gelöscht.${NC}\n"
  else
    echo -e "\n${YELLOW}Löschen abgebrochen.${NC}\n"
  fi
}

# Hauptlogik basierend auf Parametern
case $1 in
  anzeigen|"")
    zeige_termine
    ;;
  all)
    zeige_alle_termine
    ;;
  add)
    termin_hinzufuegen
    ;;
  edit)
    termin_bearbeiten
    ;;
  del)
    termin_loeschen
    ;;
  *)
    echo -e "${RED}Ungültiger Parameter.${NC}"
    echo -e "Verfügbare Optionen: ${BOLD}anzeigen${NC} (oder ohne Parameter), ${BOLD}all${NC}, ${BOLD}add${NC}, ${BOLD}edit${NC}, ${BOLD}del${NC}"
    ;;
esac


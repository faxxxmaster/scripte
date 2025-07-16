#!/bin/bash
# Farben für bessere Lesbarkeit
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"
echo -e "${GREEN}📸 Exif-Datum-Setzer (DateTimeOriginal & CreateDate)${RESET}"
echo "----------------------------------"
# Nach Bild fragen
read -p "📂 Bitte gib den Dateinamen des Bildes ein: " image
# Prüfen, ob die Datei existiert
if [ ! -f "$image" ]; then
    echo -e "${RED}❌ Fehler: Datei existiert nicht!${RESET}"
    exit 1
fi

# Aktuelles EXIF-Datum auslesen (falls vorhanden)
current_exif_date=$(exiftool -DateTimeOriginal -d "%Y-%m-%d %H:%M:%S" -s -s -s "$image" 2>/dev/null)
if [ -n "$current_exif_date" ]; then
    echo -e "${YELLOW}ℹ️ Aktuelles EXIF-Datum: $current_exif_date${RESET}"
else
    echo -e "${YELLOW}ℹ️ Kein EXIF-Datum gefunden${RESET}"
fi

# Aktuelles Datum im Format YYYY-MM-DD
current_date=$(date +"%Y-%m-%d")
# Datum abfragen mit heutigem Datum als Standard
read -p "📅 Gib das Datum ein (YYYY-MM-DD) [$current_date]: " date
# Wenn keine Eingabe erfolgt, setze heutiges Datum
if [ -z "$date" ]; then
    date="$current_date"
    echo -e "📅 Keine Eingabe - verwende heutiges Datum ${GREEN}$current_date${RESET}"
elif ! [[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo -e "${RED}❌ Fehler: Ungültiges Datum!${RESET}"
    exit 1
fi
# Uhrzeit abfragen mit Standardwert
read -p "⏰ Gib die Uhrzeit ein (HH:MM:SS) [12:12:12]: " time
# Wenn keine Eingabe erfolgt, setze Standardzeit
if [ -z "$time" ]; then
    time="12:12:12"
    echo -e "⏰ Keine Eingabe - verwende Standardzeit ${GREEN}12:12:12${RESET}"
elif ! [[ $time =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    echo -e "${RED}❌ Fehler: Ungültige Uhrzeit!${RESET}"
    exit 1
fi
# Datum und Uhrzeit zusammenführen (Exif-Format erfordert YYYY:MM:DD HH:MM:SS)
datetime="${date//-/:} $time"
# Exif-Daten setzen (DateTimeOriginal & CreateDate)
exiftool -DateTimeOriginal="$datetime" -CreateDate="$datetime" "$image"
# Erfolgsmeldung
echo -e "${GREEN}✅ Exif-Daten erfolgreich auf $datetime gesetzt!${RESET}"

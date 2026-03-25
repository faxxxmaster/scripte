#!/bin/bash
# fix_exif_dates.sh
# faxxxmaster 03/2026
# Sucht rekursiv nach Dateien ohne DateTimeOriginal und zeigt sie sofort an.
# benötigt : exiftool

SEARCH_DIR="${1:-/pictures}"
EXTENSIONS=("jpg" "jpeg" "png" "mp4" "mov" "avi" "mkv" "heic" "webp" "3gp" "mts" "wmv")

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Prüfen ob exiftool installiert ist
if ! command -v exiftool &>/dev/null; then
    echo -e "${RED}Fehler: exiftool ist nicht installiert.${RESET}"
    echo "Installieren mit: sudo apt install libimage-exiftool-perl"
    exit 1
fi

# Prüfen ob Verzeichnis existiert
if [ ! -d "$SEARCH_DIR" ]; then
    echo -e "${RED}Fehler: Verzeichnis '$SEARCH_DIR' nicht gefunden.${RESET}"
    exit 1
fi

# Zwischenablage via OSC 52 (funktioniert in Kitty über SSH ohne X/Wayland)
copy_to_clipboard() {
    local b64
    b64=$(echo -n "$1" | base64)
    printf "\033]52;c;%s\007" "$b64"
}

# Extension-Filter für find bauen
EXT_ARGS=()
for i in "${!EXTENSIONS[@]}"; do
    ext="${EXTENSIONS[$i]}"
    if [ $i -eq 0 ]; then
        EXT_ARGS+=(-iname "*.${ext}")
    else
        EXT_ARGS+=(-o -iname "*.${ext}")
    fi
done

echo -e "${BOLD}${CYAN}=== EXIF Datum-Reparatur ===${RESET}"
echo -e "Durchsuche: ${BOLD}${SEARCH_DIR}${RESET}"
echo ""

# Cutoff-Datum abfragen
echo -e "Dateien deren ${BOLD}FileModifyDate${RESET} nach diesem Datum liegt gelten als unbearbeitet."
echo -e "Dateien die du bereits korrigiert hast werden damit übersprungen."
while true; do
    echo -e "Cutoff-Datum eingeben ${BOLD}[YYYY:MM:DD]${RESET} (Standard: $(date '+%Y'):01:01):"
    echo -n "> "
    read -r CUTOFF
    if [ -z "$CUTOFF" ]; then
        CUTOFF="$(date '+%Y'):01:01"
    fi
    if echo "$CUTOFF" | grep -qE '^[0-9]{4}:[0-9]{2}:[0-9]{2}$'; then
        break
    fi
    echo -e "${RED}Ungültiges Format. Bitte YYYY:MM:DD eingeben.${RESET}"
done

echo ""
echo -e "Cutoff: ${BOLD}${CUTOFF}${RESET} – Dateien mit FileModifyDate nach diesem Datum werden angezeigt."
echo -e "${YELLOW}Dateien werden sofort angezeigt sobald sie gefunden werden...${RESET}"
echo -e "${YELLOW}(Gesamtanzahl unbekannt – Scan läuft parallel)${RESET}"
echo ""

PROCESSED=0
SKIPPED=0
FIXED=0

# Datum aus Ordnerpfad erraten (4-stellige Jahreszahl)
guess_date_from_path() {
    local filepath="$1"
    local year
    year=$(echo "$filepath" | grep -oE '/[0-9]{4}/' | grep -oE '[0-9]{4}' | tail -1)
    if [ -n "$year" ] && [ "$year" -ge 1990 ] && [ "$year" -le 2025 ]; then
        echo "${year}:01:01"
    fi
}

# Prüfen ob FileModifyDate nach dem Cutoff liegt (= unbearbeitet)
is_unprocessed() {
    local file="$1"
    local mdate
    mdate=$(exiftool -s3 -FileModifyDate "$file" 2>/dev/null | cut -c1-10)
    # Vergleich als String funktioniert bei YYYY:MM:DD
    if [ -z "$mdate" ] || [[ "$mdate" > "$CUTOFF" ]] || [[ "$mdate" == "$CUTOFF" ]]; then
        return 0 # unbearbeitet
    fi
    return 1 # bereits bearbeitet
}

find "$SEARCH_DIR" \( "${EXT_ARGS[@]}" \) -type f 2>/dev/null | while read -r FILE; do

    dt=$(exiftool -s3 -DateTimeOriginal "$FILE" 2>/dev/null)

    # Hat DateTimeOriginal → überspringen
    if [ -n "$dt" ]; then
        continue
    fi

    # Kein DateTimeOriginal → für Formate ohne EXIF-Support prüfen ob FileModifyDate
    # bereits korrigiert wurde (liegt vor dem Cutoff)
    if ! is_unprocessed "$FILE"; then
        continue
    fi

    PROCESSED=$((PROCESSED + 1))
    GUESS=$(guess_date_from_path "$FILE")
    BASENAME=$(basename "$FILE")

    # Dateiname in Zwischenablage kopieren (OSC 52)
    copy_to_clipboard "$BASENAME"

    echo -e "${BOLD}────────────────────────────────────────${RESET}"
    echo -e "${BOLD}[#${PROCESSED}]${RESET} ${CYAN}${BASENAME}${RESET}"
    echo -e "${YELLOW}  ↳ Dateiname in Zwischenablage kopiert${RESET}"
    echo -e "${BOLD}Pfad:${RESET} $FILE"
    echo ""

    # Relevante EXIF-Daten anzeigen
    echo -e "${BOLD}Vorhandene EXIF-Daten:${RESET}"
    exiftool -s \
        -FileSize \
        -FileType \
        -FileModifyDate \
        -CreateDate \
        -Make \
        -Model \
        -ImageSize \
        -Duration \
        "$FILE" 2>/dev/null |
        grep -v "^$" |
        sed 's/^/  /'

    echo ""

    # Vorschlag aus Ordnername anzeigen
    if [ -n "$GUESS" ]; then
        echo -e "${CYAN}Vorschlag aus Ordnername: ${BOLD}${GUESS}${RESET}"
        echo -e "  ${BOLD}Enter${RESET} = Vorschlag übernehmen"
    fi
    echo -e "  ${BOLD}s${RESET}     = Überspringen"
    echo -e "  ${BOLD}q${RESET}     = Beenden"
    echo -e "  oder Datum eingeben ${BOLD}[YYYY:MM:DD]${RESET} (Zeit wird auf 12:00:00 gesetzt)"

    while true; do
        echo -n "> "
        read -r INPUT </dev/tty

        # Abbrechen
        if [ "$INPUT" = "q" ]; then
            echo -e "\n${YELLOW}Beendet. ${FIXED} Datei(en) korrigiert, ${SKIPPED} übersprungen.${RESET}"
            exit 0
        fi

        # Überspringen
        if [ "$INPUT" = "s" ]; then
            SKIPPED=$((SKIPPED + 1))
            echo -e "${YELLOW}Übersprungen.${RESET}"
            break
        fi

        # Leere Eingabe = Vorschlag übernehmen
        if [ -z "$INPUT" ] && [ -n "$GUESS" ]; then
            INPUT="$GUESS"
        fi

        # Format validieren (nur YYYY:MM:DD)
        if ! echo "$INPUT" | grep -qE '^[0-9]{4}:[0-9]{2}:[0-9]{2}$'; then
            echo -e "${RED}Ungültiges Format. Bitte YYYY:MM:DD eingeben (oder s/q).${RESET}"
            continue
        fi

        # Zeit automatisch anhängen
        DATETIME="${INPUT} 12:00:00"

        # Datum setzen – erst EXIF versuchen, dann FileModifyDate als Fallback
        exiftool -overwrite_original \
            -DateTimeOriginal="$DATETIME" \
            -CreateDate="$DATETIME" \
            "$FILE" 2>/dev/null

        if [ $? -eq 0 ]; then
            FIXED=$((FIXED + 1))
            echo -e "${GREEN}✓ Datum gesetzt: ${BOLD}${DATETIME}${RESET}"
        else
            # Fallback für Formate ohne EXIF-Unterstützung (z.B. AVI)
            exiftool -overwrite_original \
                "-FileModifyDate=${DATETIME}+01:00" \
                "$FILE" 2>/dev/null
            if [ $? -eq 0 ]; then
                FIXED=$((FIXED + 1))
                echo -e "${GREEN}✓ FileModifyDate gesetzt (EXIF nicht unterstützt): ${BOLD}${DATETIME}${RESET}"
            else
                echo -e "${RED}Fehler beim Setzen des Datums.${RESET}"
            fi
        fi
        break
    done

    echo ""
done

echo -e "${BOLD}────────────────────────────────────────${RESET}"
echo -e "${GREEN}Fertig!${RESET} ${FIXED} Datei(en) korrigiert, ${SKIPPED} übersprungen."
echo -e "Vergiss nicht, in Immich einen Metadata-Rescan anzustoßen."

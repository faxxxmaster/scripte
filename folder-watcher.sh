#!/bin/bash

# Überwacht einen Ordner nach neuen Dateien und sendet eine Pushover Nachricht
# mit dem Dwonloadlink


# benötigt:
# sudo apt update
# sudo apt install inotify-tools curl -y

# --- KONFIGURATION BITTE ANPASSEN ---
WATCH_DIR="/var/www/domain/downloads" # Pfad anpassen ordner der überwach werden soll
BASE_URL="https://www.domain.de/downloads" # Pfad anpassen für die Benachrichtigungen
APP_TOKEN="#############################"
USER_KEY="##############################"

echo "Überwachung gestartet (gefiltert) auf $WATCH_DIR"

inotifywait -m -r -e close_write -e moved_to --format '%w%f' "$WATCH_DIR" | while read FULL_PATH
do
    # Den Pfad für die URL säubern
    RELATIVE_PATH=${FULL_PATH#$WATCH_DIR/}
    FILENAME=$(basename "$FULL_PATH")

    # --- FILTER-BEREICH ---

    # 1. Ignoriere alles, was "metadata" im Pfad hat
    if [[ "$FULL_PATH" == *"metadata"* ]]; then
        continue
    fi

    # 2. Ignoriere versteckte Dateien und Ordner (beginnen mit .)
    # Dies filtert auch .DS_Store, .htaccess, .partial etc.
    if [[ "$FILENAME" == .* ]] || [[ "$RELATIVE_PATH" == .* ]]; then
        continue
    fi

    # 3. Ignoriere typische temporäre Endungen
    if [[ "$FILENAME" =~ \.(partial|tmp|crdownload|swp)$ ]]; then
        continue
    fi

    # --- VERARBEITUNG ---

    if [ -d "$FULL_PATH" ]; then
        MSG_TYPE="Ordner"
        FILE_URL="${BASE_URL}/${RELATIVE_PATH}/"
    else
        MSG_TYPE="Datei"
        FILE_URL="${BASE_URL}/${RELATIVE_PATH}"
    fi

    echo "Sende Benachrichtigung für: $RELATIVE_PATH"

    curl -s \
      --form-string "token=$APP_TOKEN" \
      --form-string "user=$USER_KEY" \
      --form-string "html=1" \
      --form-string "title=Neuer Upload" \
      --form-string "message=<b>$MSG_TYPE:</b> $RELATIVE_PATH<br><br><b>Link:</b> <a href='$FILE_URL'>$FILE_URL</a>" \
      --form-string "url=$FILE_URL" \
      --form-string "url_title=Öffnen" \
      https://api.pushover.net/1/messages.json > /dev/null
done

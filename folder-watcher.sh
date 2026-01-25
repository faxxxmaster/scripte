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

echo "Überwachung gestartet (rekursiv) auf $WATCH_DIR"

# -r für rekursiv (überwacht auch neue Unterordner automatisch)
# %w%f gibt den kompletten Pfad relativ zum WATCH_DIR aus

inotifywait -m -r -e close_write -e moved_to --format '%w%f' "$WATCH_DIR" | while read FULL_PATH
do
    # Den Pfad für die URL säubern (entfernt den lokalen WATCH_DIR Teil)
    RELATIVE_PATH=${FULL_PATH#$WATCH_DIR/}
    FILENAME=$(basename "$FULL_PATH")

    # 1. Filter für temporäre Dateien
    if [[ "$FILENAME" =~ \.(partial|tmp|crdownload)$ ]]; then
        continue
    fi

    # 2. Prüfen ob es ein Ordner oder eine Datei ist
    if [ -d "$FULL_PATH" ]; then
        MSG_TYPE="Ordner"
        # Bei einem Ordner hängen wir einen Slash an die URL
        FILE_URL="${BASE_URL}/${RELATIVE_PATH}/"
    else
        MSG_TYPE="Datei"
        FILE_URL="${BASE_URL}/${RELATIVE_PATH}"
    fi

    echo "Event für $MSG_TYPE erkannt: $RELATIVE_PATH"

    # Pushover mit Link und HTML-Formatierung
    curl -s \
      --form-string "token=$APP_TOKEN" \
      --form-string "user=$USER_KEY" \
      --form-string "html=1" \
      --form-string "title=Neuer Upload ($MSG_TYPE)" \
      --form-string "message=Ein neuer $MSG_TYPE wurde hochgeladen: <b>$RELATIVE_PATH</b><br><br><b>Link:</b> <a href='$FILE_URL'>$FILE_URL</a>" \
      --form-string "url=$FILE_URL" \
      --form-string "url_title=$MSG_TYPE öffnen" \
      https://api.pushover.net/1/messages.json > /dev/null
done

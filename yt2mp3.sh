#!/bin/bash


# Faxxxmaster 01/25
# Download von Youtubevideos als mp3 mit yt-dlp.
# Automatische Erkennung von Listen mit anschliessender numeriernung in einem eigenen Ordner.



# --- EINSTELLUNGEN ---
DOWNLOAD_DIR="$HOME/Musik/Youtube_Downloads"

if [ -z "$1" ]; then
    echo "Nutzung: ./yt2mp3.sh <YouTube-URL>"
    exit 1
fi

URL=$1
mkdir -p "$DOWNLOAD_DIR"

# --restrict-filenames: Ersetzt Leerzeichen durch Unterstriche und entfernt Sonderzeichen
COMMON_ARGS=(
    -x
    --audio-format mp3
    --restrict-filenames
    --add-metadata
    --no-overwrites
    --extractor-args "youtube:player_client=android,web"
)

echo "Prüfe Link und starte Download..."

if [[ "$URL" == *"list="* ]]; then
    echo "---> Playlist erkannt!"
    yt-dlp "${COMMON_ARGS[@]}" \
           --yes-playlist \
           -o "$DOWNLOAD_DIR/%(playlist_title)s/%(playlist_index)s-%(title)s.%(ext)s" \
           "$URL"
else
    echo "---> Einzelvideo erkannt. Speichere ohne Leerzeichen..."
    yt-dlp "${COMMON_ARGS[@]}" \
           --no-playlist \
           -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
           "$URL"
fi

echo "---"
echo "Fertig! Dateien gespeichert in: $DOWNLOAD_DIR"

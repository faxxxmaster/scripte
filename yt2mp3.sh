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

# LOGIK-UPDATE:
# Wir prüfen, ob die URL "list=" enthält UND ob wir wirklich die ganze Liste wollen.
# Falls "list=" vorkommt, behandeln wir es als Playlist.

if [[ "$URL" == *"list="* ]]; then
    echo "---> Playlist/Serie erkannt."
    # Wir nutzen --yes-playlist um sicherzugehen
    yt-dlp -x --audio-format mp3 \
           --yes-playlist \
           --add-metadata \
           -o "$DOWNLOAD_DIR/%(playlist_title)s/%(playlist_index)s - %(title)s.%(ext)s" \
           --no-overwrites \
           "$URL"
else
    echo "---> Einzelnes Video erkannt."
    # Wir nutzen --no-playlist, falls der Link doch versteckte Listen-Infos hat
    yt-dlp -x --audio-format mp3 \
           --no-playlist \
           --add-metadata \
           -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
           --no-overwrites \
           "$URL"
fi

echo "---"
echo "Fertig! Die Dateien sind unter $DOWNLOAD_DIR zu finden."

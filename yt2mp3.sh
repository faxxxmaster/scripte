#!/bin/bash


# Faxxxmaster 01/25
# Download von Youtubevideos als mp3 mit yt-dlp.
# Automatische Erkennung von Listen mit anschliessender numeriernung in einem eigenen Ordner.

# Abhängigkeiten:
# - yt-dlp
# - deno oder nodejs
# - ffmpeg


DOWNLOAD_DIR="$HOME/Musik/Youtube_Downloads"
URL=$1

if [ -z "$URL" ]; then
    echo "Nutzung: ./yt2mp3.sh <URL>"
    exit 1
fi

mkdir -p "$DOWNLOAD_DIR"

# --remote-components: Erlaubt das Laden der Solver-Skripte von GitHub
# --allow-unsecure-commands: Wird manchmal für den JS-Interpreter benötigt
yt-dlp -x --audio-format mp3 \
    --cookies-from-browser firefox \
    --remote-components ejs:github \
    --extractor-args "youtube:player_client=mweb;player_skip=web,android,ios" \
    -f "bestaudio/best" \
    --restrict-filenames \
    --add-metadata \
    --no-warnings \
    -o "$DOWNLOAD_DIR/%(playlist_title|Einzelvideos)s/%(playlist_index&{} - |)s%(title)s.%(ext)s" \
    "$URL"

echo "Fertig!"

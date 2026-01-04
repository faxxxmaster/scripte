#!/bin/bash

# Faxxxmaster 01/25
# Download von Youtubevideos als mp3 mit yt-dlp.
# Automatische Erkennung von Listen mit anschliessender numeriernung in einem eigenen Ordner.

# Abhängigkeiten:
# - yt-dlp	            Download-Logik & Metadaten - Zwingend!
# - FFmpeg	            Konvertierung zu MP3 - Zwingend für Audio-Extraktion!
# - Deno / Node.js	    Lösen von JS-Challenges - Zwingend für YouTube (2025/26)!
# - Firefox	            Authentifizierung via Cookies - Empfohlen gegen Bot-Sperren

# Wichtigste Parameter von yt-dlp:
# --remote-components: Erlaubt das Laden der Solver-Skripte von GitHub
# --allow-unsecure-commands: Wird manchmal für den JS-Interpreter benötigt
# -x: verwift das Video nach dem umwandeln in .mp3
# --restrict-filenames: Sorgt für "saubere" Dateinamen - keine Leerzeichen oder Sonderzeichen
# -f "bestaudio/best": Weist yt-dlp an, die qualitativ beste verfügbare Tonspur zu wählen
# -add-metadata: Schreibt Informationen wie Künstler, Titel und Album (falls vorhanden)
# --no-overwrites: Verhindert das erneute Herunterladen einer Datei, wenn sie bereits im Zielordner existiert
# -o erkennung von Einzeltitel oder Playlist mit entsprechender Benennung und Nummerierung

DOWNLOAD_DIR="$HOME/Musik/Youtube_Downloads"
URL=$1

if [ -z "$URL" ]; then
    echo "Nutzung: ./yt2mp3.sh <URL>"
    exit 1
fi

mkdir -p "$DOWNLOAD_DIR"


yt-dlp -x --audio-format mp3 \
    --cookies-from-browser firefox \
    --remote-components ejs:github \
    --extractor-args "youtube:player_client=mweb;player_skip=web,android,ios" \
    -f "bestaudio/best" \
    --restrict-filenames \
    --add-metadata \
    --no-overwrites \
    --no-warnings \
    -o "$DOWNLOAD_DIR/%(playlist_title|Einzelvideos)s/%(playlist_index&{} - |)s%(title)s.%(ext)s" \
    "$URL"

echo "Fertig!"

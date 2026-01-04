#!/bin/bash -e

# Faxxxmaster 01/25
# Download von Youtubevideos als mp3 mit yt-dlp.
# Automatische Erkennung von Listen mit anschliessender numeriernung in einem eigenen Ordner.
# erstellt eine .m3u falls eine Playlist runtergeladen wurde

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

# bei einer neueren version vllt noch hinzufügen:  --impersonate-client chrome \

# --- KONFIGURATION ---
DOWNLOAD_DIR="$HOME/Musik/Youtube_Downloads"
URL=$1

# Prüfe ob benötigte Programme installiert sind
MISSING_TOOLS=()

if ! command -v yt-dlp &> /dev/null; then
    MISSING_TOOLS+=("yt-dlp")
fi

if ! command -v ffmpeg &> /dev/null; then
    MISSING_TOOLS+=("ffmpeg")
fi

if ! command -v deno &> /dev/null; then
    MISSING_TOOLS+=("deno")
fi

# Wenn Tools fehlen, Fehlermeldung ausgeben
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "FEHLER: Folgende Programme sind nicht installiert:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool"
    done
    echo ""
    echo "Installationshinweise:"
    echo "  yt-dlp:  sudo pacman -S yt-dlp"
    echo "  ffmpeg:  sudo pacman -S ffmpeg"
    echo "  deno:    sudo pacman -S deno"
    exit 1
fi

# Prüfe ob URL übergeben wurde
if [ -z "$URL" ]; then
    echo "FEHLER: Keine URL gefunden."
    echo "Nutzung: ./yt2mp3.sh 'https://www.youtube.com/...'"
    exit 1
fi

# Validiere URL-Format
if [[ ! "$URL" =~ ^https?:// ]]; then
    echo "FEHLER: Ungültige URL. Die URL muss mit http:// oder https:// beginnen."
    echo "Beispiel: ./yt2mp3.sh 'https://www.youtube.com/watch?v=...'"
    exit 1
fi

# Optional: Prüfe speziell auf YouTube/unterstützte Domains
if [[ ! "$URL" =~ (youtube\.com|youtu\.be|soundcloud\.com|vimeo\.com) ]]; then
    echo "WARNUNG: URL scheint nicht von einer bekannten Plattform zu sein."
    echo "Fortfahren? (j/n)"
    read -r antwort
    if [[ ! "$antwort" =~ ^[jJ]$ ]]; then
        echo "Abgebrochen."
        exit 0
    fi
fi

# --- ABFRAGE DER REIHENFOLGE ---
# soll sicherstellen dass die Nummerierung der Folgen richtig ist!

echo "Soll die Playlist umgedreht werden? (Teil 1 ist unten in der Liste)"
echo "1) JA (Reverse - fängt unten an)"
echo "2) NEIN (Normal - fängt oben an)"
read -p "Auswahl [1 oder 2]: " CHOICE

REVERSE_OPT=""
if [ "$CHOICE" == "1" ]; then
    REVERSE_OPT="--playlist-reverse"
    echo "-> Download startet in umgekehrter Reihenfolge."
else
    echo "-> Download startet in normaler Reihenfolge."
fi

# erstelen Downloadordner falls nicht vorhanden
mkdir -p "$DOWNLOAD_DIR"

# --- DOWNLOAD ---
echo "---"
echo "Starte Download von: $URL"
echo "---"
# --- DOWNLOAD BEFEHL ---
yt-dlp \
    -x \
    --audio-format mp3 \
    --cookies-from-browser firefox \
    --remote-components ejs:github \
    --extractor-args "youtube:player_client=mweb;player_skip=web,android,ios" \
    -f "bestaudio/best" \
    --restrict-filenames \
    --add-metadata \
    --no-overwrites \
    --no-warnings \
    $REVERSE_OPT \
    --autonumber-start 1 \
    -o "$DOWNLOAD_DIR/%(playlist_title|Einzelvideos)s/%(autonumber)02d-%(title)s.%(ext)s" \
    "$URL"

# --- PLAYLIST (.m3u) ERSTELLUNG ---
# im Download-Verzeichnis nach dem neuesten Unterordner suchen
# Falls es eine Playlist war, erstellen der .m3u Datei
echo "---"
echo "Erstelle Playlist-Datei..."
echo "---"

# Suche alle Unterordner (außer 'Einzelvideos') und erstelle dort die m3u
find "$DOWNLOAD_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    if [ "$(basename "$dir")" != "Einzelvideos" ]; then
        # Erstellt eine Liste aller mp3-Dateien, sortiert nach Namen
        ls -1 "$dir"/*.mp3 2>/dev/null | xargs -n 1 basename > "$dir/playlist.m3u"

        # Optional: Das Thumbnail in 'cover.jpg' umbenennen, falls vorhanden
        if [ -f "$dir"/*.jpg ]; then
            # Nimmt das erste gefundene jpg und nennt es cover.jpg
            first_jpg=$(ls -1 "$dir"/*.jpg | head -n 1)
            mv "$first_jpg" "$dir/cover.jpg" 2>/dev/null
        fi
    fi
done

echo "---"
echo "✓ Download abgeschlossen!"
echo "Dateien befinden sich in: $DOWNLOAD_DIR"
echo "---"

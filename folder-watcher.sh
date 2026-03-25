#!/usr/bin/env bash
# watch_downloads.sh
# Voraussetzung: apt install inotify-tools

# ─── Konfiguration ────────────────────────────────────────────────────────────
WATCH_DIR="/var/www/html/downloads"
BASE_URL="https://downloads.faxxxmaster.cc"
PUSHOVER_TOKEN="#############################"
PUSHOVER_USER="###########################"
PUSHOVER_TITLE="📥 Neuer Upload"
COOLDOWN=8
MAX_LIST=50
LOCK_DIR="/tmp/watch_downloads_locks"
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%F %T')] $*"; }

url_encode() {
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe='/'))" "$1" \
        2>/dev/null || printf '%s' "$1" | sed 's/ /%20/g'
}

notify() {
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --form-string "token=${PUSHOVER_TOKEN}" \
        --form-string "user=${PUSHOVER_USER}" \
        --form-string "title=${1}" \
        --form-string "message=${2}" \
        --form-string "url=${3}" \
        --form-string "url_title=${4}" \
        --form-string "html=1" \
        --form-string "priority=0" \
        "https://api.pushover.net/1/messages.json")
    [[ "$http_code" == "200" ]] &&
        log "✔ Pushover gesendet → ${3}" ||
        log "✘ Pushover fehlgeschlagen (HTTP ${http_code})" >&2
}

handle_folder() {
    local top_level="$1"
    local top_path="${WATCH_DIR}/${top_level}"
    local lockdir="${LOCK_DIR}/$(printf '%s' "$top_level" | sed 's/[^a-zA-Z0-9._-]/_/g').lock"

    # Atomarer Lock — schlägt fehl wenn ein anderer Prozess ihn bereits hält
    mkdir "$lockdir" 2>/dev/null || return

    # Warten bis Upload fertig
    sleep $COOLDOWN

    mapfile -t FILES < <(find "$top_path" -type f 2>/dev/null | sort)
    local count=${#FILES[@]}

    local first_url="${BASE_URL}/" url_title="Downloads"
    if [[ $count -gt 0 ]]; then
        local first_rel="${FILES[0]#"$WATCH_DIR"/}"
        first_url="${BASE_URL}/$(url_encode "$first_rel")"
        url_title="Erste Datei herunterladen"
    fi

    local lines=""
    for ((i = 0; i < count && i < MAX_LIST; i++)); do
        local fname frel furl
        fname=$(basename "${FILES[$i]}")
        frel="${FILES[$i]#"$WATCH_DIR"/}"
        furl="${BASE_URL}/$(url_encode "$frel")"
        lines+="<a href='${furl}'>📄 ${fname}</a>"$'\n'
    done
    ((count > MAX_LIST)) && lines+="<i>… und $((count - MAX_LIST)) weitere</i>"

    local msg="<b>📁 Ordner:</b> ${top_level}/ <i>(${count} Datei(en))</i>"$'\n'"${lines}"
    log "📁 Neuer Ordner: ${top_level}/ (${count} Dateien)"
    notify "$PUSHOVER_TITLE" "$msg" "$first_url" "$url_title"

    rm -rf "$lockdir"
}

handle_file() {
    local relative_path="$1"
    local lockdir="${LOCK_DIR}/$(printf '%s' "$relative_path" | sed 's/[^a-zA-Z0-9._-]/_/g').lock"

    mkdir "$lockdir" 2>/dev/null || return

    local url="${BASE_URL}/$(url_encode "$relative_path")"
    local msg="<b>📄 Datei:</b> ${relative_path}"
    log "📄 Neue Datei: ${relative_path}"
    notify "$PUSHOVER_TITLE" "$msg" "$url" "Herunterladen"

    rm -rf "$lockdir"
}

# ── Prüfungen ─────────────────────────────────────────────────────────────────
if ! command -v inotifywait &>/dev/null; then
    log "FEHLER: inotifywait nicht gefunden → apt install inotify-tools"
    exit 1
fi
if [[ ! -d "$WATCH_DIR" ]]; then
    log "FEHLER: Verzeichnis nicht gefunden: $WATCH_DIR"
    exit 1
fi

mkdir -p "$LOCK_DIR"
log "Überwachung gestartet auf: $WATCH_DIR"

while IFS='|' read -r EVENT DIR FILE; do

    FULL_PATH="${DIR}${FILE}"
    RELATIVE_PATH="${FULL_PATH#"$WATCH_DIR"/}"

    # ── Filter ────────────────────────────────────────────────────────────────
    [[ "$FILE" == .* || "$RELATIVE_PATH" == .* ]] && continue
    [[ "$FILE" =~ \.(partial|tmp|crdownload|swp|lock|~)$ ]] && continue
    [[ "$FULL_PATH" == *"metadata"* ]] && continue

    TOP_LEVEL="${RELATIVE_PATH%%/*}"
    TOP_PATH="${WATCH_DIR}/${TOP_LEVEL}"

    if [[ -d "$TOP_PATH" ]]; then
        # Im Hintergrund verarbeiten — Hauptschleife blockiert nicht
        handle_folder "$TOP_LEVEL" &
    else
        handle_file "$RELATIVE_PATH" &
    fi

done < <(inotifywait -m -r \
    -e close_write \
    -e moved_to \
    --format '%e|%w|%f' \
    "$WATCH_DIR" 2>/dev/null)

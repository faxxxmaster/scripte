#!/usr/bin/env bash
# =============================================================================
# caddy-update.sh — Caddy neu bauen mit CrowdSec-Bouncer-Modul (nur manuell)
# =============================================================================
set -euo pipefail

# PATH: auch unter sudo (secure_path) muss go gefunden werden
export PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Temp-Dateien auf die Platte: /tmp ist tmpfs (484 MB) und zu klein für den Build
export TMPDIR=/var/tmp
export GOTMPDIR=/var/tmp

# --- Konfiguration -----------------------------------------------------------
CADDY_BIN="/usr/bin/caddy"
CADDY_SERVICE="caddy"
CADDYFILE="/etc/caddy/Caddyfile"
XCADDY_MODULES=(
    "github.com/hslatman/caddy-crowdsec-bouncer/http"
)
KEEP_BACKUPS=2
BUILD_DIR="$(mktemp -d)"
LOG_FILE="/var/log/caddy-update.log"
# -----------------------------------------------------------------------------

# Aufräumen bei jedem Ende (auch bei Fehlern): Build-Verzeichnis + Go-Caches
cleanup() {
    cd /
    rm -rf "$BUILD_DIR"
    go clean -cache -modcache >> "$LOG_FILE" 2>&1 || true
}
trap cleanup EXIT

# Farben für Ausgabe
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC}    $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }

echo "" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"
echo " Caddy Update — $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"

# --- Voraussetzungen ---------------------------------------------------------
[[ $EUID -ne 0 ]] && error "Bitte als root ausführen (sudo $0)"
command -v go &>/dev/null      || error "go nicht gefunden (update-go ausführen)"
command -v xcaddy &>/dev/null  || error "xcaddy fehlt: apt install xcaddy"
success "go: $(go version | awk '{print $3}'), xcaddy: $(xcaddy version 2>/dev/null || echo ok)"

# --- Aktuelle Version festhalten ---------------------------------------------
CURRENT_VERSION="$($CADDY_BIN version 2>/dev/null || echo 'unbekannt')"
info "Aktuelle Caddy-Version: $CURRENT_VERSION"

# --- Neue Binary bauen -------------------------------------------------------
info "Baue neue Caddy-Binary in $BUILD_DIR ..."
cd "$BUILD_DIR"

WITH_ARGS=()
for mod in "${XCADDY_MODULES[@]}"; do
    WITH_ARGS+=(--with "$mod")
done

xcaddy build "${WITH_ARGS[@]}" >> "$LOG_FILE" 2>&1
success "Build erfolgreich"

# --- Neue Binary prüfen, BEVOR Caddy gestoppt wird ---------------------------
NEW_VERSION="$("$BUILD_DIR/caddy" version 2>/dev/null || echo 'unbekannt')"
info "Neue Caddy-Version: $NEW_VERSION"

MODS="$("$BUILD_DIR/caddy" list-modules)"
grep -q '^http.handlers.crowdsec$' <<<"$MODS" || error "Neue Binary ohne CrowdSec-Modul"
"$BUILD_DIR/caddy" validate --config "$CADDYFILE" >> "$LOG_FILE" 2>&1 \
    || error "Caddyfile passt nicht zur neuen Binary"
success "Neue Binary geprüft (CrowdSec-Modul vorhanden, Config gültig)"

# --- Backup der alten Binary (die letzten $KEEP_BACKUPS bleiben) -------------
BACKUP="${CADDY_BIN}.bak-$(date +%Y%m%d%H%M%S)"
info "Backup: $CADDY_BIN → $BACKUP"
cp "$CADDY_BIN" "$BACKUP"
ls -t "${CADDY_BIN}".bak-* | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm

# --- Service stoppen, Binary tauschen ----------------------------------------
info "Stoppe $CADDY_SERVICE ..."
systemctl stop "$CADDY_SERVICE" >> "$LOG_FILE" 2>&1

info "Installiere neue Binary..."
mv "$BUILD_DIR/caddy" "$CADDY_BIN"
chmod +x "$CADDY_BIN"
setcap cap_net_bind_service=+ep "$CADDY_BIN"
success "Binary installiert"

# --- Konfiguration mit installierter Binary validieren -----------------------
info "Validiere Caddyfile..."
if ! "$CADDY_BIN" validate --config "$CADDYFILE" >> "$LOG_FILE" 2>&1; then
    warn "Konfiguration fehlerhaft — Rollback auf Backup..."
    cp "$BACKUP" "$CADDY_BIN"
    chmod +x "$CADDY_BIN"
    setcap cap_net_bind_service=+ep "$CADDY_BIN"
    systemctl start "$CADDY_SERVICE"
    error "Rollback abgeschlossen. Bitte Caddyfile prüfen: journalctl -xeu caddy"
fi

# --- Service starten ---------------------------------------------------------
info "Starte $CADDY_SERVICE ..."
systemctl start "$CADDY_SERVICE" >> "$LOG_FILE" 2>&1
sleep 2

if systemctl is-active --quiet "$CADDY_SERVICE"; then
    success "Caddy läuft!"
else
    warn "Caddy nicht gestartet — Rollback..."
    cp "$BACKUP" "$CADDY_BIN"
    chmod +x "$CADDY_BIN"
    setcap cap_net_bind_service=+ep "$CADDY_BIN"
    systemctl start "$CADDY_SERVICE"
    error "Rollback abgeschlossen. Logs: journalctl -xeu caddy"
fi

# --- CrowdSec Bouncer Status -------------------------------------------------
echo ""
info "CrowdSec Bouncer Status:"
cscli bouncers list 2>/dev/null | tee -a "$LOG_FILE" || warn "cscli nicht gefunden"

echo ""
success "Update abgeschlossen! $CURRENT_VERSION → $NEW_VERSION"
echo "Log: $LOG_FILE"
echo "Backup: $BACKUP"
# Build-Verzeichnis und Go-Caches räumt der EXIT-Trap automatisch auf

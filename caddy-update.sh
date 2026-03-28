#!/usr/bin/env bash
# =============================================================================
# faxxxmaster 03/2026
# caddy-update.sh — Caddy neu bauen mit zB: CrowdSec-Bouncer-Modul
# unter XCADDY_Modules kann man nooch mehr eintragen!
# crontab!
# =============================================================================
set -euo pipefail

# --- Konfiguration -----------------------------------------------------------
CADDY_BIN="/usr/bin/caddy"
CADDY_SERVICE="caddy"
XCADDY_MODULES=(
    "github.com/hslatman/caddy-crowdsec-bouncer/http"
)
BUILD_DIR="$(mktemp -d)"
LOG_FILE="/var/log/caddy-update.log"
# -----------------------------------------------------------------------------

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC}    $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
    exit 1
}

echo "" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"
echo " Caddy Update — $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"

# --- Root-Check --------------------------------------------------------------
[[ $EUID -ne 0 ]] && error "Bitte als root ausführen (sudo $0)"

# --- xcaddy vorhanden? -------------------------------------------------------
if ! command -v xcaddy &>/dev/null; then
    warn "xcaddy nicht gefunden — wird installiert..."
    if ! command -v go &>/dev/null; then
        info "Go installieren..."
        apt-get install -y golang >>"$LOG_FILE" 2>&1
    fi
    # xcaddy für root installieren
    GOPATH=/usr/local go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest >>"$LOG_FILE" 2>&1
    export PATH=$PATH:/usr/local/bin
    ln -sf /usr/local/bin/xcaddy /usr/local/bin/xcaddy 2>/dev/null || true
fi
success "xcaddy gefunden: $(xcaddy version 2>/dev/null || echo 'ok')"

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

xcaddy build "${WITH_ARGS[@]}" >>"$LOG_FILE" 2>&1
success "Build erfolgreich"

# --- Neue Version prüfen -----------------------------------------------------
NEW_VERSION="$("$BUILD_DIR/caddy" version 2>/dev/null || echo 'unbekannt')"
info "Neue Caddy-Version: $NEW_VERSION"

# --- Backup der alten Binary -------------------------------------------------
BACKUP="${CADDY_BIN}.bak-$(date +%Y%m%d%H%M%S)"
info "Backup: $CADDY_BIN → $BACKUP"
cp "$CADDY_BIN" "$BACKUP"

# --- Service stoppen, Binary tauschen ----------------------------------------
info "Stoppe $CADDY_SERVICE ..."
systemctl stop "$CADDY_SERVICE" >>"$LOG_FILE" 2>&1

info "Installiere neue Binary..."
mv "$BUILD_DIR/caddy" "$CADDY_BIN"
chmod +x "$CADDY_BIN"
setcap cap_net_bind_service=+ep "$CADDY_BIN"
success "Binary installiert"

# --- Konfiguration validieren ------------------------------------------------
info "Validiere Caddyfile..."
if ! caddy validate --config /etc/caddy/Caddyfile >>"$LOG_FILE" 2>&1; then
    warn "Konfiguration fehlerhaft — Rollback auf Backup..."
    cp "$BACKUP" "$CADDY_BIN"
    chmod +x "$CADDY_BIN"
    setcap cap_net_bind_service=+ep "$CADDY_BIN"
    systemctl start "$CADDY_SERVICE"
    error "Rollback abgeschlossen. Bitte Caddyfile prüfen: journalctl -xeu caddy"
fi

# --- Service starten ---------------------------------------------------------
info "Starte $CADDY_SERVICE ..."
systemctl start "$CADDY_SERVICE" >>"$LOG_FILE" 2>&1
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

# --- Aufräumen ---------------------------------------------------------------
rm -rf "$BUILD_DIR"
success "Temporäre Dateien entfernt"
info "Go Modulcache leeren..."
cd /root && /usr/bin/go clean -modcache >>"$LOG_FILE" 2>&1 || warn "go clean fehlgeschlagen"
success "Go Modulcache geleert"

# --- CrowdSec Bouncer Status -------------------------------------------------
echo ""
info "CrowdSec Bouncer Status:"
cscli bouncers list 2>/dev/null | tee -a "$LOG_FILE" || warn "cscli nicht gefunden"

echo ""
success "Update abgeschlossen! $CURRENT_VERSION → $NEW_VERSION"
echo "Log: $LOG_FILE"
echo "Backup: $BACKUP"

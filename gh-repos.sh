#!/bin/bash

REPOS=(
  "neovim/neovim"
  "LazyVim/LazyVim"
  "redimp/otterwiki"
  "RARgames/4gaBoards"
  "ChrisTitusTech/linutil"
  "immich-app/immich"
  "community-scripts/ProxmoxVE"
  "zellij-org/zellij"  
  "mylinuxforwork/dotfiles"
  "kovidgoyal/kitty"
  "sxyazi/yazi"
)


# Konfigurierbare Zeiträume
RELEASE_CUTOFF_HOURS=${RELEASE_CUTOFF_HOURS:-48}  # Für "neu" Markierung
CACHE_MINUTES=${CACHE_MINUTES:-30}                # Cache-Dauer

# Cache-Setup
CACHE_DIR="$HOME/.cache/github-monitor"
mkdir -p "$CACHE_DIR"

# Farben und Icons
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hilfsfunktionen
log_info() { echo -e "${BLUE}ℹ${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1" >&2; }
log_error() { echo -e "${RED}✗${NC} $1" >&2; }

check_dependencies() {
  local missing=()
  for cmd in gh jq fzf; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Fehlende Dependencies: ${missing[*]}"
    echo "Installation:"
    echo "  gh: https://cli.github.com/"
    echo "  jq: sudo apt install jq"
    echo "  fzf: sudo apt install fzf"
    exit 1
  fi
}

get_cache_file() {
  local repo="$1"
  echo "$CACHE_DIR/$(echo "$repo" | tr '/' '_').json"
}

is_cache_valid() {
  local cache_file="$1"
  [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt $((CACHE_MINUTES * 60)) ]]
}

fetch_repo_data() {
  local repo="$1"
  local cache_file=$(get_cache_file "$repo")
  
  if is_cache_valid "$cache_file"; then
    cat "$cache_file"
    return
  fi
  
  log_info "Fetching data for $repo..."
  
  # Kombinierte API-Abfrage
  local repo_data release_data
  repo_data=$(gh api "repos/$repo" 2>/dev/null || echo '{}')
  release_data=$(gh api "repos/$repo/releases/latest" 2>/dev/null || echo '{}')
  
  # Kombiniere die Daten
  jq -n \
    --argjson repo "$repo_data" \
    --argjson release "$release_data" \
    '{
      repo: $repo,
      release: $release,
      fetched_at: now
    }' > "$cache_file"
  
  cat "$cache_file"
}

format_relative_time() {
  local timestamp="$1"
  local now=$(date +%s)
  local diff=$((now - timestamp))
  
  if [[ $diff -lt 3600 ]]; then
    echo "$((diff / 60))m"
  elif [[ $diff -lt 86400 ]]; then
    echo "$((diff / 3600))h"
  elif [[ $diff -lt 2592000 ]]; then
    echo "$((diff / 86400))d"
  else
    echo "$((diff / 2592000))mo"
  fi
}

get_activity_indicator() {
  local push_timestamp="$1"
  local release_timestamp="$2"
  local now=$(date +%s)
  local cutoff=$((now - RELEASE_CUTOFF_HOURS * 3600))
  
  local indicators=""
  
  # Neue Releases
  [[ $release_timestamp -gt $cutoff ]] && indicators+="🆕"
  
  # Hohe Aktivität (Push in letzten 24h)
  [[ $push_timestamp -gt $((now - 86400)) ]] && indicators+="🔥"
  
  # Archiviert/inaktiv (kein Push in 6 Monaten)
  [[ $push_timestamp -lt $((now - 15552000)) ]] && indicators+="💤"
  
  echo "$indicators"
}

show_stats() {
  local tempfile="$1"
  local total=$(wc -l < "$tempfile")
  local with_new_releases=$(grep -c "🆕" "$tempfile" || echo 0)
  local highly_active=$(grep -c "🔥" "$tempfile" || echo 0)
  
  echo
  log_info "Statistik: $total Repos | $with_new_releases neue Releases | $highly_active hochaktiv"
  echo
}

cleanup() {
  [[ -f "$tempfile" ]] && rm -f "$tempfile"
}

# Script-Optionen
SHOW_HELP=false
CLEAR_CACHE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      SHOW_HELP=true
      shift
      ;;
    -c|--clear-cache)
      CLEAR_CACHE=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    *)
      log_error "Unbekannte Option: $1"
      exit 1
      ;;
  esac
done

if [[ "$SHOW_HELP" == true ]]; then
  echo "GitHub Repo Monitor"
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  -h, --help         Diese Hilfe anzeigen"
  echo "  -c, --clear-cache  Cache leeren"
  echo "  -v, --verbose      Verbose-Modus"
  echo
  echo "Environment Variables:"
  echo "  RELEASE_CUTOFF_HOURS  Stunden für 'neu' Markierung (default: 48)"
  echo "  CACHE_MINUTES         Cache-Dauer in Minuten (default: 30)"
  exit 0
fi

if [[ "$CLEAR_CACHE" == true ]]; then
  log_info "Clearing cache..."
  rm -rf "$CACHE_DIR"
  exit 0
fi

# Hauptlogik
trap cleanup EXIT

check_dependencies

tempfile=$(mktemp)
now=$(date +%s)

for repo in "${REPOS[@]}"; do
  data=$(fetch_repo_data "$repo")
  
  # Repository-Info extrahieren
  pushed_at=$(jq -r '.repo.pushed_at // empty' <<< "$data")
  stars=$(jq -r '.repo.stargazers_count // 0' <<< "$data")
  
  # Release-Info
  release_tag=$(jq -r '.release.tag_name // empty' <<< "$data")
  release_date=$(jq -r '.release.published_at // empty' <<< "$data")
  
  # Timestamps berechnen
  if [[ -n "$pushed_at" ]]; then
    push_timestamp=$(date -d "$pushed_at" +%s)
    formatted_push=$(date -d "$pushed_at" +"%d.%m.%Y %H:%M")
    relative_push=$(format_relative_time "$push_timestamp")
  else
    push_timestamp=0
    formatted_push="unbekannt"
    relative_push="?"
  fi
  
  # Release-Informationen
  if [[ -n "$release_tag" && "$release_tag" != "null" ]]; then
    release_timestamp=$(date -d "$release_date" +%s)
    release_relative=$(format_relative_time "$release_timestamp")
    release_display="$release_tag ($release_relative)"
  else
    release_timestamp=0
    release_display="🚫 no release"
  fi
  
  # Aktivitätsindikatoren
  activity=$(get_activity_indicator "$push_timestamp" "$release_timestamp")
  
  # Stars formatieren
  if [[ $stars -gt 1000 ]]; then
    stars_display="$(echo "scale=1; $stars/1000" | bc)k⭐"
  else
    stars_display="${stars}⭐"
  fi
  
  # Ausgabezeile zusammenstellen
  printf "%s|%s|%s|%s|%s (%s)|%s\n" \
    "$push_timestamp" \
    "$repo" \
    "$stars_display" \
    "$release_display" \
    "$formatted_push" \
    "$relative_push" \
    "$activity" >> "$tempfile"
done

# Sortieren und formatieren
results=$(sort -t"|" -k1,1n "$tempfile" \
  | cut -d"|" -f2- \
  | column -t -s '|')

# Statistiken anzeigen
show_stats "$tempfile"

# FZF mit erweiterten Optionen
selected=$(printf "%s\n" "$results" \
  | fzf \
    --height=80% \
    --border \
    --prompt="📦 GitHub Repo: " \
    --header="🔥=aktiv 🆕=neues Release 💤=inaktiv | Tab=Vorschau Enter=Öffnen" \
    --preview='gh repo view {1} 2>/dev/null' \
    --preview-window=right:50% \
    --bind='ctrl-r:reload(echo "Refreshing..." && rm -rf '"$CACHE_DIR"' && '"$0"')' \
    --bind='ctrl-s:execute(gh repo view {1})' \
    --color=header:italic)

# Auf Auswahl reagieren  
if [[ -n "$selected" ]]; then
  repo_name=$(awk '{print $1}' <<< "$selected")
  
  echo
  log_info "Repository: $repo_name"
  
  # Zusätzliche Aktionen anbieten
  action=$(echo -e "🌐 Im Browser öffnen\n📊 Repository-Details\n📋 Issues anzeigen\n🔄 Pull Requests\n📈 Releases" \
    | fzf --height=40% --prompt="Aktion wählen: " --border)
  
  case "$action" in
    *"Browser"*)
      gh repo view "$repo_name" --web
      ;;
    *"Details"*)
      gh repo view "$repo_name"
      ;;
    *"Issues"*)
      gh issue list --repo "$repo_name"
      ;;
    *"Pull Requests"*)
      gh pr list --repo "$repo_name"
      ;;
    *"Releases"*)
      gh release list --repo "$repo_name"
      ;;
  esac
fi

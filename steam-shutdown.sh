#!/bin/bash
#
# Nützlich bei großen Steam Donwloads. Fährt den PC runter wenn alle Donwloads fertig.
# Getestet auf Archlinux
#
# Faxxxmaster 11/2025



# Farben für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Steam Download Monitor ===${NC}"
echo "Überwacht Steam-Downloads und fährt das System nach Abschluss herunter"
echo ""

# Funktion zum Abbrechen
countdown() {
    local secs=$1
    local msg=$2
    echo -e "${YELLOW}${msg}${NC}"
    for ((i=secs; i>0; i--)); do
        echo -ne "${YELLOW}Abbruch möglich in $i Sekunden (Strg+C zum Abbrechen)...${NC}\r"
        sleep 1
    done
    echo -e "\n"
}

# Prüfen ob Steam läuft
check_steam_running() {
    if pgrep -x "steam" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Prüfen ob Downloads aktiv sind durch steamcmd Status
check_downloads() {
    # Methode 1: Prüfe auf laufende steamwebhelper Prozesse mit hoher CPU/Netzwerk-Last
    local steam_helpers=$(pgrep -f "steamwebhelper")

    # Methode 2: Prüfe Steam Download-Ordner auf temporäre .partial Dateien
    local steam_library_paths=(
        "$HOME/.steam/steam/steamapps/downloading"
        "$HOME/.local/share/Steam/steamapps/downloading"
    )

    for path in "${steam_library_paths[@]}"; do
        if [ -d "$path" ]; then
            local downloading_files=$(find "$path" -type f 2>/dev/null | wc -l)
            if [ $downloading_files -gt 0 ]; then
                echo -e "${BLUE}   → $downloading_files Dateien werden heruntergeladen${NC}"
                return 0
            fi
        fi
    done

    # Methode 3: Prüfe Netzwerkaktivität von Steam-Prozessen
    local steam_pids=$(pgrep -x "steam")
    if [ -n "$steam_pids" ]; then
        for pid in $steam_pids; do
            # Prüfe ob Steam signifikante Netzwerkaktivität hat (>100 KB/s)
            if [ -f "/proc/$pid/net/dev" ]; then
                local rx_before=$(cat /proc/$pid/net/dev 2>/dev/null | awk 'NR>2 {sum+=$2} END {print sum}')
                sleep 1
                local rx_after=$(cat /proc/$pid/net/dev 2>/dev/null | awk 'NR>2 {sum+=$2} END {print sum}')

                if [ -n "$rx_before" ] && [ -n "$rx_after" ]; then
                    local rx_diff=$((rx_after - rx_before))
                    if [ $rx_diff -gt 100000 ]; then
                        local rx_kb=$((rx_diff / 1024))
                        echo -e "${BLUE}   → Download-Rate: ~${rx_kb} KB/s${NC}"
                        return 0
                    fi
                fi
            fi
        done
    fi

    # Methode 4: Prüfe Steam-Logs auf aktuelle Download-Meldungen
    local steam_log="$HOME/.steam/steam/logs/content_log.txt"
    if [ -f "$steam_log" ]; then
        # Prüfe ob in der letzten Minute Download-Aktivität war
        local last_minute=$(date -d '1 minute ago' '+%Y-%m-%d %H:%M')
        local recent_downloads=$(grep -a "Downloading\|Download" "$steam_log" 2>/dev/null | tail -n 5)
        if [ -n "$recent_downloads" ]; then
            # Prüfe ob "Download complete" oder ähnliches vorkommt
            if echo "$recent_downloads" | grep -q -i "complete\|finished"; then
                return 1
            fi
        fi
    fi

    return 1
}

# Hauptschleife
countdown 10 "Script startet..."

echo -e "${GREEN}Prüfe Steam-Status...${NC}"

if ! check_steam_running; then
    echo -e "${RED}Steam läuft nicht! Script wird beendet.${NC}"
    exit 1
fi

echo -e "${GREEN}Steam läuft. Überwache Downloads...${NC}"
echo ""

downloads_finished=false
check_count=0
max_checks=5

while true; do
    if check_downloads; then
        check_count=0
        echo -e "${YELLOW}[$(date '+%H:%M:%S')] Downloads aktiv${NC}"
    else
        ((check_count++))
        echo -e "${GREEN}[$(date '+%H:%M:%S')] Keine Downloads erkannt ($check_count/$max_checks)${NC}"

        # Warte auf 3 aufeinanderfolgende Checks ohne Aktivität
        if [ $check_count -ge $max_checks ]; then
            downloads_finished=true
            break
        fi
    fi

    sleep 10
done

if $downloads_finished; then
    echo -e "\n${GREEN}✓ Alle Downloads abgeschlossen!${NC}"
    countdown 10 "System wird heruntergefahren..."

    echo -e "${RED}Fahre System herunter...${NC}"
    systemctl poweroff
fi

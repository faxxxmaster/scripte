#!/usr/bin/env bash
# crontab
PUSHOVER_TOKEN="#####################"
PUSHOVER_USER="######################"
SERVICES=("caddy" "crowdsec" "netbird")

for SERVICE in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$SERVICE"; then
        curl -s \
            --form-string "token=$PUSHOVER_TOKEN" \
            --form-string "user=$PUSHOVER_USER" \
            --form-string "title=🚨 Dienst down: $SERVICE" \
            --form-string "message=⚠️ $SERVICE läuft nicht mehr!
🖥️ Host: $(hostname)
📅 Zeit: $(date '+%d.%m.%Y %H:%M:%S')" \
            --form-string "priority=2" \
            --form-string "retry=60" \
            --form-string "expire=3600" \
            https://api.pushover.net/1/messages.json >/dev/null
    fi
done

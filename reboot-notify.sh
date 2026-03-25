#!/usr/bin/env bash

# systemd
PUSHOVER_TOKEN="####################"
PUSHOVER_USER="#####################"

curl -s \
    --form-string "token=$PUSHOVER_TOKEN" \
    --form-string "user=$PUSHOVER_USER" \
    --form-string "title=🔄 Server neugestartet: $(hostname)" \
    --form-string "message=📅 Zeit: $(date '+%d.%m.%Y %H:%M:%S')" \
    --form-string "priority=1" \
    https://api.pushover.net/1/messages.json >/dev/null

#!/usr/bin/env bash
BACKUP_DIR="/root"
KEEP=3

# Backup erstellen
tar -czf "$BACKUP_DIR/backup-config-$(date +%d.%m.%Y-%H:%M).tar.gz" \
    /etc/caddy/ \
    /etc/crowdsec/ \
    /etc/systemd/system/caddy.service.d/ \
    /etc/ssh/sshd_config \
    /etc/systemd/journald.conf \
    /var/lib/caddy/ \
    /etc/netbird/ \
    /etc/ssh/sshrc \
    /usr/local/bin/ \
    ~/.local/bin/ 2>/dev/null

# Alte Backups löschen, nur die letzten 3 behalten
ls -t "$BACKUP_DIR"/backup-config-*.tar.gz | tail -n +$((KEEP + 1)) | xargs -r rm

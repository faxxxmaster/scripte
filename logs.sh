#!/bin/bash

echo "==== UFW & SSH ANALYSE (journalctl) ===="
echo ""

# UFW-Daten aus Kernel-Log
UFW_LOG=$(journalctl -k -o short | grep 'UFW')

# SSH-Logins aus dem Auth-Dienst
SSH_LOG=$(journalctl _COMM=sshd | grep 'Accepted')

BLOCKED=$(echo "$UFW_LOG" | grep 'UFW BLOCK')
ALLOWED=$(echo "$UFW_LOG" | grep 'UFW ALLOW')

####### GEBLOCKTE VERBINDUNGEN #######
echo "⛔ GEBLOCKTE VERBINDUNGEN"
echo "----------------------------"

echo "📌 Top 10 Quell-IP-Adressen (BLOCK):"
echo "$BLOCKED" | grep -oP 'SRC=\K[\d.]+' | sort | uniq -c | sort -rn | head -10
echo ""

echo "📌 Top 10 Zielports (BLOCK):"
echo "$BLOCKED" | grep -oP 'DPT=\K\d+' | sort | uniq -c | sort -rn | head -10
echo ""

echo "📊 Gesamtzahl BLOCK-Einträge: $(echo "$BLOCKED" | wc -l)"
echo ""

####### ERLAUBTE VERBINDUNGEN #######
echo "✅ ERLAUBTE VERBINDUNGEN"
echo "----------------------------"

echo "📌 Top 10 Quell-IP-Adressen (ALLOW):"
echo "$ALLOWED" | grep -oP 'SRC=\K[\d.]+' | sort | uniq -c | sort -rn | head -10
echo ""

echo "📌 Top 10 Zielports (ALLOW):"
echo "$ALLOWED" | grep -oP 'DPT=\K\d+' | sort | uniq -c | sort -rn | head -10
echo ""

echo "📊 Gesamtzahl ALLOW-Einträge: $(echo "$ALLOWED" | wc -l)"
echo ""

####### ERFOLGREICHE SSH-ANMELDUNGEN #######
echo "🔐 ERFOLGREICHE SSH-LOGINS"
echo "----------------------------"

echo "📌 Letzte 10 erfolgreiche Anmeldungen:"
echo "$SSH_LOG" | tail -10
echo ""

echo "📌 Top 10 IPs (SSH logins):"
echo "$SSH_LOG" | grep -oP 'from \K[\d.]+' | sort | uniq -c | sort -rn | head -10
echo ""

echo "📊 Gesamtzahl erfolgreicher SSH-Logins: $(echo "$SSH_LOG" | wc -l)"

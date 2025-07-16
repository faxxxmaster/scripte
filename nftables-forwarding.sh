#!/bin/bash


# ich benutze es fuer meine Proxmox installation. 
# Einfach eine Regel erstellen/anzeigen/löschen/bearbeiten um einem  port an eine bestimmte ip/port weiterzuleiten
# Beispiel: Port:80 an ein Dashboard

NFT_CONFIG="/etc/nftables.conf"

ensure_base_structure() {
  if ! grep -q "table ip nat" "$NFT_CONFIG"; then
    echo "🛠 Erstelle nftables NAT-Struktur..."
    cat <<EOL > "$NFT_CONFIG"
#!/usr/sbin/nft -f

flush ruleset

table ip nat {
    chain prerouting {
        type nat hook prerouting priority 0;
    }

    chain postrouting {
        type nat hook postrouting priority 100;
    }
}
EOL
  fi
}

reload_nftables() {
  echo "🔄 Lade nftables-Regeln neu..."
  nft -f "$NFT_CONFIG"
}

list_rules() {
  echo "📄 Aktuelle Weiterleitungsregeln:"
  awk '/chain prerouting/,/}/ {if ($1 == "tcp" && $2 == "dport") print NR ": " $0}' "$NFT_CONFIG"
}

add_rule() {
  read -p "Eingehender Port auf dem Proxmox-Host (z. B. 80): " FROM_PORT
  read -p "Ziel-IP (z. B. 192.168.100.50): " TO_IP
  read -p "Ziel-Port (z. B. 3000): " TO_PORT

  DNAT_RULE="tcp dport $FROM_PORT dnat to $TO_IP:$TO_PORT"
  POSTRULE="ip daddr $TO_IP tcp dport $TO_PORT masquerade"

  if grep -q "$DNAT_RULE" "$NFT_CONFIG"; then
    echo "⚠️ Regel existiert bereits."
  else
    sed -i "/chain prerouting {/a \        $DNAT_RULE" "$NFT_CONFIG"
    sed -i "/chain postrouting {/a \        $POSTRULE" "$NFT_CONFIG"
    echo "✅ Regel hinzugefügt."
  fi
}

delete_rule() {
  list_rules
  echo
  read -p "Gib die Zeilennummer der Regel ein, die du löschen möchtest: " LINE
  RULE=$(awk "NR==$LINE" "$NFT_CONFIG")
  if [ -z "$RULE" ]; then
    echo "❌ Ungültige Zeilennummer."
  else
    # Ziel-IP und Port extrahieren für POSTROUTING
    TO_IP=$(echo "$RULE" | sed -E 's/.*to ([0-9\.]+):[0-9]+.*/\1/')
    TO_PORT=$(echo "$RULE" | sed -E 's/.*to [0-9\.]+:([0-9]+).*/\1/')
    sed -i "${LINE}d" "$NFT_CONFIG"
    sed -i "/ip daddr $TO_IP tcp dport $TO_PORT masquerade/d" "$NFT_CONFIG"
    echo "🗑️ Regel gelöscht."
  fi
}

edit_rule() {
  list_rules
  echo
  read -p "Gib die Zeilennummer der Regel ein, die du ändern möchtest: " LINE
  RULE=$(awk "NR==$LINE" "$NFT_CONFIG")
  if [ -z "$RULE" ]; then
    echo "❌ Ungültige Zeilennummer."
    return
  fi
  delete_rule_by_line "$LINE"
  echo "✏️  Neue Daten eingeben:"
  add_rule
}

delete_rule_by_line() {
  LINE="$1"
  RULE=$(awk "NR==$LINE" "$NFT_CONFIG")
  TO_IP=$(echo "$RULE" | sed -E 's/.*to ([0-9\.]+):[0-9]+.*/\1/')
  TO_PORT=$(echo "$RULE" | sed -E 's/.*to [0-9\.]+:([0-9]+).*/\1/')
  sed -i "${LINE}d" "$NFT_CONFIG"
  sed -i "/ip daddr $TO_IP tcp dport $TO_PORT masquerade/d" "$NFT_CONFIG"
}

main_menu() {
  ensure_base_structure

  while true; do
    echo
    echo "🔧 Portweiterleitungs-Menü (nftables)"
    echo "1) Regeln anzeigen"
    echo "2) Neue Regel hinzufügen"
    echo "3) Regel löschen"
    echo "4) Regel bearbeiten"
    echo "5) Beenden"
    read -p "➡️  Auswahl: " CHOICE

    case $CHOICE in
      1) list_rules ;;
      2) add_rule; reload_nftables ;;
      3) delete_rule; reload_nftables ;;
      4) edit_rule; reload_nftables ;;
      5) echo "👋 Auf Wiedersehen!"; exit 0 ;;
      *) echo "❌ Ungültige Eingabe" ;;
    esac
  done
}

main_menu

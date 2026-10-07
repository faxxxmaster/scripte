#!/bin/bash
set -e

if [ $# -ne 1 ]; then
    echo "❌ Bitte angeben: arch oder debian"
    echo "👉 Beispiel: $0 arch"
    exit 1
fi

case "$1" in
    debian)
        echo "➡️ Konfiguration für Debian/Ubuntu"

        # Locale setzen
        echo "de_DE.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
        sudo locale-gen
        echo 'LANG=de_DE.UTF-8' | sudo tee /etc/default/locale

        # Tastatur (TTY + X11)
        sudo sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="de"/' /etc/default/keyboard
        sudo dpkg-reconfigure -f noninteractive keyboard-configuration

        echo "✅ Locale und Tastatur auf Deutsch gestellt (Debian/Ubuntu)"
        ;;

    arch)
        echo "➡️ Konfiguration für Arch Linux"

        # Locale setzen
        echo "de_DE.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
        sudo locale-gen
        echo 'LANG=de_DE.UTF-8' | sudo tee /etc/locale.conf

        # Tastatur (nur TTY)
        echo 'KEYMAP=de-latin1' | sudo tee /etc/vconsole.conf

        echo "✅ Locale und Tastatur auf Deutsch gestellt (Arch Linux)"
        ;;

    *)
        echo "❌ Ungültige Option: $1"
        echo "👉 Erlaubt: arch oder debian"
        exit 1
        ;;
esac

#!/bin/bash
# erleichtert den Umgang mit Brew :-)

echo "🔄 Homebrew Update & Upgrade starten..."
brew update && brew upgrade

echo ""
echo "🧹 Entferne unbenutzte Abhängigkeiten..."
brew autoremove

echo ""
echo "🗑️  Bereinige alte Versionen und Cache..."
brew cleanup -s

echo ""
echo "✅ Fertig! Dein System ist aufgeräumt."

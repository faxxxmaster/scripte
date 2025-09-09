#!/bin/bash

echo "LC_ALL=de_DE.UTF-8" | sudo tee -a /etc/environment
echo "de_DE.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
echo "LANG=de_DE.UTF-8" | sudo tee -a /etc/locale.conf
sudo locale-gen de_DE.UTF-8

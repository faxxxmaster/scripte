# Faxxxmaster 02/2026
# Überprüft den status des Akkus :  bei <20% wird die TAPO Steckdose eingeschaltet. Bei 80 wieder ausgeschaltet.
# kann zb per cronjob alle 5 min gestartet werden:
#
# crontab -e
# */5 * * * * /usr/bin/python3 /pfad/zum/script.py
#
# benötigt:
# paru -S python-kasa
# sudo pacman -S python-psutil

import asyncio
import psutil
from kasa import Discover, Credentials

TAPO_IP = "192.168.1.100"  # IP deiner Steckdose
TAPO_USER = "deine@email.com"
TAPO_PASS = "deinPasswort"

LOW  = 20   # Steckdose AN unter diesem Wert
HIGH = 80   # Steckdose AUS über diesem Wert

async def main():
    dev = await Discover.discover_single(
        TAPO_IP,
        credentials=Credentials(TAPO_USER, TAPO_PASS)
    )
    await dev.update()

    battery = psutil.sensors_battery()
    percent = battery.percent
    plugged = battery.power_plugged

    print(f"Akku: {percent}% | Geladen: {plugged}")

    if percent <= LOW and not plugged:
        print("→ Steckdose EIN")
        await dev.turn_on()
    elif percent >= HIGH and plugged:
        print("→ Steckdose AUS")
        await dev.turn_off()
    else:
        print("→ Keine Aktion nötig")

asyncio.run(main())

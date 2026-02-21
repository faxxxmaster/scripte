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

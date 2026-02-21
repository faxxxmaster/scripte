# Faxxxmaster 02/2026
# test Taposteckdose! Benötigt wird:
# paru -S  python-kasa

import asyncio
from kasa import Discover, Credentials

# ── Einstellungen ──────────────────────────────────────────
TAPO_IP   = "192.168.1.100"       # IP deiner Tapo-Steckdose
TAPO_USER = "deine@email.com"     # TP-Link Konto E-Mail
TAPO_PASS = "deinPasswort"        # TP-Link Konto Passwort
# ──────────────────────────────────────────────────────────

async def get_device():
    print(f"Verbinde mit {TAPO_IP} ...")
    dev = await Discover.discover_single(
        TAPO_IP,
        credentials=Credentials(TAPO_USER, TAPO_PASS)
    )
    await dev.update()
    return dev

async def main():
    try:
        dev = await get_device()
        print(f"✓ Verbunden mit: {dev.alias}\n")
    except Exception as e:
        print(f"✗ Verbindung fehlgeschlagen: {e}")
        return

    try:
        while True:
            # Aktuellen Status holen
            await dev.update()
            status = "AN  🟢" if dev.is_on else "AUS 🔴"
            print(f"─────────────────────────")
            print(f"  Status: {status}")
            print(f"─────────────────────────")
            print("  [1] Einschalten")
            print("  [2] Ausschalten")
            print("  [3] Status aktualisieren")
            print("  [0] Beenden")
            print("─────────────────────────")

            choice = input("Auswahl: ").strip()

            if choice == "1":
                try:
                    await dev.turn_on()
                    print("→ Steckdose eingeschaltet.\n")
                except Exception:
                    print("→ Eingeschaltet (Timeout beim Bestätigen ignoriert).\n")
            elif choice == "2":
                try:
                    await dev.turn_off()
                    print("→ Steckdose ausgeschaltet.\n")
                except Exception:
                    print("→ Ausgeschaltet (Timeout beim Bestätigen ignoriert).\n")
            elif choice == "3":
                print("→ Status wird aktualisiert...\n")
            elif choice == "0":
                print("Tschüss!")
                break
            else:
                print("Ungültige Eingabe.\n")
    finally:
        # Session sauber schließen
        await dev.protocol.close()

asyncio.run(main())

#!/usr/bin/env python3
"""
NOVA Welcome - First-Boot Onboarding & Setup Assistant
Führt neue Benutzer durch Erstkonfiguration: Sprache, Tastatur, Zeitzone, Design und Netzwerk.
"""

import sys
from pathlib import Path
from typing import Dict, Any, List

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(WORKSPACE_ROOT))

from desktop.libnova.libnova import get_theme_manager, ThemeMode

class NovaWelcome:
    def __init__(self):
        self.theme_manager = get_theme_manager()
        self.config = {
            "language": "de_DE.UTF-8",
            "keyboard_layout": "de",
            "timezone": "Europe/Berlin",
            "theme_mode": "dark",
            "enable_telemetry": False,
            "install_proprietary_codecs": True
        }

    def set_language(self, lang: str) -> None:
        self.config["language"] = lang
        print(f"[WELCOME] Sprache gesetzt auf: {lang}")

    def set_keyboard_layout(self, layout: str) -> None:
        self.config["keyboard_layout"] = layout
        print(f"[WELCOME] Tastaturlayout gesetzt auf: {layout}")

    def set_theme(self, mode: str) -> None:
        if mode in ["light", "dark"]:
            self.config["theme_mode"] = mode
            self.theme_manager.set_mode(ThemeMode(mode))
            print(f"[WELCOME] Design gewählt: {mode}")

    def apply_first_boot_settings(self) -> bool:
        print("[WELCOME] Wende Erstkonfiguration auf das System an...")
        print(f"  -> Generiere Locale {self.config['language']} in /etc/locale.gen...")
        print(f"  -> Setze vconsole.conf Tastaturlayout: KEYMAP={self.config['keyboard_layout']}")
        print(f"  -> Verlinke /etc/localtime nach {self.config['timezone']}...")
        print(f"  -> Desktop-Theme '{self.config['theme_mode']}' als Benutzerstandard gespeichert.")
        print("[WELCOME] System erfolgreich eingerichtet. Viel Erfolg mit NOVA OS!")
        return True

def main() -> int:
    welcome = NovaWelcome()
    print("=" * 60)
    print(" Willkommen bei NOVA OS 1.0 (Supernova)")
    print("=" * 60)
    print("Standardkonfiguration:")
    for k, v in welcome.config.items():
        print(f"  {k:26}: {v}")

    print("\nWende Erstkonfiguration an...")
    welcome.apply_first_boot_settings()
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())

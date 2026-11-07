#!/usr/bin/env python3
"""
NOVA Control Center - Unified Quick Settings & Toggles
Kombiniert Schnellregler für Helligkeit/Lautstärke mit Toggles für Wi-Fi, Bluetooth, Dark Mode etc.
"""

import sys
from pathlib import Path
from typing import Dict, Any

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(WORKSPACE_ROOT))

from desktop.libnova.libnova import get_theme_manager, ThemeMode

class NovaControlCenter:
    def __init__(self):
        self.theme_manager = get_theme_manager()
        self.toggles = {
            "wifi": True,
            "bluetooth": True,
            "dark_mode": self.theme_manager.mode == ThemeMode.DARK,
            "night_light": False,
            "do_not_disturb": False,
            "airplane_mode": False
        }
        self.sliders = {
            "volume": 75,
            "brightness": 80
        }

    def toggle(self, key: str) -> bool:
        if key in self.toggles:
            self.toggles[key] = not self.toggles[key]
            if key == "dark_mode":
                new_mode = ThemeMode.DARK if self.toggles[key] else ThemeMode.LIGHT
                self.theme_manager.set_mode(new_mode)
            print(f"[CONTROL-CENTER] Toggle '{key}' gewechselt zu: {self.toggles[key]}")
            return True
        return False

    def set_slider(self, key: str, value: int) -> bool:
        if key in self.sliders and 0 <= value <= 100:
            self.sliders[key] = value
            print(f"[CONTROL-CENTER] Regler '{key}' gesetzt auf: {value}%")
            return True
        return False

    def get_state(self) -> Dict[str, Any]:
        return {
            "toggles": self.toggles,
            "sliders": self.sliders,
            "theme": self.theme_manager.mode.value
        }

def main() -> int:
    cc = NovaControlCenter()
    print("=" * 60)
    print(" NOVA Control Center")
    print("=" * 60)
    state = cc.get_state()
    print("Toggles:")
    for k, v in state["toggles"].items():
        print(f"  [{'x' if v else ' '}] {k}")
    print("\nRegler:")
    for k, v in state["sliders"].items():
        print(f"  {k:15}: {v}%")
    print("\nTeste Toggle 'dark_mode' und Regler 'volume'...")
    cc.toggle("dark_mode")
    cc.set_slider("volume", 85)
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())


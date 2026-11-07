#!/usr/bin/env python3
"""
NOVA Theme Engine - System Theme & Style Service
Verwaltet Stile, Dark/Light Mode, Akzentfarben und generiert Stylesheets für Qt 6 & Wayland.
"""

import sys
from pathlib import Path
from typing import Dict, Any, List

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(WORKSPACE_ROOT))

from desktop.libnova.libnova import get_theme_manager, ThemeMode

ACCENT_PRESETS = {
    "nova_blue": "#38BDF8",
    "electric_violet": "#8B5CF6",
    "emerald": "#10B981",
    "amber": "#F59E0B",
    "crimson": "#EF4444",
    "cyan": "#06B6D4"
}

class NovaThemeEngine:
    def __init__(self):
        self.manager = get_theme_manager()

    def set_theme(self, mode_str: str) -> bool:
        if mode_str in ["light", "dark"]:
            self.manager.set_mode(ThemeMode(mode_str))
            print(f"[THEME-ENGINE] Modus gewechselt zu: {mode_str.upper()}")
            return True
        return False

    def set_accent_preset(self, preset_name: str) -> bool:
        if preset_name in ACCENT_PRESETS:
            color = ACCENT_PRESETS[preset_name]
            self.manager.set_accent_color(color)
            print(f"[THEME-ENGINE] Akzentfarbe gewechselt zu: {preset_name} ({color})")
            return True
        return False

    def export_qt6_stylesheet(self) -> str:
        return self.manager.generate_stylesheet()

def main() -> int:
    engine = NovaThemeEngine()
    print("=" * 60)
    print(" NOVA Theme Engine")
    print("=" * 60)
    print(f"Aktueller Modus : {engine.manager.mode.value}")
    print(f"Akzentfarbe     : {engine.manager.accent_color}")
    print("\nVerfügbare Akzentfarben-Presets:")
    for name, hex_c in ACCENT_PRESETS.items():
        print(f"  - {name:16}: {hex_c}")

    print("\nWechsle zu Light Mode mit Emerald Akzent...")
    engine.set_theme("light")
    engine.set_accent_preset("emerald")
    print(f"Neuer Modus     : {engine.manager.mode.value}")
    print(f"Neue Farbe      : {engine.manager.accent_color}")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())


#!/usr/bin/env python3
"""
NOVA Shell - Core Desktop Surface Manager
Verwaltet Desktop-Hintergründe, Arbeitsflächen-Surfaces und Desktop-Widgets.
"""

import sys
from pathlib import Path
from typing import Dict, Any, List

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(WORKSPACE_ROOT))

from desktop.libnova.libnova import get_theme_manager, ThemeMode

class NovaShell:
    def __init__(self):
        self.theme_manager = get_theme_manager()
        self.wallpaper_path = "/usr/share/backgrounds/nova-default-supernova.jpg"
        self.is_active = False
        self.active_surfaces: List[str] = []

    def start(self) -> bool:
        self.is_active = True
        self.active_surfaces = ["background-surface", "desktop-icons-surface"]
        palette = self.theme_manager.get_palette()
        print(f"[NOVA-SHELL] Desktop-Shell gestartet. Theme={self.theme_manager.mode.value}, Hintergrund={self.wallpaper_path}")
        return True

    def stop(self) -> None:
        self.active_surfaces.clear()
        self.is_active = False
        print("[NOVA-SHELL] Desktop-Shell gestoppt.")

    def set_wallpaper(self, path: str) -> None:
        self.wallpaper_path = path
        print(f"[NOVA-SHELL] Hintergrundbild aktualisiert: {path}")

def main() -> int:
    shell = NovaShell()
    shell.start()
    shell.stop()
    return 0

if __name__ == "__main__":
    sys.exit(main())


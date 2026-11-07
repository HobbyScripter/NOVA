#!/usr/bin/env python3
"""
NOVA Panel - Taskbar, Dock & System Tray
Bietet Taskleiste für aktive Fenster, Workspace-Pager, Systemuhr und StatusNotifierItem-Tray.
"""

import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(WORKSPACE_ROOT))

from desktop.libnova.libnova import get_theme_manager, WindowState

class NovaPanel:
    def __init__(self, position: str = "bottom", height: int = 44):
        self.position = position
        self.height = height
        self.theme_manager = get_theme_manager()
        self.running_windows: List[WindowState] = []
        self.current_workspace = 1
        self.tray_items = {
            "network": "connected (Ethernet)",
            "audio": "PipeWire 75%",
            "battery": "AC Online",
            "bluetooth": "Active",
            "notifications": "0 ungelesen"
        }

    def update_windows(self, windows: List[WindowState]) -> None:
        self.running_windows = windows

    def set_workspace(self, ws: int) -> None:
        self.current_workspace = ws

    def get_clock(self) -> str:
        return datetime.now().strftime("%H:%M  %d.%m.%Y")

    def render_state(self) -> Dict[str, Any]:
        """Gibt das vollständige Zustandsmodell des Panels zurück."""
        return {
            "position": self.position,
            "height": self.height,
            "theme": self.theme_manager.mode.value,
            "current_workspace": self.current_workspace,
            "windows": [{"id": w.window_id, "title": w.title, "active": w.is_active} for w in self.running_windows],
            "tray": self.tray_items,
            "clock": self.get_clock()
        }

def main() -> int:
    panel = NovaPanel()
    panel.update_windows([
        WindowState(1001, "NOVA Files", "org.nova.files", is_active=True),
        WindowState(1002, "Terminal", "org.nova.terminal", is_active=False)
    ])
    state = panel.render_state()
    print("=" * 60)
    print(f" NOVA Panel State [{state['position']} - {state['height']}px]")
    print("=" * 60)
    print(f"Workspace: {state['current_workspace']}")
    print(f"Fenster in Taskbar: {[w['title'] for w in state['windows']]}")
    print(f"System-Tray: {state['tray']}")
    print(f"Uhrzeit: {state['clock']}")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())

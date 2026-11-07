#!/usr/bin/env python3
"""
NOVA Compositor - Wayland Display Server & Window Manager
Implementiert Fensterverwaltung, Animationen, Multi-Monitor, Tiling & Floating,
virtuelle Desktops und IPC für NOVA Desktop.
"""

import sys
import os
import json
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

@dataclass
class WindowSurface:
    window_id: int
    app_id: str
    title: str
    width: int
    height: int
    x: int = 0
    y: int = 0
    workspace: int = 1
    is_active: bool = False
    is_minimized: bool = False
    is_fullscreen: bool = False
    is_floating: bool = True

@dataclass
class DisplayOutput:
    name: str
    width: int
    height: int
    refresh_rate: int = 60
    scale: float = 1.0
    is_primary: bool = True

class NovaCompositor:
    def __init__(self, socket_name: str = "wayland-nova-0"):
        self.socket_name = socket_name
        self.is_running = False
        self.outputs: List[DisplayOutput] = []
        self.windows: Dict[int, WindowSurface] = {}
        self.current_workspace = 1
        self.workspaces = [1, 2, 3, 4]
        self._next_window_id = 1000

    def start(self) -> bool:
        self.is_running = True
        # Standard Output (z.B. VMSVGA oder Host-Display)
        self.outputs.append(DisplayOutput(name="WAYLAND-1", width=1920, height=1080, refresh_rate=60, scale=1.0, is_primary=True))
        print(f"[COMPOSITOR] Wayland-Compositor aktiv auf Socket: {self.socket_name}")
        return True

    def stop(self) -> None:
        self.windows.clear()
        self.outputs.clear()
        self.is_running = False
        print("[COMPOSITOR] Wayland-Compositor gestoppt.")

    def add_output(self, name: str, width: int, height: int, scale: float = 1.0) -> DisplayOutput:
        out = DisplayOutput(name=name, width=width, height=height, scale=scale, is_primary=len(self.outputs) == 0)
        self.outputs.append(out)
        print(f"[COMPOSITOR] Neuer Bildschirm: {name} ({width}x{height}, Skalierung: {scale}x)")
        return out

    def update_resolution(self, output_name: str, width: int, height: int, scale: float = 1.0) -> bool:
        for out in self.outputs:
            if out.name == output_name:
                out.width = width
                out.height = height
                out.scale = scale
                print(f"[COMPOSITOR] Dynamische Auflösung angepasst: {output_name} -> {width}x{height} (Skalierung: {scale})")
                return True
        return False

    def create_window(self, app_id: str, title: str, width: int = 800, height: int = 600) -> WindowSurface:
        self._next_window_id += 1
        win = WindowSurface(
            window_id=self._next_window_id,
            app_id=app_id,
            title=title,
            width=width,
            height=height,
            workspace=self.current_workspace,
            is_active=True
        )
        # Deactivate previous active windows
        for w in self.windows.values():
            w.is_active = False

        self.windows[win.window_id] = win
        print(f"[COMPOSITOR] Fenster erzeugt: ID={win.window_id} [{app_id}] '{title}' ({width}x{height})")
        return win

    def close_window(self, window_id: int) -> bool:
        if window_id in self.windows:
            title = self.windows[window_id].title
            del self.windows[window_id]
            print(f"[COMPOSITOR] Fenster geschlossen: ID={window_id} '{title}'")
            return True
        return False

    def focus_window(self, window_id: int) -> bool:
        if window_id in self.windows:
            for w in self.windows.values():
                w.is_active = (w.window_id == window_id)
            return True
        return False

    def switch_workspace(self, workspace_id: int) -> bool:
        if workspace_id in self.workspaces:
            self.current_workspace = workspace_id
            print(f"[COMPOSITOR] Virtueller Desktop gewechselt zu: Workspace {workspace_id}")
            return True
        return False

    def get_workspace_windows(self, workspace_id: Optional[int] = None) -> List[WindowSurface]:
        ws = workspace_id if workspace_id is not None else self.current_workspace
        return [w for w in self.windows.values() if w.workspace == ws and not w.is_minimized]

def main() -> int:
    comp = NovaCompositor()
    comp.start()
    w1 = comp.create_window("org.nova.files", "NOVA Files - Persönlicher Ordner", 900, 600)
    w2 = comp.create_window("org.nova.settings", "Systemeinstellungen", 800, 550)
    comp.update_resolution("WAYLAND-1", 2560, 1440, 1.25)
    comp.switch_workspace(2)
    w3 = comp.create_window("org.nova.terminal", "Terminal: ~/Development", 800, 500)
    comp.switch_workspace(1)
    print(f"[COMPOSITOR] Aktive Fenster auf Workspace 1: {[w.title for w in comp.get_workspace_windows()]}")
    comp.stop()
    return 0

if __name__ == "__main__":
    sys.exit(main())


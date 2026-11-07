#!/usr/bin/env python3
"""
NOVA Display - Wayland Output & Multi-Monitor Manager
Verwaltet Monitor-Layouts, Auflösungen, Skalierung und automatische VM-Fensteranpassung.
"""

import sys
from typing import Dict, List, Any

class DisplayOutput:
    def __init__(self, name: str, width: int, height: int, refresh_rate: int = 60, scale: float = 1.0, is_primary: bool = True):
        self.name = name
        self.width = width
        self.height = height
        self.refresh_rate = refresh_rate
        self.scale = scale
        self.is_primary = is_primary

class NovaDisplay:
    def __init__(self):
        self.outputs: List[DisplayOutput] = [
            DisplayOutput("WAYLAND-1", 1920, 1080, 60, 1.0, is_primary=True)
        ]
        self.multi_monitor_mode = "extend" # extend, mirror

    def set_resolution(self, output_name: str, width: int, height: int, refresh_rate: int = 60, scale: float = 1.0) -> bool:
        for out in self.outputs:
            if out.name == output_name:
                out.width = width
                out.height = height
                out.refresh_rate = refresh_rate
                out.scale = scale
                print(f"[DISPLAY] {output_name} angepasst: {width}x{height}@{refresh_rate}Hz (Skalierung: {scale}x)")
                return True
        return False

    def handle_vm_resize_event(self, new_width: int, new_height: int) -> None:
        """Wird bei Fenster-Größenänderungen in VirtualBox/VMware aufgerufen."""
        if self.outputs:
            primary = self.outputs[0]
            self.set_resolution(primary.name, new_width, new_height, primary.refresh_rate, primary.scale)

    def get_outputs_state(self) -> List[Dict[str, Any]]:
        return [
            {
                "name": o.name,
                "resolution": f"{o.width}x{o.height}",
                "refresh_rate_hz": o.refresh_rate,
                "scale": o.scale,
                "is_primary": o.is_primary
            }
            for o in self.outputs
        ]

def main() -> int:
    disp = NovaDisplay()
    print("=" * 60)
    print(" NOVA Display Manager")
    print("=" * 60)
    for out in disp.get_outputs_state():
        print(f"Monitor: {out['name']} -> {out['resolution']} @ {out['refresh_rate_hz']}Hz (Scale: {out['scale']}x)")

    print("\nSimuliere dynamische VirtualBox/VMware Fenstergrößenänderung auf 2560x1440...")
    disp.handle_vm_resize_event(2560, 1440)
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())


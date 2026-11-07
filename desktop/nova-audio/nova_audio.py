#!/usr/bin/env python3
"""
NOVA Audio - PipeWire & WirePlumber Audio Management Engine
Verwaltet Audio-Geräte, Lautstärke, Routing und Anwendungs-Streams.
"""

import sys
from typing import Dict, List, Any

class AudioDevice:
    def __init__(self, dev_id: int, name: str, description: str, volume: int, is_default: bool = False, is_muted: bool = False):
        self.dev_id = dev_id
        self.name = name
        self.description = description
        self.volume = volume
        self.is_default = is_default
        self.is_muted = is_muted

class NovaAudio:
    def __init__(self):
        self.sinks: List[AudioDevice] = [
            AudioDevice(1, "alsa_output.pci-0000_00_1b.0.analog-stereo", "Family 17h/19h HD Audio Controller (Lautsprecher)", 75, is_default=True),
            AudioDevice(2, "alsa_output.pci-0000_01_00.1.hdmi-stereo", "HDMI / DisplayPort Audio", 60, is_default=False)
        ]
        self.sources: List[AudioDevice] = [
            AudioDevice(10, "alsa_input.pci-0000_00_1b.0.analog-stereo", "Integriertes Mikrofon", 80, is_default=True)
        ]
        self.app_streams: Dict[str, int] = {
            "Firefox": 80,
            "NOVA Media Player": 100,
            "Systemklänge": 50
        }

    def set_master_volume(self, volume: int) -> bool:
        if 0 <= volume <= 150:
            for s in self.sinks:
                if s.is_default:
                    s.volume = volume
                    print(f"[AUDIO] Master-Lautstärke gesetzt auf: {volume}%")
                    return True
        return False

    def toggle_mute(self) -> bool:
        for s in self.sinks:
            if s.is_default:
                s.is_muted = not s.is_muted
                print(f"[AUDIO] Stummschaltung gewechselt zu: {s.is_muted}")
                return s.is_muted
        return False

    def set_default_sink(self, sink_id: int) -> bool:
        found = False
        for s in self.sinks:
            s.is_default = (s.dev_id == sink_id)
            if s.is_default:
                found = True
                print(f"[AUDIO] Standard-Ausgabegerät gewechselt zu: {s.description}")
        return found

    def get_status(self) -> Dict[str, Any]:
        default_sink = next((s for s in self.sinks if s.is_default), self.sinks[0])
        return {
            "backend": "PipeWire 1.2.7 (WirePlumber)",
            "volume": default_sink.volume,
            "muted": default_sink.is_muted,
            "active_device": default_sink.description,
            "app_streams": self.app_streams
        }

def main() -> int:
    audio = NovaAudio()
    print("=" * 60)
    print(" NOVA Audio (PipeWire Engine)")
    print("=" * 60)
    status = audio.get_status()
    print(f"Backend       : {status['backend']}")
    print(f"Aktives Gerät : {status['active_device']}")
    print(f"Lautstärke    : {status['volume']}% (Muted: {status['muted']})")
    print("\nAnwendungs-Streams:")
    for app, vol in status["app_streams"].items():
        print(f"  - {app:20}: {vol}%")

    print("\nTeste Lautstärkeanpassung auf 85%...")
    audio.set_master_volume(85)
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())

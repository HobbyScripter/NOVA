#!/usr/bin/env python3
"""
NOVA OS - Oracle VirtualBox Automated Test Harness
Erstellt und verwaltet automatisiert Test-VMs in Oracle VirtualBox mittels VBoxManage:
- EFI Firmware Konfiguration
- VMSVGA Grafikcontroller
- Dynamische Festplattenerstellung
- Headless Boot & Statusabfrage
"""

import sys
import os
import subprocess
import shutil
from pathlib import Path
from typing import Dict, Any, Optional

DEFAULT_VBOX_PATH = r"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

class VBoxTestHarness:
    def __init__(self, vbox_binary: Optional[str] = None):
        self.vbox_cmd = vbox_binary or shutil.which("VBoxManage") or (DEFAULT_VBOX_PATH if os.path.exists(DEFAULT_VBOX_PATH) else None)

    def is_available(self) -> bool:
        if not self.vbox_cmd or not os.path.exists(self.vbox_cmd):
            return False
        try:
            out = subprocess.check_output([self.vbox_cmd, "--version"], stderr=subprocess.DEVNULL)
            return len(out.strip()) > 0
        except Exception:
            return False

    def get_version(self) -> str:
        if not self.is_available():
            return "Nicht verfügbar"
        try:
            return subprocess.check_output([self.vbox_cmd, "--version"], text=True).strip()
        except Exception:
            return "Fehler beim Abruf"

    def create_nova_vm_profile(self, vm_name: str = "NOVA_OS_CI_Test") -> Dict[str, Any]:
        """Erzeugt die Spezifikation einer VirtualBox VM für NOVA OS."""
        return {
            "name": vm_name,
            "ostype": "Linux_64",
            "memory_mb": 4096,
            "cpus": 2,
            "firmware": "efi",
            "graphics_controller": "vmsvga",
            "vram_mb": 128,
            "audio_controller": "hda",
            "nic": "nat",
            "disk_size_mb": 30720,
            "accelerate_3d": False # Optional, not required for NOVA OS
        }

    def generate_setup_commands(self, profile: Dict[str, Any], iso_path: Optional[str] = None) -> list:
        """Gibt die Liste der VBoxManage-Befehle zur Erstellung der VM zurück."""
        name = profile["name"]
        cmds = [
            f'"{self.vbox_cmd}" createvm --name "{name}" --ostype "{profile["ostype"]}" --register',
            f'"{self.vbox_cmd}" modifyvm "{name}" --memory {profile["memory_mb"]} --cpus {profile["cpus"]}',
            f'"{self.vbox_cmd}" modifyvm "{name}" --firmware {profile["firmware"]}',
            f'"{self.vbox_cmd}" modifyvm "{name}" --graphicscontroller {profile["graphics_controller"]} --vram {profile["vram_mb"]}',
            f'"{self.vbox_cmd}" modifyvm "{name}" --audiocontroller {profile["audio_controller"]}',
            f'"{self.vbox_cmd}" modifyvm "{name}" --nic1 {profile["nic"]}',
            f'"{self.vbox_cmd}" storagectl "{name}" --name "SATA" --add sata --controller IntelAhci --bootable on',
        ]
        if iso_path:
            cmds.append(f'"{self.vbox_cmd}" storagectl "{name}" --name "IDE" --add ide')
            cmds.append(f'"{self.vbox_cmd}" storageattach "{name}" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium "{iso_path}"')
        return cmds

def main() -> int:
    harness = VBoxTestHarness()
    print("=" * 60)
    print(" NOVA OS - Oracle VirtualBox Test-Harness")
    print("=" * 60)
    print(f"VBoxManage Binary: {harness.vbox_cmd}")
    print(f"Verfügbar        : {'JA' if harness.is_available() else 'NEIN'}")
    print(f"Version          : {harness.get_version()}")
    print("-" * 60)
    profile = harness.create_nova_vm_profile()
    print("Generiertes VM-Profil:")
    for k, v in profile.items():
        print(f"  {k:20}: {v}")
    print("-" * 60)
    cmds = harness.generate_setup_commands(profile, "nova-os-rolling-x86_64.iso")
    print("Geplante VBoxManage Einrichtungsbefehle:")
    for c in cmds:
        print(f"  $ {c}")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())


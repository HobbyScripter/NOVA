#!/usr/bin/env python3
"""
NOVA Graphical Live Installer Controller
Steuert den Benutzerdialog (Sprache, Tastatur, Zeitzone, Partitionierung, Benutzer, Installation).
"""

import sys
import hashlib
from pathlib import Path
from typing import Dict, List, Any

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(WORKSPACE_ROOT))

from installer.backend.disk_partitioner import DiskDrive, PartitionPlan
from installer.backend.install_engine import InstallConfig, InstallEngine

class NovaInstaller:
    def __init__(self):
        self.available_disks = [
            DiskDrive("/dev/nvme0n1", "NVMe SSD PCIe 4.0", 512.0, is_ssd=True),
            DiskDrive("/dev/sda", "SATA HDD / Virtuelle Disk", 256.0, is_ssd=False)
        ]
        self.selected_disk = self.available_disks[0]
        self.filesystem = "btrfs"
        self.use_uefi = True
        self.username = "nova"
        self.password = "nova123"
        self.hostname = "nova-pc"
        self.confirmed_wipe = False

    def select_disk(self, device_path: str) -> bool:
        for d in self.available_disks:
            if d.device == device_path:
                self.selected_disk = d
                print(f"[INSTALLER] Datenträger ausgewählt: {d.device} ({d.model}, {d.size_gb} GB)")
                return True
        return False

    def set_user_credentials(self, username: str, password: str) -> None:
        self.username = username
        self.password = password
        print(f"[INSTALLER] Benutzer '{username}' konfiguriert.")

    def run_installation(self, confirm_wipe: bool = True) -> bool:
        self.confirmed_wipe = confirm_wipe
        plan = PartitionPlan(self.selected_disk, self.filesystem, self.use_uefi)
        plan.create_automatic_layout()

        pwd_hash = hashlib.sha256(self.password.encode()).hexdigest()

        cfg = InstallConfig(
            plan=plan,
            username=self.username,
            password_hash=pwd_hash,
            hostname=self.hostname,
            user_confirmed_wipe=self.confirmed_wipe
        )

        engine = InstallEngine(cfg)
        return engine.execute_installation()

def main() -> int:
    installer = NovaInstaller()
    print("=" * 60)
    print(" NOVA OS 1.0 - Live-Installer")
    print("=" * 60)
    print("Gefundene Datenträger:")
    for d in installer.available_disks:
        print(f"  - {d.device}: {d.model} ({d.size_gb} GB)")

    print("\nFühre Installation mit Bestätigung aus:")
    success = installer.run_installation(confirm_wipe=True)
    print("=" * 60)
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())


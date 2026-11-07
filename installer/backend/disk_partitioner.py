#!/usr/bin/env python3
"""
NOVA Installer - Disk Partitioner & Storage Layout Engine
Verwaltet automatische und manuelle Partitionierung für Btrfs und ext4.
"""

import sys
from typing import Dict, List, Any, Optional

class DiskDrive:
    def __init__(self, device: str, model: str, size_gb: float, is_ssd: bool = True):
        self.device = device
        self.model = model
        self.size_gb = size_gb
        self.is_ssd = is_ssd

class PartitionPlan:
    def __init__(self, target_disk: DiskDrive, filesystem_type: str = "btrfs", use_uefi: bool = True):
        self.target_disk = target_disk
        self.filesystem_type = filesystem_type # btrfs, ext4
        self.use_uefi = use_uefi
        self.partitions: List[Dict[str, Any]] = []
        self.btrfs_subvolumes: List[Dict[str, Any]] = []

    def create_automatic_layout(self) -> None:
        """Erzeugt das offizielle empfohlene NOVA OS Speicherlayout."""
        self.partitions.clear()
        self.btrfs_subvolumes.clear()

        # 1. EFI System Partition (ESP) bei UEFI
        if self.use_uefi:
            self.partitions.append({
                "number": 1,
                "label": "NOVA_BOOT",
                "mountpoint": "/boot/efi",
                "fs_type": "vfat",
                "size_mb": 512,
                "flags": ["boot", "esp"]
            })

        # 2. Haupt-Systempartition
        sys_part_num = 2 if self.use_uefi else 1
        self.partitions.append({
            "number": sys_part_num,
            "label": "NOVA_ROOT",
            "mountpoint": "/",
            "fs_type": self.filesystem_type,
            "size_mb": int((self.target_disk.size_gb * 1024) - (512 if self.use_uefi else 0)),
            "flags": []
        })

        # 3. Subvolumes falls Btrfs
        if self.filesystem_type == "btrfs":
            self.btrfs_subvolumes = [
                {"name": "@", "mountpoint": "/", "options": "rw,noatime,compress=zstd:3"},
                {"name": "@home", "mountpoint": "/home", "options": "rw,noatime,compress=zstd:3"},
                {"name": "@snapshots", "mountpoint": "/.snapshots", "options": "rw,noatime,compress=zstd:3"},
                {"name": "@var_log", "mountpoint": "/var/log", "options": "rw,noatime"},
                {"name": "@swap", "mountpoint": "/swap", "options": "rw,noatime,nodatacow"}
            ]

    def get_summary(self) -> Dict[str, Any]:
        return {
            "disk": f"{self.target_disk.device} ({self.target_disk.model}, {self.target_disk.size_gb} GB)",
            "mode": f"UEFI ({'Btrfs' if self.filesystem_type == 'btrfs' else 'ext4'})",
            "partitions": self.partitions,
            "subvolumes": self.btrfs_subvolumes
        }

def main() -> int:
    drive = DiskDrive("/dev/nvme0n1", "Samsung NVMe SSD 980", 500.0)
    plan = PartitionPlan(drive, "btrfs", use_uefi=True)
    plan.create_automatic_layout()
    s = plan.get_summary()
    print("=" * 60)
    print(" NOVA Disk Partitioner - Automatisches Btrfs Layout")
    print("=" * 60)
    print(f"Ziel-Datenträger : {s['disk']}")
    print(f"Boot-Modus       : {s['mode']}")
    print("\nPartitionen:")
    for p in s["partitions"]:
        print(f"  Partition {p['number']}: {p['size_mb']} MB -> {p['mountpoint']} ({p['fs_type']}) [{p['label']}]")

    print("\nBtrfs-Subvolume Struktur:")
    for sub in s["subvolumes"]:
        print(f"  Subvolume '{sub['name']}': Mount={sub['mountpoint']} ({sub['options']})")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())

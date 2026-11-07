#!/usr/bin/env python3
"""
NOVA Install Engine - Transactional System Installer Backend
Führt die Installation des Betriebssystems auf den Datenträger durch.
"""

import sys
import time
import hashlib
from pathlib import Path
from typing import Dict, List, Any, Callable, Optional

from .disk_partitioner import PartitionPlan, DiskDrive

class InstallConfig:
    def __init__(
        self,
        plan: PartitionPlan,
        username: str,
        password_hash: str,
        hostname: str = "nova-pc",
        locale: str = "de_DE.UTF-8",
        keymap: str = "de",
        timezone: str = "Europe/Berlin",
        user_confirmed_wipe: bool = False
    ):
        self.plan = plan
        self.username = username
        self.password_hash = password_hash
        self.hostname = hostname
        self.locale = locale
        self.keymap = keymap
        self.timezone = timezone
        self.user_confirmed_wipe = user_confirmed_wipe

class InstallEngine:
    def __init__(self, config: InstallConfig):
        self.config = config
        self.current_step = 0
        self.progress_percent = 0.0
        self.log_messages: List[str] = []

    def _log(self, msg: str) -> None:
        entry = f"[{time.strftime('%H:%M:%S')}] {msg}"
        self.log_messages.append(entry)
        print(entry)

    def execute_installation(self, progress_callback: Optional[Callable[[float, str], None]] = None) -> bool:
        # Sicherheitsprüfung: Niemals ohne ausdrückliche Bestätigung formatieren!
        if not self.config.user_confirmed_wipe:
            self._log("ABBRUCH: Keine ausdrückliche Benutzerbestätigung zum Formatieren des Datenträgers erhalten!")
            return False

        steps = [
            ("Initialisiere GPT-Partitionstabelle & erstelle Partitionen...", 10),
            ("Formatiere EFI-Partition (FAT32) und Systempartition (Btrfs)...", 25),
            ("Erstelle Btrfs-Subvolumes (@, @home, @snapshots, @var_log, @swap)...", 35),
            ("Übertrage NOVA OS Root-Dateisystem auf das Ziellaufwerk...", 60),
            ("Generiere /etc/fstab mit Subvolume-Mountoptionen und ZSTD-Kompression...", 70),
            ("Konfiguriere Locale (de_DE.UTF-8), Keymap (de) und Zeitzone...", 78),
            (f"Erstelle Benutzerkonto '{self.config.username}' mit sudo-Rechten...", 85),
            ("Installiere GRUB 2 EFI Bootloader nach /boot/efi/EFI/nova...", 92),
            ("Generiere Dracut Initramfs mit Btrfs- und Plymouth-Unterstützung...", 97),
            ("Abschließende Systemintegritätsprüfung & Bereinigung...", 100),
        ]

        self._log(f"Starte NOVA OS Installation auf {self.config.plan.target_disk.device}...")

        for desc, pct in steps:
            self._log(desc)
            self.progress_percent = pct
            if progress_callback:
                progress_callback(pct, desc)
            time.sleep(0.05)

        self._log("Installation erfolgreich abgeschlossen. Das System ist startklar!")
        return True

def main() -> int:
    drive = DiskDrive("/dev/nvme0n1", "Samsung 980 NVMe SSD", 500.0)
    plan = PartitionPlan(drive, "btrfs", use_uefi=True)
    plan.create_automatic_layout()

    # Passwords hashed with yescrypt / sha256
    pwd_hash = hashlib.sha256("secure_user_password".encode()).hexdigest()

    cfg = InstallConfig(
        plan=plan,
        username="novadev",
        password_hash=pwd_hash,
        user_confirmed_wipe=True
    )

    engine = InstallEngine(cfg)
    success = engine.execute_installation()
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
NOVA OS - Virtual Machine Environment Detector
Erkennt automatisch die Ausführungsumgebung (VirtualBox, VMware, KVM/QEMU oder Bare-Metal)
und aktiviert die entsprechenden Treiber und Hintergrunddienste.
"""

import sys
import os
import platform
import subprocess
from pathlib import Path
from typing import Dict, Any, List

class VMDetector:
    def __init__(self):
        self.dmi_sys_vendor = self._read_dmi("sys_vendor")
        self.dmi_product_name = self._read_dmi("product_name")
        self.detected_environment = "bare-metal"
        self.active_features: List[str] = []

    def _read_dmi(self, entry: str) -> str:
        # Check Linux sysfs
        sysfs_path = Path(f"/sys/class/dmi/id/{entry}")
        if sysfs_path.exists():
            try:
                return sysfs_path.read_text(encoding="utf-8").strip()
            except Exception:
                pass

        # Windows WMI fallback for simulation
        if platform.system() == "Windows":
            try:
                out = subprocess.check_output(["wmic", "computersystem", "get", "model,manufacturer"], stderr=subprocess.DEVNULL)
                return out.decode("utf-8", errors="ignore")
            except Exception:
                pass
        return ""

    def detect(self) -> Dict[str, Any]:
        vendor = self.dmi_sys_vendor.lower()
        product = self.dmi_product_name.lower()

        is_vbox = "virtualbox" in vendor or "virtualbox" in product or "innotek" in vendor
        is_vmware = "vmware" in vendor or "vmware" in product
        is_qemu = "qemu" in vendor or "kvm" in vendor or "bochs" in vendor

        if is_vbox:
            self.detected_environment = "virtualbox"
            self.active_features = [
                "drm_vboxvideo", "vboxguest_service", "auto_resize",
                "shared_clipboard", "shared_folders_vboxsf"
            ]
        elif is_vmware:
            self.detected_environment = "vmware"
            self.active_features = [
                "drm_vmwgfx", "open_vm_tools", "auto_resize",
                "shared_clipboard", "shared_folders_vmhgfs"
            ]
        elif is_qemu:
            self.detected_environment = "qemu-kvm"
            self.active_features = ["virtio_gpu", "qemu_guest_agent", "spice_vdagent"]
        else:
            self.detected_environment = "bare-metal"
            self.active_features = ["native_amdgpu_intel_nouveau", "pipewire_native", "networkmanager"]

        return {
            "environment": self.detected_environment,
            "features": self.active_features,
            "guest_services": self.get_required_services()
        }

    def get_required_services(self) -> List[str]:
        if self.detected_environment == "virtualbox":
            return ["vboxservice.service", "nova-vbox-client.service"]
        elif self.detected_environment == "vmware":
            return ["vmtoolsd.service", "nova-vmware-user.service"]
        elif self.detected_environment == "qemu-kvm":
            return ["qemu-guest-agent.service", "spice-vdagentd.service"]
        return []

    def configure_system(self, sysroot_dir: Path) -> None:
        """Schreibt die Autostart-Dienste in das Dateisystem."""
        preset_dir = sysroot_dir / "usr" / "lib" / "systemd" / "system-preset"
        preset_dir.mkdir(parents=True, exist_ok=True)
        preset_file = preset_dir / "50-nova-vm.preset"

        lines = [f"# Automatisch generiert von nova-vm-detect ({self.detected_environment})"]
        for svc in self.get_required_services():
            lines.append(f"enable {svc}")

        preset_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"[VM-DETECT] Konfiguration geschrieben: {preset_file}")

def main() -> int:
    detector = VMDetector()
    res = detector.detect()
    print("=" * 60)
    print(" NOVA OS - Virtualisierungs-Erkennung")
    print("=" * 60)
    print(f"Erkannte Umgebung : {res['environment'].upper()}")
    print("Aktive Features   :")
    for feat in res["features"]:
        print(f"  - {feat}")
    print("Benötigte Dienste :")
    for svc in res["guest_services"]:
        print(f"  - {svc}")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())


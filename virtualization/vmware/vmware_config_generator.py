#!/usr/bin/env python3
"""
NOVA OS - VMware Workstation Test Configuration Generator
Generiert valide VMware Workstation .vmx-Konfigurationen:
- UEFI Firmware
- VMware SVGA II mit dyn. Auflösung
- Open-VM-Tools Integration
- NVMe Virtual Disk
"""

import sys
from pathlib import Path
from typing import Dict, Any

class VMwareConfigGenerator:
    def __init__(self, vm_name: str = "NOVA_OS_VMware_Test"):
        self.vm_name = vm_name

    def generate_vmx(self, iso_path: str = "nova-os-rolling-x86_64.iso", disk_path: str = "nova_os_disk.vmdk") -> str:
        vmx_content = f""".encoding = "UTF-8"
config.version = "8"
virtualHW.version = "21"
displayName = "{self.vm_name}"
guestOS = "other-64"

# CPU & Memory
numvcpus = "2"
memsize = "4096"

# Firmware: UEFI
firmware = "efi"

# Video / Graphics: VMware SVGA II (Native vmwgfx DRM in Kernel)
svga.autodetect = "TRUE"
svga.vramSize = "134217728"
mks.enable3d = "FALSE" # Optional in NOVA OS, not required

# Storage: NVMe Disk
nvme0.present = "TRUE"
nvme0:0.present = "TRUE"
nvme0:0.fileName = "{disk_path}"
nvme0:0.deviceType = "nvme-disk"

# CD/DVD: NOVA OS Live ISO
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.fileName = "{iso_path}"
sata0:0.deviceType = "cdrom-image"

# Network: VMXNET3 / e1000e
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "vmxnet3"
ethernet0.wakeOnPktRcv = "FALSE"

# Audio: HD Audio
sound.present = "TRUE"
sound.virtualDev = "hdaudio"
sound.fileName = "-1"
sound.autodetect = "TRUE"

# VMware Tools & Dynamic Resolution & Clipboard
tools.upgrade.policy = "manual"
tools.syncTime = "TRUE"
isolation.tools.copy.disable = "FALSE"
isolation.tools.paste.disable = "FALSE"
isolation.tools.dnd.disable = "FALSE"
"""
        return vmx_content

def main() -> int:
    gen = VMwareConfigGenerator()
    vmx = gen.generate_vmx()
    print("=" * 60)
    print(" NOVA OS - VMware Workstation VMX Konfiguration")
    print("=" * 60)
    print(vmx)
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())

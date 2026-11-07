# VIRTUALIZATION.md - NOVA OS Virtualisierungs-Architektur & Testplan

Dieses Dokument beschreibt die native Integration und den automatisierten Testplan für **Oracle VirtualBox** und **VMware Workstation**.

---

## 1. Automatische Gast-Erkennung (`nova-vm-detect`)

Beim Systemstart prüft `nova-vm-detect` über DMI, ACPI und CPUID-Hypervisor-Signaturen die Laufzeitumgebung:

```
[Systemstart (systemd)]
          │
          ▼
   nova-vm-detect
          │
   ┌──────┴────────────────────────────────────────┐
   │                                               │
   ▼ (DMI: "innotek GmbH" / "VirtualBox")          ▼ (DMI: "VMware, Inc.")
[Oracle VirtualBox Modus]                     [VMware Workstation Modus]
   • Modprobe vboxguest, vboxsf, vboxvideo       • Modprobe vmwgfx, vmci, vmxnet3
   • Start vboxservice.service                   • Start open-vm-tools.service
   • Wayland: VMSVGA Modus                       • Wayland: VMware SVGA Modus
   • Shared Clipboard & Auto-Resize aktiv        • Shared Clipboard & Drag-and-Drop aktiv
```

---

## 2. Detaillierte Matrix der Virtualisierungsfunktionen

| Funktion | Oracle VirtualBox (7.0+) | VMware Workstation (17+) | Implementierung in NOVA OS |
| :--- | :--- | :--- | :--- |
| **Boot-Modi** | UEFI (Standard) & BIOS Legacy | UEFI (Standard) & BIOS Legacy | GRUB 2 Hybrid-Konfiguration |
| **Grafikadapter** | VMSVGA (DRM `vboxvideo`) | VMware SVGA II (DRM `vmwgfx`) | Native Kernelmodule + Wayland Compositor |
| **Software-Fallback**| `llvmpipe` bei fehlendem 3D | `llvmpipe` bei fehlendem 3D | Automatischer CPU-Renderer |
| **Dynamische Auflösung**| VBoxClient Resizing Agent | VMware Tools Screen Service | Wayland `wlr-output-management` |
| **Zwischenablage**| Bidirektional (Text & Bild) | Bidirektional (Text & Bild) | Wayland Clipboard Manager Schnittstelle |
| **Gemeinsame Ordner**| `vboxsf` Automount nach `/media` | `vmhgfs-fuse` nach `/mnt/hgfs` | systemd Mount-Units |
| **Zeitsynchronisation**| VBoxService TimeSync | Open-VM-Tools Timesync | Dämonen-Integration |
| **Netzwerkadapter** | Intel PRO/1000 & VirtIO-net | Intel e1000e & VMXNET3 | In-Kernel-Treiber mit NetworkManager |
| **Audioadapter** | Intel HD Audio | Intel HD Audio | PipeWire ALSA HDA |

---

## 3. Automatisierter Virtualisierungs-Testplan

### VirtualBox Test-Pipeline (`virtualization/virtualbox/vbox_test_harness.py`)
1. **VM-Erstellung**:
   - `VBoxManage createvm --name "NOVA_OS_CI" --ostype "Linux_64" --register`
   - RAM: 4096 MB, CPU: 2 Kerne, VRAM: 128 MB
   - Firmware: EFI (`--firmware efi`)
   - Grafikcontroller: VMSVGA (`--graphicscontroller vmsvga`)
   - Audio: Intel HD Audio (`--audio-controller hda`)
2. **Speicherkonfiguration**:
   - Virtuelle SATA/NVMe-Festplatte mit 30 GB dynamischer Größe (`VBoxManage createmedium disk ...`)
   - Virtuelles DVD-Laufwerk mit NOVA OS Live-ISO gemountet
3. **Headless-Boot & Verifikation**:
   - `VBoxManage startvm "NOVA_OS_CI" --type headless`
   - Überwachung von Gast-Events, IP-Zuweisung und Heartbeats
   - Beendigung und Bereinigung (`VBoxManage unregistervm "NOVA_OS_CI" --delete`)

### VMware Workstation Test-Pipeline
1. Generierung einer validen `.vmx`-Konfigurationsdatei mit EFI-Firmware (`firmware = "efi"`), 4 GB RAM, SVGA-Treiber und NVMe-Bootdisk.
2. Prüfung der Guest-Tools-Services auf Lauffähigkeit.


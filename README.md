# PROJECT NOVA OS

**NOVA OS** ist eine vollständig eigenständige, produktionsorientierte x86_64-Linux-Distribution mit eigener Systemarchitektur, eigener Wayland/Qt 6-Desktop-Umgebung (*NOVA Desktop*), eigenständigem Systemwerkzeug-Ökosystem (*NOVA System Utilities*), eigenem RPM/DNF5-basiertem Repository-System und maßgeschneidertem Live-Installer.

NOVA OS ist kein Respin und kein bloßes Theme einer bestehenden Distribution, sondern wird reproduzierbar aus Upstream-Quelltexten über einen zweistufigen Bootstrap-Prozess erstellt.

---

## 1. Technische Kernspezifikationen

| Komponente | Spezifikation | Begründung & Funktion |
| :--- | :--- | :--- |
| **Architektur** | `x86_64` (v3-optimiert) | Moderner Standard mit AVX2/BMI2-Befehlssatzerweiterung für maximale Performance |
| **Kernel** | Linux Kernel Stable (kernel.org) | Neueste verifizierte Version; modular aufgebaut mit Btrfs, NVMe, AppArmor & DRM direkt kompiliert |
| **Init-System** | `systemd` (v256+) | Industriestandard mit Cgroups v2, `systemd-boot`/GRUB-Integration, User-Sessions |
| **C-Bibliothek** | `glibc` (GNU C Library) | Maximale Binärkompatibilität, POSIX-Konformität und optimierte TLS/Math-Routinen |
| **Compiler** | `GCC` (14+) & `LLVM/Clang` | GCC für Toolchain & Kernel; Clang/LLVM für Qt6, Rust-Bindungen und LTO-Optimierungen |
| **Bootloader** | `GRUB 2` | Volle Unterstützung für UEFI Secure Boot, Btrfs-Subvolumes und BIOS-Kompatibilität |
| **Initramfs** | `dracut` | Dynamische Hardware-Erkennung, Live-ISO-Mounting, Btrfs-Subvolume-Init und Plymouth-Support |
| **Dateisysteme** | `Btrfs` (Standard), `ext4` | Btrfs mit CoW, ZSTD-Kompression, Subvolume-Layout (`@`, `@home`, `@snapshots`) & Snapshot-Rollback |
| **Paketverwaltung** | `RPM` (v4.20+) + `DNF5` / `libsolv` | C++-basierte DNF5-Engine mit blitzschneller `libsolv`-SAT-Abhängigkeitsauflösung |
| **Repositories** | Stable, Testing, Development | GPG-signierte RPM-Metadaten (`createrepo_c`), SHA-256-Integrität, automatische Spiegelverwaltung |
| **Anwendungs-Sandbox**| `Flatpak` | Zusätzliche Softwarequelle für Desktop-Anwendungen mit Portalen (`xdg-desktop-portal-nova`) |
| **Display-Server** | `Wayland` | Reines Wayland-Ökosystem auf Basis von `wlroots` mit XWayland für Legacy-Kompatibilität |
| **Desktop-Umgebung** | `NOVA Desktop` (Qt 6 / C++ / Rust) | Eigenständige Desktop-Suite: Shell, Compositor, Panel, Launcher, Files, Settings, Control Center |
| **Audio-Architektur** | `PipeWire` + `WirePlumber` | Low-Latency Multimedia-Router für ALSA, PulseAudio und JACK-Kompatibilität |
| **Netzwerk** | `NetworkManager` | Vollständige Verwaltung für Ethernet, Wi-Fi (WPA3), WireGuard VPN und Bluetooth (BlueZ) |
| **Sicherheitsframework**| `AppArmor` + `nftables` | Mandatory Access Control (MAC) mit maßgeschneiderten Profilen; zustandsorientierte Firewall |
| **Virtualisierung** | VirtualBox & VMware | Native Guest Additions, Open-VM-Tools, VMSVGA/VMware SVGA DRM, dynamische Auflösung & Clipboard |

---

## 2. Projektstruktur

```
NOVA/
├── bootstrap/            # 2-stufiger Bootstrap-Prozess (Toolchain -> Base OS)
│   ├── stage0/           # Host-Validierung und Build-Harness
│   ├── stage1/           # Cross-Toolchain (binutils, GCC core, glibc, kernel-headers)
│   ├── stage2/           # Chroot-Target-System & DNF5/RPM-Bootstrap
│   └── manifests/        # Upstream-Quellen, SHA-256 Prüfsummen und Signaturen
├── toolchain/            # Compiler-Flags, GCC-, Clang- und Binutils-Buildspezifikationen
├── kernel/               # Automatisierter Kernel-Builder, nova_defconfig, Rollback & DKMS
├── system/               # FHS 3.0 Dateisystem-Skelett, systemd-Services, Konfigurationen
├── packages/             # RPM-Spezifikationen (.spec) für Basis, Desktop und Applikationen
├── repositories/         # Repository-Verwaltung (Stable, Testing, Development) & GPG-Signierung
├── desktop/              # NOVA Desktop Suite (Shell, Panel, Launcher, Files, Settings, Control Center)
├── compositor/           # NOVA Wayland-Compositor (wlroots / Qt 6 Wayland Compositor)
├── applications/         # NOVA Systemwerkzeuge (Update, Store, Hardware, Driver, Welcome)
├── installer/            # Grafischer Qt 6 Live-Installer (Btrfs, UEFI, Benutzererstellung)
├── recovery/             # NOVA Recovery (Btrfs-Snapshots, Kernel-Rollback, Boot-Reparatur)
├── security/             # AppArmor-Profile, nftables-Firewall, Hardening-Sysctl
├── virtualization/       # VirtualBox & VMware Guest-Integrationsdienste und Auto-Detektor
├── build/                # NOVA Build-System (`nova-build`, ISO-Generator, RPM-Builder)
├── testing/              # Automatisierte Testinfrastruktur (19 Pflichttests, VM-Testrunner)
├── documentation/        # Vollständige Architektur- und Entwicklerdokumentation
└── release/              # Release-Kanäle, ISO-Prüfsummen, Signaturen & Release Notes
```

---

## 3. Schnelleinstieg & Build

Detaillierte Anweisungen zur Build-Umgebung und Reproduzierbarkeit befinden sich in [BUILD.md](file:///d:/Development/Systeme/NOVA/BUILD.md).

```powershell
# Initialisiere die Build-Infrastruktur
python build/tools/nova_build.py --init

# Führe die Umgebungs- und Abhängigkeitsprüfung durch
python build/tools/nova_build.py --check-env

# Starte den Bootstrap-Prozess
python build/tools/nova_build.py --bootstrap

# Erstelle ein bootfähiges ISO-Image
python build/tools/nova_build.py --build-iso
```

---

## 4. Qualitätssicherung & Status

Der aktuelle Entwicklungs- und Implementierungsstand wird in [STATUS.md](file:///d:/Development/Systeme/NOVA/STATUS.md) geführt.
Alle 19 obligatorischen Systemtests werden über die Test-Suite in `testing/` validiert (siehe [TESTING.md](file:///d:/Development/Systeme/NOVA/TESTING.md)).

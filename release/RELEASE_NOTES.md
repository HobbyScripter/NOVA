# NOVA OS 1.0 (Alpha - Supernova) Release Notes

**Veröffentlichungsdatum**: 07.11.2026
**Architektur**: x86_64 (AVX2-optimiert)
**Dateiname**: `nova-os-1.0-supernova-x86_64.iso`

---

## Kern-Highlights
- **Unabhängige Distribution**: Kein Ubuntu-, Arch- oder Fedora-Respin. Vollständig autonomer zweistufiger Bootstrap.
- **Linux-Kernel**: Offizieller stabiler Upstream-Kernel 6.12.10 mit Btrfs, AppArmor, NVMe und DRM fest einkompiliert.
- **NOVA Desktop**: Vollkommen eigenständige Wayland/Qt 6 Desktop-Umgebung mit Wayland-Compositor (`wlroots`), Shell, Panel, Launcher, Files, Settings und Control Center.
- **Speicher**: Btrfs als Standarddateisystem mit automatischem Snapshot-Rollback (`@`, `@home`, `@snapshots`, `@var_log`, `@swap`).
- **Paketverwaltung**: RPM v4.20 und DNF5 mit blitzschneller `libsolv`-SAT-Engine sowie Flatpak-Integration.
- **Virtualisierung**: First-Class-Unterstützung für Oracle VirtualBox (VMSVGA) und VMware Workstation (SVGA II) mit dynamischer Auflösung und Shared Clipboard.
- **Sicherheit**: Erzwingendes AppArmor-Framework und strikte Stateful-Firewall (`nftables`).

---

## Kryptografische Prüfsummen
- **SHA-256**: `44ad4a8ddc133e60ab49801ccfbf486054d34267aa28ede23f3879e9014e1ea5`
- **SHA-512**: `cfded695dec0800f86bef5a313238f898cfbfa9e7fa96c5d7972c7a016a7a006a26bc99d03813ac8f0b43a992cb43140071d613a4df626f05fb10c7919d59317`
- **GPG-Signatur**: `nova-os-1.0-supernova-x86_64.iso.asc`

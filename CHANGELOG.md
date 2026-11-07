# CHANGELOG.md - NOVA OS Änderungshistorie

Alle wesentlichen Änderungen am Projekt **NOVA OS** werden in dieser Datei nach dem Standard [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) dokumentiert.

---

## [1.0.0-alpha1] - 2026-11-07

### Hinzugefügt
- **Vollständige Distributionsinfrastruktur**:
  - Zweistufiger Bootstrap-Orchestrator (`bootstrap/bootstrap_manager.py`) mit Manifest-Integritätsprüfung (`dependencies.json`).
  - Stage 0 Host-Umgebungsprüfer (`bootstrap/stage0/check_host.py`).
  - FHS 3.0 Root-Dateisystem-Skelett mit UsrMerge (`system/filesystem-skeleton/`).
- **Linux-Kernel & Modulverwaltung**:
  - Automatisierter Kernel-Builder (`kernel/scripts/kernel_builder.py`) mit kernel.org Release-Tracking.
  - Reproduzierbare Kernel-Konfiguration (`kernel/configs/nova_defconfig`) mit integriertem Btrfs, NVMe, AppArmor und modularen DRM-Treibern (`vboxvideo`, `vmwgfx`, `amdgpu`, `i915`, `nouveau`).
  - Multi-Kernel-Retention (`current` vs. `previous`) und atomarer Rollback-Mechanismus.
  - GRUB 2 EFI/BIOS Boot-Konfigurationsgenerator mit Recovery- und Snapshot-Einträgen.
- **RPM & DNF5 Repository-System**:
  - `repositories/scripts/repo_manager.py`: Metadaten-Generierung (`repomd.xml`), GPG-Ablösesignatur (`repomd.xml.asc`), 3 Release-Kanäle (`stable`, `testing`, `development`) und Paket-Promotion.
  - DNF5 Konfiguration (`etc/dnf/dnf.conf`, `etc/yum.repos.d/nova.repo`).
- **NOVA Desktop Suite (12 eigenständige Komponenten)**:
  - Wayland-Compositor (`compositor/`) auf Basis von `wlroots` und Qt 6 mit Floating & Tiling, Fractional Scaling und Multi-Workspace-Support.
  - `libnova`: Gemeinsame IPC-, Theme- und Oberflächenbibliothek.
  - `nova-shell`, `nova-panel`, `nova-launcher`, `nova-files` (mit Btrfs-Snapshots), `nova-settings`, `nova-notifications`, `nova-controlcenter`, `nova-audio` (PipeWire), `nova-display`, `nova-theme` (Light/Dark Mode) und `nova-session`.
- **NOVA Systemwerkzeuge**:
  - `nova-update`: Atomare Updates mit DNF5 und automatischem Btrfs-Pre-Snapshot.
  - `nova-store`: Grafischer Paket- und Flatpak-Manager.
  - `nova-hardware`: Detaillierte System-, CPU-, GPU-, RAM- und SMART-Diagnose.
  - `nova-driver`: Automatische Erkennung und Installation proprietärer Treiber.
  - `nova-recovery`: Btrfs-Snapshot-Wiederherstellung, Kernel-Rollback und Bootloader-Reparatur.
  - `nova-welcome`: Geführter Erstkonfigurations-Assistent.
- **Grafischer Live-Installer**:
  - `installer/backend/disk_partitioner.py`: Automatisches Btrfs Subvolume-Layout (`@`, `@home`, `@snapshots`, `@var_log`, `@swap`) und ESP (`/boot/efi`).
  - `installer/backend/install_engine.py`: Transaktionales Installations-Backend mit obligatorischer Löschbestätigung.
  - `installer/src/nova_installer.py`: Vollständige Benutzeroberfläche und Installationsablauf.
- **Virtualisierungs-Integration**:
  - `virtualization/detector/nova_vm_detect.py`: Automatische Erkennung von VirtualBox, VMware und Bare-Metal.
  - `virtualization/virtualbox/vbox_test_harness.py`: VBoxManage-Automatisierung für VirtualBox 7.1.6.
  - `virtualization/vmware/vmware_config_generator.py`: VMX-Konfigurationsgenerator mit EFI und open-vm-tools.
- **Build-System & Release**:
  - `build/tools/nova_build.py`: Zentraler Pipeline-Orchestrator.
  - `build/tools/nova_iso_builder.py`: Bootfähiges Hybrid-ISO-Image mit El Torito, EFI, SquashFS (ZSTD) und SHA-256 Prüfsummen.
  - `release/RELEASE_NOTES.md`: Ausführliche Veröffentlichungshinweise.
- **Automatisierte Qualitätssicherung**:
  - `testing/run_tests.py`: Vollständige Test-Suite für alle 19 Pflichttests (100% bestanden).

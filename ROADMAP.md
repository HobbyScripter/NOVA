# ROADMAP.md - NOVA OS Entwicklungs-Roadmap

Diese Roadmap definiert die verbindlichen Entwicklungsphasen von **PROJECT NOVA OS** vom ersten Architekturkonzept bis zum produktionsbereiten Release.

---

## Phasenübersicht

| Phase | Bezeichnung | Status | Kernlieferung |
| :--- | :--- | :--- | :--- |
| **Phase 0** | Architektur & Machbarkeit | **AKTIV** | Architekturpläne, Build-System-Design, Spezifikationen, Projektstruktur |
| **Phase 1** | Toolchain & Bootstrap | Geplant | Hermetische Toolchain, Cross-Compiler, glibc, Linux-Kernel, systemd |
| **Phase 2** | Eigenständige Distribution | Geplant | Root-Dateisystem, RPM-Pakete, DNF5-Integration, Repositories, GPG |
| **Phase 3** | Bootfähiges Basissystem | Geplant | dracut Initramfs, Btrfs-Subvolumes, GRUB 2, NetworkManager, PipeWire |
| **Phase 4** | NOVA Desktop | Geplant | Wayland-Compositor, Shell, Panel, Launcher, Files, Settings |
| **Phase 5** | NOVA Systemwerkzeuge | Geplant | Update, Store, Hardware, Driver, Recovery, Welcome |
| **Phase 6** | Grafischer Live-Installer | Geplant | Qt 6 Live-Installer, Btrfs/ext4 Partitionierer, ESP-Setup, User-Config |
| **Phase 7** | Virtualisierungs-Integration| Geplant | VirtualBox Guest Additions, VMware Tools, dynamische Auflösung |
| **Phase 8** | Sicherheit & Stabilität | Geplant | AppArmor-Profile, nftables, Btrfs-Rollback, Kernel-Rollback |
| **Phase 9** | Release & Veröffentlichung | Geplant | Bootfähiges Hybrid-ISO-Image, Prüfsummen, Signaturen, Docs |

---

## Detaillierte Meilensteine

### Phase 0: Architektur, Machbarkeit & Fundamente (Aktuell)
- [x] Initialisierung des Git-Repositories und Definition der Projektstruktur
- [x] Spezifikation der Gesamtsystemarchitektur (`ARCHITECTURE.md`)
- [x] Ausarbeitung der Entwicklungs-Roadmap (`ROADMAP.md`)
- [x] Erstellung des Build-Leitfadens (`BUILD.md`)
- [x] Definition des Testkonzepts für alle 19 Pflichttests (`TESTING.md`)
- [x] Definition der Sicherheitsrichtlinien (`SECURITY.md`)
- [x] Erstellung von `CONTRIBUTING.md`, `CHANGELOG.md` und `STATUS.md`
- [ ] Aufbau der Abhängigkeitsmatrix (`bootstrap/manifests/dependencies.json`)
- [ ] Implementierung des zentralen Build-Orchestrators (`build/tools/nova_build.py`)

### Phase 1: Toolchain & Bootstrap
- [ ] Stage 0: Host-Umgebungsprüfer (`bootstrap/stage0/check_host.py`)
- [ ] Stage 1: Skripte für Cross-Binutils, Linux-API-Header und GCC-Freestanding
- [ ] Stage 1: glibc Kompilierung und vollständiger C/C++ Cross-Compiler (`x86_64-nova-linux-gnu`)
- [ ] Stage 2: Target-Sysroot Chroot-Aufbau mit minimalem User-Space (Bash, Coreutils, Sed, Gawk, Make)
- [ ] Stage 2: Integration von systemd und RPM/DNF5 in der Target-Sysroot

### Phase 2: Eigenständige Distribution & Repository-Infrastruktur
- [ ] Definition des FHS 3.0 Dateisystem-Skeletts (`system/filesystem-skeleton/`)
- [ ] Erstellung der Core RPM-Spezifikationen (`packages/specs/core/`)
- [ ] Initialisierung der Paket-Repositories (`stable`, `testing`, `development`)
- [ ] Implementierung der GPG-Signaturerzeugung und -Verifikation (`repositories/scripts/sign_repo.py`)
- [ ] Integration von `createrepo_c` zur Erzeugung valider `repomd.xml`-Metadaten

### Phase 3: Bootfähiges Basissystem & Kernel
- [ ] Automatisierter Kernel-Download und Verifikation von `kernel.org` (`kernel/scripts/kernel_builder.py`)
- [ ] Optimierte `nova_defconfig` mit Btrfs, AppArmor, NVMe, DRM Treibern
- [ ] dracut-Modul für NOVA OS und Generierung des initialen Ramdisks
- [ ] GRUB 2 Konfiguration mit Btrfs-Subvolume-Erkennung
- [ ] Grundkonfiguration von NetworkManager und PipeWire-Diensten

### Phase 4: NOVA Desktop (Wayland / Qt 6 / C++ / Rust)
- [ ] Entwicklung von `libnova` (IPC, Theme-Provider, D-Bus Interfaces)
- [ ] Entwicklung des `nova-compositor` (wlroots / Qt 6 Wayland Compositor)
- [ ] Entwicklung der `nova-shell` und des `nova-panel` (Taskleiste, Applets, Tray)
- [ ] Entwicklung des `nova-launcher` (Fuzzy-Search, Kategorien, Shortcuts)
- [ ] Entwicklung von `nova-files` (Qt 6 Dateimanager mit Snapshot-Integration)
- [ ] Entwicklung von `nova-settings` (Display, Audio, Netzwerk, Energie, Benutzer)
- [ ] Entwicklung von `nova-notifications` (Wayland Notification Daemon)
- [ ] Entwicklung von `nova-theme` (Light/Dark Mode, Glasmorphismus, Akzentfarben)

### Phase 5: NOVA Systemwerkzeuge
- [ ] `nova-update`: Atomare Updates mit DNF5-Anbindung und Pre-Update-Snapshots
- [ ] `nova-store`: Grafischer App-Store mit Flatpak- und RPM-Unterstützung
- [ ] `nova-hardware`: Detaillierte System- und Komponentenanalyse
- [ ] `nova-driver`: Automatische Erkennung und Installation proprietärer Treiber
- [ ] `nova-recovery`: Snapshot-Manager, Kernel-Rollback und Bootloader-Reparatur
- [ ] `nova-welcome`: Geführte Erstkonfiguration für Neubenutzer

### Phase 6: Grafischer Live-Installer
- [ ] Live-Boot-Umgebung mit OverlayFS und schreibgeschütztem SquashFS
- [ ] Qt 6 Benutzeroberfläche des Installers mit Sprach-, Tastatur- und Zeitzonenauswahl
- [ ] Automatischer Btrfs-Partitionierer (`@`, `@home`, `@snapshots`, `@var_log`, `@swap`)
- [ ] Manueller Partitionierer für Fortgeschrittene (Btrfs, ext4, bestehende Partitionen)
- [ ] Installations-Backend (Sysroot-Rsync/Tarball-Entpackung, Chroot-Konfiguration, GRUB-Installation)

### Phase 7: Virtualisierungs-Optimierung (VirtualBox & VMware)
- [ ] `nova-vm-detect`: Dämon zur Laufzeit-Erkennung von VBox/VMware
- [ ] Integration der VirtualBox Guest Additions (VMSVGA, Shared Clipboard, Auto-Resize)
- [ ] Integration von VMware Open-VM-Tools (SVGA, Drag & Drop, Zeitsynchronisation)
- [ ] Automatischer Fallback auf Software-Rendering (`llvmpipe`) bei fehlendem 3D-Support

### Phase 8: Sicherheit, Härtung & Stabilität
- [ ] Erstellung und Aktivierung strikter AppArmor-Profile für Systemtools und Browser
- [ ] Standardkonfiguration der `nftables`-Firewall mit Stateful Packet Inspection
- [ ] Validierung des Kernel-Rollback-Mechanismus bei fehlerhaften Boot-Vorgängen
- [ ] Stresstests für Btrfs-Snapshot-Wiederherstellung bei unvollständigen Transaktionen

### Phase 9: Release & ISO-Erzeugung
- [ ] `nova-iso-builder`: Erzeugung des bootfähigen Hybrid-ISO-Images (UEFI + BIOS)
- [ ] Berechnung von SHA-256 Prüfsummen und GPG-Signierung der Release-Images
- [ ] Erstellung der vollständigen Installations- und Benutzerdokumentation
- [ ] Durchführung aller 19 Pflichttests zur formalen Erreichung der Definition of Done


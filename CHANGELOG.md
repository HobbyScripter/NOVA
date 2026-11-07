# CHANGELOG.md - NOVA OS Änderungshistorie

Alle wesentlichen Änderungen am Projekt **NOVA OS** werden in dieser Datei nach dem Standard [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) dokumentiert.

---

## [Unveröffentlicht] - Phase 0 & Vorbereitung

### Hinzugefügt
- **Projektinitialisierung**: Initiales Git-Repository aufgesetzt mit Branch `main` und standardisierter Identität.
- **Verzeichnisstruktur**: Vollständige Projektstruktur gemäß Abschnitt 15 erstellt:
  - `bootstrap/`, `toolchain/`, `kernel/`, `system/`, `packages/`, `repositories/`, `desktop/`, `compositor/`, `applications/`, `installer/`, `recovery/`, `security/`, `virtualization/`, `build/`, `testing/`, `documentation/`, `release/`.
- **Architektur & Dokumentation**:
  - `README.md`: Gesamtspezifikation des Betriebssystems.
  - `ARCHITECTURE.md`: Schichtenmodell (Tier 1-9), Btrfs-Subvolume-Layout, Bootstrap-Ablauf, Wayland/Qt 6 Desktop-Design.
  - `ROADMAP.md`: Detaillierte Phasen 0 bis 9 mit konkreten Meilensteinen und Akzeptanzkriterien.
  - `BUILD.md`: Zweistufiger Bootstrap-Guide, Compiler-Flags, Kernel- und ISO-Build-Anweisungen.
  - `TESTING.md`: Matrix aller 19 verbindlichen Pflichttests und Ausführungsmodi.
  - `SECURITY.md`: AppArmor-Profile, nftables-Regelsatz, Yescrypt-Passworthashing, Compiler-Härtung.
  - `CONTRIBUTING.md`: Kodierungsstandards (C++20, Rust 2021, Qt 6, Python 3.10+), Commit-Konventionen.
  - `STATUS.md`: Kontinuierlicher Entwicklungs- und Fortschrittsbericht.

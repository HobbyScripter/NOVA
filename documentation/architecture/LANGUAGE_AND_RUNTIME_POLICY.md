# LANGUAGE_AND_RUNTIME_POLICY.md - Sprach- und Laufzeitrichtlinie

Dieses Dokument definiert die verbindlichen Richtlinien bezüglich Programmiersprachen, Laufzeitumgebungen und Systemabhängigkeiten für **PROJECT NOVA OS**.

---

## 1. Verbindliche Grundregeln

1. **Kein Python im installierten Basissystem**:
   - Das installierte NOVA OS (Minimal-Installation bis hin zum Desktop) darf für Kernfunktionen keine Abhängigkeit von einer Python-Laufzeitumgebung aufweisen.
   - Alle Daemons, Systemdienste, Desktop-Surfaces und Systemwerkzeuge müssen native Maschinencode-Binärdateien sein (C, C++, Rust).

2. **Einsatzbereich von Python**:
   - Python 3 ist ausschließlich zugelassen für:
     - Das Host-Build-System (`build/tools/`)
     - Das Bootstrap-Orchestrierungswerkzeug (`bootstrap/`)
     - Die Release- und Repository-Verwaltung auf Build-Servern (`repositories/scripts/`, `kernel/scripts/`)
     - Die Host- und VM-Testautomatisierung (`testing/`, `virtualization/virtualbox/`, `virtualization/vmware/`)

3. **Sprachmatrix nach Systemebenen**:

| Systemebene | Zugelassene Sprachen | Technologien & Bibliotheken | Begründung |
| :--- | :--- | :--- | :--- |
| **Kernel & Treiber** | C, Rust | Linux Kernel Stable, in-tree Module | Hardwarenah, minimale Latenz, keine Runtime |
| **Init & Systemdaemons** | C, Rust | systemd, D-Bus, sysfs, udev | Hohe Zuverlässigkeit, minimaler Speicherverbrauch |
| **Wayland-Compositor** | C, C++ | `wlroots`, Qt 6 Wayland Compositor API | Direkte KMS/DRM-Ansteuerung, V-Sync, Frame-Pacing |
| **NOVA Desktop** | C++ (C++20/23), Qt 6 | Qt 6 Widgets / QML, libnova IPC | Schneller Kaltstart, flüssige 60/120+ FPS UI |
| **Systemwerkzeuge** | C++, Qt 6, Rust | DNF5 C++ API (`libdnf5`), `libsolv`, Btrfs ioctl | Direkte Integration in C-Bibliotheken ohne FFI-Overhead |
| **Recovery & Notfall** | Rust, C, POSIX Shell | Statisch gelinkte Binaries | Maximale Robustheit auch bei beschädigten Bibliotheken |
| **Build & Test-Harness**| Python 3 (3.10+) | Standardbibliothek, Subprocess | Plattformunabhängigkeit und schnelle Scriptbarkeit auf dem Host |

---

## 2. Technische Begründung der Migration

- **Speicherbedarf (Footprint)**:
  Ein Python-Dämon belegt typischerweise 25 bis 60 MB RSS (Resident Set Size). Dieselbe Komponente in nativem C oder Rust benötigt lediglich 1,5 bis 4 MB RAM. Bei einem Dutzend Desktop- und Hintergrundkomponenten summiert sich dieser Unterschied auf über 400 MB unnötig belegten Arbeitsspeicher.
- **Kaltstart-Latenz**:
  Der Start eines Python-Prozesses benötigt auf Standard-Hardware 80 bis 250 Millisekunden (Modul-Imports, Bytecode-Kompilierung). Eine C++/Rust-Binärdatei startet in unter 5 Millisekunden.
- **Abhängigkeitsintegrität**:
  Wird Python im Basissystem vermieden, können Paket-Aktualisierungen von Python-Bibliotheken (oder deren Inkompatibilitäten bei Minor-Versionssprüngen) niemals kritische Systemfunktionen wie den Boot-Prozess, das Netzwerk oder die Wiederherstellung lahmlegen.


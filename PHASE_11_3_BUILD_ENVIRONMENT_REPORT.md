# Phase 11.3: Linux Build Environment Report

**Report Date**: 2026-11-08, 12:35 CET
**Phase**: Phase 11.3 – Linux Build Environment Setup
**Status**: **ABGESCHLOSSEN MIT DOKUMENTIERTEN ABWEICHUNGEN** (siehe Abschnitt 8 und 10)
**Ausführung**: real in einer laufenden VMware-Workstation-Pro-VM, keine Schätzwerte

---

## 1. Zusammenfassung

Phase 11.3 wurde in einer tatsächlich laufenden Ubuntu-24.04-LTS-VM unter VMware Workstation Pro ausgeführt. Alle drei vorgesehenen Skripte wurden real gestartet und ihre Ergebnisse protokolliert.

**Ergebnis in einem Satz**: Ubuntu wurde erkannt, alle benötigten Build-Abhängigkeiten sind installiert, die Projektprüfung und die automatisierten Tests laufen unter Linux erfolgreich (10/10, Exit-Code 0) – die VM erfüllt aber **nicht** alle Hardware-Vorgaben (BIOS statt UEFI, 2 statt 4–6 vCPU, 5,7 GiB statt 8 GB RAM, 100 statt 120 GB). Diese Abweichungen wurden auf ausdrückliche Entscheidung des Auftraggebers **nicht** durch Umkonfiguration oder Neuinstallation behoben, sondern dokumentiert.

Zusätzlich wurden bei der vorgeschriebenen Vorabprüfung der Skripte **sieben Defekte in vier Skriptdateien** gefunden; einer davon (ein Syntaxfehler in `phase11_create_rootfs.sh`) hätte Phase 11.5 unmittelbar blockiert. Alle sieben sind behoben und durch erneute Ausführung verifiziert (Abschnitt 7).

---

## 2. Ausführungsumgebung

### 2.1 Host

| Merkmal | Wert |
|---|---|
| Betriebssystem | Windows 11 (Build 10.0.26300) |
| CPU | AMD Ryzen 7 5800X 8-Core |
| Logische CPUs | 16 |
| Arbeitsspeicher | 31,9 GB |
| Hypervisor im Host aktiv | Ja (`HypervisorPresent = True`) |
| VMware Workstation Pro | 26.0.0 build-25388281 (`vmware.exe`, `vmrun.exe`) |
| vmrun | Version 1.17.0.25388281 |

### 2.2 Virtuelle Maschine

**VMX-Pfad**: `D:\Users\DFark\OneDrive\Dokumente\Virtual Machines\Ubuntu 24.04\Ubuntu 24.04.vmx`
**displayName**: `Ubuntu 24.04` · **guestOS**: `ubuntu-64` · **virtualHW.version**: 22
**VMware Tools**: laufen (`checkToolsState` → `running`)
**Gast-IP (NAT)**: 192.168.43.132
**Snapshots**: keine

| Merkmal | Konfiguriert | Vorgabe Phase 11.3 | Bewertung |
|---|---|---|---|
| RAM | 6144 MB (`memsize`) | 8 GB | ❌ zu klein |
| vCPU | 2 (`numvcpus`) | 4–6 | ❌ zu klein |
| Festplatte | 100 GiB (26 Extents, `twoGbMaxExtentSparse`) | 120 GB | ❌ zu klein |
| Firmware | BIOS (kein `firmware = "efi"`) | UEFI | ❌ falsch |
| Netzwerk | NAT, `e1000` | NAT | ✅ |
| Grafik | SVGA, 256 MB VRAM, 3D an | – | ✅ |

### 2.3 Gast-Betriebssystem

| Merkmal | Wert |
|---|---|
| Distribution | Ubuntu 24.04.4 LTS (Noble Numbat) |
| `ID` / `ID_LIKE` | `ubuntu` / `debian` |
| Kernel | 7.0.0-42-generic (`#42~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC`) |
| Hostname | ramon-VMware-Virtual-Platform |
| Benutzer | `ramon` (UID 1000, Mitglied in `sudo`) |
| Root-Dateisystem | `/dev/sda2`, 98 GB, 13 GB belegt |

---

## 3. Systemprüfung (`phase11_3_system_check.sh`)

**Exit-Code**: 0 · **Log**: `phase11_3_system_check.log`
**Hinweis**: Das Skript setzt bei erkannten Fehlern nur `echo_error` ab und ändert seinen Exit-Code **nicht**. Ein Exit-Code 0 bedeutet hier daher *nicht* „alle Prüfungen bestanden".

| Test | Ergebnis | Bewertung |
|---|---|---|
| 1 Ubuntu-Version | `Ubuntu 24.04.4 LTS (Noble Numbat)`, `ID=ubuntu` | ✅ Ubuntu 24.04 LTS bestätigt |
| 2 Kernelversion | 7.0.0-42-generic | ✅ ≥ 6.x |
| 3 CPU | 2 Kerne, AMD Ryzen 7 5800X | ⚠️ weniger als 4–6 Kerne |
| 3 RAM | `free -g` = 5 GB gesamt / 4 GB verfügbar (real 5,7 GiB) | ❌ unter 8 GB |
| 4 Speicherplatz | 98 GB gesamt, 81 GB frei | ✅ ≥ 80 GB |
| 5 Netzwerk | kernel.org erreichbar, archive.ubuntu.com erreichbar | ✅ |
| 6 UEFI | `/sys/firmware/efi` fehlt → BIOS-Modus | ❌ kein UEFI |
| 7 Systeminfo | Hostname, Uptime 27 min, Load 0.08/0.10/0.20 | ✅ |

---

## 4. Installierte Build-Abhängigkeiten (`phase11_3_install_dependencies.sh`)

**Exit-Code**: 0 · **Dauer**: ca. 2 Minuten · **Log**: `phase11_3_dependencies_install.log`
**Ausführung mit Root-Rechten im Gast** (apt benötigt Root); `DEBIAN_FRONTEND=noninteractive` und `NEEDRESTART_MODE=a` waren gesetzt, um interaktive Rückfragen zu verhindern.

### 4.1 Compiler-Toolchain

| Tool | Tatsächliche Version | Status |
|---|---|---|
| GCC | 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1) | ✅ |
| G++ | 13.3.0 | ✅ |
| Clang | 18.1.3 (1ubuntu1) | ✅ |
| lld | installiert (Teil von `lld`) | ✅ |
| Rust (rustc) | 1.99.1 (58cf8f9c3 2026-10-13) | ✅ |
| Cargo | 1.99.1 (5f94df478 2026-08-27) | ✅ |

### 4.2 Build-Systeme

| Tool | Tatsächliche Version | Status |
|---|---|---|
| CMake | 3.28.3 | ✅ |
| Ninja | 1.11.1 | ✅ |
| Meson | 1.3.2 | ✅ |
| pkg-config | vorhanden | ✅ |
| git | vorhanden | ✅ |

### 4.3 Desktop- und Grafikbibliotheken

| Bibliothek | Tatsächliche Version | Vorgabe | Status |
|---|---|---|---|
| Qt 6 (`Qt6Core`) | 6.4.2 | 6.5+ | ⚠️ Noble-Repository liefert 6.4.2 |
| Wayland (`wayland-client`) | 1.22.0 | 1.22+ | ✅ |
| wlroots | 0.17.1 | 0.17+ | ✅ |
| libinput, libdrm, libxkbcommon, Mesa (GL/EGL/GBM) | installiert (`-dev`) | – | ✅ |
| Vulkan (`libvulkan-dev`, `vulkan-tools`) | installiert | optional | ✅ |

### 4.4 System-Werkzeuge

| Werkzeug | Tatsächliche Version | Status |
|---|---|---|
| dracut | 060+5-1ubuntu3.4 | ✅ |
| btrfs-progs | v6.6.3 | ✅ |
| ShellCheck | 0.9.0 | ✅ |
| debootstrap | 1.0.134ubuntu2 | ✅ |
| xorriso | vorhanden | ✅ |
| squashfs-tools (`mksquashfs`) | vorhanden | ✅ |
| GRUB 2 (`grub2-common`, `grub-pc-bin`, `grub-efi-amd64`, `grub-efi-amd64-signed`, `shim-signed`) | installiert | ✅ |
| build-essential, bc, bison, flex, openssl, zlib1g-dev, libssl-dev | installiert | ✅ |

### 4.5 Paketquellen

```
/etc/apt/sources.list                     → nur Kommentarzeile ("sources have moved")
/etc/apt/sources.list.d/ubuntu.sources    → aktive Quelle (Ubuntu Noble)
/etc/apt/sources.list.d/ubuntu.sources.curtin.orig → Installer-Original
```

---

## 5. Projektprüfung (`phase11_3_project_check.sh`)

**Exit-Code**: 0 · **NOVA_ROOT**: `/home/ramon/nova-os` · **Log**: `phase11_3_project_check.log`

| Test | Ergebnis |
|---|---|
| 1 Projektverzeichnis | ✅ `build/`, `kernel/`, `desktop/`, `applications/`, `documentation/` vorhanden (196 Dateien, 6,1 MB) |
| 2 Dateiberechtigungen | ✅ alle 9 Skripte ausführbar |
| 3 Build-Skripte | ✅ GPG-Verifizierung, SHA256-Prüfung, Mount-Cleanup, `ROOT_PASSWORD`, `ROOTFS_DIR`-Prüfung, placeholder-UUID, EFI-Modulprüfung |
| 4 Kernel-Konfiguration | ✅ `CONFIG_DRM_VMWGFX`, `CONFIG_DRM_VBOXVIDEO`, `CONFIG_BTRFS_FS`, `CONFIG_EXT4_FS`, `CONFIG_DRM`, `CONFIG_DRM_KMS_HELPER` |
| 5 Downloadquellen | ✅ kernel.org CDN, GPG, SHA256 |
| 6 Dokumentation | ✅ 8/8 Dokumente vorhanden |
| 7 Automatisierte Tests | ✅ 10/10 bestanden (siehe Abschnitt 6) |
| 8 Speicherplatz | ⚠️ 79 GB frei (nach Installation unter der 80-GB-Empfehlung) |

---

## 6. Automatisierte Tests (`phase11_2_automated_tests.sh`) unter Linux

**Exit-Code**: 0 · **Log**: `phase11_2_test_results.log`

| # | Test | Ergebnis |
|---|---|---|
| 1 | ShellCheck-Syntaxprüfung (5 Skripte) | ✅ PASSED |
| 2 | Ausführbarkeit der Skripte | ✅ PASSED |
| 3 | Fehlerbehandlung Kernel-Skript | ✅ PASSED |
| 4 | Fehlerbehandlung Rootfs-Skript | ✅ PASSED |
| 5 | Initramfs-Skript Berechtigungen | ✅ PASSED |
| 6 | ISO-Skript GRUB-Konfiguration | ✅ PASSED |
| 7 | Distributionsunabhängige Abhängigkeiten | ✅ PASSED |
| 8 | Dokumentationsdateien | ✅ PASSED |
| 9 | Kernel-Konfigurationsvalidierung | ✅ PASSED |
| 10 | Release-Version | ✅ PASSED |

**Gesamt**: 10/10 bestanden, 0 fehlgeschlagen – sowohl im Verbund der Projektprüfung als auch als direkter Einzelaufruf (`bash build/phase11_2_automated_tests.sh`, Exit-Code 0).

**ShellCheck-Detail** (in der VM gemessen, nach allen Korrekturen): Die fünf von der Suite geprüften Skripte haben **0 Befunde der Ebene `error`**, dazu 12 Warnungen und 1 Hinweis (überwiegend SC2155 „declare and assign separately", außerdem SC2034 und SC2086/SC2129/SC1091). Über alle neun Skripte in `build/` und `virtualization/vmware/` sind es 45 Stilbefunde und 0 Fehler (SC2155 28×, SC2129 6×, SC2086 4×, SC1091 3×, SC2002 2×, SC2034 1×, SC2012 1×). Zusätzlich: `bash -n` für alle neun Skripte → 9/9 syntaktisch korrekt. Die vollständige ShellCheck-Ausgabe steht im Testlog.

---

## 7. Gefundene und behobene Fehler

Alle Befunde entstanden aus der vorgeschriebenen Vorabprüfung der Skripte und aus realer Ausführung unter Linux.

### 7.1 `build/phase11_create_rootfs.sh` – nicht geschlossene Zeichenkette (kritisch)

* **Befund**: Zeile 356 lautete `rm -rf "$ROOTFS_DIR/var/cache/apt` – das schließende `"` fehlte.
* **Nachweis**: `bash -n build/phase11_create_rootfs.sh` → `line 396: unexpected EOF while looking for matching '"'`; ShellCheck: SC1072/SC1073 (Schweregrad *error*).
* **Auswirkung**: Das Skript war nicht parsebar; Phase 11.5 (Rootfs) wäre sofort gescheitert.
* **Behebung**: Anführungszeichen ergänzt. **Verifiziert**: `bash -n` → rc=0 in der VM.

### 7.2 `build/phase11_2_automated_tests.sh` – Suite konnte nie fehlschlagen

* **Befund**: Keine der zehn Testfunktionen gab einen Status zurück; die letzte Anweisung war ein `echo` mit Rückgabewert 0. Dadurch meldete die Suite **immer** „Passed: 10 / Failed: 0", auch als Test 1 tatsächlich als `FAILED` protokolliert wurde.
* **Auswirkung**: Falsche Erfolgsmeldung – genau der Fall, den die Sicherheitsvorgaben ausschließen.
* **Behebung**: `return 0` / `return 1` je Testfunktion ergänzt. **Verifiziert**: Erfolgs- und Fehlerpfad werden jetzt korrekt gezählt.

### 7.3 `build/phase11_2_automated_tests.sh` – Warnungen als „Syntaxfehler" gewertet

* **Befund**: `if shellcheck "$script"` wertet jeden Befund ungleich 0 als Syntaxfehler. ShellCheck liefert aber auch bei reinen Stilhinweisen (SC2155/SC2034) Exit-Code 1.
* **Auswirkung**: Test 1 meldete „Syntax errors found", obwohl nur Warnungen vorlagen.
* **Behebung**: Entscheidung über Erfolg jetzt über `shellcheck -S error`; die vollständige Analyse wird weiterhin ins Log geschrieben (`|| true`, damit `set -e` die Suite nicht abbricht).

### 7.4 `build/phase11_3_project_check.sh` – `NOVA_ROOT` nicht exportiert

* **Befund**: `NOVA_ROOT` war eine reine Shell-Variable. Der Kindprozess `phase11_2_automated_tests.sh` sah sie nicht und fiel auf seinen Windows-Standardpfad `D:/Development/Systeme/NOVA` zurück.
* **Auswirkung**: Unter Linux wären alle dateibasierten Tests falsch fehlgeschlagen.
* **Behebung**: `export NOVA_ROOT` ergänzt.

### 7.5 `build/phase11_3_project_check.sh` – `set -e` verhinderte die Auswertung von Test 7

* **Befund**: `bash "$test_script"` lief unter `set -e`; bei einem Fehlschlag brach das gesamte Skript ab, bevor `$?` ausgewertet wurde. Der Fehlerpfad („Automatisierte Tests: fehlgeschlagen") war unerreichbar.
* **Behebung**: `local test_result=0; bash "$test_script" || test_result=$?`.

### 7.6 `build/phase11_2_automated_tests.sh` – Windows-Standardpfad verhinderte Einzelaufruf unter Linux

* **Befund**: Der Einzelaufruf in der VM scheiterte mit `D:/Development/Systeme/NOVA/phase11_2_test_results.log: No such file or directory` (Exit-Code 1).
* **Behebung**: Standard ist jetzt die skriptrelative Projektwurzel (`$(dirname "$BASH_SOURCE")/..`), überschreibbar per `NOVA_ROOT`.

### 7.7 `build/phase11_3_install_dependencies.sh` – SC2145 in sechs `echo_info`-Zeilen

* **Befund**: Sechs Zeilen der Form `echo_info "Installiere Pakete: ${build_tools[@]}"` mischen Zeichenkette und Array (ShellCheck SC2145, Schweregrad *error*).
* **Auswirkung**: Kein Abbruch – die Installation lief mit Exit-Code 0 durch –, aber die Logzeile wird nicht wie beabsichtigt zusammengesetzt. Für die Testsuite ist die Datei nicht relevant, für eine saubere Fehlerbilanz der Skripte schon.
* **Behebung**: `${array[@]}` → `${array[*]}` in den sechs betroffenen Zeilen.
* **Verifiziert**: 0 Befunde der Ebene *error* über alle neun Skripte.

### 7.8 Nicht behobene Kleinigkeit (kein Blocker)

`phase11_3_install_dependencies.sh` dokumentiert die Paketquellen mit `cat /etc/apt/sources.list`. Diese Datei enthält unter Ubuntu 24.04 nur noch eine Kommentarzeile; die aktiven Quellen liegen in `/etc/apt/sources.list.d/ubuntu.sources`. Das Skript bricht dadurch nicht ab (Ausgabe läuft über `tee`), dokumentiert die Quellen aber unvollständig. Bewusst unverändert gelassen, um den Skriptumfang nicht ohne Auftrag zu ändern.

---

## 8. Abweichungen von den Vorgaben (nicht behoben – Entscheidung des Auftraggebers)

| Vorgabe | Ist-Zustand | Konsequenz |
|---|---|---|
| UEFI | BIOS-Modus | UEFI-Prüfung schlägt fehl; eine Umstellung erfordert Neuinstallation der VM |
| 8 GB RAM | 6144 MB (5,7 GiB sichtbar) | RAM-Prüfung schlägt fehl; „erforderlich: 8 GB" |
| 4–6 vCPU | 2 vCPU | Warnung „weniger als 4 CPU-Kerne"; Kernel-Build mit `-j2` entsprechend langsam |
| 120 GB Speicher | 100 GiB, davon 79 GB frei | Speicherprüfung fällt nach der Installation unter die 80-GB-Empfehlung |
| Qt 6.5+ | 6.4.2 (Noble-Repository) | Höhere Qt-Version nur über Fremd-Repository oder Eigenbau |
| Projektpfad `~/nova-os` | Neu angelegt; eine ältere root-eigene Kopie liegt unter `~/nova_os` | Altkopie wurde **nicht** verändert und nicht verwendet |

**Wichtig für den Kernel-Build**: Bei 2 vCPU und 5,7 GiB RAM ist ein vollständiger Kernel-Build möglich, aber deutlich langsamer und ohne Reserve für parallele Jobs. Mit 80 GB freiem Speicher ist der in Abschnitt 9 veranschlagte Bedarf (~15 GB) gedeckt, der Puffer ist jedoch kleiner als geplant.

---

## 9. Speicherplatz

| Position | Wert |
|---|---|
| Root-Dateisystem gesamt | 98 GB |
| Belegt | 13 GB (vor Abhängigkeitsinstallation) |
| Frei (Systemprüfung) | 81 GB |
| Frei (Projektprüfung, nach Installation) | 79 GB |
| Erwarteter Build-Bedarf (Kernel + Rootfs + Initramfs + ISO + temporär) | ca. 15 GB |

---

## 10. Abschlusskriterien

| Kriterium | Status |
|---|---|
| Ubuntu erfolgreich erkannt | ✅ Ubuntu 24.04.4 LTS bestätigt |
| Alle benötigten Abhängigkeiten installiert | ✅ (Qt 6.4.2 statt 6.5 – dokumentiert) |
| Projektprüfung erfolgreich | ✅ Exit-Code 0, alle Prüfungen bestanden (79-GB-Warnung) |
| Automatisierte Tests unter Linux ausgeführt | ✅ 10/10, Exit-Code 0, echt ausgeführt |
| Tatsächliche Ergebnisse dokumentiert | ✅ dieser Report + vier Logdateien |
| UEFI | ❌ BIOS-Modus (nicht behoben, Entscheidung des Auftraggebers) |
| 8 GB RAM / 4–6 vCPU / 120 GB | ❌ 6 GB / 2 vCPU / 100 GiB (nicht behoben, Entscheidung des Auftraggebers) |

**Bewertung**: Die *funktionalen* Kriterien sind erfüllt – die Umgebung ist arbeitsfähig und alle Tests laufen unter echtem Linux durch. Die *Hardware*-Vorgaben sind teilweise nicht erfüllt. Phase 11.3 gilt damit als **abgeschlossen mit dokumentierten Abweichungen**, nicht als vollständig vorschriftsgemäß.

---

## 11. Anhang

### 11.1 Ausgeführte Schritte (real)

1. Projekt frisch nach `/home/ramon/nova-os` übertragen (196 Dateien; Altkopie `~/nova_os` unangetastet), Skripte ausführbar gemacht.
2. `bash build/phase11_3_system_check.sh` (als Benutzer `ramon`) → Exit-Code 0.
3. `bash build/phase11_3_install_dependencies.sh` (mit Root-Rechten im Gast) → Exit-Code 0.
4. `bash build/phase11_3_project_check.sh` → Exit-Code 0, Tests 10/10.
5. Nach den Korrekturen aus Abschnitt 7: erneuter Lauf von Projektprüfung und Tests → Exit-Code 0, Tests 10/10; zusätzlich Einzelaufruf des Testskripts → Exit-Code 0.
6. Zusatzprüfung: `bash -n` für alle 9 Skripte → alle OK (vorher 1 Fehler).

**Technischer Hinweis zur Automatisierung**: Die Steuerung erfolgte über `vmrun` (Gast-Login `ramon`) mit deaktivierter MSYS-Pfadkonvertierung (`MSYS_NO_PATHCONV=1`), da Git Bash sonst POSIX-Gastpfade in Windows-Pfade umschreibt. Das temporäre Passwortfile im Gast (`/tmp/nova_pw`, Modus 600) wurde nach der Installation gelöscht und ist in keiner Projektdatei enthalten.

### 11.2 Berichte und Logs

| Datei | Inhalt |
|---|---|
| `phase11_3_system_check.log` | Systemprüfung |
| `phase11_3_dependencies_install.log` | apt-Ausgabe der Abhängigkeitsinstallation (50 KB) |
| `phase11_3_project_check.log` | Projektprüfung |
| `phase11_2_test_results.log` | Automatisierte Tests inkl. ShellCheck-Ausgabe |

### 11.3 Geänderte Projektdateien

| Datei | Änderung |
|---|---|
| `build/phase11_create_rootfs.sh` | Fehlendes `"` in Zeile 356 ergänzt |
| `build/phase11_2_automated_tests.sh` | Rückgabewerte der Testfunktionen, ShellCheck-Schweregrad, skriptrelativer `NOVA_ROOT` |
| `build/phase11_3_project_check.sh` | `export NOVA_ROOT`, `set -e`-sichere Auswertung von Test 7 |
| `build/phase11_3_install_dependencies.sh` | SC2145: `${array[@]}` → `${array[*]}` in sechs Logzeilen |

### 11.4 Nicht ausgeführt

* Kein Kernel-Build, keine Rootfs-, Initramfs- oder ISO-Erstellung.
* Keine Änderung an VM-Hardware, Firmware oder an der Altkopie `~/nova_os`.

---

**END OF REPORT**

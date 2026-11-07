# TESTING.md - NOVA OS Testinfrastruktur & Qualitätsmatrix

Dieses Dokument definiert das verbindliche Testkonzept für **PROJECT NOVA OS**.
Gemäß den Projektvorgaben gilt ein Test **nur dann als bestanden, wenn er tatsächlich ausgeführt und verifiziert wurde**.

---

## 1. Übersicht der 19 obligatorischen Systemtests

| ID | Testbezeichnung | Testbereich | Automatisierung | Kriterien für Erfolg (Done) |
| :--- | :--- | :--- | :--- | :--- |
| **TEST-01** | Kernel-Build | Kernel & Toolchain | `test_kernel_build` | Erfolgreiche Kompilierung von `bzImage` und Modulen mit `nova_defconfig` |
| **TEST-02** | Root-Dateisystem-Build | Sysroot & FHS | `test_rootfs_fhs` | FHS 3.0 Konformität, `usr-merge` intakt, keine verwaisten Links |
| **TEST-03** | Paketinstallation | RPM / DNF5 | `test_package_install` | Saubere Installation von Core-RPMs via DNF5 ohne Abhängigkeitskonflikte |
| **TEST-04** | Repository-Verifikation | Repositories & GPG | `test_repo_verification` | `repomd.xml` valide, GPG-Signaturprüfung erfolgreich, Checksummen stimmen |
| **TEST-05** | ISO-Build | Build & Release | `test_iso_generation` | Gültiges Hybrid-ISO erzeugt, bootfähig via El Torito (BIOS) & EFI (UEFI) |
| **TEST-06** | Live-System-Boot | Init & Dracut | `test_live_boot` | QEMU/VM bootet Live-ISO bis zum grafischen Login ohne Panics |
| **TEST-07** | Installer-Funktion | NOVA Installer | `test_installer_flow` | Automatische Btrfs-Partitionierung & Installation im virtuellen Disk-Image |
| **TEST-08** | Benutzeranmeldung | Session & PAM | `test_user_login` | Erfolgreiche Authentifizierung eines Non-Root-Users über PAM / systemd-logind |
| **TEST-09** | Desktop-Start | Wayland & Qt 6 | `test_desktop_start` | `nova-compositor` und `nova-shell` starten fehlerfrei auf Wayland-Socket |
| **TEST-10** | Netzwerkverbindung | NetworkManager | `test_network` | Loopback, DHCP-Lease und DNS-Auflösung via NetworkManager verifiziert |
| **TEST-11** | Audio-Architektur | PipeWire | `test_audio` | PipeWire-Daemon und WirePlumber aktiv, ALSA/PulseAudio-Emulation bereit |
| **TEST-12** | Grafik & Rendering | DRM / KMS / OpenGL | `test_graphics` | Hardware-Rendering via DRM/KMS oder fehlerfreier Fallback auf `llvmpipe` |
| **TEST-13** | Softwareinstallation | NOVA Store / DNF5 | `test_store_install` | Installation und Deinstallation eines Anwendungs-RPMs & Flatpak-Test |
| **TEST-14** | Systemupdates | NOVA Update | `test_system_update` | Atomare Transaktion, automatischer Btrfs-Pre-Snapshot, Paket-Aktualisierung |
| **TEST-15** | Kernelupdates | Kernel-Infrastruktur| `test_kernel_update` | Neuer Kernel installiert, vorheriger Kernel beibehalten, GRUB-Eintrag erzeugt |
| **TEST-16** | Kernel-Rollback | Stabilität & Boot | `test_kernel_rollback`| Gezielter Boot des vorherigen Kernels nach simuliertem Fehler im neuen Kernel |
| **TEST-17** | Recovery-System | NOVA Recovery | `test_recovery_system` | Btrfs-Snapshot-Wiederherstellung eines früheren Systemzustands via CLI/GUI |
| **TEST-18** | VirtualBox-Integration | Virtualisierung | `test_vbox_guest` | Boot in VirtualBox 7+, VMSVGA-Treiber aktiv, dynamische Auflösung & Clipboard |
| **TEST-19** | VMware-Integration | Virtualisierung | `test_vmware_guest` | Boot in VMware Workstation, `open-vm-tools` aktiv, vmwgfx aktiv |

---

## 2. Test-Ausführung & Harness (`testing/run_tests.py`)

Die Tests werden über die zentrale Python-Testsuite automatisiert gesteuert:

```powershell
# Alle Unit- und Architektur-Tests ausführen
python testing/run_tests.py --suite core

# Repository- und Pakettests ausführen
python testing/run_tests.py --suite packages

# Virtualisierungs- und Boot-Tests durchführen
python testing/run_tests.py --suite vm --hypervisor virtualbox

# Vollständigen Testbericht aller 19 Tests generieren
python testing/run_tests.py --all --report report.json
```

---

## 3. Testumgebungen

1. **Host-Umgebung / Sandboxed Runner**:
   - Syntax-, Lint-, Typen- und Abhängigkeitsprüfungen.
   - Rootfs-Dateisystem-Analysen und Spec-Validierungen.
   - RPM-Header- und Metadaten-Prüfungen.
2. **QEMU / KVM**:
   - Schnelle Headless-Integrationstests des Kernels und des Live-Images (`qemu-system-x86_64 -m 4096 -enable-kvm -cdrom ...`).
3. **Oracle VirtualBox**:
   - Vollständiger Gastsystem-Test via `VBoxManage`:
     - VM-Erstellung: `VBoxManage createvm --name "NOVA_OS_Test" --ostype "Linux_64" --register`
     - EFI-Aktivierung: `VBoxManage modifyvm "NOVA_OS_Test" --firmware efi`
     - Grafikadapter: `VBoxManage modifyvm "NOVA_OS_Test" --graphicscontroller vmsvga`
     - ISO-Mount und Headless-Start: `VBoxManage startvm "NOVA_OS_Test" --type headless`
4. **VMware Workstation**:
   - VMX-Konfigurationsbasierte Validierung mit EFI-Boot und `open-vm-tools`.

---

## 4. Test-Dokumentation & Protokollierung

Jeder Testlauf erzeugt ein standardisiertes JSON- und Markdown-Protokoll in `testing/logs/`:
- Startzeit und Endzeit
- Exit-Code und Standardausgabe / Standardfehler
- Detaillierter Stacktrace bei Fehlschlag
- System-Hardware- und Hypervisor-Zustand


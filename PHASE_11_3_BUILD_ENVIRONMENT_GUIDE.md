# Phase 11.3: Linux Build Environment Setup - Anleitung

**Anleitung für Ausführung in VMware Workstation Pro VM**

**VM Konfiguration**:
- Betriebssystem: Ubuntu 24.04 LTS Desktop
- RAM: 8 GB
- CPUs: 4-6 Kerne
- Festplatte: 120 GB
- Firmware: UEFI
- Netzwerk: NAT

---

## 1. Vorbereitung in VMware

### 1.1 VM erstellen

1. VMware Workstation Pro öffnen
2. "Create a New Virtual Machine" wählen
3. "Installer disc image file (iso)" wählen
4. Ubuntu 24.04 LTS ISO auswählen
5. VM konfigurieren:
   - Name: NOVA-Build-VM
   - Location: Pfad mit ausreichend Speicher
   - Disk size: 120 GB
   - Store virtual disk as single file
6. Hardware anpassen:
   - Memory: 8192 MB (8 GB)
   - Processors: 4 CPUs
   - Network: NAT
   - USB Controller: USB 3.0
7. VM starten und Ubuntu 24.04 LTS installieren

### 1.2 Post-Installation

Nach der Installation:

1. System-Updates durchführen:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. VMware Tools installieren (optional, für Drag-and-Drop):
   ```bash
   sudo apt install open-vm-tools-desktop
   ```

3. Neustart:
   ```bash
   sudo reboot
   ```

---

## 2. NOVA OS Projekt in VM übertragen

### 2.1 Methode A: Drag-and-Drop (VMware Tools)

1. Projektverzeichnis `D:\Development\Systeme\NOVA` vom Windows-Host in die VM ziehen
2. In VM: Projekt nach `/home/<user>/nova-os` verschieben

### 2.2 Methode B: Git Clone

1. In VM Terminal:
   ```bash
   cd ~
   git clone <repository-url> nova-os
   cd nova-os
   ```

### 2.3 Methode C: Shared Folder

1. VMware VM Settings → Options → Shared Folders
2. Ordner `D:\Development\Systeme\NOVA` freigeben
3. In VM: `/mnt/hgfs/<folder-name>` verwenden

---

## 3. Ausführung der Phase 11.3 Skripte

Alle Skripte müssen im NOVA OS Projektverzeichnis ausgeführt werden.

### 3.1 Projektverzeichnis wechseln

```bash
cd ~/nova-os
```

### 3.2 Systemprüfung

```bash
sudo bash build/phase11_3_system_check.sh
```

**Erwartetes Ergebnis**:
- Ubuntu 24.04 LTS bestätigt
- Mindestens 4 CPU-Kerne
- Mindestens 8 GB RAM
- Mindestens 80 GB freier Speicher
- Netzwerkverbindung aktiv
- UEFI aktiviert

**Bericht**: `phase11_3_system_check.log`

### 3.3 Build-Abhängigkeiten installieren

```bash
sudo bash build/phase11_3_install_dependencies.sh
```

**Dauer**: ~10-15 Minuten

**Erwartetes Ergebnis**:
- Alle Build-Tools installiert (GCC, Clang, CMake, Ninja, Meson)
- Rust installiert
- Qt 6 installiert
- Wayland und wlroots installiert
- System-Tools installiert (GRUB, dracut, btrfs-progs)
- ShellCheck installiert

**Bericht**: `phase11_3_dependencies_install.log`

### 3.4 Projektprüfung

```bash
bash build/phase11_3_project_check.sh
```

**Erwartetes Ergebnis**:
- Alle Build-Skripte vorhanden und ausführbar
- Kernel-Konfiguration korrekt
- Downloadquellen verifiziert
- Dokumentation vollständig
- Automatisierte Tests bestanden (10/10)

**Bericht**: `phase11_3_project_check.log`

---

## 4. Fehlersuche

### 4.1 Systemprüfung fehlgeschlagen

**Problem**: Weniger als 8 GB RAM
- **Lösung**: VM in VMware Konfiguration anpassen und RAM erhöhen

**Problem**: Weniger als 80 GB freier Speicher
- **Lösung**: VM Disk vergrößern oder Daten bereinigen

**Problem**: Keine Netzwerkverbindung
- **Lösung**: Netzwerk-Adapter in VMware auf NAT prüfen

### 4.2 Abhängigkeiten-Installation fehlgeschlagen

**Problem**: Paket nicht gefunden
- **Lösung**: `sudo apt update` erneut ausführen

**Problem**: Installationsfehler
- **Lösung**: Fehlerbericht prüfen, Internetverbindung prüfen

### 4.3 Projektprüfung fehlgeschlagen

**Problem**: Skripte nicht ausführbar
- **Lösung**: `chmod +x build/phase11_*.sh`

**Problem**: Dateien fehlen
- **Lösung**: Projekt vollständig übertragen

---

## 5. Überprüfung der Installation

### 5.1 Manuelle Prüfung

Wichtige Komponenten manuell prüfen:

```bash
# GCC Version
gcc --version

# CMake Version
cmake --version

# Qt 6
pkg-config --modversion Qt6Core

# Wayland
pkg-config --modversion wayland-client

# dracut
dracut --version

# ShellCheck
shellcheck --version
```

### 5.2 Versionen protokollieren

Alle Versionen im Build-Environment-Report dokumentieren:

```bash
# Versions-Informationen sammeln
gcc --version | head -1
clang --version | head -1
cmake --version | head -1
ninja --version
rustc --version
pkg-config --modversion Qt6Core
pkg-config --modversion wayland-client
pkg-config --modversion wlroots
systemctl --version
dracut --version
btrfs --version
```

---

## 6. Erfolgreiches Setup erkennen

Das Setup ist erfolgreich, wenn:

- [x] Systemprüfung bestanden (Ubuntu 24.04 LTS, 8 GB RAM, 80 GB+ Speicher)
- [x] Alle Build-Abhängigkeiten installiert
- [x] Alle Versionen korrekt
- [x] Projektprüfung bestanden
- [x] Automatisierte Tests bestanden (10/10)
- [x] Keine kritischen Fehler

---

## 7. Nächste Schritte nach erfolgreichem Setup

Nach erfolgreichem Setup kann mit Phase 11.4 fortgefahren werden:

1. Kernel-Build ausführen
2. Rootfs-Erstellung ausführen
3. Initramfs-Erstellung ausführen
4. ISO-Erstellung ausführen
5. VM-Tests durchführen

---

## 8. Troubleshooting

### 8.1 WSL2 vs VMware

**Wichtig**: Diese Skripte sind für eine **echte Linux VM** (VMware Workstation Pro) konzipiert, nicht für WSL2.

**Grund**: WSL2 hat keine vollständige systemd-Unterstützung und keine UEFI-Boot-Fähigkeit.

### 8.2 VirtualBox vs VMware

Diese Skripte sind für **VMware Workstation Pro** optimiert, können aber mit Anpassungen auch in VirtualBox verwendet werden.

**Anpassungen für VirtualBox**:
- Installieren Sie VirtualBox Guest Additions statt Open VM Tools
- Netzwerk-Adapter-Name kann variieren

### 8.3 Netzwerk-Probleme

Wenn das Netzwerk nicht funktioniert:

```bash
# Netzwerk-Adapter prüfen
ip link show

# DNS prüfen
cat /etc/resolv.conf

# Netzwerk neu starten
sudo systemctl restart NetworkManager
```

---

## 9. Berichte

Alle Berichte werden im NOVA OS Projektverzeichnis erstellt:

- `phase11_3_system_check.log` - System-Prüfungsbericht
- `phase11_3_dependencies_install.log` - Installationsbericht
- `phase11_3_project_check.log` - Projektprüfungsbericht

Diese Berichte werden für den Build-Environment-Report verwendet.

---

## 10. Support

Bei Problemen:

1. Berichte prüfen
2. Fehlermeldungen lesen
3. Systemanforderungen prüfen
4. Netzwerkverbindung prüfen
5. Speicherplatz prüfen

---

**END OF ANLEITUNG**

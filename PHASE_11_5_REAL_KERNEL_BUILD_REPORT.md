# Phase 11.5 – Erster echter NOVA OS Kernel

**Datum**: 2026-11-08
**Umgebung**: Ubuntu 24.04.4 LTS, Kernel 7.0.0-42-generic, 2 vCPU, 5,7 GiB RAM, 79 GB frei
**Projekt**: `/home/ramon/nova-os` (Benutzer `ramon`)
**Ergebnis**: **ERFOLGREICH** – Linux 6.18.62 wurde aus offizieller Quelle kompiliert, als `6.18.62-nova` installiert und unabhängig verifiziert.

---

## 1. Kernel-Quelle und Version

| Merkmal | Wert |
|---|---|
| Version | **6.18.62** (LTS) |
| Bezug | `https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.62.tar.xz` |
| Tarball-Größe | 155.352.516 Bytes |
| Entpackter Quellbaum | 1,7 GB unter `build/kernel-build/linux-6.18.62` |
| Veröffentlichung lt. Server | 2026-11-06 18:40 UTC |
| `Makefile`-Kopf | `VERSION = 6 / PATCHLEVEL = 18 / SUBLEVEL = 62` |

Verfügbarkeit vorab geprüft: der v6.x-Index von kernel.org listet `linux-6.18.62.tar.xz`, HEAD liefert HTTP 200. Es wurde ausschließlich diese offizielle Quelle verwendet, kein Mirror, kein Distributions-Patchsatz.

## 2. Prüfsummen- und Signaturprüfung

| Prüfung | Ergebnis |
|---|---|
| SHA-256 (berechnet) | `490a7aedf1b355c565d3a6c05333ccccb5da82064eca46b590448a7099d7d651` |
| Abgleich mit `sha256sums.asc` von kernel.org | **OK** (`sha256sum -c` → `linux-6.18.62.tar.xz: OK`) |
| GPG-Signatur des Tarballs (`linux-6.18.62.tar.sign`) | **GOODSIG / VALIDSIG**, Schlüssel `647F28654894E3BD457199BE38DBBDC86092693E`, UID *Greg Kroah-Hartman <gregkh@kernel.org>*, Signaturdatum 2026-11-06 |
| Signatur der Prüfsummenliste (`sha256sums.asc`) | **nicht verifizierbar** – Schlüssel `B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1` war über WKD nicht abrufbar |

Die Authentizität ist damit über die Tarball-Signatur von Greg Kroah-Hartman belegt, nicht über die signierte Prüfsummenliste. Die SHA-256-Prüfung deckt zusätzlich Transportfehler ab. Es wurde kein Schlüssel ungeprüft als vertrauenswürdig markiert.

## 3. Verwendete Konfiguration

Ausgangspunkt war `kernel/configs/nova_defconfig` (149 Zeilen, 117 `CONFIG_`-Einträge, Ziel laut Kopf „6.12.x"). Diese Datei ist ein **Fragment**, keine vollständige `.config`; `make olddefconfig` ergänzt die übrigen Optionen aus den Kconfig-Standardwerten.

Dabei fielen zunächst zentrale Treiber heraus, weil ihre Abhängigkeiten im Fragment fehlten (kein `CONFIG_PCI`, kein `CONFIG_SCSI`) — SATA/AHCI, NVMe, e1000 und vmwgfx waren deshalb „nicht gesetzt". Ergänzt wurden daraufhin unter anderem:

`PCI`, `PCI_MSI`, `PCI_DIRECT`, `SCSI`, `SCSI_MOD`, `BLK_DEV`, `ATA`, `SATA_AHCI`, `ATA_PIIX`, `BLK_DEV_NVME`, `NETDEVICES`, `NET_VENDOR_INTEL`, `E1000`, `E1000E`, `VMXNET3`, `VMWARE_PVSCSI`, `DRM`, `DRM_KMS_HELPER`, `DRM_VMWGFX`, `DRM_VMWGFX_FBCON`, `USB_SUPPORT`, `USB`, `INPUT_EVDEV`, `BLK_DEV_INITRD`, `DEVTMPFS`, `DEVTMPFS_MOUNT`, `TMPFS`, `CGROUPS`, `SERIAL_8250_CONSOLE`, `IKCONFIG`, `IKCONFIG_PROC`.

| Merkmal | Wert |
|---|---|
| `make kernelrelease` | **6.18.62-nova** (`localversion` = `-nova`) |
| `.config`-Größe | 120.775 Bytes |
| `CONFIG_`-Zeilen | 1.308 (vor dem IKCONFIG-Zusatz) |
| Finale Datei im Projekt | `kernel/configs/nova-6.18.62.config` |

### 3.1 Nachgewiesene Pflichtoptionen

Alle aus der eingebetteten Konfiguration des fertigen Kernels gelesen:

```
CONFIG_PCI=y              CONFIG_CGROUPS=y            CONFIG_SATA_AHCI=y
CONFIG_BLK_DEV_NVME=y     CONFIG_E1000=y              CONFIG_DRM_VMWGFX=y
CONFIG_BLK_DEV_INITRD=y   CONFIG_DEVTMPFS=y           CONFIG_DEVTMPFS_MOUNT=y
CONFIG_TMPFS=y            CONFIG_PROC_FS=y            CONFIG_SYSFS=y
CONFIG_EXT4_FS=y          CONFIG_BTRFS_FS=y           CONFIG_SQUASHFS=y
CONFIG_OVERLAY_FS=y       CONFIG_ISO9660_FS=y         CONFIG_VFAT_FS=y
CONFIG_SECURITY_APPARMOR=y CONFIG_EFI_STUB=y          CONFIG_MODULES=y
CONFIG_NF_TABLES=y        CONFIG_SERIAL_8250_CONSOLE=y
```

### 3.2 Von `nova_defconfig` verworfene oder umbenannte Symbole

| Symbol | Ursache |
|---|---|
| `CONFIG_CC_STACKPROTECTOR_STRONG` | in neueren Kerneln `CONFIG_STACKPROTECTOR_STRONG` |
| `CONFIG_NVME_CORE` | existiert nicht mehr (in `CONFIG_BLK_DEV_NVME` aufgegangen) |
| `CONFIG_MCORE2` | Konflikt mit `CONFIG_GENERIC_CPU`; `GENERIC_CPU` hat gewonnen |
| `SND_SOC_SOF_TOPLEVEL=m` | Symbol ist `bool` – `make` warnt, Wert wird auf `y` korrigiert |
| `DRM_AMDGPU/I915/NOUVEAU/XE`, `SND_HDA_INTEL`, `VBOXGUEST`, `VMWARE_VMCI`, `VMWARE_BALLOON` | `=m` gesetzt, aber Abhängigkeiten (Firmware-Loader, I²C/Backlight, PCI-Sound, VMCI-Transport) im Fragment nicht aktiviert → stillschweigend verworfen |

`CONFIG_DRM_VMWGFX` wurde bewusst auf `=y` (eingebaut) statt `=m` gesetzt, damit der VMware-Grafiktreiber ohne Initramfs verfügbar ist.

## 4. Kompilierung

Alle Schritte als Benutzer `ramon`, ohne Root:

```bash
cd ~/nova-os/build/kernel-build/linux-6.18.62
cp ~/nova-os/kernel/configs/nova_defconfig .config
echo "-nova" > localversion
scripts/config --file .config --enable <Abhängigkeiten siehe Abschnitt 3>
make -s olddefconfig
make -j2 bzImage modules
make INSTALL_MOD_PATH=~/nova-os/build/output/sysroot modules_install
```

| Kennzahl | Wert |
|---|---|
| Parallele Jobs | 2 (`-j2`, Vorgabe eingehalten) |
| Build-Dauer (vollständig) | **572 Sekunden (9 min 32 s)**, 21:09:42 → 21:19:14 |
| Inkrementeller Nachbau (IKCONFIG) | 21 Sekunden, Kernel `#2` |
| Kompilierte Objektdateien | 2.306 |
| Build-Log | 119.532 Bytes, `build/kernel-build/kbuild-6.18.62.log` |
| Fehlerzeilen im Log | **0** (`Error [0-9]` / `error:`), Exit-Code 0 |
| Übersprungene Schritte | keine |

Die kurze Bauzeit erklärt sich aus der bewusst schlanken Konfiguration (1.300 statt ~10.000 Optionen) und dem kleinen Modulumfang.

## 5. Erzeugte Artefakte

### 5.1 Kernel-Image

| Merkmal | Wert |
|---|---|
| Pfad | `build/output/sysroot/boot/vmlinuz-nova-6.18.62` und `…/vmlinuz-nova-current` |
| Größe | **8.922.112 Bytes** |
| SHA-256 | `868a959ecb991423525ff9e33dcab44192da6d0acbf84c361c79d0327f9b8785` |
| `file` | `Linux kernel x86 boot executable bzImage, version 6.18.62-nova (ramon@ramon-VMware-Virtual-Platform) #2 SMP PREEMPT_DYNAMIC Sun Nov 8 21:20:41 CET 2026` |
| Entpacktes `vmlinux` | 28.209.960 Bytes, `ELF 64-bit LSB executable, x86-64, statically linked` |

Der 65-Byte-Platzhalter wurde **nicht überschrieben, sondern gesichert**: `vmlinuz-nova-current.placeholder-bak`.

### 5.2 Weitere Dateien

| Datei | Größe |
|---|---|
| `System.map-6.18.62-nova` | 4.572.410 Bytes |
| `config-6.18.62-nova` | 120.775 Bytes |
| `build/kernel-build/kbuild-6.18.62.log` | 119.532 Bytes |
| `build/kernel-build/ikconfig-extracted-6.18.62.txt` | 120.775 Bytes |
| `kernel/configs/nova-6.18.62.config` | 120.775 Bytes |
| `build/output/sysroot/boot` (gesamt) | 22 MB |
| `build/output/sysroot/lib/modules` | 2,1 MB |

## 6. Module

| Merkmal | Wert |
|---|---|
| Anzahl installierter Module | **20** (`*.ko`) |
| Modulverzeichnis | `build/output/sysroot/lib/modules/6.18.62-nova` |
| `modules.dep` | vorhanden (depmod lief) |
| Vermagic | `6.18.62-nova SMP preempt` |
| Format | `ELF 64-bit LSB relocatable, x86-64` |

Gebaut: `snd-pcm`, `snd-timer`, `snd-compress`, `snd-soc-core`, `snd-soc-acpi`, `snd-intel-sst-core`, `snd-intel-sst-acpi`, `snd-intel-dspcfg`, `snd-intel-sdw-acpi`, `snd-soc-sdca`, `snd-soc-acpi-intel-match`, `snd-soc-acpi-intel-sdca-quirks`, `snd-soc-sst-atom-hifi2-platform`, `rng-core`, `amd-rng`, `intel-rng`, `via-rng`, `iosf_mbi`, `regmap-i2c`, `x86_pkg_temp_thermal`.

## 7. Testergebnisse

Alle folgenden Prüfungen wurden **tatsächlich ausgeführt**:

| Test | Ergebnis |
|---|---|
| Quelle: SHA-256 gegen offizielle Liste | bestanden |
| Quelle: GPG-Signatur des Tarballs | bestanden (GOODSIG, Greg Kroah-Hartman) |
| Kernel-Image existiert und ist binär | bestanden (8,9 MB, bzImage) |
| Version = 6.18.62 | bestanden (`6.18.62-nova`, `#2`) |
| `vmlinux` entpackbar und ELF | bestanden (28,2 MB, ELF64) |
| Konfiguration tatsächlich verwendet | **bestanden**: `scripts/extract-ikconfig` liefert 120.775 Bytes und ist **byte-identisch** mit `.config` |
| Kernel-Module erstellt | bestanden (20 `.ko`) |
| Modulverzeichnis enthält echte Module | bestanden (ELF relocatable, Vermagic passend) |
| Symbole der Pflicht-Subsysteme | bestanden: `btrfs_get_tree` (2.650 Btrfs-Symbole, `open_ctree`), `ext4_fill_super`, `squashfs_fill_super`, `zstd_decompress`, `apparmor_init`, `e1000_probe`, `ahci_pci_driver`, `nvme_probe`, `vmw_probe` |
| Keine Build-Fehler | bestanden (Exit 0, 0 Fehlerzeilen in beiden Läufen) |
| Hostkernel unverändert | bestanden (`/lib/modules` enthält nur `7.0.0-42-generic`, mtime unverändert 11:43:53) |
| Ergebnisse gehören `ramon` | bestanden (0 fremde Einträge in `sysroot`) |
| `~/nova_os` unverändert | bestanden (`root:root`) |

**Nicht durchgeführt** (laut Auftrag ausgeschlossen): RootFS-Erstellung, Initramfs, ISO, Boottest, VMware-Konfigurationsänderung.

## 8. Berechtigungen

* Sämtliche Build- und Installationsschritte liefen als `ramon`.
* Root war ausschließlich für die Paketinstallation von `libelf-dev` und `dwarves` (pahole) nötig — beide fehlten und sind für `objtool`/BTF erforderlich.
* Keine pauschalen `chmod`/`chown`-Läufe in diesem Schritt; der Ausgabebaum war bereits aus Phase 11.4 benutzereigen.
* `INSTALL_MOD_PATH` zeigt auf den Staging-Pfad; der Host-Kernel und `/lib/modules` wurden nicht berührt.

## 9. Offene Probleme

1. **Nur 20 Module.** Die in `nova_defconfig` als Modul vorgesehenen Grafik- (amdgpu, i915, nouveau, xe), Audio- (`snd_hda_intel`) und VM-Treiber (vboxguest, vmci, balloon) wurden von `olddefconfig` verworfen, weil ihre Abhängigkeiten im Fragment fehlen. Für VMware ist Grafik über das eingebaute `vmwgfx` abgedeckt; Audio und VMCI fehlen.
2. **`nova_defconfig` ist veraltet und unvollständig.** Sie enthält umbenannte Symbole (Ziel „6.12.x"), keine PCI/SCSI-Basis und keinen `IKCONFIG`. Empfehlung: durch `kernel/configs/nova-6.18.62.config` als neuen, vollständigen Ausgangspunkt ersetzen.
3. **Kein Boottest.** Der Kernel ist nicht gestartet (im Auftrag ausgeschlossen, und ohne Initramfs/RootFS nicht bootfähig).
4. **`kernel/kernel_state.json` ist inkonsistent**: führt weiterhin `current_kernel: 7.3.3` (Artefakt des alten Platzhalter-Builders). Der Python-Manager kann den Zustand erst setzen, wenn ein echtes Initramfs vorliegt.
5. **`sha256sums.asc` nicht signaturgeprüft** (Schlüssel nicht abrufbar) – siehe Abschnitt 2.
6. **Platzhalterdateien** `vmlinuz-nova-7.3.3` (65 B) und `initramfs-nova-*.img` (54 B) liegen weiterhin im Staging; nur `vmlinuz-nova-current` wurde ersetzt (mit Sicherung als `.placeholder-bak`).
7. **Quellbaum belegt 1,7 GB** zusätzlich zum Tarball (150 MB). Für Phase 11.6 sollte der Baum erhalten bleiben, solange Module nachgebaut werden.

## 10. Empfehlung für Phase 11.6

1. `nova-6.18.62.config` als neue Basis übernehmen und um `FW_LOADER`, `I2C`, `BACKLIGHT_CLASS_DEVICE`, `SND_HDA`, `SND_PCI`, `VMWARE_VMCI` erweitern, damit die vorgesehenen Module tatsächlich entstehen.
2. Initramfs mit dracut gegen genau dieses Modulverzeichnis erzeugen (`--kver 6.18.62-nova`).
3. Erst danach RootFS und ISO — der reparierte Builder aus Phase 11.4 verlangt echte Artefakte, die jetzt für Kernel und (dann) Initramfs vorliegen.

## 11. Statusmatrix

| Aufgabe | Status |
|---|---|
| Build-Umgebung und Speicherplatz geprüft | ✅ ausgeführt (79 GB frei, 2 vCPU) |
| Kernel 6.18.62 aus offizieller Quelle | ✅ ausgeführt |
| Prüfsumme und Signatur | ✅ ausgeführt (Tarball-Signatur GOODSIG) |
| Konfiguration erstellt/erweitert | ✅ ausgeführt (1.308 CONFIG-Zeilen) |
| `make -j2 bzImage modules` | ✅ ausgeführt (572 s, Exit 0) |
| Module in NOVA-Staging installiert | ✅ ausgeführt (20 `.ko`) |
| Unabhängige Verifikation | ✅ ausgeführt (IKCONFIG identisch, Symbole, Vermagic) |
| RootFS / Initramfs / ISO | ⛔ nicht durchgeführt (auftragsgemäß ausgeschlossen) |
| Boottest / VMware-Änderung | ⛔ nicht durchgeführt (auftragsgemäß ausgeschlossen) |

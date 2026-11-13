# Phase 11.6 — Real-RootFS und Initramfs für NOVA OS

**Datum:** 2026-11-13
**Kernel:** `6.18.62-nova` (aus Phase 11.5.1, `build/output/sysroot-drivers`)
**Ergebnis:** RootFS und Initramfs wurden real gebaut und verifiziert — **aber es ist kein unabhängiges NOVA-OS-RootFS, sondern ein technisches Test-RootFS** (Begründung in Abschnitt 3).
**Gesamtstatus:** `STAGE1_OK`, `STAGE2_OK`, `STAGE3_OK`, `STAGE4_OK`, `VERIFIKATION_OK`

---

## 1. Auftrag und Grenzen

Gefordert war ein echtes, überprüfbares NOVA-OS-RootFS samt passendem Initramfs für `6.18.62-nova`, ohne Platzhalter, ohne simulierte Dateien, ohne künstliche Erfolgsmeldungen. Ausdrücklich **nicht** Teil dieser Phase: ISO-Erzeugung, VMware-Boot-Test, Test auf physischer Hardware, Secure Boot, Umstellung der Kernel-Baseline, Löschen alter Artefakte.

Alle diese Grenzen wurden eingehalten. Es wurde kein Boot-Vorgang durchgeführt; die Artefakte sind gebaut und statisch/strukturell verifiziert, nicht gestartet.

## 2. Ausgangslage: keine NOVA-Paketbasis

Vor dem Build wurde der Bestand geprüft:

| Pfad | Inhalt | Bewertung |
|---|---|---|
| `packages/specs/core/` | 3 Spec-Dateien (`nova-release.spec` u. a.) | keine baubare Paketbasis |
| `repositories/` | Skripte zur Repository-Verwaltung | keine Pakete |
| `system/` | 8 Skeleton-Dateien (`os-release`, `fstab` …) | nur Vorlagen |
| `toolchain/` | leer | kein Cross-Toolchain |
| `rootfs/`, `install/` | existieren nicht | keine RootFS-Vorlage |

Es gibt also **keine unabhängige NOVA-Paketbasis**. Die einzige ehrliche Option war eine klar gekennzeichnete Testbasis. Die alten Skripte `build/phase11_create_rootfs.sh` und `build/phase11_generate_initramfs.sh` wurden geprüft und **nicht verwendet**: sie enthalten Platzhalter (`UUID=<root-uuid>`), eine `systemd`-Unit, die nur eine Erfolgsmeldung per `echo` schreibt, eine veraltete `KERNEL_VERSION=6.12.5` und nicht existierende Pfade (`rootfs/`, `install/`).

## 3. Klassifizierung: technisches Test-RootFS, nicht unabhängig

**Das Ergebnis ist kein unabhängiges NOVA-OS.** Es ist ein technisches Test-RootFS auf Ubuntu-24.04-`noble`-Basis (`debootstrap --variant=minbase`), das den NOVA-Kernel, NOVA-Branding und die geforderte Systemausstattung trägt. Die fehlende Unabhängigkeit ist im Artefakt selbst hinterlegt und nicht nur im Bericht:

`/etc/nova/rootfs-class`:
```
class=technical-test-rootfs
independent=nova-package-base-missing
base=ubuntu-noble-debootstrap
kernel=6.18.62-nova
created-by=phase11.6
```

`/usr/lib/os-release` (mit Symlink `/etc/os-release`):
```
NAME="NOVA OS"
PRETTY_NAME="NOVA OS 1.0 (Technisches Test-RootFS)"
ID=nova
ID_LIKE=ubuntu
VERSION="1.0-testrootfs"
VERSION_ID="1.0"
VERSION_CODENAME="Supernova"
DEFAULT_HOSTNAME=nova-test
BUILD_BASIS="Ubuntu 24.04 noble (debootstrap) - TESTROOTFS, keine unabhaengige NOVA-Paketbasis"
```

Jedes Werkzeug, das `os-release` oder `rootfs-class` liest, erkennt den Status damit ohne Rückgriff auf diesen Bericht. Ein unabhängiges NOVA-RootFS setzt eine eigene Paketbasis voraus (Phase ≥ 11.7) — diese Phase liefert die technische Grundlage dafür, nicht das Ergebnis.

## 4. RootFS-Aufbau (Stufe 1 und 2)

**Ziel:** `build/output/rootfs-6.18.62-nova` (neu, nichts überschrieben)
**Werkzeug:** `debootstrap 1.0.134ubuntu2`, Variante `minbase`, Suite `noble`, Quelle `http://archive.ubuntu.com/ubuntu`
**Umgebung:** Ubuntu 24.04.5 LTS, x86_64, Build-Benutzer `ramon`, 5,7 GiB RAM, 74 GB frei

| Kennzahl | Wert |
|---|---|
| debootstrap-Laufzeit | 50 s |
| Ergebnis nach Stufe 1 | 196.554.073 B, 4.043 Dateien, 684 Verzeichnisse |
| Exit-Code | `debootstrap_rc=0`, Marker `STAGE1_OK` |

Stufe 2 installierte die Systemausstattung im chroot (bind-mounts für `dev`, `pts`, `proc`, `sys`, `policy-rc.d` mit `exit 101`, damit keine Dienste im chroot starten):

`systemd systemd-sysv udev dbus kmod dracut network-manager wpasupplicant nftables apparmor apparmor-profiles btrfs-progs e2fsprogs dosfstools squashfs-tools util-linux procps psmisc lsof strace less file iproute2 iputils-ping curl wget ca-certificates tar gzip xz-utils zstd nano linux-firmware`

| Kennzahl | Wert |
|---|---|
| Laufzeit | 104 s |
| Exit-Codes | `apt_update_rc=0`, `apt_install_rc=0`, Marker `STAGE2_OK` |
| Pakete nach Abschluss | **214** |

Einzige Auffälligkeit im Log: `NetworkManager could not reload connections` — erwartbar, da im chroot kein D-Bus-Systembus läuft. Kein Fehler, keine Auswirkung auf das Ergebnis.

**Endstand RootFS:** 789 MB (787.016.470 B nutzbar gezählt), 12.556 Dateien, 1.738 Verzeichnisse, 2.895 Symlinks.

## 5. Paketinventar und Herkunft

Vollständige Liste: `build/phase11_6-logs/phase11_6-packages.txt` (214 Pakete, aus `dpkg-query` im chroot, nicht generiert).

Herkunft: **alle** Pakete stammen aus `http://archive.ubuntu.com/ubuntu` (Suite `noble`) — debootstrap-Basissystem plus die in Abschnitt 4 genannte Liste. Es gibt keine NOVA-eigenen Pakete, keine lokal gebauten `.deb`.

Größte Pakete (KiB, `Installed-Size`): `linux-firmware` 473.705, `libc6` 13.430, `systemd` 11.728, `udev` 10.842, `libpython3.12-stdlib` 9.012. `linux-firmware` dominiert das RootFS allein durch seine Größe (467 MB in `/lib/firmware`).

Schlüsselpakete mit Version:

| Paket | Version |
|---|---|
| systemd / systemd-sysv / udev | 255.4-1ubuntu8 |
| network-manager | 1.46.0-1ubuntu2 |
| nftables | 1.0.9-1build1 |
| apparmor | 4.0.0-beta3-0ubuntu3 |
| btrfs-progs | 6.6.3-1.1build2 |
| e2fsprogs | 1.47.0-2.4~exp1ubuntu4 |
| dracut | 060+5-1ubuntu3 |
| kmod | 31+20240202-2ubuntu7 |
| linux-firmware | 20240318.git3b128b60-0ubuntu2 |
| squashfs-tools | 1:4.6.1-1build1 |
| dosfstools | 4.2-1.1build1 |

## 6. Kernel, Module und Branding (Stufe 3)

Der Kernel wurde aus der Phase-11.5.1-Ausgabe übernommen, die Baseline blieb unangetastet:

| Artefakt | Wert |
|---|---|
| Quelle | `build/output/sysroot-drivers/boot/vmlinuz-6.18.62-nova` |
| Größe | 9.946.112 B |
| SHA-256 (Quelle = Ziel) | `7f1f7d8d4077d191a3b3c5bbabbe85b4ee2328005a26af4cb172f2847c10b5ab` |
| Module kopiert | 98 (`find … -name '*.ko'`) |
| `depmod -b` | `depmod_rc=0`, `modules.dep` mit 98 Einträgen |
| Modulverzeichnis | 51.833.431 B |
| Marker | `STAGE3_OK` |

Begleitdateien im RootFS: `vmlinuz-6.18.62-nova`, `System.map-6.18.62-nova`, `config-6.18.62-nova`, `lib/modules/6.18.62-nova/`.

Branding: `os-release` (Abschnitt 3), `/etc/issue`, `/etc/hostname` = `nova-test`, leere `machine-id` (wird beim ersten Boot bzw. bei der Installation erzeugt).

`/etc/fstab` enthält **bewusst keine Root-UUID** — nur `tmpfs` für `/tmp` und `/var/tmp`. Die NOVA-Vorlage aus `system/filesystem-skeleton` arbeitet mit Btrfs-Subvolumes und echten UUIDs; solche Einträge wären in einem nicht installierten Test-RootFS reine Platzhalter. Die Root-Partition wird beim Booten über Kernel/Initramfs übergeben; echte UUID-Einträge entstehen erst mit der Installation (Phase ≥ 11.8). Das ist eine bewusste Leerstelle, kein vergessener Wert.

## 7. Initramfs-Aufbau mit dracut (Stufe 4)

**Ziel:** `build/output/initramfs-6.18.62-nova.img` (neu)
**Werkzeug:** `dracut 060+5-1ubuntu3.4`

Aufruf (vollständig, aus dem Log):

```
dracut --force --no-hostonly --kver 6.18.62-nova \
  --kmoddir build/output/sysroot-drivers/lib/modules/6.18.62-nova \
  --compress zstd \
  --add "base systemd systemd-udevd systemd-initrd kernel-modules rootfs-block fs-lib" \
  --filesystems "ext4 btrfs squashfs overlay" \
  --omit-drivers "amdgpu i915 xe nouveau iwlwifi btusb snd_hda_intel snd_usb_audio r8169 e1000e vmxnet3 vmw_balloon vmw_vmci vmw_vsock_vmci_transport" \
  --omit "plymouth nfs lvm dm dmraid mdraid multipath crypt iscsi fcoe resume cifs" \
  --no-hostonly-cmdline --logfile phase11_6-dracut.log \
  build/output/initramfs-6.18.62-nova.img
```

20 dracut-Module wurden eingebunden: `systemd`, `systemd-initrd`, `systemd-udevd`, `console-setup`, `i18n`, `btrfs`, `kernel-modules`, `kernel-modules-extra`, `nvdimm`, `qemu`, `lunmask`, `rootfs-block`, `terminfo`, `udev-rules`, `virtiofs`, `dracut-systemd`, `usrmount`, `base`, `fs-lib`, `shutdown`.

| Kennzahl | Wert |
|---|---|
| Laufzeit | 23 s |
| Exit-Code | `dracut_rc=0`, `STAGE4_OK` |
| Größe | 35.828.908 B |
| SHA-256 | `cad8910f89334496eb96950142ad5d2a7175edec4914a7d37b22f4e0f42b158d` |
| Einträge (`lsinitrd`) | 553 |
| udev-Regeln | 37 Dateien |
| systemd-Units | 102 |
| Binaries unter `usr/` | 439 |
| Init | `init → usr/lib/systemd/systemd` |
| Vorab-Microcode | `AuthenticAMD.bin`, `GenuineIntel.bin` (3 Einträge) |

### Warum nur 2 Kernelmodule im Initramfs

Alle geforderten Storage- und Dateisystemtreiber sind im NOVA-Kernel **fest eingebaut**, nicht als Modul gebaut:

```
CONFIG_BLK_DEV_NVME=y   CONFIG_SATA_AHCI=y      CONFIG_BLK_DEV_SD=y
CONFIG_USB_STORAGE=y    CONFIG_USB_HID=y        CONFIG_USB_XHCI_PCI=y
CONFIG_USB_EHCI_PCI=y   CONFIG_VMWARE_PVSCSI=y  CONFIG_BTRFS_FS=y
CONFIG_EXT4_FS=y        CONFIG_SQUASHFS=y       CONFIG_OVERLAY_FS=y
CONFIG_CRYPTO_CRC32C=y
```

Ein Initramfs-Modul für diese Treiber ist damit weder möglich noch nötig; NVMe, AHCI/SATA, SCSI, USB-Speicher und der VMware-PVSCSI-Controller sind ab dem ersten Kernelzustand verfügbar. Enthalten sind nur zwei Module, die dracut als Abhängigkeit mitnimmt: `hid-apple.ko`, `led-class.ko`. Das ist das erwartete Ergebnis einer `=y`-Konfiguration und **keine** unvollständige Modulinstallation — der frühere Verdacht darauf wird in Abschnitt 10 belegt widerlegt.

## 8. Initramfs-Verifikation im Detail

| Prüfung | Ergebnis |
|---|---|
| Format | Cpio-Archiv (SVR4, kein CRC) mit zstd-komprimiertem Abschnitt — zstd-Magic im Image nachgewiesen |
| `lsinitrd` | liest 553 Einträge, Exit 0 |
| Kernelversion-Abgleich | Modulverzeichnis im Image: `lib/modules/6.18.62-nova` → identisch mit `--kver` |
| Storage-Treiber | als `=y` im Kernel nachgewiesen (Abschnitt 7), Module nicht erforderlich |
| Firmware | 0 Dateien im Image — konsistent, da kein Treiber im Image Firmware anfordert |
| Platzhalter | keine leeren Binaries, keine Platzhaltertexte |
| dracut-Log | 53 Zeilen, **0** Fehlerzeilen, 20 Modul-Includes aus genau einem Lauf |
| Rechte | `644 ramon:ramon` (für spätere Phasen lesbar; dracut erzeugt sonst `600 root`) |

Reproduzierbar ist das Image nicht byte-identisch (dracut bettet Zeitstempel ein); verifizierbar sind Struktur, Modulbezug, Kernelversion und Fehlerfreiheit des Logs.

## 9. Firmware-Inventur, Zuordnung und Lücken

**Im RootFS** (`/lib/firmware`, aus `linux-firmware 20240318.git3b128b60-0ubuntu2`):

| Kennzahl | Wert |
|---|---|
| Reguläre Dateien | 2.776 |
| davon `.zst` | 2.761 |
| davon `.xz` | 0 |
| unkomprimiert | 15 (ausschließlich `.jsn`-Deskriptoren für Qualcomm-Modems) |
| Symlinks | 1.528 |
| Größe | 467 MB |
| Loader-Kompression | `CONFIG_FW_LOADER_COMPRESS_XZ=y`, `CONFIG_FW_LOADER_COMPRESS_ZSTD=y` |

`.zst` ist damit zulässig und der Normalfall; der Kernel kann beide Formate entpacken. Die 15 unkomprimierten Dateien sind keine Lücke, sondern JSON-Deskriptoren, die nicht komprimiert ausgeliefert werden.

Vorhandene Firmware nach Zielgruppe: `i915` 120 Dateien, `amdgpu` 449 Dateien, `iwlwifi` 137 Flatfiles (`iwlwifi-*.ucode`). Damit ist die Firmware für die in Phase 11.5.1 gebauten GPU-/WLAN-Module im RootFS vorhanden.

**Im Initramfs:** 0 Dateien. Zuordnung: Die im Initramfs wirksamen Treiber (NVMe, AHCI, SCSI, USB-Speicher, PVSCSI, ext4, Btrfs, SquashFS, OverlayFS) sind fest eingebaut und benötigen keine Firmware. GPU-, WLAN-, Bluetooth- und Audio-Treiber sind per `--omit-drivers` bewusst ausgeschlossen; ihre Firmware wäre im Initramfs reiner Ballast.

**Bekannte Lücken (bewusst, dokumentiert):**
- Keine Firmware im Initramfs ⇒ ein System, das im early boot zwingend WLAN- oder GPU-Firmware braucht, ist mit diesem Image nicht versorgt. Für Storage-Root-Boot ist das irrelevant.
- Der Initramfs enthält keine `uas`-Unterstützung: `CONFIG_USB_UAS` ist im Kernel **nicht** gesetzt (nur `CONFIG_USB_STORAGE=y`). UAS-Gehäuse laufen damit über den USB-Storage-Fallback, nicht über UAS.
- `xe`/`nouveau`-Firmware ist im RootFS nur soweit enthalten, wie `linux-firmware` sie mitbringt; die zugehörigen Module sind nicht Teil der 98 gebauten Module.

## 10. Fehleranalyse: zwei echte Fehlversuche und ihre Ursachen

Beide Fehlversuche sind im Artefaktverzeichnis als Beweis erhalten und nicht gelöscht.

**Versuch 1 — `dracut[E]: Module 'udev' cannot be found`**
Ursache: Ubuntu-dracut 060 kennt kein Modul `udev`; der udev-Pfad heißt dort `systemd-udevd`. Korrektur: `--add "base systemd systemd-udevd systemd-initrd kernel-modules rootfs-block fs-lib"`.

**Versuch 2 — `dracut-install: Failed to find module 'uas'` mit anschließend 0 Modulen im Image**
Ursache: `uas` existiert in diesem Kernel nicht als Modul (`CONFIG_USB_UAS` nicht gesetzt). Ein einziger unauflösbarer Name lässt `dracut-install` die **gesamte** Modulinstallation abbrechen — bei `dracut_rc=0`, weil dracut danach weiterläuft. Das gebaute Image war 35.828.318 B groß und enthielt **null** Module; es wäre beim Booten trotzdem scheinbar „fertig" gewesen. Korrektur: Die Modulliste wird jetzt dynamisch gegen den echten Modulbaum geprüft (`find … -name "$m.ko"`), nicht mehr aus Wunschdenken gesetzt.

**Versuch 3 (Verifikationsfehler, kein Buildfehler) — falsch grüne Prüfung**
Die Prüfung „dracut-Log ohne Fehlerzeilen" meldete OK, obwohl das Log noch die Fehler des ersten Laufs enthielt: dracut **hängt** an `--logfile` an. Korrektur: Das Log wird vor jedem Lauf gelöscht, und die Prüfung verwendet ein Regex, das die echten Fehlerformate trifft (`^E:`, `^dracut[E]`, `Failed to find module`) — zusätzlich wird die Zahl der Modul-Includes ausgegeben (20 = genau ein Lauf). Erst danach ist die Aussage belastbar.

Erhaltene Beweisartefakte: `initramfs-6.18.62-nova.img.vorheriger-build` (Versuch 2) und `…img.vorheriger-build-20261113T200712` (Zwischenstand).

## 11. Reproduzierbarkeit: Skripte, Logs, Exit-Codes

Vier Build-Stufen plus Verifikation, alle als Skript im Repo und im Gast unter `/home/ramon/nova-os/build/`:

| Skript | Aufgabe | Abbruchverhalten |
|---|---|---|
| `phase11_6_stage1_debootstrap.sh` | debootstrap noble minbase | bricht ab, wenn das Ziel existiert |
| `phase11_6_stage2_packages.sh` | chroot-apt, 28 Pakete | bricht bei apt-Fehler ab, räumt bind-mounts ab |
| `phase11_6_stage3_kernel_branding.sh` | Kernel, Module, `depmod -b`, Branding | prüft Quell-Hash vor der Übernahme |
| `phase11_6_stage4_initramfs.sh` | dracut, dynamische Modulliste | sichert vorhandenes Image, löscht Log, prüft rc **und** Existenz |
| `phase11_6_stage5_verification.sh` | 13 Prüfblöcke | zählt Fehlschläge, Endmarker `VERIFIKATION_OK`/`VERIFIKATION_FEHLER=n` |

Exit-Codes und Marker: `debootstrap_rc=0`, `apt_update_rc=0`, `apt_install_rc=0`, `depmod_rc=0`, `dracut_rc=0`, `STAGE1_OK`, `STAGE2_OK`, `STAGE3_OK`, `STAGE4_OK`, `VERIFIKATION_OK`.

Logs im Host-Repo (`build/phase11_6-logs/`): `phase11_6-debootstrap.log` (15.575 B), `phase11_6-apt.log` (54.086 B), `phase11_6-dracut.log` (3.770 B), `phase11_6-stage4.out` (4.723 B), `phase11_6-verification.out` (5.368 B), `phase11_6-packages.txt` (214 Zeilen), `phase11_6-initramfs-modules.txt`, `phase11_6-initramfs-firmware.txt` (leer = 0 Dateien), `phase11_6-umgebungsdaten.txt`, `phase11_6-detailfakten*.txt`.

Sicherheitsregeln eingehalten: Build als `ramon`, Root-Operationen ausschließlich über gezielte Skript-Re-Execs, **keine** rekursiven Berechtigungsänderungen, keine Änderung an `~/nova_os`, Host-Kernel oder VM-Konfiguration, keine alten Artefakte gelöscht.

## 12. Hashes und Größen (Gesamtübersicht)

| Artefakt | Größe | SHA-256 |
|---|---|---|
| Kernel `vmlinuz-6.18.62-nova` | 9.946.112 B | `7f1f7d8d4077d191a3b3c5bbabbe85b4ee2328005a26af4cb172f2847c10b5ab` |
| RootFS `rootfs-6.18.62-nova` | 789 MB (787.016.470 B) | nicht als Einzeldatei gehasht (Verzeichnis, 12.556 Dateien) |
| Module im RootFS | 98 Dateien, 51.833.431 B | Vermagic aller 98 = `6.18.62-nova` |
| Initramfs `initramfs-6.18.62-nova.img` | 35.828.908 B | `cad8910f89334496eb96950142ad5d2a7175edec4914a7d37b22f4e0f42b158d` |
| Baseline-Kernel `sysroot/boot/vmlinuz-nova-6.18.62` | unverändert | `868a959ecb991423525ff9e33dcab44192da6d0acbf84c361c79d0327f9b8785` |
| Baseline-Module `sysroot` | 20 Module (unverändert) | — |
| ISO `validation-20261108-2059.iso` | 130.662.400 B (unverändert) | — |

## 13. Bewertung, Grenzen und was diese Phase nicht liefert

**Erreicht:** Ein real gebautes RootFS mit 214 Paketen, NOVA-Kernel `6.18.62-nova`, 98 Modulen, systemd 255.4 und vollständigem Storage-/Dateisystem-Stack; ein dracut-Initramfs mit sauberem Log, korrektem Kernelbezug und zstd-Kompression. Beide Artefakte sind strukturell verifiziert, alle Kennzahlen stammen aus echten Messungen, es gibt keine Platzhalter und keine erzeugten Erfolgsmeldungen.

**Nicht erreicht — und das ist die zentrale Aussage dieser Phase:** Das RootFS ist **kein unabhängiges NOVA-OS**. Es basiert vollständig auf Ubuntu 24.04 `noble`; jede Binärdatei außer dem Kernel stammt aus dem Ubuntu-Archiv. Kennzeichnung in `os-release` und `/etc/nova/rootfs-class` macht das unübersehbar. Ein unabhängiges NOVA-RootFS erfordert eine eigene Paketbasis — die existiert nicht und ist nicht Teil dieser Phase.

**Nicht durchgeführt (auftragsgemäß):** kein Boot-Test, kein VMware-Start, keine ISO, kein Test auf physischer Hardware, kein Secure Boot, keine Umstellung der Baseline, kein Löschen alter Artefakte.

**Offene Punkte für Folgeschritte:**
1. Boot-Test des Initramfs gegen das RootFS (eigene Phase, VMware) — die eigentliche Bewährungsprobe; bis dahin ist „bootfähig" **nicht** belegt.
2. `CONFIG_USB_UAS` im Kernel aktivieren, wenn UAS-Gehäuse unterstützt werden sollen.
3. `/etc/fstab` mit echten UUIDs und Btrfs-Subvolumes erst bei der Installation (Phase ≥ 11.8).
4. Paketbasis für echte Unabhängigkeit (Phase ≥ 11.7) — erst danach darf von „NOVA OS" ohne Test-Zusatz gesprochen werden.
5. `machine-id`, Hostkeys und Benutzerkonten werden bei der Installation erzeugt, nicht im Test-RootFS vorweggenommen.

**Fazit:** Die Phase liefert ein belastbares, ehrlich gekennzeichnetes Test-RootFS plus passendes Initramfs als technische Grundlage. Sie liefert ausdrücklich **kein** unabhängiges NOVA-Betriebssystem und **keinen** Boot-Nachweis.

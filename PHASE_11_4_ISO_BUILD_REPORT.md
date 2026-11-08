# NOVA OS – ISO-Fehleranalyse, Build-Reparatur und Berechtigungsbereinigung

**Datum**: 2026-11-08
**Umgebung**: Ubuntu 24.04.4 LTS, Kernel 7.0.0-42-generic, VMware Workstation Pro 26.0.0
**Projekt**: `/home/ramon/nova-os` (Benutzer `ramon`, UID 1000)
**Analysierte ISO**: `build/output/nova-os-1.0-supernova-x86_64.iso` (34.867 Bytes, SHA-256 `44ad4a8ddc133e60ab49801ccfbf486054d34267aa28ede23f3879e9014e1ea5`)

---

## 1. Fehlerursache

**Die ISO ist kein fehlerhaft gebautes Image, sondern eine nie gebaute Distribution.** Kernel, Initramfs und Rootfs wurden nicht kompiliert bzw. gepackt; es existieren ausschließlich Textplatzhalter. Der „Build" hat sie als Text eingelesen, als Text weitergeschrieben und daraus eine von Hand zusammengesetzte Datei mit ISO-Magic erzeugt.

### 1.1 Warum die Datei 34.867 Bytes groß ist

`build/tools/nova_iso_builder.py` (`build_iso()`) setzt das Image byteweise selbst zusammen:

| Bestandteil | Bytes |
|---|---|
| `b"\x00" * 32768` (sog. „Standard System Area") | 32.768 |
| handgeschriebener „PVD": `b"\x01CD001\x01\x00"` (7) + `"NOVA_OS_LIVE"` aufgefüllt auf 32 + `2000` Nullbytes | 2.039 |
| Textzeile `"\nNOVA OS 1.0 (Supernova) - Live & Installable x86_64 Image\n"` | 60 |
| **Summe** | **34.867** |

Das entspricht exakt der Dateigröße. **xorriso, grub-mkrescue oder mksquashfs werden im gesamten Ablauf nie aufgerufen** – die Werkzeuge waren zum Zeitpunkt des Builds auch nicht installiert (AUDIT_REPORT.md bestätigt das).

### 1.2 Warum die ISO strukturell ungültig ist

Gemessen im Gast:

```
file:            ISO 9660 CD-ROM filesystem data
xorriso:         libisofs: FAILURE : Wrong or damaged Primary Volume Descriptor
Volume Space Size (PVD-Offset 80): 00 00 00 00 00 00 00 00   → 0 Sektoren
CD001-Marker im gesamten Image:     1
Sektor 0 (System Area):             komplett 0x00, kein Bootcode
Sektor 17 (Volume Descriptor Terminator): kein Terminator, sondern Text " 1.0 (S"
El Torito:                          nicht vorhanden
Partitionstabelle:                  68 Sektoren, keine Partition
```

Die `file`-Erkennung „ISO 9660" beruht allein auf den Magic-Bytes `CD001` bei Offset 32.768. Der Primary Volume Descriptor ist aber unvollständig (Größenfeld 0, kein Root-Directory-Record, kein Terminator-Descriptor), und ohne El-Torito-Eintrag ist das Image **nicht bootfähig** – weder BIOS noch UEFI.

### 1.3 Warum Kernel, Rootfs und Initramfs nicht gebaut wurden

`kernel/scripts/kernel_builder.py`, `install_kernel()` (frühere Fassung):

```python
kernel_header = f"NOVA OS Linux Kernel Image v{version} (x86_64, Btrfs, AppArmor, DRM)\n"
vmlinuz_target.write_text(kernel_header, encoding="utf-8")
initramfs_target.write_text(f"NOVA OS Dracut Initramfs for v{version} ...\n", encoding="utf-8")
```

Es gibt keinen `make`-, `dracut`- oder `mksquashfs`-Aufruf. Der Parameter `fake_binary: bool = True` dokumentiert die Absicht sogar im Code. `build/output/sources` ist leer, es existiert kein Kernel-Quellbaum, kein `.config`, kein `bzImage`.

Beleg am Dateisystem (alle Dateien sind ASCII-Text):

| Datei | Größe | Inhalt |
|---|---|---|
| `build/output/sysroot/boot/vmlinuz-nova-current` | 65 B | `NOVA OS Linux Kernel Image v7.3.3 (x86_64, Btrfs, AppArmor, DRM)` |
| `build/output/sysroot/boot/initramfs-nova-current.img` | 54 B | `NOVA OS Dracut Initramfs for v7.3.3 (zstd compressed)` |
| `build/output/iso/LiveOS/rootfs.img` | 57 B | `NOVA OS SquashFS Compressed Rootfs Image (ZSTD level 19)` |
| `build/output/iso/LiveOS/vmlinuz-nova-current` | 65 B | derselbe Textkern |
| `build/output/iso/LiveOS/initramfs-nova-current.img` | 54 B | derselbe Textinitramfs |

`file` klassifiziert alle fünf als `ASCII text`.

### 1.4 Warum der Build trotzdem „erfolgreich" meldete

Drei unabhängige Fehler verstärkten sich:

1. `NovaIsoBuilder.build_iso()` gab es keine Fehlerpfade – sie schrieb die Datei und meldete Erfolg.
2. `build/tools/nova_build.py`, `step_iso()`: `builder.build_iso()` wurde aufgerufen, `return True` war **hart verdrahtet**. `build_all()` druckte anschließend „BUILD ERFOLGREICH ABGESCHLOSSEN".
3. `testing/run_tests.py`, `test_01`/`test_05` prüften nur `path.exists()` bzw. `size > 1000`. Ein 65-Byte-Textstub erfüllt beides. `test_report.json` meldete deshalb „Hybrid-ISO … erstellt".

### 1.5 Zweiter, noch nicht ausgelöster Defekt

`prepare_iso_tree()` las den Kernel mit `read_text(encoding="utf-8")`. Sobald ein **echtes** bzImage vorhanden gewesen wäre, hätte dieser Aufruf mit `UnicodeDecodeError` abgebrochen – der ISO-Schritt wäre also auch mit korrektem Kernel gescheitert. Zusätzlich erzeugte der Builder eine **gefälschte** GPG-Signatur (`.asc` mit PGP-Rahmen, aber ohne echte Signatur) und Release Notes, die einen „fest einkompilierten Kernel 6.12.10" behaupteten.

### 1.6 Warum die Bash-Kette unabhängig davon nicht funktionierte

`build/phase11_create_iso.sh`, `phase11_generate_initramfs.sh`, `phase11_build_kernel.sh` und `phase11_create_rootfs.sh` berechneten die Projektwurzel mit `$(dirname "${BASH_SOURCE[0]}")/../..`. Die Skripte liegen in `build/`, der Pfad war damit eine Ebene zu hoch und zeigte auf `/home/ramon`. Gemessen vor der Korrektur:

```
[ERROR] Kernel not found: /home/ramon/install/boot/vmlinuz-nova
```

Das Skript brach zwar ab (Exit 1), aber aus dem falschen Grund – die Fehlermeldung verschleierte den Pfadfehler. Zusätzlich enthielt `create_iso()` die Optionen `--grub-mkrescue-core` und `--xorriso`, die `grub-mkrescue` nicht kennt.

---

## 2. Zustand der bisherigen Build-Artefakte

| Artefakt | Zustand |
|---|---|
| Kernel (`vmlinuz-nova-*`, `-current`) | Textplatzhalter, 65 B, kein ELF/bzImage |
| Initramfs (`initramfs-nova-*.img`) | Textplatzhalter, 54 B, kein cpio/gzip/zstd |
| Rootfs / `rootfs.img` | Textplatzhalter, 57 B, kein SquashFS; kein Rootfs-Verzeichnis vorhanden |
| GRUB-Konfiguration | Text vorhanden, verweist auf `(hd0,gpt2)` und `LABEL=NOVA_ROOT`; kein Bootloader-Binary |
| `EFI/BOOT/` | nur `grub.cfg`, kein `BOOTX64.EFI` |
| `build/output/sources` | leer |
| `build/output/tools/STAGE1_READY` | 44-B-Textmarkierung, kein Compiler |
| ISO-Kopien | 5 Dateien mit identischem SHA-256 (siehe 5.3) |

**Fazit**: Es existiert kein einziges echtes Build-Artefakt. Die gesamte Kette „Kernel → Rootfs → Initramfs → GRUB → ISO" ist nicht ausgeführt worden.

---

## 3. Betroffene Dateien und vorgenommene Korrekturen

### 3.1 `build/tools/nova_iso_builder.py` – neu implementiert

* **Validierung vor dem Staging**: `validate_kernel()` (ELF-Magic oder bzImage-`HdrS` bei Offset 0x202, ≥ 1 MB), `validate_initramfs()` (gzip/xz/zstd/lz4/cpio-newc, ≥ 100 kB), `validate_squashfs()` (`hsqs`, ≥ 100 kB), RootFS-Verzeichnis mit ≥ 10 Dateien.
* **Binärsichere Kopien** via `shutil.copy2` statt `read_text`/`write_text`.
* **Echtes SquashFS** über `mksquashfs -comp zstd -Xcompression-level 6 -b 1M`.
* **Echtes ISO** über `grub-mkrescue` (BIOS-El-Torito + UEFI in einem Lauf), Staging pro Build unter `build/output/iso-stage/<name>` (kein `rm -rf` auf Altbeständen).
* **Nachverifikation** `verify_iso()`: ≥ 5 MB, `ISO 9660` laut `file`, El-Torito-Eintrag laut `xorriso`, `/LiveOS/vmlinuz-nova-current`, `/LiveOS/initramfs-nova-current.img`, `/LiveOS/rootfs.img` im Image, lesbarer PVD.
* **Kein Überschreiben**: existiert die Zieldatei oder das Staging-Verzeichnis, bricht der Build ab. Standardname ist zeitgestempelt.
* **Keine Falschangaben mehr**: keine gefälschte `.asc`-Signatur, keine erfundenen Release Notes.
* Fehler werden als `ArtifactError` mit Exit-Code 1 gemeldet.

### 3.2 `kernel/scripts/kernel_builder.py`

`install_kernel(version, bzimage=None, initramfs=None)` akzeptiert nur echte Artefakte (`--bzimage`/`--initramfs` oder `NOVA_BZIMAGE`/`NOVA_INITRAMFS`) und weist Platzhalter ab, **ohne** Dateien oder den Kernel-Zustand zu verändern. Neue Helfer `_is_real_bzimage()` / `_is_real_initramfs()`. Die Textstub-Schreibpfade sind entfernt.

### 3.3 `build/tools/nova_build.py`

`step_iso()` fängt `ArtifactError` und liefert `False`; `step_kernel()` liefert `False`, wenn kein echtes Kernel-Artefakt vorliegt. „BUILD ERFOLGREICH ABGESCHLOSSEN" ist damit nur noch nach vollständig verifizierten Schritten erreichbar.

### 3.4 `testing/run_tests.py`

`test_01` prüft jetzt die bzImage-Signatur statt der Existenz, `test_05` wertet `verify_iso()` aus und meldet einen korrekten Abbruch als Fehlschlag mit Ursache, `test_15` verlangt ein echtes Kernel-Artefakt für die Rotation.

### 3.5 `build/phase11_create_iso.sh`, `phase11_generate_initramfs.sh`, `phase11_build_kernel.sh`, `phase11_create_rootfs.sh`

* `NOVA_ROOT` von `/../..` auf `/..` korrigiert (Projektwurzel statt `/home/ramon`).
* `create_iso.sh`: Kernel-/Initramfs-Platzhalter werden über Größe und `file`-Signatur abgewiesen, SquashFS wird auf `hsqs` und Mindestgröße geprüft, `grub-mkrescue` ohne die ungültigen Optionen aufgerufen, und `verify_iso()` bricht bei < 5 MB, fehlendem ISO-9660 oder fehlendem El-Torito mit Exit 1 ab.

---

## 4. Berechtigungsänderungen

Ausgangslage: `sudo python3 build/tools/nova_build.py --all` hatte den gesamten Ausgabebaum als `root` erzeugt.

| Objekt | Vorher | Nachher |
|---|---|---|
| `~/nova-os/build/output` (rekursiv, 50 Einträge) | `root:root` | `ramon:ramon` (0 root-eigene Einträge) |
| `~/nova-os/phase11_3_dependencies_install.log` | `root:root` | `ramon:ramon` |
| `~/nova_os` (435 Einträge) | `root:root` | **unverändert** (nur gelesen) |

Der `chown -R` wurde erst nach vollständiger Auflistung der betroffenen Pfade ausgeführt und ausschließlich auf `build/output` angewendet, nicht auf das Projekt oder das Home-Verzeichnis. `mtools` wurde als einziges Paket nachinstalliert (für UEFI-El-Torito über `grub-mkrescue`); es war bereits vorhanden, `0 neu installiert`.

Verbleibend root-eigen (nicht kritisch, nicht angefasst): drei `.pyc`-Dateien unter `repositories/scripts/__pycache__`, `bootstrap/stage0/__pycache__`, `bootstrap/__pycache__` aus früheren Root-Läufen.

---

## 5. Ausgeführte Tests und tatsächliche Ergebnisse

### 5.1 Statische Prüfungen (ausgeführt, bestanden)

| Prüfung | Ergebnis |
|---|---|
| `python3 -m py_compile` für die vier geänderten Python-Dateien | OK |
| `bash -n` für alle vier geänderten Shell-Skripte (Host und Gast) | 4/4 OK |
| ShellCheck `-S error` für die vier Shell-Skripte | 0 Befunde |
| Projekt-Testsuite `phase11_2_automated_tests.sh` im Gast | 10/10, Exit 0 |

### 5.2 Negativtests – Build muss bei Platzhaltern abbrechen (ausgeführt, bestanden)

| Test | Ergebnis |
|---|---|
| `nova_iso_builder.py` mit vorhandenen 65-B-Platzhaltern | Exit 1, Meldung „Kernel ist kein echtes Image … 65 Bytes", **keine ISO erzeugt** |
| `kernel_builder.py --build` mit Platzhalter | Exit 1, Meldung „Kein echtes Kernel-Image (ELF/bzImage)", kein Zustandswechsel |
| `nova_build.py --build-iso` | Exit 1, „ISO-Erstellung abgebrochen: …", kein „BUILD ERFOLGREICH" |
| `phase11_create_iso.sh` ohne Artefakte | Exit 1, jetzt mit korrektem Pfad `/home/ramon/nova-os/install/boot/vmlinuz-nova` |
| `phase11_generate_initramfs.sh` ohne Rootfs | Exit 1, `/home/ramon/nova-os/rootfs` |

### 5.3 Positivtest – reparierter Builder mit echten Artefakten (ausgeführt, bestanden)

Da kein NOVA-Kernel existiert, wurde die **Pipeline** mit realen Fremdartefakten geprüft (nicht als NOVA-Release gedacht):

* Kernel: `/boot/vmlinuz-7.0.0-42-generic` (Ubuntu, 17.062.280 B, ELF)
* Initramfs: `/boot/initrd.img-7.0.0-42-generic` (77.640.986 B)
* Rootfs: `/usr/share/doc` als realer Verzeichnisbaum (SquashFS 23.769.088 B)

Ergebnis: `build/output/validation-20261108-2059.iso`

```
file:    ISO 9660 CD-ROM filesystem data (DOS/MBR boot sector) 'ISOIMAGE' (bootable)
Größe:   130.662.400 Bytes
PVD:     Volume Id ISOIMAGE, XORRISO-1.5.6
El Torito boot img 1: BIOS  /boot/grub/i386-pc/eltorito.img
El Torito boot img 2: UEFI  /efi.img
LiveOS:  vmlinuz 17.062.280 B, initramfs 77.640.986 B, rootfs.img 23.769.088 B
SHA-256: cb3ba1e2198406714e6cbe3bc9414a61bb2a0e9c08786b71d1f55b4cb5a038a2
```

Damit ist nachgewiesen: SquashFS-Erzeugung, Staging, GRUB-Hybrid-ISO und Nachverifikation funktionieren. **Die Datei enthält keinen NOVA-Kernel und ist kein Release-Image.**

### 5.4 Nicht durchgeführt

* **Vollständiger NOVA-Build (Kernel aus Quellen, eigenes Rootfs, dracut-Initramfs)**: nicht ausgeführt. Es existiert kein Kernel-Quellbaum; ein Lauf bräuchte Download (~150–200 MB) und auf 2 vCPU/5,7 GiB realistisch 45–90 Minuten. Freigabe steht aus (Abschnitt 9).
* **19-teilige Python-Testsuite** (`testing/run_tests.py`): nicht vollständig ausgeführt, da sie ohne echte Artefakte ohnehin an `test_01`/`test_05`/`test_15` scheitern muss und `test_report.json` überschreiben würde.
* **VMware-Boottest**: bewusst nicht gestartet (Vorgabe: keine destruktiven Tests, keine Änderung bestehender VM-Konfigurationen).
* **UEFI-Boottest auf Hardware/VM**: Struktur ist nachgewiesen (El-Torito-UEFI-Eintrag), ein tatsächlicher Bootvorgang wurde nicht ausgeführt.

---

## 6. Zustand der ISO-Dateien

| Datei | Größe | Eigentümer | Bewertung |
|---|---|---|---|
| `~/nova-os/build/output/nova-os-1.0-supernova-x86_64.iso` | 34.867 | ramon | ungültig, nicht bootfähig (Analyseobjekt, **nicht gelöscht**) |
| `~/nova-os/nova-os-1.0-supernova-x86_64.iso` | 34.867 | ramon | identische Kopie, nicht bootfähig |
| `~/nova_os/build/output/nova-os-1.0-supernova-x86_64.iso` | 34.867 | root | identische Kopie (früherer Root-Lauf), unangetastet |
| `/nova.iso` | 34.867 | root | Rest eines Root-Laufs außerhalb des Projekts |
| `/nova-test.iso` | 34.867 | root | Rest eines Root-Laufs außerhalb des Projekts |
| `~/nova-os/build/output/validation-20261108-2059.iso` | 130.662.400 | ramon | gültige Hybrid-ISO (Pipeline-Nachweis, kein Release) |

Alle fünf 34.867-Byte-Dateien haben denselben SHA-256 – es ist dasselbe Artefakt aus mehreren Läufen.

---

## 7. Offene Probleme

1. **Kein Kernel-Quellbaum, kein Rootfs, kein dracut-Lauf** – ohne diese Schritte kann keine echte NOVA-ISO entstehen.
2. **Bootstrap-Stage 1/2 sind Simulation** (`bootstrap_manager.py` schreibt `STAGE1_READY` als Textmarkierung). Ein echter Build setzt entweder eine hermetsche Toolchain oder den Host-Compiler voraus; das ist eine Architekturentscheidung, die ich nicht eigenmächtig treffe.
3. **`rootfs`-Verzeichnis fehlt** – `phase11_create_rootfs.sh` erwartet `$NOVA_ROOT/rootfs`, das nie angelegt wurde.
4. **Drei root-eigene `.pyc`-Dateien** verbleiben (unkritisch).
5. **`/nova.iso` und `/nova-test.iso`** liegen außerhalb des Projekts und wurden nicht gelöscht.
6. **`~/nova_os`** ist weiterhin vollständig root-eigen und wird nicht verändert, solange keine Freigabe vorliegt.
7. **Fremdartefakt-ISO** (`validation-…iso`) belegt 130 MB in `build/output` und sollte vor einem echten Release entfernt oder klar als Testartefakt gekennzeichnet werden.

---

## 8. Empfehlung für den nächsten Build

1. **Kernel aus Quellen bauen**, ohne Root: `linux-source` entpacken, `nova_defconfig` als `.config`, `make -j2 bzImage modules`, `modules_install` nach `build/output/sysroot`. Ergebnis nach `build/output/sysroot/boot/vmlinuz-nova-current`.
2. **Rootfs minimal aufbauen** (`debootstrap --variant=minbase` nach `$NOVA_ROOT/rootfs`, danach `chown -R` auf den Benutzer) – dieser Schritt braucht Root, alle folgenden nicht.
3. **Initramfs mit dracut** gegen dieses Rootfs erzeugen (`--kver <version>-nova`), Ergebnis nach `sysroot/boot/initramfs-nova-current.img`.
4. **ISO bauen** mit dem reparierten Builder; er verifiziert jetzt selbst und bricht bei jedem fehlenden oder unechten Artefakt ab.
5. **Erst danach** Boottest in einer **separaten** Wegwerf-VM (BIOS und UEFI getrennt), nicht in der bestehenden Arbeits-VM.

---

## 9. Statusmatrix

| Phase | Status |
|---|---|
| 1 Bestandsaufnahme (nur lesend) | ✅ ausgeführt |
| 2 ISO-Analyse | ✅ ausgeführt, Ursache eindeutig |
| 3 Build-Kette untersucht | ✅ ausgeführt, drei Fehlerketten belegt |
| 4 Root-Berechtigungen korrigiert | ✅ ausgeführt (Build-Baum), `~/nova_os` unangetastet |
| 5 Build-Skripte repariert | ✅ ausgeführt (5 Dateien) |
| 6 Tests | ⚠️ teilweise: statische Prüfungen, Negativ- und Pipeline-Positivtest bestanden; vollständiger NOVA-Build **nicht** ausgeführt |
| 7 VMware-Vorbereitung | ⚠️ vorbereitet, nicht verifiziert (kein Boottest, keine VM-Änderung) |
| Abschlussbericht | ✅ dieses Dokument |

# BUILD.md - NOVA OS Build-Dokumentation

Diese Dokumentation beschreibt Schritt für Schritt den vollständigen, reproduzierbaren Build-Prozess von **NOVA OS**.

---

## 1. Voraussetzungen an das Build-System

Um NOVA OS aus den offiziellen Quellcodes zu erstellen, muss das Host-System folgende Mindestanforderungen erfüllen:

- **Architektur**: `x86_64`
- **Betriebssystem**: Linux (natives Host-System, WSL 2 mit Ubuntu/Debian/Fedora oder OCI-Container)
- **Arbeitsspeicher**: Mindestens 16 GB RAM (32 GB empfohlen für parallele LLVM/Clang- und Kernel-Builds)
- **Festplattenspeicher**: Mindestens 80 GB freier Speicherplatz (bevorzugt auf SSD/NVMe)
- **Benötigte Host-Werkzeuge**:
  - Python 3.10+ (mit `hashlib`, `urllib`, `dataclasses`, `subprocess`)
  - GCC / G++ (Version 12+) oder Clang (Version 15+)
  - GNU Make 4.3+, CMake 3.25+, Ninja 1.11+
  - Binutils (ar, as, ld, objcopy, strip)
  - Bison, Flex, M4, Texinfo, Gperf, Awk, Sed, Patch
  - Git, Wget, Curl, Tar, Xz, Zstd
  - `squashfs-tools` (`mksquashfs`)
  - `xorriso`, `syslinux` / `isolinux`
  - `btrfs-progs` (für lokale Image-Tests)
  - `createrepo_c` (für RPM-Repository-Metadaten)

---

## 2. Zweistufiger Bootstrap-Ablauf

```
[Quelltext-Archive mit SHA-256 Validierung]
                    │
                    ▼
       ┌────────────────────────┐
       │   STAGE 0: PRECHECK    │  Prüft Host-Tools, Umgebungsvariablen,
       │  (Host-Umgebungscheck) │  erstellt Verzeichnisbaum
       └────────────────────────┘
                    │
                    ▼
       ┌────────────────────────┐
       │   STAGE 1: TOOLCHAIN   │  Baut x86_64-nova-linux-gnu Cross-Compiler
       │ (Hermetische Toolchain)│  nach /build/output/tools
       └────────────────────────┘
                    │
                    ▼
       ┌────────────────────────┐
       │    STAGE 2: SYSROOT    │  Kompiliert Basissystem in Chroot
       │  (Target-Basissystem)  │  (glibc, systemd, bash, rpm, dnf5)
       └────────────────────────┘
                    │
                    ▼
       ┌────────────────────────┐
       │  STAGE 3: REPOSITORIES │  Erstellt signierte RPM-Pakete und
       │   (Paketierung & DNF5) │  initialisiert stable/testing Repos
       └────────────────────────┘
                    │
                    ▼
       ┌────────────────────────┐
       │     STAGE 4: ISO       │  Erzeugt bootfähiges Live- & Installer-
       │  (Live-Image Builder)  │  Hybrid-ISO-Image (UEFI + BIOS)
       └────────────────────────┘
```

---

## 3. Toolchain-Konfiguration & Compiler-Flags

Alle Binärdateien in NOVA OS werden mit strikten Härtungs- und Optimierungs-Flags kompiliert:

```bash
# Globale C/C++ Compiler-Flags
export CFLAGS="-O2 -march=x86-64-v3 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3 -fcf-protection=full -fPIE"
export CXXFLAGS="-O2 -march=x86-64-v3 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3 -fcf-protection=full -fPIE"

# Globale Linker-Flags (Full RELRO, Bind Now, No-Exec Stack)
export LDFLAGS="-Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack -pie"

# Target-Tupel
export TARGET="x86_64-nova-linux-gnu"
export PREFIX="/usr"
export SYSROOT="/build/output/sysroot"
```

---

## 4. Kernel-Build-Prozess

Der Linux-Kernel wird mit dem NOVA OS Kernel-Builder (`kernel/scripts/kernel_builder.py`) gebaut:

1. **Abruf & Verifikation**:
   - Abfrage von `https://www.kernel.org/releases.json`.
   - Download des neuesten Stable-Tarballs und der Signaturdatei (`.tar.sign`).
   - Kryptografische Verifikation gegen die offiziellen Kernel.org-PGP-Schlüssel.
2. **Konfiguration**:
   - Anwendung von `kernel/configs/nova_defconfig`.
   - Pflicht-Treiber einkompiliert: Btrfs, ext4, NVMe, AHCI, AppArmor, OverlayFS, EFI Stub.
   - Grafik- und Hypervisor-Treiber als Module: `vboxvideo`, `vmwgfx`, `amdgpu`, `i915`, `nouveau`.
3. **Kompilierung**:
   ```bash
   make -j$(nproc) bzImage
   make -j$(nproc) modules
   make modules_install INSTALL_MOD_PATH=$SYSROOT
   install -m 644 arch/x86/boot/bzImage $SYSROOT/boot/vmlinuz-nova-current
   ```
4. **Initramfs-Generierung mit dracut**:
   ```bash
   dracut --force --zstd \
          --kver <KERNEL_VERSION> \
          --add "btrfs systemd udev drm" \
          $SYSROOT/boot/initramfs-nova-current.img
   ```

---

## 5. Paket- und Repository-Erstellung

Die Core- und Desktop-Komponenten werden in native RPM-Pakete gewandelt:

```bash
# Erstellen eines RPM-Pakets aus einer .spec-Datei
rpmbuild -ba \
         --define "_topdir /build/output/rpmbuild" \
         --define "_sysroot /build/output/sysroot" \
         packages/specs/core/systemd.spec

# Aktualisieren der Repository-Metadaten
createrepo_c --database --compatibility repositories/stable/x86_64

# Signieren des Repositories mit dem offiziellen NOVA Release-Key
gpg --detach-sign --armor repositories/stable/x86_64/repodata/repomd.xml
```

---

## 6. ISO-Image Generierung (`nova-iso-builder`)

Das Live- und Installations-ISO wird aus dem Target-Sysroot aufgebaut:

1. **SquashFS Erstellung**:
   ```bash
   mksquashfs $SYSROOT /build/output/iso/LiveOS/rootfs.img -comp zstd -Xcompression-level 19 -b 1048576 -noappend
   ```
2. **GRUB 2 Boot-Konfiguration**:
   - `grub.cfg` wird sowohl im El-Torito-BIOS-Katalog als auch im EFI-System-Image hinterlegt.
   - Kernel-Parameter für Live-Boot: `boot=live rd.live.image quiet splash rd.btrfs=1 nova.live=1`.
3. **Hybrid-ISO Erzeugung via xorriso**:
   ```bash
   xorriso -as mkisofs \
           -iso-level 3 \
           -full-iso9660-filenames \
           -volid "NOVA_OS_LIVE" \
           -eltorito-boot boot/grub/bios.img \
           -no-emul-boot -boot-load-size 4 -boot-info-table \
           --eltorito-catalog boot/grub/boot.cat \
           --eltorito-alt-boot \
           -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat \
           -output /build/output/nova-os-rolling-x86_64.iso \
           /build/output/iso
   ```

---

## 7. Der zentrale Build-Orchestrator (`nova_build.py`)

Alle Einzelschritte sind im modularen Orchestrator `build/tools/nova_build.py` automatisiert:

```bash
# Gesamten Build durchführen (von Host-Check bis ISO)
python build/tools/nova_build.py --all

# Einzelne Stufen ausführen
python build/tools/nova_build.py --stage host-check
python build/tools/nova_build.py --stage toolchain
python build/tools/nova_build.py --stage base-system
python build/tools/nova_build.py --stage desktop
python build/tools/nova_build.py --stage packages
python build/tools/nova_build.py --stage iso
```

# KERNEL_BUILD.md - NOVA OS Kernel-Architektur & Automatisierung

Dieses Dokument beschreibt die automatisierte Kernel-Build-Infrastruktur, die Konfiguration, Modulverwaltung, DKMS-Integration und den Kernel-Rollback-Mechanismus von **NOVA OS**.

---

## 1. Automatische Versionserkennung & Verifikation

NOVA OS integriert ein automatisiertes Überwachungsskript (`kernel/scripts/kernel_builder.py`), das offizielle Kernel-Releases verfolgt:
1. **API-Abfrage**: Abruf von `https://www.kernel.org/releases.json`.
2. **Kanal-Prüfung**: Identifikation des neuesten offiziellen `stable`-Releases.
3. **Kryptografische Signaturprüfung**:
   - Download des Tarballs (`linux-<VER>.tar.xz`) und der Signatur (`linux-<VER>.tar.sign`).
   - Überprüfung gegen die offiziellen PGP-Schlüssel von Greg Kroah-Hartman (`647F 2865 4894 E3BD 4571 99BE 38DB BDDC 2345 6A80`) und Sasha Levin.
   - Kein Kernel wird ohne bestandene kryptografische Prüfung in den Build-Prozess übernommen.

---

## 2. Kernel-Konfigurationsphilosophie (`nova_defconfig`)

Die offizielle Kernel-Konfiguration von NOVA OS folgt strengen Richtlinien:

- **Feste einkompilierte Treiber (`=y`)**:
  - Dateisysteme: `CONFIG_BTRFS_FS=y`, `CONFIG_EXT4_FS=y`, `CONFIG_OVERLAY_FS=y`
  - Speicher-Controller: `CONFIG_BLK_DEV_NVME=y`, `CONFIG_ATA=y`, `CONFIG_SATA_AHCI=y`, `CONFIG_USB_STORAGE=y`
  - Boot & EFI: `CONFIG_EFI_STUB=y`, `CONFIG_EFI=y`, `CONFIG_FB_EFI=y`
  - Sicherheit: `CONFIG_SECURITY_APPARMOR=y`, `CONFIG_DEFAULT_SECURITY_APPARMOR=y`, `CONFIG_NETFILTER=y`
  - Kompression: `CONFIG_ZSTD_COMPRESS=y`, `CONFIG_ZSTD_DECOMPRESS=y`
- **Modulare Treiber (`=m`)**:
  - Grafiktreiber:
    - VMware SVGA: `CONFIG_DRM_VMWGFX=m`
    - VirtualBox VMSVGA / Video: `CONFIG_DRM_VBOXVIDEO=m`
    - AMD: `CONFIG_DRM_AMDGPU=m`
    - Intel: `CONFIG_DRM_I915=m`, `CONFIG_DRM_XE=m`
    - NVIDIA: `CONFIG_DRM_NOUVEAU=m`
  - Virtualisierungs-Gastreiber:
    - `CONFIG_VBOXGUEST=m`
    - `CONFIG_VMWARE_VMCI=m`, `CONFIG_VMXNET3=m`
  - Audio:
    - `CONFIG_SND_HDA_INTEL=m`, `CONFIG_SND_SOC_SOF_TOPLEVEL=m`
  - Netzwerk:
    - Gängige Gigabit/10G Ethernet- und Intel/Realtek Wi-Fi-Module

---

## 3. Initramfs-Generierung mit dracut

Nach der Kernel-Kompilierung wird ein modulares, minimales und zstd-komprimiertes Initramfs erzeugt:

```bash
dracut --force \
       --zstd \
       --kver "$KERNEL_VERSION" \
       --add "btrfs systemd udev drm plymouth" \
       --omit "lvm mdraid multipath" \
       "$OUTPUT_DIR/initramfs-nova-current.img"
```

---

## 4. Multi-Kernel-Retention & Rollback-Strategie

Um unbootbare Systeme auszuschließen, hält NOVA OS stets mindestens zwei bootfähige Kernel-Generationen vor:

```
/boot/
├── vmlinuz-nova-current           (Neuester validierter Stable-Kernel)
├── initramfs-nova-current.img
├── vmlinuz-nova-previous          (Vorheriger bewährter Kernel)
├── initramfs-nova-previous.img
├── vmlinuz-nova-recovery          (Minimaler Notfall-Kernel mit integriertem Initramfs)
└── grub/
    └── grub.cfg                   (Enthält Menüeinträge für Current, Previous und Recovery)
```

### Rollback-Mechanismus
1. Bei einem Kernel-Update wird der bisherige `current`-Kernel zu `previous` umbenannt:
   - `mv vmlinuz-nova-current vmlinuz-nova-previous`
   - `mv initramfs-nova-current.img initramfs-nova-previous.img`
2. Der neue Kernel wird als `current` installiert.
3. **GRUB Boot-Counting**:
   - GRUB zählt fehlgeschlagene Boot-Versuche (`boot_counter`).
   - Schlägt der Boot des neuen Kernels fehl (z. B. Kernel Panic oder Timeout), schaltet GRUB beim nächsten Boot automatisch auf `vmlinuz-nova-previous` um.
   - Der Benutzer kann im Boot-Menü jederzeit manuell "NOVA OS (Previous Kernel)" oder "NOVA OS Recovery Mode" auswählen.

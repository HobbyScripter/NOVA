# Phase 11.5.1 – Kernel Driver Expansion

**Datum**: 2026-11-08
**Umgebung**: Ubuntu 24.04.4 LTS, 2 vCPU, 5,7 GiB RAM, 74 GB frei (nach Build)
**Projekt**: `/home/ramon/nova-os`
**Ergebnis**: **ERFOLGREICH** – Kernel `6.18.62-nova` mit 98 Modulen neu kompiliert und unabhängig verifiziert; der in Phase 11.5 verifizierte Kernel bleibt unverändert erhalten.

---

## 1. Ausgangslage und Sicherung

Basis war der in Phase 11.5 gebaute, verifizierte Kernel:

| Merkmal | Baseline (Phase 11.5) |
|---|---|
| Kernel | 6.18.62-nova |
| `bzImage` | 8.922.112 Bytes, SHA-256 `868a959ecb991423525ff9e33dcab44192da6d0acbf84c361c79d0327f9b8785` |
| Module | 20 |
| Konfiguration | `kernel/configs/nova-6.18.62.config` (1.310 `CONFIG_`-Zeilen) |

Vor jeder Änderung gesichert:

* `build/output/phase11_5-artifacts-backup.tar.zst` (19.099.558 Bytes) – enthält `sysroot/boot` und `sysroot/lib/modules` der Baseline.
* Der Quellbaum `build/kernel-build/linux-6.18.62` wurde **nicht angefasst**; sein `bzImage` trägt nach dem Lauf weiterhin SHA-256 `868a959e…9b8785`.
* Der neue Build entstand in einer **separaten** Quellkopie `linux-6.18.62-drv` (aus dem bereits signaturgeprüften Tarball) und wurde in ein **separates** Staging `build/output/sysroot-drivers` installiert. `sysroot` selbst blieb unverändert (weiterhin 20 Module).

## 2. Bestandsaufnahme

Fehlend gegenüber dem Auftrag waren in der Baseline:

| Bereich | Baseline | Ursache |
|---|---|---|
| AMD-Grafik | fehlt | `=m` gesetzt, aber Abhängigkeiten (Firmware-Loader, I²C, Backlight, DRM-Helper) im Fragment nicht aktiv |
| Intel-Grafik | fehlt | dito |
| NVIDIA (nouveau) | fehlt | dito |
| HD-Audio | fehlt | `SND_HDA`, `SND_PCI` nicht aktiviert |
| VMware VMCI/Balloon/Vsock | fehlt | `VMCI`, `VSOCKETS` nicht aktiviert |
| WLAN/Bluetooth | fehlt | `CFG80211`, `MAC80211`, `BT` nicht aktiviert |

## 3. Konfigurationsstrategie

Ausgangspunkt: `nova-6.18.62.config`. Ergänzt wurden zuerst die **Abhängigkeiten**, dann die Treiberziele, danach `make olddefconfig` (zweimal, um indirekte Abhängigkeiten aufzulösen).

Drei Fallstricke traten dabei auf und wurden behoben:

1. **`make O=<dir>` scheitert an einem bereits gebauten Quellbaum.** Kbuild verweigert ein Out-of-tree-Verzeichnis, wenn im Quellbaum generierte Dateien liegen (`outputmakefile`-Fehler). Lösung: saubere zweite Quellkopie per `tar --strip-components=1`.
2. **`CONFIG_VMWARE_VSOCKETS` existiert nicht.** Das Symbol heißt `CONFIG_VMWARE_VMCI_VSOCKETS`. Mit dem falschen Namen blieb der Transport ungesetzt.
3. **Firmware wird auf Ubuntu als `.zst` ausgeliefert** (675 AMD-Dateien, 0 unkomprimierte). Ohne `CONFIG_FW_LOADER_COMPRESS_ZSTD` hätte der Kernel die Firmware nicht laden können – obwohl die Dateien vorhanden sind. Ergänzt und in 27 Sekunden inkrementell nachgebaut.

Ergebnis: **1.541 `CONFIG_`-Zeilen** (Baseline 1.310), **98 `=m`**, `.config` = 137.233 Bytes, `kernelrelease` = `6.18.62-nova`.
Gespeichert als `kernel/configs/nova-6.18.62-drivers.config` und gegenprüfbar identisch mit der aus dem `bzImage` extrahierten Konfiguration (`build/kernel-build/ikconfig-extracted-6.18.62-drv.txt`).

## 4. Grafikunterstützung

| Treiber | CONFIG | Status | Artefakt |
|---|---|---|---|
| AMD | `CONFIG_DRM_AMDGPU=m`, `CONFIG_DRM_AMD_DC=y` | **als Modul verfügbar** | `amdgpu.ko`, 21.406.920 Bytes |
| Intel (i915) | `CONFIG_DRM_I915=m` | **als Modul verfügbar** | `i915.ko`, 8.255.360 Bytes |
| Intel (Xe) | `CONFIG_DRM_XE=m`, `CONFIG_DRM_XE_DISPLAY=y` | **als Modul verfügbar** | `xe.ko`, 6.213.760 Bytes |
| NVIDIA Open Source | `CONFIG_DRM_NOUVEAU=m` | **als Modul verfügbar** | `nouveau.ko`, 5.760.072 Bytes |
| VMware | `CONFIG_DRM_VMWGFX=y` | **fest integriert** | 329 `vmw_*`-Symbole in `System.map`, u. a. `vmw_probe` |
| DRM/KMS-Helfer | `CONFIG_DRM=y`, `DRM_KMS_HELPER`, `DRM_DISPLAY_HELPER`, `DRM_TTM`, `DRM_SCHED`, `DRM_BUDDY`, `DRM_EXEC`, `DRM_GPUVW` | teils integriert, teils Modul | `drm_display_helper.ko` 371.104, `drm_gpuvm.ko` 72.232, `drm_exec.ko` 17.256, `drm_buddy.ko` 7.944 Bytes |

`DRM_VMWGFX` bleibt bewusst **eingebaut**, damit VMware-Grafik ohne Initramfs funktioniert. Die Modulabhängigkeiten sind aufgelöst, Stichprobe:

```
amdgpu: drm_exec,drm_display_helper,amdxcp,gpu-sched,drm_panel_backlight_quirks,
        cec,drm_suballoc_helper,video,drm_buddy,i2c-algo-bit
i915:    drm_display_helper,video,cec,iosf_mbi,intel-gtt,drm_buddy,i2c-algo-bit
```

## 5. Audio

| Komponente | CONFIG | Status | Artefakt |
|---|---|---|---|
| ALSA-Kern | `CONFIG_SND=y`, `SND_PCM=m` | gemischt | `snd-pcm.ko` |
| HD-Audio-Bus | `CONFIG_SND_HDA=m` | **als Modul verfügbar** | `snd-hda-core.ko` |
| Intel HDA-Controller | `CONFIG_SND_HDA_INTEL=m` | **als Modul verfügbar** | 85.880 Bytes |
| Realtek-Codec | `CONFIG_SND_HDA_CODEC_REALTEK=m` | **als Modul verfügbar** | 81.632 Bytes |
| HDMI-Codec | `CONFIG_SND_HDA_CODEC_HDMI=m` | **als Modul verfügbar** | 87.328 Bytes |
| USB-Audio | `CONFIG_SND_USB_AUDIO=m` | **als Modul verfügbar** | 906.360 Bytes |

Damit ist die ALSA-Grundlage für eine spätere PipeWire-Integration vorhanden. PipeWire selbst ist Userspace und nicht Teil dieses Schritts.

## 6. VMware-Unterstützung

| Komponente | CONFIG | Status | Artefakt |
|---|---|---|---|
| PCI-Passthrough-SCSI | `CONFIG_VMWARE_PVSCSI=y` | **fest integriert** | im `bzImage` |
| Balloon | `CONFIG_VMWARE_BALLOON=m` | **als Modul verfügbar** | `vmw_balloon.ko`, 28.608 Bytes |
| VMCI | `CONFIG_VMWARE_VMCI=m` | **als Modul verfügbar** | `vmw_vmci.ko`, 181.040 Bytes |
| Vsock-Transport | `CONFIG_VMWARE_VMCI_VSOCKETS=m`, `CONFIG_VSOCKETS=m` | **als Modul verfügbar** | `vmw_vsock_vmci_transport.ko`, 76.368 Bytes |
| VMXNET3 | `CONFIG_VMXNET3=m` | **als Modul verfügbar** | 142.072 Bytes |
| Grafik | `CONFIG_DRM_VMWGFX=y` | fest integriert | siehe Abschnitt 4 |

Die VMware-Unterstützung ist **rein additiv**: alle zuvor vorhandenen physischen Treiber (AHCI, NVMe, e1000, USB, IOMMU) sind unverändert aktiv.

## 7. Weitere Hardware

| Bereich | CONFIG | Status |
|---|---|---|
| USB 3.x / 2.0 | `USB_XHCI_HCD=y`, `USB_EHCI_HCD=y`, `USB_STORAGE=y`, `USB_HID=y` | **fest integriert** |
| NVMe | `BLK_DEV_NVME=y` | **fest integriert** |
| SATA/AHCI | `SATA_AHCI=y`, `ATA_PIIX=y`, `SCSI=y` | **fest integriert** |
| Ethernet Intel | `E1000=y`, `E1000E=m` | integriert / **Modul** (561.144 Bytes) |
| Ethernet Realtek | `R8169=m` | **Modul** (276.352 Bytes) |
| VirtIO-Netz | `VIRTIO_NET=m` | **Modul** |
| WLAN-Grundlage | `CFG80211=y`, `MAC80211=y`, `IWLWIFI=m`, `IWLMVM=m` | Stack integriert, Intel-Treiber **als Modul** (788.568 Bytes) |
| Bluetooth | `BT=y`, `BT_HCIBTUSB=m` | Stack integriert, USB-Transport **als Modul** (128.816 Bytes) |
| ACPI/EFI | `ACPI=y`, `EFI=y`, `EFI_STUB=y`, `EFI_VARS=y` | **fest integriert** |
| IOMMU | `IOMMU_SUPPORT=y`, `INTEL_IOMMU=y`, `AMD_IOMMU=y` | **fest integriert** |
| Secure Boot | `CONFIG_MODULE_SIG` **nicht gesetzt** | **nicht umgesetzt** |

Bluetooth über serielle Schnittstelle (`BT_HCIUART`) und WLAN-Treiber anderer Hersteller (rtw88/rtw89, ath10k/ath11k) sind **noch nicht umgesetzt** – deren Firmware liegt teilweise bereits im System (11 rtw88-Dateien).

## 8. Firmware-Übersicht

Grundlage sind ausschließlich die von `modinfo -F firmware` gemeldeten Anforderungen der installierten Module; es wurde **keine** Firmware erfunden oder Platzhalter eingebunden.

| Kennzahl | Wert |
|---|---|
| Von allen 98 Modulen geforderte Firmware-Dateien (unique) | **1.283** |
| Dateien in `/lib/firmware` | 4.107 (`linux-firmware` installiert) |
| AMD (`amdgpu.ko`) | 553 Dateien gefordert, im System als `.bin.zst` (675 Dateien im Verzeichnis `amdgpu/`) |
| Intel i915 | 58 gefordert, **58 vorhanden** |
| Intel WLAN (`iwlwifi.ko`) | 49 gefordert, **30 fehlen** |
| NVIDIA (`nouveau.ko`) | 519 gefordert |
| Bluetooth (`btrtl.ko`) | 50 gefordert |
| Intel Xe | 39 gefordert |
| Realtek Ethernet (`r8169.ko`) | 26 gefordert |

Stichprobe AMD (erste 60 Anforderungen, inklusive `.zst`/`.xz`): 5 fehlen. Ursache ist die Versionsdifferenz zwischen Kernel 6.18.62 und dem `linux-firmware`-Paket von Ubuntu 24.04 — einzelne neuere GPU-Firmwaredateien existieren dort noch nicht.

## 9. Neukompilierung

```bash
cd ~/nova-os/build/kernel-build/linux-6.18.62-drv
cp ../../kernel/configs/nova-6.18.62-drivers.config .config
scripts/config --file .config --enable <Abhängigkeiten und Ziele>
make -s olddefconfig        # zweimal
make -j2 bzImage modules
make INSTALL_MOD_PATH=~/nova-os/build/output/sysroot-drivers modules_install
```

| Kennzahl | Wert |
|---|---|
| Parallele Jobs | 2 (`-j2`) |
| Build-Dauer | **1.324 s (22 min 4 s)** |
| Inkrementeller Nachbau (Firmware-Loader) | 27 s, Kernel `#2` |
| Objektdateien | 4.952 |
| Module | 98 (`*.ko`) |
| Build-Log | 273.429 Bytes, 0 Fehlerzeilen, Exit 0 |
| Installationsziel | `build/output/sysroot-drivers` (Modulverzeichnis 50 MB, `boot` 15 MB) |

## 10. Verifikation

| Prüfung | Ergebnis |
|---|---|
| Kernel-Version | **6.18.62-nova**, `#2 SMP PREEMPT_DYNAMIC` |
| `bzImage` | **9.946.112 Bytes**, SHA-256 `7f1f7d8d4077d191a3b3c5bbabbe85b4ee2328005a26af4cb172f2847c10b5ab` |
| Eingebettete Konfiguration | **byte-identisch** mit `.config` (137.233 Bytes, `cmp` ohne Unterschied) |
| Grafikmodule | amdgpu 21,4 MB · i915 8,3 MB · xe 6,2 MB · nouveau 5,8 MB · vmwgfx eingebaut |
| Audiomodule | HDA-Intel 85.880 B · Realtek 81.632 B · HDMI 87.328 B · USB-Audio 906.360 B |
| VMware-Module | Balloon 28.608 B · VMCI 181.040 B · Vsock 76.368 B · VMXNET3 142.072 B · PVSCSI eingebaut |
| Modulanzahl | **98** |
| Modulabhängigkeiten | `modules.dep` mit 98 Einträgen, `depmod` erfolgreich |
| Vermagic aller Stichproben | `6.18.62-nova SMP preempt` |
| Firmware-Anforderungen | 1.283 Dateien, gegen `/lib/firmware` abgeglichen (Abschnitt 8) |
| Fehlerfreie Kompilierung | Exit 0, 0 Fehlerzeilen in beiden Läufen |
| Baseline unverändert | `vmlinuz-nova-6.18.62` weiterhin `868a959e…9b8785`, 20 Module |
| Hostkernel unverändert | `/lib/modules` enthält nur `7.0.0-42-generic` |
| Rechte | alle Artefakte `ramon:ramon`, kein Root in diesem Schritt |

## 11. Statusklassifikation

**Erfolgreich kompiliert und als Modul verfügbar (98 Module):** amdgpu, i915, xe, nouveau, snd-hda-core, snd-hda-intel, snd-hda-codec-realtek, snd-hda-codec-hdmi, snd-usb-audio, vmw_balloon, vmw_vmci, vmw_vsock_vmci_transport, vsock_loopback, vmxnet3, e1000e, r8169, virtio_net, iwlwifi, iwlmvm, btusb, btrtl, btintel, sowie DRM-/Audio-/Thermal-Helfer.

**Fest in den Kernel integriert:** vmwgfx, vmware_pvscsi, ahci, ata_piix, nvme, sd, xhci/ehci, usb-storage/hid, e1000, Btrfs, ext4, SquashFS, OverlayFS, ISO9660, VFAT, AppArmor, EFI-Stub, IOMMU (Intel/AMD), nf_tables, CFG80211/MAC80211-Stack, Bluetooth-Stack.

**Nur konfiguriert, aber nicht als eigenes Artefakt vorhanden:** `DRM_AMD_DC=y` (eingebauter Bestandteil von amdgpu), `DRM_XE_DISPLAY=y` (Teil von xe.ko).

**Noch nicht umgesetzt:** `CONFIG_MODULE_SIG` (Secure-Boot-Modulsignierung ohne Schlüssel bewusst nicht aktiviert), `BT_HCIUART` (serielles Bluetooth), WLAN-Treiber anderer Hersteller, vollständige Firmware für AMD/Xe/NVIDIA (Paketstand Ubuntu 24.04), `CONFIG_USB_VIDEO_CLASS` und weitere optionale Klassen.

## 12. Offene Probleme

1. **Firmware-Lücke bei neuer Hardware.** 30 von 49 iwlwifi-Dateien und einzelne AMD-/Xe-/NVIDIA-Dateien fehlen im Paketstand von Ubuntu 24.04. Für ein Release muss `linux-firmware` aus einer neueren Quelle stammen oder gepinnt werden.
2. **Modulumfang 50 MB** – für ein Live-Medium relevant (Initramfs-Größe in Phase 11.6).
3. **`CONFIG_DRM_XE` baut, ist aber auf dieser Hardware nicht testbar** (keine Intel-Xe-GPU in der VM); „kompiliert" ist nicht „funktioniert".
4. **Keine Bootprüfung** – auftragsgemäß kein RootFS, kein Initramfs, keine ISO, kein VM-Start.
5. **Zwei Kernel-Bäume belegen Platz**: `linux-6.18.62` (1,7 GB) und `linux-6.18.62-drv` (1,7 GB) plus zwei Staging-Bäume; 74 GB frei.
6. **Zwei Staging-Bäume** (`sysroot` mit Baseline-Kernel, `sysroot-drivers` mit erweitertem Kernel) müssen in Phase 11.6 bewusst zusammengeführt werden — ich habe sie absichtlich getrennt gelassen, um die Baseline nicht zu überschreiben.
7. **`kernel_state.json`** führt weiterhin `7.3.3` (Artefakt des alten Platzhalter-Builders).

## 13. Empfehlung für Phase 11.6

1. `sysroot-drivers` als neuen Standard setzen (Kernel + 98 Module), `sysroot` als Rollback-Baseline behalten.
2. Initramfs mit dracut gegen `6.18.62-nova` bauen; Module für SquashFS/OverlayFS/Btrfs sind eingebaut, GPU-Treiber können im Initramfs entfallen.
3. Firmware-Paketstand prüfen und die für die Zielhardware nötigen Dateien explizit nach `/lib/firmware` übernehmen (keine Platzhalter).
4. `CONFIG_MODULE_SIG` erst einführen, wenn eine Schlüsselinfrastruktur existiert — sonst booten die 98 Module nicht.

## 14. Statusmatrix

| Aufgabe | Status |
|---|---|
| Bestandsaufnahme und Sicherung | ✅ ausgeführt (Backup 19,1 MB, Baseline-Hash geprüft) |
| Grafiktreiber AMD/Intel/NVIDIA/VMware | ✅ kompiliert (amdgpu, i915, xe, nouveau als Module; vmwgfx integriert) |
| Audio | ✅ kompiliert (HDA-Intel, beide Codecs, USB-Audio) |
| VMware (Balloon, VMCI, Vsock, PVSCSI, VMXNET3) | ✅ kompiliert |
| USB/NVMe/SATA/Ethernet/WLAN/BT/ACPI/IOMMU/EFI | ✅ kompiliert |
| Firmware-Übersicht | ✅ erstellt (1.283 Anforderungen abgeglichen) |
| Neukompilierung `-j2` | ✅ ausgeführt (1.324 s, 98 Module, 0 Fehler) |
| Unabhängige Verifikation | ✅ ausgeführt (IKCONFIG identisch, Vermagic, Abhängigkeiten) |
| Secure-Boot-Vorbereitung | ⛔ nicht umgesetzt (kein Schlüssel vorhanden) |
| RootFS / Initramfs / ISO / Boottest | ⛔ auftragsgemäß nicht durchgeführt |

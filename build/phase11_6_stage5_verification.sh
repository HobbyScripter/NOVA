#!/bin/bash
# Phase 11.6 - Stufe 5: Verifikation von RootFS und Initramfs
set -u

R=/home/ramon/nova-os
OUT=$R/build/output

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@"
  exit $?
fi

exec > "$OUT/phase11_6-verification.out" 2>&1
set -u

RF=$OUT/rootfs-6.18.62-nova
DRV=$OUT/sysroot-drivers
KREL=6.18.62-nova
IMG=$OUT/initramfs-$KREL.img
FAIL=0
ok()   { echo "  [OK]   $*"; }
bad()  { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

echo "=== Phase 11.6 Verifikation $(date -Is) ==="
echo
echo "--- 1. RootFS-Verzeichnisstruktur ---"
for d in bin boot dev etc home lib lib64 mnt opt proc root run sbin srv sys tmp usr var; do
  if [ -e "$RF/$d" ]; then ok "/$d vorhanden ($( [ -L "$RF/$d" ] && echo Symlink || echo Verzeichnis ))"; else bad "/$d fehlt"; fi
done

echo
echo "--- 2. Architektur der ELF-Binaries ---"
for b in usr/bin/bash usr/bin/ls usr/lib/systemd/systemd usr/sbin/init; do
  [ -e "$RF/$b" ] || { bad "$b fehlt"; continue; }
  hdr=$(readelf -h "$RF/$b" 2>/dev/null)
  cls=$(echo "$hdr" | awk '/Class:/{print $2}')
  mach=$(echo "$hdr" | awk -F: '/Machine:/{print $2}' | sed 's/^ *//')
  lnk=$(echo "$hdr" | awk -F: '/interpreter/{print $2}' | sed 's/^ *//')
  [ "$cls" = "ELF64" ] && ok "$b: ELF64, $mach${lnk:+, Interpreter $lnk}" || bad "$b: Klasse '$cls'"
done

echo
echo "--- 3. Dynamischer Loader und Bibliotheken ---"
LOADER=$(readelf -l "$RF/usr/bin/bash" 2>/dev/null | awk -F: '/interpreter/{gsub(/^ +/,"",$2); print $2}')
if [ -n "$LOADER" ]; then
  [ -e "$RF$LOADER" ] && ok "Loader $LOADER vorhanden ($(stat -c%s "$RF$LOADER") Bytes)" || bad "Loader $LOADER fehlt"
else
  bad "kein Interpreter in /usr/bin/bash"
fi
missing_libs=0
for lib in $(readelf -d "$RF/usr/bin/bash" 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/'); do
  if ! find "$RF/lib" "$RF/usr/lib" -name "$lib" -print -quit 2>/dev/null | grep -q .; then
    bad "benoetigte Bibliothek fehlt: $lib"; missing_libs=$((missing_libs+1))
  fi
done
[ "$missing_libs" -eq 0 ] && ok "alle NEEDED-Bibliotheken von /usr/bin/bash vorhanden"

echo
echo "--- 4. systemd im RootFS ---"
chroot "$RF" /usr/bin/systemd --version 2>/dev/null | head -1 | sed 's/^/  /'
sv=$(chroot "$RF" /usr/bin/systemd --version 2>/dev/null | head -1 | awk '{print $2}')
[ -n "$sv" ] && ok "systemd reagiert: $sv" || bad "systemd nicht ausfuehrbar"
[ -e "$RF/usr/lib/systemd/systemd-udevd" ] && ok "systemd-udevd vorhanden" || bad "systemd-udevd fehlt"
[ -e "$RF/usr/bin/udevadm" ] || [ -e "$RF/usr/bin/systemd-udevadm" ] && ok "udevadm vorhanden" || bad "udevadm fehlt"

echo
echo "--- 5. Installierte Pakete ---"
chroot "$RF" dpkg-query -W -f='${Package}\t${Version}\n' > "$OUT/phase11_6-packages.txt" 2>/dev/null
pkgn=$(wc -l < "$OUT/phase11_6-packages.txt")
echo "  Pakete: $pkgn"
for p in systemd systemd-sysv udev network-manager nftables apparmor btrfs-progs e2fsprogs dracut kmod linux-firmware squashfs-tools; do
  v=$(awk -F'\t' -v p="$p" '$1==p{print $2}' "$OUT/phase11_6-packages.txt")
  [ -n "$v" ] && ok "Paket $p $v" || bad "Paket $p fehlt im dpkg-Bestand"
done

echo
echo "--- 6. Kernel und Module im RootFS ---"
[ -f "$RF/boot/vmlinuz-$KREL" ] && ok "vmlinuz-$KREL ($(stat -c%s "$RF/boot/vmlinuz-$KREL") Bytes, sha256 $(sha256sum "$RF/boot/vmlinuz-$KREL" | cut -c1-16)…)" || bad "Kernel fehlt"
mods=$(find "$RF/lib/modules/$KREL" -name '*.ko' | wc -l)
[ "$mods" -eq 98 ] && ok "98 Module im RootFS" || bad "Modulzahl $mods statt 98"
vm_bad=$(for m in $(find "$RF/lib/modules/$KREL" -name '*.ko'); do modinfo -F vermagic "$m"; done | sort -u | grep -vc "^$KREL ")
[ "$vm_bad" -eq 0 ] && ok "Vermagic aller Module = $KREL" || bad "$vm_bad abweichende Vermagic-Werte"
[ -s "$RF/lib/modules/$KREL/modules.dep" ] && ok "modules.dep: $(wc -l < "$RF/lib/modules/$KREL/modules.dep") Eintraege" || bad "modules.dep fehlt"

echo
echo "--- 7. Dateisystem- und Mount-Unterstuetzung (Kernel-Konfiguration) ---"
CFG=$RF/boot/config-$KREL
for o in EXT4_FS BTRFS_FS SQUASHFS OVERLAY_FS VFAT_FS ISO9660_FS BLK_DEV_NVME SATA_AHCI VMWARE_PVSCSI SCSI BLK_DEV_SD USB_STORAGE VIRTIO_BLK; do
  line=$(grep -E "^CONFIG_$o=" "$CFG" 2>/dev/null)
  if [ -n "$line" ]; then ok "$line"; else bad "CONFIG_$o nicht gesetzt"; fi
done

echo
echo "--- 8. Initramfs-Format ---"
[ -f "$IMG" ] || { bad "Initramfs fehlt"; }
if [ -f "$IMG" ]; then
  echo "  Groesse: $(stat -c%s "$IMG") Bytes"
  echo "  SHA-256: $(sha256sum "$IMG" | cut -d' ' -f1)"
  echo "  Typ: $(file -b "$IMG")"
  file -b "$IMG" | grep -qiE 'zstd|cpio' && ok "Initramfs ist ein komprimiertes cpio-Archiv" || bad "Initramfs-Format unbekannt"
  n=$(lsinitrd "$IMG" 2>/dev/null | wc -l)
  echo "  Dateien im Initramfs: $n"
  [ "$n" -gt 100 ] && ok "Initramfs enthaelt $n Eintraege" || bad "Initramfs wirkt leer ($n Eintraege)"
fi

echo
echo "--- 9. Kernelmodule im Initramfs ---"
if [ -f "$IMG" ]; then
  lsinitrd "$IMG" 2>/dev/null | grep -E '\.ko(\.zst)?$' | sed 's#.*/##' | sort > "$OUT/phase11_6-initramfs-modules.txt"
  echo "  Module im Initramfs: $(wc -l < "$OUT/phase11_6-initramfs-modules.txt")"
  for m in nvme ahci libahci sd_mod usb-storage uas xhci_pci ehci_pci vmw_pvscsi btrfs ext4 squashfs overlay crc32c usbhid; do
    if grep -qE "^${m}\.ko" "$OUT/phase11_6-initramfs-modules.txt"; then ok "Modul $m enthalten"; else bad "Modul $m fehlt im Initramfs"; fi
  done
  echo "  Liste: $(tr '\n' ' ' < "$OUT/phase11_6-initramfs-modules.txt")"
fi

echo
echo "--- 10. Kernelversion im Initramfs ---"
if [ -f "$IMG" ]; then
  lsinitrd "$IMG" 2>/dev/null | grep -E "lib/modules/" | sed 's#.*lib/modules/##; s#/.*##' | sort -u | sed 's/^/  kernelver: /'
  kvi=$(lsinitrd "$IMG" 2>/dev/null | grep -cE "lib/modules/$KREL")
  [ "$kvi" -gt 0 ] && ok "Initramfs gebaut fuer $KREL" || bad "Initramfs nennt nicht $KREL"
fi

echo
echo "--- 11. Firmware im Initramfs ---"
if [ -f "$IMG" ]; then
  lsinitrd "$IMG" 2>/dev/null | grep -E 'lib/firmware/' | sed 's#.*lib/firmware/##' | sort -u > "$OUT/phase11_6-initramfs-firmware.txt"
  echo "  Firmware-Dateien: $(wc -l < "$OUT/phase11_6-initramfs-firmware.txt")"
  head -10 "$OUT/phase11_6-initramfs-firmware.txt" | sed 's/^/  /'
fi

echo
echo "--- 12. Platzhalter-Pruefung ---"
empty=$(find "$RF/usr/bin" "$RF/usr/sbin" "$RF/bin" "$RF/sbin" -type f -empty 2>/dev/null | wc -l)
[ "$empty" -eq 0 ] && ok "keine leeren Binaries" || bad "$empty leere Dateien in Bin-Verzeichnissen"
dummy=$(grep -rl "PLACEHOLDER\|placeholder" "$RF/etc" 2>/dev/null | wc -l)
[ "$dummy" -eq 0 ] && ok "keine Platzhalter-Texte in /etc" || bad "$dummy Dateien mit Platzhalter-Text"
echo "  RootFS-Groesse: $(du -sh --exclude=proc --exclude=sys "$RF" 2>/dev/null | cut -f1)"
echo "  RootFS-Dateien: $(find "$RF" -type f 2>/dev/null | wc -l)"

echo
echo "--- 13. Baseline unveraendert ---"
echo "  sysroot-Kernel sha256: $(sha256sum "$OUT/sysroot/boot/vmlinuz-nova-6.18.62" | cut -d' ' -f1)"
echo "  sysroot-Module: $(find "$OUT/sysroot/lib/modules" -name '*.ko' | wc -l)"
echo "  vmware-test.iso: $(ls -l "$OUT"/validation-*.iso 2>/dev/null | awk '{print $5" Bytes"}' | head -1)"

echo
if [ "$FAIL" -eq 0 ]; then echo "VERIFIKATION_OK"; else echo "VERIFIKATION_FEHLER=$FAIL"; fi

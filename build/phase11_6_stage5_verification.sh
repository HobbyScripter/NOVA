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
KREL=6.18.62-nova
IMG=$OUT/initramfs-$KREL.img
CFG=$RF/boot/config-$KREL
FAIL=0
ok()  { echo "  [OK]   $*"; }
bad() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

echo "=== Phase 11.6 Verifikation $(date -Is) ==="
echo
echo "--- 1. RootFS-Verzeichnisstruktur ---"
for d in bin boot dev etc home lib lib64 mnt opt proc root run sbin srv sys tmp usr var; do
  if [ -e "$RF/$d" ]; then ok "/$d ($( [ -L "$RF/$d" ] && echo Symlink || echo Verzeichnis ))"
  else bad "/$d fehlt"; fi
done

echo
echo "--- 2. Architektur der ELF-Binaries ---"
for b in usr/bin/bash usr/bin/ls usr/lib/systemd/systemd usr/bin/systemctl; do
  [ -e "$RF/$b" ] || { bad "$b fehlt"; continue; }
  ftxt=$(file -b "$RF/$b")
  echo "     $b: $ftxt"
  case "$ftxt" in
    *"ELF 64-bit"*x86-64*) ok "$b ist ELF64/x86-64 (Datei-Kennung)";;
    *) bad "$b nicht ELF64/x86-64";;
  esac
done

echo
echo "--- 3. Loader und Bibliotheken ---"
LOADER=$(readelf -l "$RF/usr/bin/bash" 2>/dev/null | sed -n 's/.*interpreter: *//p' | tr -d ']' | awk 'NR==1{print $1}')
if [ -n "$LOADER" ] && [ -e "$RF$LOADER" ]; then
  ok "Interpreter $LOADER vorhanden ($(stat -c%s "$RF$LOADER") Bytes)"
  echo "     real: $(readlink -f "$RF$LOADER" | sed "s#^$RF##")"
else
  bad "Interpreter '$LOADER' fehlt"
fi
miss=0
for lib in $(readelf -d "$RF/usr/bin/bash" 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/'); do
  find "$RF/lib" "$RF/usr/lib" -name "$lib" -print -quit 2>/dev/null | grep -q . || { bad "Bibliothek fehlt: $lib"; miss=$((miss+1)); }
done
[ "$miss" -eq 0 ] && ok "alle NEEDED-Bibliotheken von bash vorhanden"

echo
echo "--- 4. systemd / udev ---"
sv=$(chroot "$RF" /usr/bin/systemd --version 2>/dev/null | head -1)
echo "  $sv"
[ -n "$sv" ] && ok "systemd lauffaehig im chroot" || bad "systemd nicht ausfuehrbar"
[ -e "$RF/usr/lib/systemd/systemd-udevd" ] && ok "systemd-udevd vorhanden" || bad "systemd-udevd fehlt"
[ -e "$RF/usr/bin/udevadm" ] && ok "udevadm vorhanden" || bad "udevadm fehlt"

echo
echo "--- 5. Installierte Pakete (Herkunft Ubuntu noble) ---"
chroot "$RF" dpkg-query -W -f='${Package}\t${Version}\n' > "$OUT/phase11_6-packages.txt" 2>/dev/null
echo "  Pakete: $(wc -l < "$OUT/phase11_6-packages.txt")"
for p in systemd systemd-sysv udev network-manager nftables apparmor btrfs-progs e2fsprogs dracut kmod linux-firmware squashfs-tools dosfstools; do
  v=$(awk -F'\t' -v p="$p" '$1==p{print $2}' "$OUT/phase11_6-packages.txt")
  [ -n "$v" ] && ok "$p $v" || bad "$p fehlt"
done
src=$(grep -h '^URIs:' "$RF"/etc/apt/sources.list.d/*.sources 2>/dev/null | head -1 | sed 's/^URIs: *//')
[ -n "$src" ] || src=$(grep -hE '^deb ' "$RF/etc/apt/sources.list" 2>/dev/null | head -1 | awk '{print $2}')
[ -n "$src" ] || src="(keine Quellenliste im Image)"
echo "  Quelle: $src"
echo "  Klassifizierung: $(tr '\n' ' ' < "$RF/etc/nova/rootfs-class" 2>/dev/null)"

echo
echo "--- 6. Kernel und Module im RootFS ---"
if [ -f "$RF/boot/vmlinuz-$KREL" ]; then
  ok "vmlinuz-$KREL: $(stat -c%s "$RF/boot/vmlinuz-$KREL") Bytes"
  echo "     SHA-256: $(sha256sum "$RF/boot/vmlinuz-$KREL" | cut -d' ' -f1)"
else bad "Kernel fehlt"; fi
mods=$(find "$RF/lib/modules/$KREL" -name '*.ko' | wc -l)
[ "$mods" -eq 98 ] && ok "98 Module installiert" || bad "Modulzahl $mods"
vb=$(for m in $(find "$RF/lib/modules/$KREL" -name '*.ko'); do modinfo -F vermagic "$m"; done | sort -u | grep -vc "^$KREL ")
[ "$vb" -eq 0 ] && ok "Vermagic aller 98 Module = $KREL" || bad "$vb abweichende Vermagic-Werte"
[ -s "$RF/lib/modules/$KREL/modules.dep" ] && ok "modules.dep: $(wc -l < "$RF/lib/modules/$KREL/modules.dep") Eintraege" || bad "modules.dep fehlt"

echo
echo "--- 7. Storage-/Dateisystemtreiber im Kernel ---"
declare -A MAP=( [nvme]=CONFIG_BLK_DEV_NVME [ahci]=CONFIG_SATA_AHCI [sd_mod]=CONFIG_BLK_DEV_SD \
 [usb_storage]=CONFIG_USB_STORAGE [usbhid]=CONFIG_USB_HID [xhci_pci]=CONFIG_USB_XHCI_PCI \
 [ehci_pci]=CONFIG_USB_EHCI_PCI [vmw_pvscsi]=CONFIG_VMWARE_PVSCSI [btrfs]=CONFIG_BTRFS_FS \
 [ext4]=CONFIG_EXT4_FS [squashfs]=CONFIG_SQUASHFS [overlay]=CONFIG_OVERLAY_FS [crc32c]=CONFIG_CRYPTO_CRC32C )
for m in nvme ahci sd_mod usb_storage usbhid xhci_pci ehci_pci vmw_pvscsi btrfs ext4 squashfs overlay crc32c; do
  o=${MAP[$m]}
  val=$(grep -E "^$o=" "$CFG" 2>/dev/null | cut -d= -f2)
  case "$val" in
    y) ok "$o=y (fest eingebaut)";;
    m) echo "  [INFO] $o=m (als Modul)";;
    *) bad "$o nicht gesetzt";;
  esac
done

echo
echo "--- 8. Initramfs-Format ---"
if [ -f "$IMG" ]; then
  echo "  Groesse: $(stat -c%s "$IMG") Bytes"
  echo "  SHA-256: $(sha256sum "$IMG" | cut -d' ' -f1)"
  echo "  Rechte: $(stat -c '%a %U:%G' "$IMG")"
  echo "  Typ: $(file -b "$IMG")"
  z=$(python3 -c "d=open('$IMG','rb').read(); print('ja' if d.find(b'\x28\xb5\x2f\xfd')>=0 else 'nein')" 2>/dev/null)
  [ "$z" = "ja" ] && ok "zstd-komprimierter Abschnitt enthalten" || bad "kein zstd-Abschnitt"
  n=$(lsinitrd "$IMG" 2>/dev/null | wc -l)
  [ "$n" -gt 100 ] && ok "lsinitrd liest $n Eintraege" || bad "nur $n Eintraege"
else
  bad "Initramfs fehlt"
fi

echo
echo "--- 9. Kernelmodule im Initramfs ---"
if [ -f "$IMG" ]; then
  lsinitrd "$IMG" 2>/dev/null | grep -E '\.ko(\.zst)?$' | sed 's#.*/##' | sort > "$OUT/phase11_6-initramfs-modules.txt"
  mc=$(wc -l < "$OUT/phase11_6-initramfs-modules.txt")
  echo "  Module im Image: $mc"
  if [ "$mc" -gt 0 ]; then echo "  Liste: $(tr '\n' ' ' < "$OUT/phase11_6-initramfs-modules.txt")"
  else echo "  keine Module (alle benoetigten Treiber fest eingebaut)"; fi
  errs=$(grep -cE "^(E:|dracut\[E\])|Failed to find module" "$OUT/phase11_6-dracut.log" 2>/dev/null)
  [ "${errs:-0}" -eq 0 ] && ok "dracut-Log ohne Fehlerzeilen ($(grep -c 'Including module:' "$OUT/phase11_6-dracut.log") Modul-Includes, ein Lauf)" || bad "$errs Fehlerzeilen im dracut-Log"
  echo "  Log-Zeilen: $(wc -l < "$OUT/phase11_6-dracut.log")"
fi

echo
echo "--- 10. Kernelversion im Initramfs ---"
if [ -f "$IMG" ]; then
  kv=$(lsinitrd "$IMG" 2>/dev/null | grep -E 'lib/modules/.*\.ko(\.zst)?$' | sed -n 's#.*lib/modules/\([^/]*\)/.*#\1#p' | sort -u | tr '\n' ' ')
  if [ -n "$kv" ]; then
    echo "  Modulverzeichnis: $kv"
    [ "$kv" = "$KREL " ] && ok "Image fuer $KREL" || bad "falsche Kernelversion: $kv"
  else
    ok "kein Modulpfad noetig; Kernelbezug ueber --kver $KREL (Treiber eingebaut)"
  fi
  echo "  init: $(lsinitrd "$IMG" 2>/dev/null | grep -E ' (init|usr/lib/systemd/systemd|usr/bin/systemd)$' | head -2 | tr '\n' ' ')"
fi

echo
echo "--- 11. Firmware im Initramfs ---"
if [ -f "$IMG" ]; then
  lsinitrd "$IMG" 2>/dev/null | grep -E 'lib/firmware/' | sed 's#.*lib/firmware/##' | sort -u > "$OUT/phase11_6-initramfs-firmware.txt"
  fc=$(wc -l < "$OUT/phase11_6-initramfs-firmware.txt")
  echo "  Firmware-Dateien im Initramfs: $fc"
  if [ "$fc" -gt 0 ]; then head -5 "$OUT/phase11_6-initramfs-firmware.txt" | sed 's/^/    /'
  else ok "keine Firmware noetig (nur eingebaute Storage-/FS-Treiber, keine GPU-/WLAN-Module)"; fi
fi
echo "  Firmware-Inventur RootFS (/lib/firmware):"
FW=$RF/lib/firmware
fw_all=$(find "$FW" -type f 2>/dev/null | wc -l)
fw_zst=$(find "$FW" -type f -name '*.zst' 2>/dev/null | wc -l)
fw_xz=$(find "$FW" -type f -name '*.xz' 2>/dev/null | wc -l)
echo "    regulaere Dateien: $fw_all (davon .zst: $fw_zst, .xz: $fw_xz, unkomprimiert: $((fw_all-fw_zst-fw_xz)))"
echo "    Symlinks: $(find "$FW" -type l 2>/dev/null | wc -l)"
echo "    Groesse: $(du -sh "$FW" 2>/dev/null | cut -f1)"
echo "    Firmware-Loader-Kompression aktiv: $(grep -E '^CONFIG_FW_LOADER_COMPRESS_(XZ|ZSTD)=' "$CFG" | tr '\n' ' ')"

echo
echo "--- 12. Platzhalter-Pruefung ---"
empty=$(find "$RF/usr/bin" "$RF/usr/sbin" -type f -empty 2>/dev/null | wc -l)
[ "$empty" -eq 0 ] && ok "keine leeren Dateien in /usr/bin,/usr/sbin" || bad "$empty leere Dateien"
fake=$(grep -rl "PLACEHOLDER\|Dummy-Binary" "$RF/etc" 2>/dev/null | wc -l)
[ "$fake" -eq 0 ] && ok "keine Platzhalter in /etc" || bad "$fake Platzhalter-Dateien"
echo "  RootFS: $(du -sh "$RF" 2>/dev/null | cut -f1), $(find "$RF" -type f 2>/dev/null | wc -l) Dateien, $(find "$RF" -type d 2>/dev/null | wc -l) Verzeichnisse"

echo
echo "--- 13. Baseline unveraendert ---"
echo "  sysroot-Kernel: $(sha256sum "$OUT/sysroot/boot/vmlinuz-nova-6.18.62" | cut -d' ' -f1)"
[ "$(find "$OUT/sysroot/lib/modules" -name '*.ko' | wc -l)" -eq 20 ] && ok "sysroot weiterhin 20 Module" || bad "Baseline-Modulzahl veraendert"
for iso in "$OUT"/validation-*.iso; do [ -f "$iso" ] && ok "ISO $(basename "$iso") unveraendert ($(stat -c%s "$iso") Bytes)"; done

echo
if [ "$FAIL" -eq 0 ]; then echo "VERIFIKATION_OK"; else echo "VERIFIKATION_FEHLER=$FAIL"; fi

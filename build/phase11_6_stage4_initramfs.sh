#!/bin/bash
# Phase 11.6 - Stufe 4: Initramfs mit dracut fuer 6.18.62-nova erzeugen
#
# Erkenntnisse aus dem ersten Versuch:
#  - Ubuntu-dracut (060) kennt kein Modul "udev"; der udev-Pfad heisst "systemd-udevd".
#  - "uas" existiert in diesem Kernel nicht als Modul; ein unaufloesbarer Name laesst
#    dracut-install die gesamte Modulinstallation abbrechen (Ergebnis: 0 Module).
#    Deshalb wird die Modulliste jetzt gegen den echten Modulbaum geprueft.
set -u

R=/home/ramon/nova-os
OUT=$R/build/output

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@"
  exit $?
fi

exec > "$OUT/phase11_6-stage4.out" 2>&1
set -u

DRV=$OUT/sysroot-drivers
KREL=6.18.62-nova
KMOD=$DRV/lib/modules/$KREL
IMG=$OUT/initramfs-$KREL.img
DLOG=$OUT/phase11_6-dracut.log

echo "=== Phase 11.6 Stufe 4: Initramfs $(date -Is) ==="
[ -d "$KMOD" ] || { echo "ABBRUCH: Module fehlen"; echo "STAGE4_FEHLER"; exit 4; }

if [ -e "$IMG" ]; then
  mv "$IMG" "$IMG.vorheriger-build"
  echo "vorheriges Artefakt gesichert als $(basename "$IMG").vorheriger-build"
fi

# --- Nur Treiber aufnehmen, die tatsaechlich als Modul existieren ---
REQ=""
for m in nvme ahci libahci sd_mod usb_storage usbhid xhci_pci ehci_pci vmw_pvscsi \
         btrfs ext4 squashfs overlay crc32c virtio_blk virtio_pci sr_mod cdrom; do
  if find "$KMOD/kernel" -name "$m.ko" -print -quit 2>/dev/null | grep -q .; then
    REQ="$REQ $m"
  fi
done
echo "als Modul vorhanden:$REQ"
echo "dracut_version=$(dracut --version 2>/dev/null | head -1)"

ADD_DRV_ARGS=()
[ -n "$REQ" ] && ADD_DRV_ARGS=(--add-drivers "$REQ")

t0=$(date +%s)
dracut --force --no-hostonly --kver "$KREL" --kmoddir "$KMOD" \
  --compress zstd \
  --add "base systemd systemd-udevd systemd-initrd kernel-modules rootfs-block fs-lib" \
  "${ADD_DRV_ARGS[@]}" \
  --filesystems "ext4 btrfs squashfs overlay" \
  --omit-drivers "amdgpu i915 xe nouveau iwlwifi btusb snd_hda_intel snd_usb_audio r8169 e1000e vmxnet3 vmw_balloon vmw_vmci vmw_vsock_vmci_transport" \
  --omit "plymouth nfs lvm dm dmraid mdraid multipath crypt iscsi fcoe resume cifs" \
  --no-hostonly-cmdline \
  --logfile "$DLOG" \
  "$IMG"
rc=$?
t1=$(date +%s)

echo "dracut_rc=$rc"
echo "dauer_sek=$((t1-t0))"
echo "dracut_fehler_im_log=$(grep -cE '^dracut\[E\]|Failed to find module' "$DLOG" 2>/dev/null || echo 0)"
grep -E '^dracut\[E\]|Failed to find module' "$DLOG" 2>/dev/null | head -5

if [ "$rc" -ne 0 ] || [ ! -f "$IMG" ]; then
  echo "STAGE4_FEHLER"
  exit "$rc"
fi

# Artefakt fuer spaetere Phasen durch den Build-Benutzer lesbar machen
chmod 0644 "$IMG"
chown ramon:ramon "$IMG"

echo "initramfs_bytes=$(stat -c%s "$IMG")"
echo "initramfs_sha256=$(sha256sum "$IMG" | cut -d' ' -f1)"
echo "dateityp=$(file -b "$IMG")"
echo "module_im_image=$(lsinitrd "$IMG" 2>/dev/null | grep -cE '\.ko(\.zst)?$')"
echo "STAGE4_OK"

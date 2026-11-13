#!/bin/bash
# Phase 11.7.1 - Boot-Test-Datentraeger aus dem 11.7.1-RootFS (neuer Kernel)
# Aufruf: phase11_7_1_diskbuild.sh A|B
set -u

TAG="${1:-A}"
R=/home/ramon/nova-os
OUT=$R/build/output

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$TAG"
  exit $?
fi

exec > "$OUT/phase11_7_1-diskbuild-$TAG.out" 2>&1
set -u

D=$OUT/boottest-11.7.1-$TAG
RF=$OUT/rootfs-6.18.62-nova-11.7.1
KREL=6.18.62-nova
IMG=$D/nova-boottest-$TAG-disk.raw
SIZE=1073741824

mkdir -p "$D"
if [ -e "$IMG" ]; then echo "ABBRUCH: $IMG existiert bereits"; echo "DISKBUILD_${TAG}_FEHLER"; exit 4; fi
for f in "$RF/boot/vmlinuz-$KREL" "$OUT/initramfs-$KREL.img" "$OUT/phase11_7_bootcheck_v3.sh"; do
  [ -e "$f" ] || { echo "ABBRUCH: $f fehlt"; echo "DISKBUILD_${TAG}_FEHLER"; exit 4; }
done

echo "=== Phase 11.7.1 Datentraeger $TAG $(date -Is) ==="
echo "kernel_quelle_sha256=$(sha256sum "$RF/boot/vmlinuz-$KREL" | cut -d' ' -f1)"
echo "initramfs_quelle_sha256=$(sha256sum "$OUT/initramfs-$KREL.img" | cut -d' ' -f1)"

truncate -s "$SIZE" "$IMG"
sfdisk --quiet "$IMG" <<'PART'
label: dos
start=2048, type=83, bootable
PART
LOOP=$(losetup --find --show --partscan "$IMG")
sleep 1
PARTDEV=${LOOP}p1
echo "loop=$LOOP part=$PARTDEV"

t0=$(date +%s)
mke2fs -q -t ext4 -L "NOVA-1171-$TAG" -F -d "$RF" "$PARTDEV"
echo "mkfs_rc=$? dauer=$(( $(date +%s)-t0 ))s typ=$(blkid -s TYPE -o value "$PARTDEV")"
UUID=$(blkid -s UUID -o value "$PARTDEV")
echo "uuid=$UUID"

MNT=$D/mnt; mkdir -p "$MNT"
mount "$PARTDEV" "$MNT"
echo "mount_rc=$? belegung=$(df -h "$MNT" | tail -1 | awk '{print $3"/"$2" ("$5")"}')"

cp -a "$OUT/initramfs-$KREL.img" "$MNT/boot/initramfs-$KREL.img"
echo "kernel_im_image_sha256=$(sha256sum "$MNT/boot/vmlinuz-$KREL" | cut -d' ' -f1)"

cat > "$MNT/etc/fstab" <<EOF
# /etc/fstab - NOVA OS Boot-Test $TAG (Phase 11.7.1)
UUID=$UUID  /        ext4   defaults,noatime          0 1
tmpfs       /tmp     tmpfs  nosuid,nodev,mode=1777    0 0
tmpfs       /var/tmp tmpfs  nosuid,nodev,mode=1777    0 0
EOF

install -m 0755 "$OUT/phase11_7_bootcheck_v3.sh" "$MNT/usr/local/sbin/nova-bootcheck.sh"
cat > "$MNT/etc/systemd/system/nova-bootcheck.service" <<'UNIT'
[Unit]
Description=NOVA OS Boot-Test Harness (Phase 11.7.1)
After=network.target systemd-user-sessions.service
Wants=network.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=/usr/local/sbin/nova-bootcheck.sh
TimeoutStartSec=900
StandardOutput=journal

[Install]
WantedBy=multi-user.target
UNIT
mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/nova-bootcheck.service "$MNT/etc/systemd/system/multi-user.target.wants/nova-bootcheck.service"

mkdir -p "$MNT/boot/grub"
cat > "$MNT/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=5

menuentry 'NOVA OS 6.18.62-nova (CONFIG_PACKET=y) - Phase 11.7.1 Lauf $TAG' {
  linux /boot/vmlinuz-$KREL root=UUID=$UUID ro console=tty0 console=ttyS0,115200 loglevel=7 systemd.log_level=info systemd.show_status=true
  initrd /boot/initramfs-$KREL.img
}
EOF
sed 's/^/  /' "$MNT/boot/grub/grub.cfg"

grub-install --target=i386-pc --boot-directory="$MNT/boot" \
  --modules="part_msdos ext2 normal linux echo search search_fs_uuid configfile" \
  --no-floppy --recheck "$LOOP"
echo "grub_install_rc=$?"

sync
umount "$MNT"
echo "umount_rc=$?"
losetup -d "$LOOP"
echo "sha256_raw=$(sha256sum "$IMG" | cut -d' ' -f1)"
echo "bytes_raw=$(stat -c%s "$IMG")"
echo "DISKBUILD_${TAG}_OK"

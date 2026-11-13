#!/bin/bash
# Phase 11.7.1 - Datentraeger Lauf C
# Unterschied zu A/B: der Harness laeuft NICHT als Teil von multi-user.target,
# sondern ueber einen Timer 45 s nach Boot. Damit kann der Bootsstatus
# (systemctl is-system-running) unbeeinflusst gemessen werden.
set -u

TAG=C
R=/home/ramon/nova-os
OUT=$R/build/output

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0"
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

echo "=== Phase 11.7.1 Datentraeger $TAG $(date -Is) ==="
echo "kernel_sha256=$(sha256sum "$RF/boot/vmlinuz-$KREL" | cut -d' ' -f1)"
echo "initramfs_sha256=$(sha256sum "$OUT/initramfs-$KREL.img" | cut -d' ' -f1)"

truncate -s "$SIZE" "$IMG"
sfdisk --quiet "$IMG" <<'PART'
label: dos
start=2048, type=83, bootable
PART
LOOP=$(losetup --find --show --partscan "$IMG")
sleep 1
PARTDEV=${LOOP}p1
mke2fs -q -t ext4 -L "NOVA-1171-$TAG" -F -d "$RF" "$PARTDEV"
echo "mkfs_rc=$? typ=$(blkid -s TYPE -o value "$PARTDEV")"
UUID=$(blkid -s UUID -o value "$PARTDEV")
echo "uuid=$UUID"

MNT=$D/mnt; mkdir -p "$MNT"
mount "$PARTDEV" "$MNT"
echo "mount_rc=$? belegung=$(df -h "$MNT" | tail -1 | awk '{print $3"/"$2" ("$5")"}')"
cp -a "$OUT/initramfs-$KREL.img" "$MNT/boot/initramfs-$KREL.img"

cat > "$MNT/etc/fstab" <<EOF
# /etc/fstab - NOVA OS Boot-Test $TAG (Phase 11.7.1)
UUID=$UUID  /        ext4   defaults,noatime          0 1
tmpfs       /tmp     tmpfs  nosuid,nodev,mode=1777    0 0
tmpfs       /var/tmp tmpfs  nosuid,nodev,mode=1777    0 0
EOF

install -m 0755 "$OUT/phase11_7_bootcheck_v3.sh" "$MNT/usr/local/sbin/nova-bootcheck.sh"
cat > "$MNT/etc/systemd/system/nova-bootcheck.service" <<'UNIT'
[Unit]
Description=NOVA OS Boot-Test Harness (Phase 11.7.1, Lauf C)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nova-bootcheck.sh
TimeoutStartSec=900
StandardOutput=journal
UNIT
cat > "$MNT/etc/systemd/system/nova-bootcheck.timer" <<'UNIT'
[Unit]
Description=NOVA Boot-Test Harness Start (45 s nach Boot)

[Timer]
OnBootSec=45s
AccuracySec=1s
Unit=nova-bootcheck.service

[Install]
WantedBy=timers.target
UNIT
mkdir -p "$MNT/etc/systemd/system/timers.target.wants"
ln -sf /etc/systemd/system/nova-bootcheck.timer "$MNT/etc/systemd/system/timers.target.wants/nova-bootcheck.timer"
echo "timer_verlinkt=$(readlink "$MNT/etc/systemd/system/timers.target.wants/nova-bootcheck.timer")"

mkdir -p "$MNT/boot/grub"
cat > "$MNT/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=5

menuentry 'NOVA OS 6.18.62-nova (PACKET=y, DNS-Fix K2) - Phase 11.7.1 Lauf $TAG' {
  linux /boot/vmlinuz-$KREL root=UUID=$UUID ro console=tty0 console=ttyS0,115200 loglevel=7 systemd.log_level=info systemd.show_status=true
  initrd /boot/initramfs-$KREL.img
}
EOF
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

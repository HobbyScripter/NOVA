#!/bin/bash
# Phase 11.7 - Boot-Test-Datentraeger bauen
# Erzeugt aus dem technischen Test-RootFS eine eigene virtuelle Platte mit
# MBR-Partitionstabelle, ext4-Root und GRUB (BIOS/i386-pc).
# Das RootFS-Artefakt selbst wird nur gelesen, nie veraendert.
set -u

R=/home/ramon/nova-os
OUT=$R/build/output

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@"
  exit $?
fi

exec > "$OUT/phase11_7-diskbuild.out" 2>&1
set -u

D=$OUT/boottest-11.7
RF=$OUT/rootfs-6.18.62-nova
KREL=6.18.62-nova
IMG=$D/nova-boottest-disk.raw
SIZE=1610612736          # 1,5 GiB
OFF=1048576              # 1 MiB (2048 Sektoren)

mkdir -p "$D"
if [ -e "$IMG" ]; then echo "ABBRUCH: $IMG existiert bereits"; echo "DISKBUILD_FEHLER"; exit 4; fi
[ -d "$RF" ] || { echo "ABBRUCH: RootFS fehlt"; echo "DISKBUILD_FEHLER"; exit 4; }
[ -f "$OUT/initramfs-$KREL.img" ] || { echo "ABBRUCH: Initramfs fehlt"; echo "DISKBUILD_FEHLER"; exit 4; }
[ -f "$OUT/phase11_7_bootcheck.sh" ] || { echo "ABBRUCH: Harness fehlt"; echo "DISKBUILD_FEHLER"; exit 4; }

echo "=== Phase 11.7 Datentraeger-Build $(date -Is) ==="
echo "image=$IMG size=$SIZE"

echo "--- 1. Rohimage und Partitionstabelle ---"
truncate -s "$SIZE" "$IMG"
sfdisk --quiet "$IMG" <<'PART'
label: dos
start=2048, type=83, bootable
PART
sfdisk -l "$IMG" | sed 's/^/  /'

echo "--- 2. Loop-Geraet ---"
LOOP=$(losetup --find --show --partscan "$IMG")
echo "loop=$LOOP"
sleep 1
lsblk "$LOOP" | sed 's/^/  /'
PARTDEV=${LOOP}p1
[ -b "$PARTDEV" ] || { echo "ABBRUCH: Partition nicht sichtbar"; }
echo "partdev=$PARTDEV groesse=$(blockdev --getsize64 "$PARTDEV")"

echo "--- 3. ext4 mit RootFS-Inhalt ---"
t0=$(date +%s)
mke2fs -q -t ext4 -L NOVA-TEST -F -d "$RF" "$PARTDEV"
echo "mkfs_rc=$? dauer=$(( $(date +%s)-t0 ))s"
echo "fs_typ=$(blkid -s TYPE -o value "$PARTDEV")"
echo "fs_uuid=$(blkid -s UUID -o value "$PARTDEV")"
echo "fs_label=$(blkid -s LABEL -o value "$PARTDEV")"

echo "--- 4. Mount und Bootdateien ---"
MNT=$D/mnt; mkdir -p "$MNT"
mount "$PARTDEV" "$MNT"
echo "mount_rc=$?"
UUID=$(blkid -s UUID -o value "$PARTDEV")

cp -a "$OUT/initramfs-$KREL.img" "$MNT/boot/initramfs-$KREL.img"
echo "initramfs_im_image=$(stat -c%s "$MNT/boot/initramfs-$KREL.img") B"
echo "kernel_im_image=$(stat -c%s "$MNT/boot/vmlinuz-$KREL") B"

cat > "$MNT/etc/fstab" <<EOF
# /etc/fstab - NOVA OS Boot-Test-Datentraeger (Phase 11.7)
# Echte UUID dieser Testplatte, keine Platzhalter.
UUID=$UUID  /        ext4   defaults,noatime          0 1
tmpfs       /tmp     tmpfs  nosuid,nodev,mode=1777    0 0
tmpfs       /var/tmp tmpfs  nosuid,nodev,mode=1777    0 0
EOF
echo "fstab:"; sed 's/^/  /' "$MNT/etc/fstab"

install -m 0755 "$OUT/phase11_7_bootcheck.sh" "$MNT/usr/local/sbin/nova-bootcheck.sh"
cat > "$MNT/etc/systemd/system/nova-bootcheck.service" <<'UNIT'
[Unit]
Description=NOVA OS Boot-Test Harness (Phase 11.7)
After=network.target systemd-user-sessions.service
Wants=network.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 12
ExecStart=/usr/local/sbin/nova-bootcheck.sh
TimeoutStartSec=600
StandardOutput=journal

[Install]
WantedBy=multi-user.target
UNIT
mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/nova-bootcheck.service "$MNT/etc/systemd/system/multi-user.target.wants/nova-bootcheck.service"
echo "harness_unit_verlinkt=$(readlink "$MNT/etc/systemd/system/multi-user.target.wants/nova-bootcheck.service")"

mkdir -p "$MNT/boot/grub"
cat > "$MNT/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=5
set timeout_style=menu

menuentry 'NOVA OS 6.18.62-nova (Technisches Test-RootFS) - Phase 11.7' {
  echo 'NOVA: lade Kernel 6.18.62-nova'
  linux /boot/vmlinuz-$KREL root=UUID=$UUID ro console=tty0 console=ttyS0,115200 loglevel=7 systemd.log_level=debug systemd.show_status=true systemd.log_target=journal+console
  echo 'NOVA: lade Initramfs'
  initrd /boot/initramfs-$KREL.img
}

menuentry 'NOVA OS 6.18.62-nova - Wiederherstellung (single)' {
  linux /boot/vmlinuz-$KREL root=UUID=$UUID ro console=tty0 console=ttyS0,115200 loglevel=7 systemd.unit=rescue.target
  initrd /boot/initramfs-$KREL.img
}
EOF
echo "grub.cfg:"; sed 's/^/  /' "$MNT/boot/grub/grub.cfg"

echo "--- 5. GRUB (BIOS, i386-pc) installieren ---"
grub-install --target=i386-pc --boot-directory="$MNT/boot" \
  --modules="part_msdos ext2 normal linux echo search search_fs_uuid configfile" \
  --no-floppy --recheck "$LOOP"
echo "grub_install_rc=$?"
ls -l "$MNT/boot/grub/i386-pc/core.img" 2>/dev/null | sed 's/^/  /'

sync
echo "--- 6. Aushaengen ---"
umount "$MNT"
echo "umount_rc=$?"
losetup -d "$LOOP"
echo "belegung: $(du -h --apparent-size "$IMG" | cut -f1) apparent"
echo "sha256_raw=$(sha256sum "$IMG" | cut -d' ' -f1)"
echo "bytes_raw=$(stat -c%s "$IMG")"
echo "DISKBUILD_OK"

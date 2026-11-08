#!/bin/bash
# Phase 11.6 - Stufe 2: Systempakete im RootFS installieren (chroot)
set -u

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@" > /tmp/p116_s2.out 2>&1
  exit $?
fi

exec > /tmp/p116_s2.out 2>&1
set -u

R=/home/ramon/nova-os
OUT=$R/build/output
RF=$OUT/rootfs-6.18.62-nova
LOG=$OUT/phase11_6-apt.log

echo "=== Phase 11.6 Stufe 2: Systempakete $(date -Is) ==="
[ -d "$RF/etc" ] || { echo "ABBRUCH: RootFS fehlt"; echo "STAGE2_FEHLER"; exit 4; }

cleanup() {
  umount "$RF/dev/pts" 2>/dev/null || true
  umount "$RF/dev" 2>/dev/null || true
  umount "$RF/proc" 2>/dev/null || true
  umount "$RF/sys" 2>/dev/null || true
}
trap cleanup EXIT

mount --bind /dev "$RF/dev" || { echo "ABBRUCH: bind /dev"; exit 5; }
mkdir -p "$RF/dev/pts"
mount --bind /dev/pts "$RF/dev/pts" || { echo "ABBRUCH: bind /dev/pts"; exit 5; }
mount -t proc proc "$RF/proc" || { echo "ABBRUCH: proc"; exit 5; }
mount -t sysfs sys "$RF/sys" || { echo "ABBRUCH: sysfs"; exit 5; }

cp /etc/resolv.conf "$RF/etc/resolv.conf"

# Keine Dienste während der Installation starten
printf '#!/bin/sh\nexit 101\n' > "$RF/usr/sbin/policy-rc.d"
chmod 755 "$RF/usr/sbin/policy-rc.d"

PKGS="systemd systemd-sysv udev dbus kmod dracut network-manager wpasupplicant \
nftables apparmor apparmor-profiles btrfs-progs e2fsprogs dosfstools squashfs-tools \
util-linux procps psmisc lsof strace less file iproute2 iputils-ping curl wget \
ca-certificates tar gzip xz-utils zstd nano linux-firmware"

echo "paketliste: $PKGS"
t0=$(date +%s)
: > "$LOG"

DEBIAN_FRONTEND=noninteractive chroot "$RF" apt-get update >> "$LOG" 2>&1
rc_update=$?

DEBIAN_FRONTEND=noninteractive chroot "$RF" apt-get install -y \
  --no-install-recommends \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confold \
  $PKGS >> "$LOG" 2>&1
rc_install=$?
t1=$(date +%s)

echo "apt_update_rc=$rc_update"
echo "apt_install_rc=$rc_install"
echo "dauer_sek=$((t1-t0))"
echo "installierte_pakete_im_log=$(grep -c '^Setting up ' "$LOG")"
echo "--- Log-Ende ---"
tail -8 "$LOG"
echo "---------------"

rm -f "$RF/usr/sbin/policy-rc.d"
DEBIAN_FRONTEND=noninteractive chroot "$RF" apt-get clean >> "$LOG" 2>&1
rm -rf "$RF/var/lib/apt/lists"/*

if [ "$rc_update" -ne 0 ] || [ "$rc_install" -ne 0 ]; then
  echo "STAGE2_FEHLER"
  exit 6
fi

echo "rootfs_bytes=$(du -sb "$RF" | cut -f1)"
echo "systemd_binary=$(ls -l "$RF/usr/lib/systemd/systemd" 2>/dev/null | awk '{print $5}')"
echo "STAGE2_OK"

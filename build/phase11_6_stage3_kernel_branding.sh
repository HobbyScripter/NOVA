#!/bin/bash
# Phase 11.6 - Stufe 3: NOVA-Kernel + Module uebernehmen, Branding, depmod
set -u

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@" > /tmp/p116_s3.out 2>&1
  exit $?
fi

exec > /tmp/p116_s3.out 2>&1
set -u

R=/home/ramon/nova-os
OUT=$R/build/output
RF=$OUT/rootfs-6.18.62-nova
DRV=$OUT/sysroot-drivers
KREL=6.18.62-nova

echo "=== Phase 11.6 Stufe 3: Kernel und Branding $(date -Is) ==="
[ -d "$RF/etc" ] || { echo "ABBRUCH: RootFS fehlt"; echo "STAGE3_FEHLER"; exit 4; }
[ -f "$DRV/boot/vmlinuz-nova-6.18.62-drv" ] || { echo "ABBRUCH: Kernel fehlt"; echo "STAGE3_FEHLER"; exit 4; }

echo "kernel_quelle_sha=$(sha256sum "$DRV/boot/vmlinuz-nova-6.18.62-drv" | cut -d' ' -f1)"
echo "kernel_quelle_bytes=$(stat -c%s "$DRV/boot/vmlinuz-nova-6.18.62-drv")"

# --- Standardverzeichnisse sicherstellen (Symlinks nicht ueberschreiben) ---
for d in bin boot dev etc home lib lib64 mnt opt proc root run sbin srv sys tmp usr var \
         usr/bin usr/sbin usr/lib usr/lib64 usr/share var/log var/tmp media; do
  [ -e "$RF/$d" ] || mkdir -p "$RF/$d"
done
chmod 1777 "$RF/tmp" "$RF/var/tmp"
chmod 700 "$RF/root"

# --- Kernel, Module, depmod ---
mkdir -p "$RF/boot"
cp -f "$DRV/boot/vmlinuz-nova-6.18.62-drv" "$RF/boot/vmlinuz-$KREL"
cp -f "$DRV/boot/System.map-6.18.62-nova-drv" "$RF/boot/System.map-$KREL"
cp -f "$DRV/boot/config-6.18.62-nova-drv" "$RF/boot/config-$KREL"
rm -rf "$RF/lib/modules/$KREL"
mkdir -p "$RF/lib/modules"
cp -a "$DRV/lib/modules/$KREL" "$RF/lib/modules/$KREL"
echo "module_kopiert=$(find "$RF/lib/modules/$KREL" -name '*.ko' | wc -l)"

depmod -b "$RF" "$KREL"
echo "depmod_rc=$?"
echo "modules_dep_eintraege=$(wc -l < "$RF/lib/modules/$KREL/modules.dep" 2>/dev/null || echo 0)"

# --- NOVA-Identitaet (ausdruecklich als Test-RootFS gekennzeichnet) ---
cat > "$RF/usr/lib/os-release" <<'EOF'
NAME="NOVA OS"
PRETTY_NAME="NOVA OS 1.0 (Technisches Test-RootFS)"
ID=nova
ID_LIKE=ubuntu
VERSION="1.0-testrootfs"
VERSION_ID="1.0"
VERSION_CODENAME="Supernova"
ANSI_COLOR="0;36"
HOME_URL="https://nova-os.org/"
SUPPORT_URL="https://nova-os.org/support"
BUG_REPORT_URL="https://bugs.nova-os.org/"
DOCUMENTATION_URL="https://docs.nova-os.org/"
LOGO=nova-logo-icon
DEFAULT_HOSTNAME=nova-test
BUILD_BASIS="Ubuntu 24.04 noble (debootstrap) - TESTROOTFS, keine unabhaengige NOVA-Paketbasis"
EOF
ln -sf ../usr/lib/os-release "$RF/etc/os-release"

printf 'NOVA OS 1.0 (Technisches Test-RootFS) \\n \\l\n\n' > "$RF/etc/issue"

echo "nova-test" > "$RF/etc/hostname"
cat > "$RF/etc/hosts" <<'EOF'
127.0.0.1   localhost
127.0.1.1   nova-test.localdomain nova-test
::1         localhost ip6-localhost ip6-loopback
EOF

: > "$RF/etc/machine-id"
chmod 444 "$RF/etc/machine-id"
rm -f "$RF/var/lib/dbus/machine-id" 2>/dev/null || true

# fstab: bewusst ohne erfundene UUIDs; Root wird vom Initramfs bzw. Bootloader uebergeben
cat > "$RF/etc/fstab" <<'EOF'
# /etc/fstab - NOVA OS Test-RootFS
# Die Root-Partition wird beim Booten von Kernel/Initramfs uebergeben.
# Echte UUID-Eintraege entstehen erst bei der Installation (Phase >= 11.8).
tmpfs   /tmp        tmpfs   nosuid,nodev,mode=1777   0 0
tmpfs   /var/tmp   tmpfs   nosuid,nodev,mode=1777   0 0
EOF

# Klassifizierung als Artefakt
mkdir -p "$RF/etc/nova"
cat > "$RF/etc/nova/rootfs-class" <<'EOF'
class=technical-test-rootfs
independent=nova-package-base-missing
base=ubuntu-noble-debootstrap
kernel=6.18.62-nova
created-by=phase11.6
EOF

# dracut-Konfiguration im Zielsystem (fuer spaetere Neuerzeugung)
mkdir -p "$RF/etc/dracut.conf.d"
cat > "$RF/etc/dracut.conf.d/10-nova.conf" <<'EOF'
# NOVA OS - Initramfs-Konfiguration
hostonly="no"
compress="zstd"
filesystems+=" ext4 btrfs squashfs overlay "
add_drivers+=" nvme ahci libahci sd_mod usb-storage uas usbhid xhci_pci ehci_pci vmw_pvscsi "
omit_drivers+=" amdgpu i915 xe nouveau iwlwifi btusb snd_hda_intel snd_usb_audio r8169 e1000e vmwgfx "
EOF

echo "os_release: $(grep PRETTY_NAME "$RF/usr/lib/os-release")"
echo "rootfs_bytes=$(du -sb "$RF" | cut -f1)"
echo "STAGE3_OK"

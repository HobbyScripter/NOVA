#!/bin/bash
# Phase 11.7.1 - separates Test-RootFS mit dem neuen Kernel (CONFIG_PACKET=y)
# Das Phase-11.6-RootFS bleibt unveraendert.
set -u

R=/home/ramon/nova-os
OUT=$R/build/output

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@"
  exit $?
fi

exec > "$OUT/phase11_7_1-rootfs.out" 2>&1
set -u

SRC=$OUT/rootfs-6.18.62-nova
DST=$OUT/rootfs-6.18.62-nova-11.7.1
D=$R/build/kernel-build/phase11_7_1
S=$D/linux-6.18.62
KREL=6.18.62-nova
FAIL=0
ok() { echo "  [OK]   $*"; }
bad() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

echo "=== Phase 11.7.1 RootFS-Kopie $(date -Is) ==="
if [ -e "$DST" ]; then echo "ABBRUCH: $DST existiert bereits"; echo "ROOTFS_FEHLER"; exit 4; fi
[ -d "$SRC" ] || { echo "ABBRUCH: Quelle fehlt"; exit 4; }
[ -f "$S/arch/x86/boot/bzImage" ] || { echo "ABBRUCH: bzImage fehlt"; exit 4; }

echo "--- 1. Kopie (cp -a, Rechte erhalten) ---"
t0=$(date +%s)
cp -a "$SRC" "$DST"
echo "cp_rc=$? dauer=$(( $(date +%s)-t0 ))s"
echo "dateien_vorher=$(find "$SRC" -type f 2>/dev/null | wc -l) nachher=$(find "$DST" -type f 2>/dev/null | wc -l)"

echo "--- 2. neuer Kernel und Module einsetzen ---"
OLD_SHA=$(sha256sum "$DST/boot/vmlinuz-$KREL" | cut -d' ' -f1)
echo "kernel_alt_sha256=$OLD_SHA"
cp -f "$S/arch/x86/boot/bzImage" "$DST/boot/vmlinuz-$KREL"
cp -f "$S/System.map" "$DST/boot/System.map-$KREL"
cp -f "$S/.config" "$DST/boot/config-$KREL"
NEW_SHA=$(sha256sum "$DST/boot/vmlinuz-$KREL" | cut -d' ' -f1)
echo "kernel_neu_sha256=$NEW_SHA"
echo "kernel_bytes=$(stat -c%s "$DST/boot/vmlinuz-$KREL")"

echo "--- 3. Module ersetzen ---"
rm -rf "$DST/lib/modules/$KREL"
mkdir -p "$DST/lib/modules/$KREL"
t0=$(date +%s)
make -s -C "$S" INSTALL_MOD_PATH="$DST" INSTALL_MOD_STRIP=1 modules_install
echo "modules_install_rc=$? dauer=$(( $(date +%s)-t0 ))s"
depmod -b "$DST" "$KREL"
echo "depmod_rc=$?"
echo "module_neu=$(find "$DST/lib/modules/$KREL" -name '*.ko' | wc -l)"
echo "modules.dep_eintraege=$(wc -l < "$DST/lib/modules/$KREL/modules.dep" 2>/dev/null)"

echo "--- 4. Vermagic-Abgleich ---"
vm=$(modinfo -F vermagic "$DST/lib/modules/$KREL/kernel/drivers/net/ethernet/intel/e1000e/e1000e.ko" 2>/dev/null)
echo "vermagic_modul=$vm"
case "$vm" in "$KREL "*) ok "Vermagic passt zu $KREL";; *) bad "Vermagic passt nicht: $vm";; esac

echo "--- 5. K1 und Klassifizierung ---"
K1=$DST/etc/NetworkManager/conf.d/99-nova-managed-ethernet.conf
[ -f "$K1" ] && ok "K1-Datei vorhanden" || bad "K1-Datei fehlt"
sed 's/^/  /' "$K1" 2>/dev/null
echo "  NetworkManager-Dienst: $(ls "$DST/lib/systemd/system/NetworkManager.service" >/dev/null 2>&1 && echo vorhanden || echo FEHLT)"
echo "  NM-Wants-Link: $(readlink "$DST/etc/systemd/system/multi-user.target.wants/NetworkManager.service" 2>/dev/null || echo 'kein Link')"
echo "  NM-dispatcher-wants: $(ls "$DST/etc/systemd/system/NetworkManager-dispatcher.service.wants" >/dev/null 2>&1 && echo vorhanden || echo '-')"
echo "  widerspruechliche Netzwerkdateien:"
echo "    /etc/network/interfaces: $(grep -vE '^\s*#|^$' "$DST/etc/network/interfaces" 2>/dev/null | head -3 | tr '\n' ' ' || echo 'nicht vorhanden')"
echo "    netplan: $(ls "$DST/etc/netplan" 2>/dev/null | tr '\n' ' ' || echo 'kein netplan')"
echo "    systemd-networkd enabled: $(ls "$DST/etc/systemd/system/dbus-org.freedesktop.network1.service" >/dev/null 2>&1 && echo ja || echo nein)"
echo "  rootfs-class:"; sed 's/^/    /' "$DST/etc/nova/rootfs-class"

if ! grep -q '^kernel-packet-fix=' "$DST/etc/nova/rootfs-class"; then
  echo "kernel-packet-fix=11.7.1 CONFIG_PACKET=y kernel-sha256=$NEW_SHA" >> "$DST/etc/nova/rootfs-class"
  echo "  rootfs-class ergaenzt"; fi

echo "--- 6. Kennzeichnung erhalten? ---"
grep -q 'class=technical-test-rootfs' "$DST/etc/nova/rootfs-class" && ok "Test-Klassifizierung erhalten" || bad "Test-Klassifizierung fehlt"
grep -q 'TESTROOTFS' "$DST/usr/lib/os-release" && ok "os-release-Kennzeichnung erhalten" || bad "os-release-Kennzeichnung fehlt"

echo "--- 7. Quell-RootFS unveraendert ---"
echo "  quelle_kernel_sha256=$(sha256sum "$SRC/boot/vmlinuz-$KREL" | cut -d' ' -f1)"
echo "  quelle_module=$(find "$SRC/lib/modules/$KREL" -name '*.ko' | wc -l)"
echo "  ziel_groesse=$(du -sh "$DST" | cut -f1) dateien=$(find "$DST" -type f 2>/dev/null | wc -l)"

echo
[ "$FAIL" -eq 0 ] && echo "ROOTFS_KOPIE_OK" || echo "ROOTFS_KOPIE_FEHLER=$FAIL"

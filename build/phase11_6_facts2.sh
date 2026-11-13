#!/bin/bash
# Phase 11.6 - Detailabfragen (Root noetig fuer chroot)
if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@"
  exit $?
fi
exec > /tmp/facts2.out 2>&1

OUT=/home/ramon/nova-os/build/output
RF=$OUT/rootfs-6.18.62-nova
FW=$RF/lib/firmware

echo "nft-Binary: $(ls -l "$RF/usr/sbin/nft" 2>/dev/null | awk '{print $5}') Bytes"
echo "nft im PATH des RootFS: $(chroot "$RF" bash -c 'command -v nft' 2>/dev/null)"
echo "iwlwifi-Flatfiles: $(find "$FW" -maxdepth 1 -name 'iwlwifi-*' -type f 2>/dev/null | wc -l)"
echo "i915: $(find "$FW/i915" -type f 2>/dev/null | wc -l) Dateien"
echo "amdgpu: $(find "$FW/amdgpu" -type f 2>/dev/null | wc -l) Dateien"
echo "--- nicht-.zst-Dateien in /lib/firmware ---"
find "$FW" -type f ! -name '*.zst' 2>/dev/null | sed 's#.*/lib/firmware/#  #' | head -18
echo "--- Top-Pakete nach Groesse (KiB) ---"
chroot "$RF" dpkg-query -W -f='${Installed-Size}\t${Package}\n' 2>/dev/null | sort -rn | head -8
echo "--- dracut-Log Kopf ---"
head -2 "$OUT/phase11_6-dracut.log"
echo "--- dracut-Log Zeilen mit Moduln ---"
grep -c 'Including module:' "$OUT/phase11_6-dracut.log"

#!/bin/bash
# Phase 11.6 - Diagnose Root-Zugang im Gast
exec > /tmp/rootcheck116.out 2>&1
set -u
echo "pw_datei: $(ls -l /tmp/nova_pw 2>/dev/null | awk '{print $1, $3, $5" Bytes"}' || echo FEHLT)"
if [ -r /tmp/nova_pw ]; then
  echo "pw_laenge=$(stat -c%s /tmp/nova_pw)"
  echo "root_uid_test: $(printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' id -u 2>&1 | tail -1)"
  echo "root_name_test: $(printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' id -un 2>&1 | tail -1)"
else
  echo "KEINE_PW_DATEI"
fi
echo "rootfs_ziel: $([ -e /home/ramon/nova-os/build/output/rootfs-6.18.62-nova ] && echo existiert || echo frei)"
echo "RAM: $(awk '/MemTotal/{printf "%.1f GiB", $2/1048576}' /proc/meminfo) total"
echo "df_home: $(df -h /home/ramon | tail -1)"
echo "skripte: $(ls /home/ramon/nova-os/build/phase11_6_*.sh 2>/dev/null | wc -l) vorhanden"

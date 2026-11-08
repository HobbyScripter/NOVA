#!/bin/bash
# Phase 11.6 - Stufe 1: Basis-RootFS via debootstrap (technisches Test-RootFS, Ubuntu noble)
# Schreibt nach build/output/rootfs-6.18.62-nova; bricht ab, wenn das Ziel existiert.
set -u

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@" > /tmp/p116_s1.out 2>&1
  exit $?
fi

exec > /tmp/p116_s1.out 2>&1
set -u

R=/home/ramon/nova-os
OUT=$R/build/output
RF=$OUT/rootfs-6.18.62-nova
DLOG=$OUT/phase11_6-debootstrap.log

echo "=== Phase 11.6 Stufe 1: debootstrap $(date -Is) ==="
echo "uid=$(id -u) user=$(id -un)"

if [ -e "$RF" ]; then
  echo "ABBRUCH: Ziel existiert bereits: $RF"
  echo "STAGE1_FEHLER"
  exit 4
fi

mkdir -p "$OUT"
t0=$(date +%s)
debootstrap --variant=minbase --arch=amd64 --components=main,universe \
  noble "$RF" http://archive.ubuntu.com/ubuntu > "$DLOG" 2>&1
rc=$?
t1=$(date +%s)

echo "debootstrap_rc=$rc"
echo "dauer_sek=$((t1-t0))"
echo "--- Log-Ende ---"
tail -6 "$DLOG"
echo "---------------"

if [ "$rc" -ne 0 ]; then
  echo "STAGE1_FEHLER"
  exit "$rc"
fi

echo "rootfs_bytes=$(du -sb "$RF" | cut -f1)"
echo "dateien=$(find "$RF" -type f | wc -l)"
echo "verzeichnisse=$(find "$RF" -type d | wc -l)"
echo "release: $(grep PRETTY_NAME "$RF/etc/os-release" 2>/dev/null)"
echo "debootstrap_version=$(debootstrap --version 2>/dev/null | head -1)"
echo "STAGE1_OK"

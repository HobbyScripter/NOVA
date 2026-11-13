#!/bin/bash
# Phase 11.7 - Korrektur K1 aus Bootversuch 2:
# NetworkManager verwaltete Ethernet nicht, weil Ubuntus
# /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf alle Geraete
# ausser WLAN/GSM/CDMA auf "unmanaged" setzt (fuer Netplan-Systeme gedacht).
# Ohne Netplan bleibt Ethernet damit unmanaged.
set -u

R=/home/ramon/nova-os
OUT=$R/build/output

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@"
  exit $?
fi

exec > "$OUT/phase11_7-fix-k1.out" 2>&1
set -u

RF=$OUT/rootfs-6.18.62-nova
F=$RF/etc/NetworkManager/conf.d/99-nova-managed-ethernet.conf

echo "=== Korrektur K1 $(date -Is) ==="
if [ -e "$F" ]; then
  echo "K1 bereits vorhanden, keine Aenderung"
else
  cat > "$F" <<'CONF'
# NOVA OS - Korrektur K1 (Phase 11.7, nach Bootversuch 2)
# Ubuntu setzt in /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
# alle Geraete ausser WLAN/GSM/CDMA auf "unmanaged" (gedacht fuer Netplan-Systeme).
# Ohne Netplan bleibt Ethernet damit unmanaged. Diese Datei ueberschreibt das fuer
# Ethernet und WLAN, sodass NetworkManager die Geraete verwaltet.
[keyfile]
unmanaged-devices=except:type:ethernet,except:type:wifi
CONF
  echo "K1 geschrieben: $F"
fi
sed 's/^/  /' "$F"

if ! grep -q '^corrections=' "$RF/etc/nova/rootfs-class"; then
  echo "corrections=k1-networkmanager-managed-ethernet" >> "$RF/etc/nova/rootfs-class"
fi
echo "rootfs-class:"; sed 's/^/  /' "$RF/etc/nova/rootfs-class"
echo "dateien=$(find "$RF" -type f 2>/dev/null | wc -l)"
echo "groesse_bytes=$(du -sb "$RF" 2>/dev/null | cut -f1)"
echo "FIX_K1_OK"

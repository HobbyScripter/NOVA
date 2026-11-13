#!/bin/bash
# Phase 11.7.1 - Korrektur K2: DNS
# NetworkManager ist per /usr/lib/NetworkManager/conf.d/10-dns-resolved.conf auf
# dns=systemd-resolved eingestellt, aber systemd-resolved ist im Test-RootFS nicht
# installiert (debootstrap minbase). /etc/resolv.conf zeigt auf den nicht
# existierenden Stub 127.0.0.53 -> Namensaufloesung schlaegt fehl.
# K2 stellt NetworkManager auf eigene resolv.conf-Verwaltung (dns=default).
set -u

R=/home/ramon/nova-os
OUT=$R/build/output

if [ "$(id -u)" -ne 0 ]; then
  if [ ! -r /tmp/nova_pw ]; then echo "FEHLER: /tmp/nova_pw fehlt"; exit 3; fi
  printf '%s\n' "$(cat /tmp/nova_pw)" | sudo -S -p '' bash "$0" "$@"
  exit $?
fi

exec > "$OUT/phase11_7_1-fix-k2.out" 2>&1
set -u

RF=$OUT/rootfs-6.18.62-nova-11.7.1
F=$RF/etc/NetworkManager/conf.d/99-nova-dns.conf

echo "=== Korrektur K2 $(date -Is) ==="
if [ -e "$F" ]; then
  echo "K2 bereits vorhanden"
else
  cat > "$F" <<'CONF'
# NOVA OS - Korrektur K2 (Phase 11.7.1)
# systemd-resolved ist im Test-RootFS nicht installiert, NetworkManager war aber
# per /usr/lib/NetworkManager/conf.d/10-dns-resolved.conf darauf eingestellt.
# dns=default laesst NetworkManager /etc/resolv.conf selbst schreiben.
[main]
dns=default
CONF
  echo "K2 geschrieben: $F"
fi
sed 's/^/  /' "$F"

# /etc/resolv.conf ist ein toter Symlink auf systemd-resolved -> durch echte Datei ersetzen
if [ -L "$RF/etc/resolv.conf" ]; then
  echo "resolv.conf war Symlink -> $(readlink "$RF/etc/resolv.conf")"
  rm -f "$RF/etc/resolv.conf"
  printf 'nameserver 192.168.43.2\n' > "$RF/etc/resolv.conf"
  echo "resolv.conf als regulaere Datei ersetzt (Fallback, wird von NM ueberschrieben)"
fi

if ! grep -q '^dns-fix=' "$RF/etc/nova/rootfs-class"; then
  echo "dns-fix=k2-networkmanager-dns-default" >> "$RF/etc/nova/rootfs-class"
fi
echo "rootfs-class:"; sed 's/^/  /' "$RF/etc/nova/rootfs-class"
echo "FIX_K2_OK"

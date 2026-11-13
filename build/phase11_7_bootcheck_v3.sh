#!/bin/bash
# Phase 11.7 - Boot-Test-Harness, Versuch 3
# Gegenueber V2: kuerzere Wartezeit, Analyse der offenen systemd-Jobs,
# NetworkManager-Verifikation nach Korrektur K1 (Ethernet wird verwaltet).
LOG=/var/log/nova-bootcheck.log
exec > >(tee -a "$LOG" > /dev/ttyS0) 2>&1
set +e

MARK() { echo; echo "########## $* ##########"; }

MARK "NOVA 11.7 BOOTCHECK V3 START $(date -Is)"
echo "hostname: $(cat /etc/hostname)"
echo "uptime_sekunden: $(cut -d' ' -f1 /proc/uptime)"

MARK "0 AUF BOOT-ENDE WARTEN (max 120 s)"
for i in $(seq 1 30); do
  st=$(systemctl is-system-running 2>&1)
  echo "  t=$((i*4))s $st"
  case "$st" in starting|initializing|"") sleep 4 ;; *) break ;; esac
done
echo "boot_zustand: $(systemctl is-system-running 2>&1)"

MARK "0a OFFENE JOBS"
systemctl list-jobs --no-legend --no-pager 2>&1 | sed 's/^/  job: /'
echo "job_anzahl: $(systemctl list-jobs --no-legend --no-pager 2>/dev/null | wc -l)"
MARK "0b UNITS IM ZUSTAND ACTIVATING"
systemctl list-units --state=activating --no-legend --no-pager 2>&1 | sed 's/^/  /'
MARK "0c BOOT-ANALYSE"
systemd-analyze 2>&1 | sed 's/^/  /'

MARK "1 KERNEL"
echo "uname_a: $(uname -a)"
echo "cpus: $(nproc)  mem_mb: $(free -m | awk '/^Mem:/{print $2}')"
echo "cmdline: $(cat /proc/cmdline)"
echo "boot_id: $(cat /proc/sys/kernel/random/boot_id)"

MARK "2 INIT-SYSTEM"
echo "pid1_comm: $(cat /proc/1/comm)"
echo "pid1_cmdline: $(tr '\0' ' ' < /proc/1/cmdline)"
echo "default_target: $(systemctl get-default)"
echo "reached_targets: $(systemctl list-units --type=target --state=active --no-legend --no-pager 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"
echo "failed_count: $(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)"
systemctl --failed --no-legend --no-pager 2>&1 | sed 's/^/  failed: /'
echo "running_services: $(systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"

MARK "3 ROOTFS"
echo "mount_root: $(awk '$2=="/"{print $1" "$3" ("$4")"}' /proc/mounts)"
echo "root_fs: $(blkid -s TYPE -o value /dev/sda1) uuid=$(blkid -s UUID -o value /dev/sda1) label=$(blkid -s LABEL -o value /dev/sda1)"
echo "df_root: $(df -h / | tail -1)"
echo "os_release_pretty: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo "rootfs_class: $(tr '\n' ' ' < /etc/nova/rootfs-class)"
echo "schreibtest: $(touch /var/log/.w 2>/dev/null && echo JA || echo NEIN)$(rm -f /var/log/.w)"
echo "userspace: $(id -u)/$(id -un) $(bash --version | head -1 | cut -d, -f1) $(date -Is)"

MARK "4 HARDWARE"
echo "pci_anzahl: $(ls -d /sys/bus/pci/devices/* | wc -l)  vmware: $(grep -l 0x15ad /sys/bus/pci/devices/*/vendor 2>/dev/null | wc -l)"
for d in /sys/bus/pci/devices/*; do
  c=$(cat "$d/class" 2>/dev/null)
  case "$c" in
    0x03*|0x0106*|0x0200*|0x0c03*) echo "  $(basename "$d") class=$c vendor=$(cat "$d/vendor") device=$(cat "$d/device") treiber=$(basename "$(readlink -f "$d/driver" 2>/dev/null)")";;
  esac
done
echo "framebuffer: $(ls /sys/class/graphics | tr '\n' ' ') $(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>&1 | sed 's/^/  /'
for d in /sys/bus/usb/devices/*; do [ -f "$d/idVendor" ] && echo "  usb $(basename "$d") $(cat "$d/idVendor"):$(cat "$d/idProduct") $(cat "$d/product" 2>/dev/null)"; done
for i in /sys/class/input/*; do echo "  input $(basename "$i") $(cat "$i/device/name" 2>/dev/null)"; done

MARK "5 NETZWERK (nach Korrektur K1)"
echo "net_devices: $(ls /sys/class/net | tr '\n' ' ')"
echo "NetworkManager: $(systemctl is-active NetworkManager)"
echo "K1-Datei: $(cat /etc/NetworkManager/conf.d/99-nova-managed-ethernet.conf 2>/dev/null | tr '\n' ' ')"
systemctl restart NetworkManager 2>&1 | sed 's/^/  restart: /'
for i in $(seq 1 15); do
  ip=$(ip -o -4 addr show enp2s1 2>/dev/null | awk '{print $4}')
  [ -n "$ip" ] && break
  sleep 2
done
MARK "5a ZUSTAND"
nmcli -t device status 2>&1 | sed 's/^/  /'
echo "ip_enp2s1: ${ip:-keine}"
echo "ip_addr: $(ip -o -4 addr show | tr '\n' '|')"
echo "route: $(ip route | tr '\n' '|')"
echo "dns: $(grep -v '^#' /etc/resolv.conf | tr '\n' ' ')"
GW=$(ip route | awk '/^default/{print $3; exit}')
echo "gateway: ${GW:-keiner}"
echo "ping_gateway: $([ -n "$GW" ] && ping -c1 -W2 "$GW" >/dev/null 2>&1 && echo OK || echo FEHLGESCHLAGEN)"
echo "ping_internet: $(ping -c1 -W3 1.1.1.1 >/dev/null 2>&1 && echo erreichbar || echo nicht_erreichbar)"
echo "http_test: $(curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://archive.ubuntu.com/ubuntu/ 2>/dev/null || echo '-')"

MARK "6 MODULE/FIRMWARE"
echo "module: $(lsmod | tail -n +2 | wc -l) -> $(lsmod | tail -n +2 | awk '{print $1}' | tr '\n' ' ')"
dmesg | grep -iE 'firmware.*(fail|error|not found)|Direct firmware load' | head -5 | sed 's/^/  fw: /'

MARK "7 FEHLER"
echo "dmesg_err: $(dmesg --level=err | wc -l)"; dmesg --level=err | head -10 | sed 's/^/  /'
echo "journal_err: $(journalctl -b -p err --no-pager 2>/dev/null | tail -n +2 | wc -l)"
journalctl -b -p err --no-pager 2>/dev/null | tail -10 | sed 's/^/  /'

MARK "8 ABSCHLUSS"
echo "systemctl_is_system_running_final: $(systemctl is-system-running 2>&1)"
echo "failed_units_final: $(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)"
echo "jobs_final: $(systemctl list-jobs --no-legend --no-pager 2>/dev/null | wc -l)"
echo "uptime_ende: $(cut -d' ' -f1 /proc/uptime) s"
echo "NOVA_BOOTCHECK_V3_FERTIG $(date -Is)"
sync
sleep 2
systemctl poweroff 2>&1 || poweroff -f

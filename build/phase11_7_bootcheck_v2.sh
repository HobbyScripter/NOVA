#!/bin/bash
# Phase 11.7 - Boot-Test-Harness, Versuch 2
# Aenderungen gegenueber Versuch 1:
#  - wartet, bis systemd den Boot abgeschlossen hat (is-system-running)
#  - erfasst systemd-analyze erst danach
#  - diagnostiziert NetworkManager und versucht die NIC zu verwalten (DHCP)
#  - prueft danach erneut fehlgeschlagene Units
LOG=/var/log/nova-bootcheck.log
exec > >(tee -a "$LOG" > /dev/ttyS0) 2>&1
set +e

MARK() { echo; echo "########## $* ##########"; }
HAT() { command -v "$1" >/dev/null 2>&1; }

MARK "NOVA 11.7 BOOTCHECK V2 START $(date -Is)"
echo "hostname: $(cat /etc/hostname 2>/dev/null)"
echo "uptime_sekunden: $(cut -d' ' -f1 /proc/uptime)"

MARK "0 AUF BOOT-ENDE WARTEN"
for i in $(seq 1 60); do
  st=$(systemctl is-system-running 2>&1)
  echo "  t=$((i*4))s zustand=$st"
  case "$st" in
    starting|initializing|"") sleep 4 ;;
    *) break ;;
  esac
done
echo "boot_zustand_final: $(systemctl is-system-running 2>&1)"
echo "uptime_nach_warten: $(cut -d' ' -f1 /proc/uptime)"

MARK "1 KERNEL"
echo "uname_a: $(uname -a)"
echo "uname_r: $(uname -r)"
grep -m1 'model name' /proc/cpuinfo | sed 's/^/cpu: /'
echo "cpus: $(nproc)"
HAT free && free -m | sed 's/^/mem: /'
echo "cmdline: $(cat /proc/cmdline)"
echo "boot_id: $(cat /proc/sys/kernel/random/boot_id)"

MARK "2 INIT-SYSTEM"
echo "pid1_comm: $(cat /proc/1/comm)"
echo "pid1_cmdline: $(tr '\0' ' ' < /proc/1/cmdline)"
echo "systemctl_is_system_running: $(systemctl is-system-running 2>&1)"
echo "systemctl_default_target: $(systemctl get-default 2>&1)"
echo "reached_targets: $(systemctl list-units --type=target --state=active --no-legend --no-pager 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"
MARK "2a FEHLGESCHLAGENE UNITS"
systemctl --failed --no-legend --no-pager 2>&1 | sed 's/^/  /'
echo "failed_count: $(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)"
MARK "2b BOOT-DAUER"
systemd-analyze 2>&1 | sed 's/^/  /'
systemd-analyze blame 2>&1 | head -10 | sed 's/^/  blame: /'
MARK "2c AKTIVE DIENSTE"
systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | awk '{print "  "$1}' | head -30

MARK "3 ROOTFS"
echo "mount_root: $(awk '$2=="/"{print $1" "$3" ("$4")"}' /proc/mounts)"
echo "root_fs_typ_blkid: $(blkid -s TYPE -o value "$(awk '$2=="/"{print $1}' /proc/mounts)" 2>/dev/null)"
echo "root_fs_uuid: $(blkid -s UUID -o value "$(awk '$2=="/"{print $1}' /proc/mounts)" 2>/dev/null)"
echo "root_fs_label: $(blkid -s LABEL -o value "$(awk '$2=="/"{print $1}' /proc/mounts)" 2>/dev/null)"
echo "rootfs_schreibbar: $(touch /var/log/.w 2>/dev/null && echo JA || echo NEIN)$(rm -f /var/log/.w)"
echo "df_root: $(df -h / | tail -1)"
echo "os_release_pretty: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo "rootfs_class: $(tr '\n' ' ' < /etc/nova/rootfs-class)"
echo "userspace: bash=$(bash --version | head -1 | cut -d, -f1) date=$(date -Is) id=$(id -u)"

MARK "4 HARDWARE"
echo "pci_anzahl: $(ls -d /sys/bus/pci/devices/* | wc -l)"
echo "vmware_geraete: $(grep -l 0x15ad /sys/bus/pci/devices/*/vendor 2>/dev/null | wc -l)"
MARK "4a GRAFIK"
for d in /sys/bus/pci/devices/*; do c=$(cat "$d/class" 2>/dev/null); case "$c" in 0x03*) echo "  $(basename "$d") class=$c vendor=$(cat "$d/vendor") device=$(cat "$d/device") treiber=$(basename "$(readlink -f "$d/driver" 2>/dev/null)")";; esac; done
echo "framebuffer: $(ls /sys/class/graphics/ | tr '\n' ' ') aufloesung=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)"
MARK "4b STORAGE"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>&1 | sed 's/^/  /'
for d in /sys/bus/pci/devices/*; do c=$(cat "$d/class" 2>/dev/null); case "$c" in 0x0106*|0x0104*) echo "  storage_ctrl $(basename "$d") class=$c treiber=$(basename "$(readlink -f "$d/driver" 2>/dev/null)")";; esac; done
MARK "4c USB/EINGABE"
for d in /sys/bus/usb/devices/*; do [ -f "$d/idVendor" ] && echo "  $(basename "$d") $(cat "$d/idVendor"):$(cat "$d/idProduct") $(cat "$d/product" 2>/dev/null)"; done
for i in /sys/class/input/*; do echo "  input $(basename "$i") $(cat "$i/device/name" 2>/dev/null)"; done

MARK "5 NETZWERK"
echo "net_devices: $(ls /sys/class/net | tr '\n' ' ')"
echo "nmcli: $(nmcli --version 2>&1)"
echo "NetworkManager: $(systemctl is-active NetworkManager 2>&1)"
MARK "5a NM-KONFIGURATION"
for f in /etc/NetworkManager/NetworkManager.conf /etc/network/interfaces /usr/lib/NetworkManager/conf.d/*.conf; do
  [ -f "$f" ] && { echo "  --- $f ---"; sed 's/^/    /' "$f"; }
done
MARK "5b ZUSTAND VOR EINGRIFF"
nmcli -t device status 2>&1 | sed 's/^/  /'
echo "ip_vorher: $(ip -o -4 addr show | tr '\n' '|')"
MARK "5c NETZWERK AKTIVIEREN"
nmcli device set enp2s1 managed yes 2>&1 | sed 's/^/  managed_yes: /'
sleep 3
nmcli -t device status 2>&1 | sed 's/^/  nach_managed: /'
nmcli connection add type ethernet ifname enp2s1 con-name nova-dhcp ipv4.method auto ipv6.method disabled 2>&1 | sed 's/^/  add: /'
nmcli connection up nova-dhcp 2>&1 | sed 's/^/  up: /'
sleep 10
MARK "5d ZUSTAND NACH EINGRIFF"
nmcli -t device status 2>&1 | sed 's/^/  /'
nmcli -f DEVICE,TYPE,STATE,CONNECTION device 2>&1 | sed 's/^/  /'
echo "ip_addr: $(ip -o -4 addr show | tr '\n' '|')"
echo "route: $(ip route | tr '\n' '|')"
echo "dns: $(grep -v '^#' /etc/resolv.conf 2>/dev/null | tr '\n' ' ')"
echo "ping_gateway: $(GW=$(ip route | awk '/^default/{print $3; exit}'); [ -n "$GW" ] && ping -c 1 -W 2 "$GW" >/dev/null 2>&1 && echo OK || echo FEHLGESCHLAGEN)"
echo "ping_dns_test: $(ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && echo erreichbar || echo nicht_erreichbar)"

MARK "6 MODULE UND FIRMWARE"
echo "geladene_module: $(lsmod | tail -n +2 | wc -l)"
lsmod | tail -n +2 | awk '{print "  "$1}' | head -25
echo "firmware_fehler:"; dmesg | grep -iE 'firmware.*(fail|error|not found)|Direct firmware load' | head -10 | sed 's/^/  /'

MARK "7 KERNELFEHLER"
echo "dmesg_err_anzahl: $(dmesg --level=err | wc -l)"
dmesg --level=err | head -20 | sed 's/^/  /'
echo "journal_err_anzahl: $(journalctl -b -p err --no-pager | tail -n +2 | wc -l)"
journalctl -b -p err --no-pager 2>/dev/null | tail -20 | sed 's/^/  /'

MARK "8 JOURNAL ENDE"
journalctl -b --no-pager | tail -25 | sed 's/^/  /'

MARK "9 ABSCHLUSS"
echo "systemctl_is_system_running_final: $(systemctl is-system-running 2>&1)"
echo "failed_units_final: $(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)"
echo "uptime_ende: $(cut -d' ' -f1 /proc/uptime) s"
echo "NOVA_BOOTCHECK_V2_FERTIG $(date -Is)"
sync
sleep 2
systemctl poweroff 2>&1 || poweroff -f

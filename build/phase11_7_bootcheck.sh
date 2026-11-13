#!/bin/bash
# Phase 11.7 - Boot-Test-Harness
# Laeuft INNERHALB des gebooteten NOVA OS (systemd oneshot) und schreibt
# alle Laufzeitbefunde auf die serielle Konsole (ttyS0) und in eine Logdatei.
# Keine Erfolgsmeldung ohne tatsaechliche Messung: jede Zeile stammt aus dem laufenden System.

LOG=/var/log/nova-bootcheck.log
exec > >(tee -a "$LOG" > /dev/ttyS0) 2>&1
set +e

MARK() { echo; echo "########## $* ##########"; }
HAT() { command -v "$1" >/dev/null 2>&1; }

MARK "NOVA 11.7 BOOTCHECK START $(date -Is)"
echo "hostname: $(cat /etc/hostname 2>/dev/null)"
echo "uptime_sekunden_seit_boot: $(cut -d' ' -f1 /proc/uptime)"
echo "kernel_boot_time: $(date -d "@$(( $(date +%s) - ${UPTIME%%.*} ))" -Is 2>/dev/null)"

MARK "1 KERNEL"
echo "uname_a: $(uname -a)"
echo "uname_r: $(uname -r)"
echo "uname_m: $(uname -m)"
grep -m1 'model name' /proc/cpuinfo | sed 's/^/cpu: /'
echo "cpus: $(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)"
HAT free && free -m | sed 's/^/mem: /'
echo "cmdline: $(cat /proc/cmdline)"
echo "boot_id: $(cat /proc/sys/kernel/random/boot_id)"

MARK "2 INIT-SYSTEM"
echo "pid1_comm: $(cat /proc/1/comm)"
echo "pid1_cmdline: $(tr '\0' ' ' < /proc/1/cmdline)"
echo "pid1_exe: $(readlink -f /proc/1/exe)"
echo "systemctl_is_system_running: $(systemctl is-system-running 2>&1)"
echo "systemctl_default_target: $(systemctl get-default 2>&1)"
MARK "2a FEHLGESCHLAGENE UNITS"
systemctl --failed --no-legend --no-pager 2>&1 | sed 's/^/  /'
echo "failed_count: $(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)"
MARK "2b AKTIVE UNITS (Auswahl)"
systemctl list-units --type=service --state=running --no-legend --no-pager 2>&1 | awk '{print "  "$1}' | head -40
MARK "2c BOOT-DAUER"
HAT systemd-analyze && systemd-analyze 2>&1 | sed 's/^/  /'

MARK "3 ROOTFS"
echo "mount_root: $(awk '$2=="/"{print $1" "$3" ("$4")"}' /proc/mounts)"
echo "mounts_alle:"; sed 's/^/  /' /proc/mounts | head -30
echo "root_fs_typ: $(stat -f -c %T / 2>/dev/null)"
echo "root_fs_uuid: $(blkid -s UUID -o value "$(awk '$2=="/"{print $1}' /proc/mounts)" 2>/dev/null)"
echo "rootfs_schreibbar_test: $(touch /var/log/.nova_write_test 2>&1 && echo JA || echo NEIN)$(rm -f /var/log/.nova_write_test 2>/dev/null)"
MARK "3a os-release"
sed 's/^/  /' /etc/os-release
MARK "3b rootfs-class"
sed 's/^/  /' /etc/nova/rootfs-class 2>&1
MARK "3c Userspace-Kommandos"
echo "pwd: $(pwd)"
echo "ls_root: $(ls / | tr '\n' ' ')"
echo "id: $(id)"
echo "bash_version: $(bash --version | head -1)"
echo "date: $(date -Is)"
echo "binaries: bash=$(stat -c%s /usr/bin/bash) systemd=$(stat -c%s /usr/lib/systemd/systemd) systemctl=$(stat -c%s /usr/bin/systemctl)"

MARK "4 HARDWARE - PCI"
for d in /sys/bus/pci/devices/*; do
  v=$(cat "$d/vendor" 2>/dev/null); dev=$(cat "$d/device" 2>/dev/null); c=$(cat "$d/class" 2>/dev/null)
  drv=$(basename "$(readlink -f "$d/driver" 2>/dev/null)" 2>/dev/null)
  echo "  $(basename "$d") vendor=$v device=$dev class=$c treiber=${drv:-keiner}"
done
echo "pci_anzahl: $(ls -d /sys/bus/pci/devices/* 2>/dev/null | wc -l)"
echo "vmware_geraete (vendor 0x15ad): $(grep -l 0x15ad /sys/bus/pci/devices/*/vendor 2>/dev/null | wc -l)"

MARK "4a GRAFIK"
for d in /sys/bus/pci/devices/*; do
  c=$(cat "$d/class" 2>/dev/null)
  case "$c" in 0x03*) echo "  grafik: $(basename "$d") class=$c vendor=$(cat "$d/vendor") device=$(cat "$d/device")";; esac
done
echo "vmwgfx_modul: $(lsmod 2>/dev/null | awk '$1=="vmwgfx"{print "geladen"}' )"
echo "framebuffer: $(ls /sys/class/graphics/ 2>/dev/null | tr '\n' ' ')"
echo "fb0_aufloesung: $(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)"

MARK "4b STORAGE"
HAT lsblk && lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>&1 | sed 's/^/  /'
echo "block_devices: $(ls /sys/block 2>/dev/null | tr '\n' ' ')"
echo "sata_controller:"; grep -l '0x0106' /sys/bus/pci/devices/*/class 2>/dev/null | sed 's#/sys/bus/pci/devices/##; s#/class##; s/^/  /'
echo "ahci_modul: $(lsmod 2>/dev/null | awk '$1~/^ahci|^libahci/{print $1}')"

MARK "4c NETZWERK-HARDWARE"
echo "net_devices: $(ls /sys/class/net 2>/dev/null | tr '\n' ' ')"
for n in /sys/class/net/*; do
  i=$(basename "$n")
  echo "  $i: mac=$(cat "$n/address" 2>/dev/null) state=$(cat "$n/operstate" 2>/dev/null) mtu=$(cat "$n/mtu" 2>/dev/null)"
done
echo "net_treiber: $(for n in /sys/class/net/*; do basename "$(readlink -f "$n/device/driver" 2>/dev/null)"; done | tr '\n' ' ')"

MARK "4d USB"
for d in /sys/bus/usb/devices/*; do
  [ -f "$d/idVendor" ] || continue
  echo "  $(basename "$d") id=$(cat "$d/idVendor"):$(cat "$d/idProduct") produkt=$(cat "$d/product" 2>/dev/null)"
done
echo "usb_controller: $(grep -l '0x0c03' /sys/bus/pci/devices/*/class 2>/dev/null | wc -l)"

MARK "4e EINGABEGERAETE"
for i in /sys/class/input/*; do
  echo "  $(basename "$i") name=$(cat "$i/device/name" 2>/dev/null)"
done
echo "input_anzahl: $(ls -d /sys/class/input/* 2>/dev/null | wc -l)"

MARK "5 NETZWERK-KONFIGURATION"
echo "nmcli_version: $(nmcli --version 2>&1)"
echo "NetworkManager_active: $(systemctl is-active NetworkManager 2>&1)"
HAT nmcli && nmcli -t device status 2>&1 | sed 's/^/  device: /'
HAT nmcli && nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>&1 | sed 's/^/  detail: /'
echo "ip_addr:"; ip -o addr show 2>&1 | sed 's/^/  /'
echo "ip_route:"; ip route 2>&1 | sed 's/^/  /'
echo "dns: $(cat /etc/resolv.conf 2>/dev/null | grep -v '^#' | tr '\n' ' ')"
echo "link_state: $(cat /sys/class/net/*/carrier 2>/dev/null | tr '\n' ' ')"

MARK "6 MODULE UND FIRMWARE"
echo "geladene_module: $(lsmod 2>/dev/null | tail -n +2 | wc -l)"
lsmod 2>/dev/null | tail -n +2 | awk '{print "  "$1}' | head -40
MARK "6a FIRMWARE-FEHLER IM DMESG"
dmesg 2>/dev/null | grep -iE 'firmware.*(fail|error|not found)|direct firmware load' | head -20 | sed 's/^/  /'
echo "firmware_fehler_anzahl: $(dmesg 2>/dev/null | grep -icE 'firmware.*(fail|error|not found)')"

MARK "7 KERNELFEHLER"
echo "dmesg_err_anzahl: $(dmesg --level=err 2>/dev/null | wc -l)"
dmesg --level=err 2>/dev/null | head -25 | sed 's/^/  /'
echo "dmesg_warn_anzahl: $(dmesg --level=warn 2>/dev/null | wc -l)"
dmesg --level=warn 2>/dev/null | head -15 | sed 's/^/  /'

MARK "8 JOURNAL (letzte Zeilen)"
journalctl -b --no-pager 2>/dev/null | tail -80 | sed 's/^/  /'

MARK "9 ABSCHLUSS"
echo "systemctl_is_system_running_final: $(systemctl is-system-running 2>&1)"
echo "failed_units_final: $(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)"
echo "uptime_ende: $(cut -d' ' -f1 /proc/uptime) s"
echo "NOVA_BOOTCHECK_FERTIG $(date -Is)"
sync
sleep 2
systemctl poweroff 2>&1 || poweroff -f

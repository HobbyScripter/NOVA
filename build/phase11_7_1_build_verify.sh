#!/bin/bash
# Phase 11.7.1 - Verifikation des neu gebauten Kernels
set -u
D=/home/ramon/nova-os/build/kernel-build/phase11_7_1
S=$D/linux-6.18.62
OUT=/home/ramon/nova-os/build/output
LOG=$D/verify-packetfix.out

exec > "$LOG" 2>&1
echo "=== Phase 11.7.1 Kernel-Verifikation $(date -Is) ==="
FAIL=0
ok() { echo "  [OK]   $*"; }
bad() { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }

echo
echo "--- 1. Build-Exit-Code ---"
rc=$(grep -oE 'MAKE_RC=[0-9]+' "$D/kbuild-6.18.62-packetfix.log" | tail -1 | cut -d= -f2)
echo "  MAKE_RC=${rc:-unbekannt}"
[ "${rc:-1}" = "0" ] && ok "Build mit Exit-Code 0 beendet" || bad "Build-Exit-Code ${rc:-unbekannt}"

echo
echo "--- 2. bzImage ---"
BI=$S/arch/x86/boot/bzImage
if [ -f "$BI" ]; then
  ok "bzImage vorhanden: $(stat -c%s "$BI") B"
  echo "     file: $(file -b "$BI")"
  echo "     sha256: $(sha256sum "$BI" | cut -d' ' -f1)"
  file -b "$BI" | grep -q 'Linux kernel' && ok "als Linux-Kernel erkannt" || bad "nicht als Linux-Kernel erkannt"
else
  bad "bzImage fehlt"
fi

echo
echo "--- 3. extract-vmlinux (ELF64) ---"
if [ -x "$S/scripts/extract-vmlinux" ]; then
  "$S/scripts/extract-vmlinux" "$BI" > "$D/vmlinux-extrahiert" 2>"$D/extract-vmlinux.err"
  echo "  rc=$? groesse=$(stat -c%s "$D/vmlinux-extrahiert" 2>/dev/null)"
  if [ -s "$D/vmlinux-extrahiert" ]; then
    hdr=$(readelf -h "$D/vmlinux-extrahiert" 2>/dev/null)
    echo "  $(echo "$hdr" | grep -E 'Class:|Machine:|Type:' | tr '\n' ' ')"
    echo "$hdr" | grep -q 'ELF64' && ok "extrahiertes vmlinux ist ELF64" || bad "kein ELF64"
    echo "  vmlinux_sha256=$(sha256sum "$D/vmlinux-extrahiert" | cut -d' ' -f1)"
  else
    bad "extract-vmlinux lieferte kein Ergebnis"
  fi
else
  bad "scripts/extract-vmlinux fehlt"
fi

echo
echo "--- 4. eingebettete Konfiguration (extract-ikconfig) ---"
"$S/scripts/extract-ikconfig" "$BI" > "$D/ikconfig-extracted-11.7.1.txt" 2>"$D/ikconfig.err"
echo "  rc=$? zeilen=$(wc -l < "$D/ikconfig-extracted-11.7.1.txt")"
echo "  sha256=$(sha256sum "$D/ikconfig-extracted-11.7.1.txt" | cut -d' ' -f1)"
echo "  vergleich_mit_build_config: $(cmp -s "$D/ikconfig-extracted-11.7.1.txt" "$S/.config" && echo IDENTISCH || echo ABWEICHEND)"
cmp -s "$D/ikconfig-extracted-11.7.1.txt" "$S/.config" && ok "eingebettete Config == Build-Config" || bad "eingebettete Config weicht ab"

echo
echo "--- 5. CONFIG_PACKET in der eingebetteten Konfiguration ---"
line=$(grep -E '^CONFIG_PACKET=' "$D/ikconfig-extracted-11.7.1.txt")
echo "  ${line:-KEINE_ZEILE}"
[ "$line" = "CONFIG_PACKET=y" ] && ok "CONFIG_PACKET=y nachgewiesen" || bad "CONFIG_PACKET nicht als y nachgewiesen"
echo "  Kontext:"; grep -nE 'PACKET' "$D/ikconfig-extracted-11.7.1.txt" | head -5 | sed 's/^/    /'

echo
echo "--- 6. Kernelversion und Vermagic ---"
krel=$(make -s -C "$S" kernelrelease 2>/dev/null)
echo "  kernelrelease=$krel"
vm_new=$(modinfo -F vermagic "$S/drivers/net/ethernet/intel/e1000e/e1000e.ko" 2>/dev/null)
echo "  vermagic_neues_modul=${vm_new:-unbekannt}"
[ -n "$vm_new" ] && ok "Modul-Vermagic lesbar" || bad "kein Modul gefunden"
echo "  vermagic_alter_kernel: $(modinfo -F vermagic /home/ramon/nova-os/build/output/sysroot-drivers/lib/modules/6.18.62-nova/kernel/drivers/net/ethernet/intel/e1000e/e1000e.ko 2>/dev/null)"

echo
echo "--- 7. Module und VMware-Treiber ---"
n=$(find "$S" -name '*.ko' -newer "$S/.config" 2>/dev/null | wc -l)
echo "  gebaute Module (neuer als .config): $n"
for m in e1000e vmxnet3 vmw_vmci vmw_balloon vmw_vsock_vmci_transport vsock; do
  f=$(find "$S" -name "$m.ko" -print -quit 2>/dev/null)
  [ -n "$f" ] && ok "Modul $m gebaut ($(echo "$f" | sed "s#^$S/##"))" || echo "  [INFO] Modul $m nicht als .ko im Baum (evtl. Built-in)"
done
for o in VMWARE_VMCI_VSOCKETS VSOCKETS; do
  printf '  %-26s %s\n' "CONFIG_$o" "$(grep -E "^CONFIG_${o}(=| is not set)" "$S/.config" || echo NICHT_VORHANDEN)"
done
[ -f "$S/drivers/net/ethernet/intel/e1000/built-in.a" ] && ok "e1000 als Built-in kompiliert" || echo "  [INFO] e1000 built-in.a nicht gefunden"

echo
echo "--- 8. Netzoptionen im neuen Kernel ---"
for o in PACKET NET INET UNIX NETDEVICES ETHERNET E1000 E1000E MODVERSIONS; do
  printf '  %-22s %s\n' "CONFIG_$o" "$(grep -E "^CONFIG_${o}(=| is not set)" "$D/ikconfig-extracted-11.7.1.txt" || echo NICHT_VORHANDEN)"
done

echo
if [ "$FAIL" -eq 0 ]; then echo "KERNEL_VERIFIKATION_OK"; else echo "KERNEL_VERIFIKATION_FEHLER=$FAIL"; fi

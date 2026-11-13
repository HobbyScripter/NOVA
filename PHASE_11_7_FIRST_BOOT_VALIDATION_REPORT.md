# Phase 11.7 — First Boot & Runtime Validation

**Datum:** 2026-11-13
**Kernel:** `6.18.62-nova` (#2 SMP PREEMPT_DYNAMIC, x86_64)
**Ergebnis:** NOVA OS bootet in VMware Workstation Pro aus dem eigenen Kernel, über das erzeugte Initramfs, in einen laufenden systemd-Userspace mit eingebundenem Test-RootFS. **Netzwerkkonfiguration funktioniert nicht** — Ursache im Kernel (`CONFIG_PACKET` fehlt), außerhalb des Auftrags dieser Phase.

**Status je Erfolgskriterium:** 7 von 7 Boot-Kriterien erfüllt, Netzwerk als Befund dokumentiert (kein Erfolgskriterium laut Auftrag).

---

## 1. VMware-Testumgebung

**Vorbereitet und ausgeführt:** Drei separate Test-VMs auf dem Windows-Host (VMware Workstation Pro), unabhängig von der bestehenden Ubuntu-VM.

| Merkmal | Wert |
|---|---|
| Host | Windows, VMware Workstation Pro (`D:\Program Files\VMware\VMware Workstation`) |
| Firmware | BIOS (kein UEFI), passend zur bisherigen VM |
| vCPU / RAM | 2 vCPU / 5120 MB |
| Datenträger | 1 SATA-Platte, eigener VMDK pro Versuch (monolithicFlat, e1000 als NIC) |
| Netzwerk | `e1000`, NAT (`ethernet0.connectionType = "nat"`) |
| Serielle Konsole | COM1 auf Datei (`serial0.fileType = "file"`), 115200 Baud |
| USB | xHCI + EHCI aktiv, keine Floppy, kein Sound |
| VMX-Dateien | `build/vm-boottest-11.7/nova-boottest.vmx`, `…-v2/nova-boottest2.vmx`, `…-v3/nova-boottest3.vmx` |

**Die bestehende Ubuntu-VM wurde nicht verändert:** kein VMX-Edit, keine zusätzliche Hardware, keine Paketinstallation. Sie lief während aller Versuche weiter (`Gastkernel 7.0.0-42-generic`, unverändert). Am Ende aller Versuche waren alle Test-VMs ausgeschaltet; laufend war nur die originale Ubuntu-VM.

**Warum ein eigener Testdatenträger statt direkter Kernelstart:** VMware Workstation bietet keinen verlässlichen Direktstart von Kernel+Initramfs ohne Bootloader. Der Auftrag erlaubt dafür ausdrücklich einen eigenen GRUB-Testdatenträger — genau das wurde gebaut.

## 2. Verwendete Artefakte und Prüfsummen

**Vor dem Boot verifiziert (ausgeführt):**

| Artefakt | Wert |
|---|---|
| Kernel `build/output/rootfs-6.18.62-nova/boot/vmlinuz-6.18.62-nova` | 9.946.112 B, SHA-256 `7f1f7d8d4077d191a3b3c5bbabbe85b4ee2328005a26af4cb172f2847c10b5ab` ✔ (erwartet `7f1f7d8d…c10b5ab`) |
| Initramfs `build/output/initramfs-6.18.62-nova.img` | 35.828.908 B, SHA-256 `cad8910f89334496eb96950142ad5d2a7175edec4914a7d37b22f4e0f42b158d` ✔ (erwartet `cad8910f…f42b158d`) |
| RootFS-Klassifizierung | `class=technical-test-rootfs`, `independent=nova-package-base-missing` — erhalten, zusätzlich `corrections=k1-networkmanager-managed-ethernet` |
| Platzhalter | keine; `/etc/fstab` im Testdatenträger mit echter UUID der jeweiligen Platte |

Die Initramfs-Datei wurde unverändert in jeden Testdatenträger kopiert (Größe im Image: 35.828.908 B, Kernel: 9.946.112 B).

**Testdatenträger (eigene Rohimages im Gast, als VMDK auf dem Host):**

| Versuch | Größe | Dateisystem | UUID | SHA-256 Rohimage |
|---|---|---|---|---|
| 1 | 1,5 GiB | ext4, Label `NOVA-TEST` | `7fda0f94-33b8-4705-b62f-192d9e7b20aa` | `bb1791cc54fea7d962e0047086fc5fb15c7336be311871c405437c67e6ca22ff` |
| 2 | 1,0 GiB | ext4, Label `NOVA-TEST-V2` | `dea266c9-b631-4253-a962-7656f970eff7` | `d8e5bfd1f781a5741798a687c1a882829f005ca1e05434ad2828e82ba30aebc6` |
| 3 | 1,0 GiB | ext4, Label `NOVA-TEST-V3` | `f83e6d81-e2a1-4b5e-b52b-dc5ef64bd2ed` | `43b69890e3767a6326dd5d1f32f8e025a2329f81b715d1cbf2c8f0157af44867` |

Nach jedem Transfer wurde die Hostkopie gegen den Gast gehasht: **alle drei identisch**. Kein Platzhalter, keine erfundene UUID — die `root=UUID=`-Werte stammen aus `blkid` der real erzeugten Dateisysteme.

## 3. Aufbau des Testdatenträgers (nachvollziehbar)

Ablauf je Versuch (`build/phase11_7_diskbuild*.sh`, Logs `build/phase11_7-logs/phase11_7-diskbuild*.out`):

1. `truncate` Rohimage, `sfdisk` MBR mit einer Linux-Partition ab Sektor 2048, Bootflag.
2. `losetup --partscan`, `mke2fs -t ext4 -L … -d build/output/rootfs-6.18.62-nova` — der RootFS-Inhalt wird mit erhaltenen Rechten (uid/gid) direkt in das Dateisystem geschrieben; das RootFS-Artefakt wird nur gelesen.
3. Mount, Initramfs nach `/boot/` kopieren, `/etc/fstab` mit **echter** UUID schreiben.
4. Boot-Check-Harness (`/usr/local/sbin/nova-bootcheck.sh`) und `nova-bootcheck.service` (oneshot, `WantedBy=multi-user.target`) installieren.
5. `grub-install --target=i386-pc --modules="part_msdos ext2 …"` auf das Loop-Gerät, `grub.cfg` mit Kernel, `root=UUID=…` und Initramfs.
6. Unmount, Hash, Transfer auf den Host, VMDK-Deskriptor (`monolithicFlat`), VM-Start mit `vmrun … start … nogui`.

Messwerte: ext4-Erzeugung inkl. 12.557 Dateien 74 s (1,5 GiB) bzw. 20–23 s (1,0 GiB); GRUB-Installation jeweils fehlerfrei (`grub_install_rc=0`). Versuch-3-Platte zu 91 % belegt (834 MiB von 989 MiB).

## 4. Bootparameter

Verwendet (Versuch 1/2/3, `grub.cfg`):

```
linux /boot/vmlinuz-6.18.62-nova root=UUID=<echte UUID> ro \
      console=tty0 console=ttyS0,115200 loglevel=7 \
      systemd.log_level=debug|info systemd.show_status=true
      [Versuch 1 zusätzlich: systemd.log_target=journal+console]
initrd /boot/initramfs-6.18.62-nova.img
```

`systemd.log_target=journal+console` aus Versuch 1 war ungültig (`Failed to parse log target`) und wurde ab Versuch 2 entfernt — eine Korrektur am Testaufbau, nicht am System.

Ein zweiter GRUB-Eintrag (`systemd.unit=rescue.target`) existierte in Versuch 1 als Rückfallebene und wurde nicht benötigt.

## 5. Versuch 1 — erster Boot (ausgeführt, verifiziert)

**Zeit:** 2026-11-13 20:25–20:27 UTC · **Datenträger:** 1,5 GiB · **Ergebnis: erfolgreich**

- Kernel startet: `Linux version 6.18.62-nova (ramon@ramon-VMware-Virtual-Platform) … #2 SMP PREEMPT_DYNAMIC`.
- Initramfs wird ausgeführt: `Run /init as init process`, systemd `255.4-1ubuntu8.18` **„Running in initrd"**, `initrd-switch-root` → Root-Wechsel.
- RootFS eingebunden: `/dev/sda1 / ext4 rw,noatime`, UUID `7fda0f94…`.
- `pid1_comm: systemd`, `--switched-root --system`.
- Userspace: `bash 5.2.21`, `id 0/root`, `touch` auf `/var/log` erfolgreich.
- Targets: `basic.target`, `network.target`, `getty.target` erreicht; `getty@tty1` und `serial-getty@ttyS0` aktiv.
- Hardware erkannt (siehe Abschnitt 8).
- `failed_count: 0`.
- Harness startete bei Uptime 71,02 s, endete mit `NOVA_BOOTCHECK_FERTIG`, danach **geordnetes Herunterfahren** (`Reached target poweroff.target`, `reboot: Power down`).
- Offener Punkt: `systemctl is-system-running` = `starting`; NetworkManager meldete `enp2s1: unmanaged`.

Log: `build/phase11_7-logs/serial-versuch1.txt` (111.981 B, 1.687 Zeilen), Auszug `harness-versuch1.txt`.

## 6. Versuch 2 — Diagnose (ausgeführt, verifiziert)

**Zeit:** 2026-11-13 20:36–20:41 UTC · **Datenträger:** 1,0 GiB, Harness v2 · **Ergebnis: Boot erfolgreich, Netzwerkdefekt lokalisiert**

Der Harness wartete bis zu 240 s auf `systemctl is-system-running` — der Zustand blieb durchgehend `starting`. Alle Targets (`basic`, `getty`, `network`, `timers`, …) waren erreicht, `failed_count: 0`.

**Netzwerkdiagnose (neu):** NetworkManager lief (`active`), meldete `enp2s1:ethernet:unmanaged`. Ursache eindeutig aus der Konfiguration:

```
/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
[keyfile]
unmanaged-devices=*,except:type:wifi,except:type:gsm,except:type:cdma
```

Diese Datei stammt aus Ubuntus Netplan-Integration und setzt **alle** Geräte außer WLAN/GSM/CDMA auf `unmanaged`. In einem `debootstrap`-System ohne Netplan übernimmt niemand Ethernet. Ein manuelles `nmcli device set enp2s1 managed yes` half nicht, weil die Regel aus `conf.d` jede Verwaltung überschreibt — der Versuch endete mit `Error: Connection activation failed: No suitable device found`.

Damit war ein **echter Konfigurationsfehler des Test-RootFS** belegt, den nur ein Boot-Test zeigen konnte. Er wurde als Korrektur K1 behoben (Abschnitt 7).

Log: `serial-versuch2.txt` (102.828 B), `harness-versuch2.txt`.

## 7. Korrektur K1 und Versuch 3 (ausgeführt, verifiziert)

**Korrektur K1** (`build/phase11_7_fix_k1.sh`, Log `phase11_7-fix-k1.out`): neue Datei
`/etc/NetworkManager/conf.d/99-nova-managed-ethernet.conf` mit
`unmanaged-devices=except:type:ethernet,except:type:wifi` (überschreibt die `*`-Regel für Ethernet/WLAN) und Ergänzung von `corrections=k1-networkmanager-managed-ethernet` in `/etc/nova/rootfs-class`.

Damit ist das RootFS-Artefakt **geändert** worden — bewusst und nachvollziehbar: eine Konfigurationsdatei, kein Binärartefakt. Stand danach: 12.557 Dateien, 787.029.726 B; Kernel und Initramfs unverändert (Prüfsummen in Abschnitt 2 gelten weiter).

**Versuch 3:** 2026-11-13 20:50–20:53 UTC, 1,0 GiB, Harness v3.

- K1 wirkt: `enp2s1:ethernet:connecting (getting IP configuration)` mit Profil `Wired connection 1` — das Gerät ist jetzt verwaltet.
- DHCP scheitert dennoch: `dhcp4 (enp2s1): error -97 dispatching events` (EAFNOSUPPORT), keine IP, keine Route, kein Gateway, `ping` und HTTP-Test ohne Verbindung.
- **Ursache im Kernel nachgewiesen:** `CONFIG_PACKET` ist **nicht gesetzt** (siehe `phase11_7-kernel-netzoptionen.txt`). Ohne `AF_PACKET` kann kein DHCP-Client (NetworkManager-intern, dhclient, udhcpc) Pakete senden; der Fehler -97 ist genau EAFNOSUPPORT. `CONFIG_UNIX`, `CONFIG_INET`, `CONFIG_NETFILTER`, `CONFIG_IPV6` sind vorhanden; `CONFIG_BRIDGE` und `CONFIG_TUN` fehlen ebenfalls.
- **Offene Jobs (neu erfasst):** `graphical.target` und `multi-user.target` warten auf `sys-subsystem-net-devices-eth0.device` (Zustand `activating tentative`) und `systemd-update-utmp-runlevel.service`. Deshalb bleibt `is-system-running` = `starting`, obwohl alle regulären Targets erreicht sind und **0 Units fehlgeschlagen** sind. Der Effekt hängt am selben Netzwerkthema.
- Boot-Dauer: Harness-Start bei Uptime 44,47 s (davon 10 s `ExecStartPre`), `network.target` und `getty.target` davor erreicht — der Userspace ist also rund 34 s nach Kernelstart bereit.
- Wieder geordnetes Herunterfahren, danach VM aus.

Log: `serial-versuch3.txt` (96.361 B), `harness-versuch3.txt`.

## 8. Hardwareerkennung (verifiziert, Versuch 3)

| Komponente | Befund |
|---|---|
| PCI gesamt | 44 Geräte, davon 38 mit VMware-Vendor `0x15ad` |
| Grafik | `0000:00:0f.0` class `0x030000`, vendor `0x15ad` device `0x0405`, Treiber **vmwgfx**; Framebuffer `fb0`/`fbcon`, Auflösung 1280×800 |
| Storage-Controller | `0000:02:02.0` class `0x010601` (SATA/AHCI), Treiber **ahci**; zusätzlich `0000:00:07.1` `ata_piix` |
| Datenträger | `sda` 1,0 GiB, `sda1` ext4, eingebunden auf `/` |
| Netzwerkkarte | `0000:02:01.0` vendor `0x8086` device `0x100f`, Treiber **e1000**, MAC `00:0c:29:0e:f3:fa` |
| USB | `0000:02:00.0` (EHCI) und `0000:03:00.0` class `0x0c0330` (**xhci_hcd**); Geräte: VMware Virtual USB Mouse, 2× xHCI Host Controller |
| Eingabegeräte | `Power Button`, `AT Translated Set 2 keyboard`, `ImPS/2 Generic Wheel Mouse`, `VMware VMware Virtual USB Mouse` (8 Input-Nodes) |
| VMCI | `0000:00:07.7` vendor `0x15ad`, Treiber **vmw_vmci** |
| Geladene Module | `vmw_balloon`, `vmw_vmci`, `input_leds`, `led_class` (alles Übrige ist fest eingebaut) |

Damit ist die VMware-Grundhardware vollständig erkannt: Grafik, Netzwerk, Storage-Controller, USB, Eingabe.

## 9. Kernelstatus und Fehlerbild

**Kernel (verifiziert):** `6.18.62-nova`, `#2 SMP PREEMPT_DYNAMIC`, gebaut `Sun Nov 8 21:58:32 CET 2026`, x86_64; 2 vCPU vom Typ `AMD Ryzen 7 5800X 8-Core Processor` (Host-CPU durchgereicht), 4.938 MB RAM nutzbar, kein Swap; DMI `VMware Virtual Platform`, Hypervisor VMware erkannt (`vmcall`-Modus, TSC 3800,035 MHz).

**Kritische Fehler:** keine. `failed_count: 0` in allen drei Versuchen, kein Kernel-Panic, kein Absturz, kein Notfall-Remount.

**Befunde und ihre Einordnung:**

| # | Befund | Bewertung |
|---|---|---|
| F1 | `CONFIG_PACKET` fehlt → kein DHCP möglich (`error -97`) | echte Lücke im Kernel, außerhalb dieser Phase (Kernel-Baseline darf nicht geändert werden) |
| F2 | NetworkManager verwaltete Ethernet nicht | **behoben durch K1** |
| F3 | `is-system-running` bleibt `starting` (eth0-Device-Units „tentative") | Folge von F1, keine Fehlfunktion |
| F4 | `Failed to find module 'autofs4'` | systemd möchte das Modul, es ist nicht gebaut; Autofs wird nicht benötigt |
| F5 | `regulatory.db` fehlt | `wireless-regdb` nicht installiert, ohne WLAN-Treiber folgenlos |
| F6 | udev: `renderD128/card0/rfkill: Failed to apply ACL` | ohne systemd-logind-ACL-Unterstützung im Test-RootFS, folgenlos für den Boot |
| F7 | `[Firmware Bug]: … APIC520 … vector already in use` | Meldung der VMware-BIOS-Emulation, keine Fehlfunktion |
| F8 | ungültiger Kernelparameter `systemd.log_target=journal+console` (Versuch 1) | Fehler im Testaufbau, ab Versuch 2 entfernt |
| F9 | Harness-Fehler in Versuch 1 (`kernel_boot_time` Arithmetik) | kosmetisch, in v2/v3 behoben |

## 10. Ergebnis je Testversuch

| Versuch | Ziel | Ergebnis | Boot | systemd | RootFS | Hardware | Netzwerk |
|---|---|---|---|---|---|---|---|
| 1 | erster Boot | erfolgreich | ja | PID 1, 0 failed, `starting` | ext4 `/dev/sda1` | vollständig | unmanaged |
| 2 | Boot-Ende + Netzdiagnose | erfolgreich (Diagnose) | ja | PID 1, 0 failed, `starting` | ext4 | vollständig | Ursache gefunden |
| 3 | K1 + Job-Analyse | erfolgreich | ja | PID 1, 0 failed, `starting`, 4 offene Jobs | ext4, UUID `f83e6d81…` | vollständig | verwaltet, DHCP scheitert (F1) |

Alle drei Versuche endeten mit einem **geordneten Shutdown** durch das System selbst (`systemctl poweroff`), nicht durch Abschalten der VM.

## 11. Bewertung gegen die Erfolgskriterien

| Kriterium | Status | Beleg |
|---|---|---|
| Kernel tatsächlich gestartet | **verifiziert** | `uname -a` = `6.18.62-nova` im laufenden System, Kernel-Log ab Zeile 1 |
| Initramfs tatsächlich ausgeführt | **verifiziert** | `Run /init as init process`, systemd „Running in initrd", `initrd-switch-root` |
| systemd als PID 1 | **verifiziert** | `/proc/1/comm` = `systemd`, `/proc/1/cmdline` = `--switched-root --system` |
| RootFS korrekt eingebunden | **verifiziert** | `/proc/mounts`: `/dev/sda1 / ext4 rw,noatime`, UUID-Abgleich, Schreibtest OK |
| Userspace-Kommandos ausführbar | **verifiziert** | Harness lief als Unit, `bash`, `systemctl`, `nmcli`, `ip`, `lsblk`, `blkid`, `date`, `id` |
| keine kritischen Bootfehler | **verifiziert** | 0 failed Units, kein Panic, sauberer Shutdown |
| VMware-Grundhardware erkannt | **verifiziert** | Abschnitt 8 |
| Logs und Prüfsummen gesichert | **verifiziert** | `build/phase11_7-logs/`, Hashes in Abschnitt 2 |
| Netzwerk (kein Muss-Kriterium) | **nicht erreicht** | F1: `CONFIG_PACKET` fehlt |

**Phase 11.7 ist damit inhaltlich erfüllt:** NOVA OS bootet mit Kernel `6.18.62-nova`, dem erstellten Initramfs und dem technischen Test-RootFS bis in einen laufenden systemd-Userspace.

## 12. Grenzen dieser Phase

**Nicht durchgeführt (auftragsgemäß):** keine endgültige ISO, keine Installation auf physischer Hardware, keine Umstellung der Kernel-Baseline, keine unabhängige NOVA-Paketbasis, keine Veröffentlichung, keine Löschung alter Artefakte, keine Änderung der bestehenden Ubuntu-VM.

**Ausdrücklich nicht behauptet:** Es gibt keinen Nachweis, dass NOVA OS auf physischer Hardware bootet, dass Secure Boot funktioniert, dass das System „production ready" ist, oder dass `systemd` den Boot als *abgeschlossen* meldet (`is-system-running` = `starting`, Ursache F3). Die Aussage dieser Phase lautet präzise: **Kernel, Initramfs, RootFS-Mount, PID 1 und Userspace funktionieren; die Netzwerkkonfiguration scheitert an einer fehlenden Kerneloption.**

**Erforderliche Folgeschritte:**
1. `CONFIG_PACKET=y` (und für spätere Phasen `CONFIG_BRIDGE`, `CONFIG_TUN`) im Kernel ergänzen, Kernel neu bauen, Initramfs neu erzeugen, Prüfsummen aktualisieren — dann Netzwerk erneut testen. Das ist eine Kernel-Änderung und gehört in eine eigene Phase, nicht in 11.7.
2. Nach F1-Behebung prüfen, ob die `eth0`-Device-Units verschwinden und `is-system-running` auf `running` wechselt.
3. `autofs4` bauen oder systemd-seitig abwählen; `wireless-regdb` aufnehmen, sobald WLAN-Treiber dazukommen.
4. Test-RootFS weiterhin klar als Test klassifizieren — die Kennzeichnung hat den Boot überstanden (`os-release`, `rootfs-class` inkl. `corrections=k1…`).

**Fazit:** Der erste echte Boot von NOVA OS ist belegt — mit vollständigem Kernelstart, ausgeführtem Initramfs, systemd als PID 1, eingebundenem Test-RootFS, lauffähigem Userspace, erkannter VMware-Hardware und geordnetem Shutdown. Der Boot-Test hat dabei zwei echte Defekte aufgedeckt (NetworkManager-Konfiguration, fehlendes `CONFIG_PACKET`), von denen einer behoben und einer mit Ursache und Maßnahme dokumentiert ist.

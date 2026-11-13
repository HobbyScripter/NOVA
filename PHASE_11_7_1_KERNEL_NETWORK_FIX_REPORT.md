# Phase 11.7.1 — Kernel Network Fix

**Datum:** 2026-11-13
**Kernel:** `6.18.62-nova` #1, neu gebaut mit `CONFIG_PACKET=y`
**Ergebnis:** Der Netzwerkfehler aus Phase 11.7 ist behoben und in drei unabhängigen VMware-Bootläufen nachgewiesen. Zusätzlich zwei weitere echte Defekte gefunden und behoben (DNS-Konfiguration) bzw. als Selbstblockade des Testaufbaus entlarvt (`is-system-running`).

**Kurzstatus:** Kernel gebaut ✅ · `CONFIG_PACKET=y` nachgewiesen ✅ · DHCP in Lauf A **und** B ✅ · IPv4 + Default-Route ✅ · NetworkManager „connected" ✅ · `is-system-running` = **running** ✅ · DNS + HTTP ✅ · 0 fehlgeschlagene Units ✅

---

## 1. Ausgangszustand (VERIFIZIERT)

Aus Phase 11.7 übernommen und vor jeder Änderung geprüft:

| Artefakt | Wert vor der Phase |
|---|---|
| Kernel im RootFS | 9.946.112 B, SHA-256 `7f1f7d8d4077d191a3b3c5bbabbe85b4ee2328005a26af4cb172f2847c10b5ab` |
| Initramfs | 35.828.908 B, SHA-256 `cad8910f89334496eb96950142ad5d2a7175edec4914a7d37b22f4e0f42b158d` |
| K1-Konfiguration | `99-nova-managed-ethernet.conf`, SHA-256 `cbebb9355c758ffb7d0502b3be0e47f7d30a64c00a973df67cd839927530a393` |
| `rootfs-class` | SHA-256 `fc483640227a21cae96dd693c8df04852c3862091d97395190f251c1ed5ef7ed` |
| Phase-11.7-Testplatten | 3 Images (1,5 + 1,0 + 1,0 GiB), unangetastet |
| Quelle | `build/kernel-build/linux-6.18.62.tar.xz` (155.352.516 B) |

Befund aus 11.7: Ethernet erkannt, NetworkManager verwaltete das Gerät nach K1, DHCP scheiterte mit `error -97` (EAFNOSUPPORT).

## 2. Festgestellte Ursache (VERIFIZIERT)

Die 11.5.1-Konfiguration enthielt an Zeile 1003:

```
# CONFIG_PACKET is not set
```

Damit fehlt die Adressfamilie `AF_PACKET`. NetworkManagers interner DHCP-Client öffnet Raw-Sockets über `AF_PACKET`/`SOCK_RAW`; ohne diese Familie liefert der Kernel `EAFNOSUPPORT` (= -97). Genau dieser Fehler stand in Phase 11.7 im Journal: `dhcp4 (enp2s1): error -97 dispatching events`.

Gegenprobe der Abhängigkeiten (alle vorhanden, also war `PACKET` die einzige fehlende Stufe): `CONFIG_NET=y`, `CONFIG_INET=y`, `CONFIG_UNIX=y`, `CONFIG_NETDEVICES=y`, `CONFIG_ETHERNET=y`, `CONFIG_E1000=y` (Built-in), `CONFIG_E1000E=m`, `CONFIG_NETFILTER=y`, `CONFIG_NF_CONNTRACK=y`, `CONFIG_IPV6=y`.

## 3. Geänderte Kernel-Konfiguration (VERIFIZIERT)

**Genau eine Option** wurde geändert:

| Option | vorher | nachher | Begründung |
|---|---|---|---|
| `CONFIG_PACKET` | `# CONFIG_PACKET is not set` | `CONFIG_PACKET=y` | AF_PACKET für DHCP-Raw-Sockets; als Built-in, damit es ohne Modul-Laden ab Boot verfügbar ist |

`CONFIG_BRIDGE` und `CONFIG_TUN` wurden **nicht** aktiviert (für einfaches Ethernet-DHCP nicht erforderlich; sie bleiben für spätere Phasen offen). `make olddefconfig` lief mit `olddefconfig_rc=0` und hat keine weiteren Optionen verändert — die Konfiguration wuchs lediglich um die PACKET-Zeile (5.184 → 5.185 Zeilen).

## 4. Build-Umgebung und Befehle (AUSGEFÜHRT)

Separater Build-Bereich `build/kernel-build/phase11_7_1/`, als Benutzer `ramon`, Quelle frisch aus dem verifizierten Tarball entpackt (kein geerbter Objektbaum):

```
mkdir -p build/kernel-build/phase11_7_1
cd build/kernel-build/phase11_7_1 && tar -xJf ../linux-6.18.62.tar.xz
cp /home/ramon/nova-os/kernel/configs/nova-6.18.62-drivers.config linux-6.18.62/.config
cd linux-6.18.62
./scripts/config --enable PACKET
make olddefconfig
make -j4 bzImage modules
```

Umgebung: 4 CPUs, 5,9 GB RAM, 68 GB frei, `gcc 13.3.0`, `pahole` vorhanden. Build-Log: `build/phase11_7_1-logs/kbuild-6.18.62-packetfix.log` (273.737 B).

## 5. Kernel-Build-Ergebnis (VERIFIZIERT)

| Prüfung | Ergebnis |
|---|---|
| `MAKE_RC` | **0** |
| `error:` im Log | 0 |
| `bzImage` | vorhanden, 9.970.688 B, `Kernel: arch/x86/boot/bzImage is ready (#1)` |
| `file` | `Linux kernel x86 boot executable bzImage, version 6.18.62-nova … #1 SMP PREEMPT_DYNAMIC Fri Nov 13 21:18:30 CET 2026` |
| `extract-vmlinux` | rc=0, 28.870.140 B, ELF64 |
| `extract-ikconfig` | rc=0, 5.185 Zeilen, **byte-identisch** mit der Build-`.config` |
| Kernelversion | `6.18.62-nova` (unverändert) |
| Module | 98 `.ko`, Vermagic `6.18.62-nova SMP preempt` |
| VMware-Treiber | `e1000` (Built-in), `e1000e.ko`, `vmxnet3.ko`, `vmw_vmci.ko`, `vmw_balloon.ko`, `vsock.ko`, `vmw_vsock_vmci_transport.ko` |

Das bzImage ist 24.576 B größer als das 11.5.1-Image (9.946.112 → 9.970.688 B) — plausibel durch den zusätzlichen PACKET-Stack.

## 6. SHA-256 des neuen Kernels (VERIFIZIERT)

| Artefakt | Größe | SHA-256 |
|---|---|---|
| neuer Kernel `bzImage` | 9.970.688 B | `e9be2ec489f45d91d1b6be8cdd54e4f23ea98398644fc52738dd6c858f58c8d9` |
| extrahiertes `vmlinux` | 28.870.140 B | `fb6bea3182c5e85aa9fbc4b43f0e3a65e66058868997cb2edb06099979ce5bf6` |
| eingebettete Konfiguration | 137.254 B (5.185 Zeilen) | `c82ba3f828aa53564c5dcb224eb5c955605b4bef318aeaca1c56caea3dff8b03` |
| Kernel im ausgelieferten RootFS | 9.970.688 B | `e9be2ec489f45d91d1b6be8cdd54e4f23ea98398644fc52738dd6c858f58c8d9` (identisch) |
| alter Kernel (Phase 11.6, unverändert) | 9.946.112 B | `7f1f7d8d4077d191a3b3c5bbabbe85b4ee2328005a26af4cb172f2847c10b5ab` |

## 7. Nachweis der eingebetteten Kernel-Konfiguration (VERIFIZIERT)

`scripts/extract-ikconfig` aus dem gebauten `bzImage` liefert exakt die Build-Konfiguration (`cmp` → IDENTISCH). Die Zeile:

```
1003:CONFIG_PACKET=y
1004:# CONFIG_PACKET_DIAG is not set
```

`CONFIG_PACKET=y` ist damit nicht nur in der Build-Datei, sondern **im ausgelieferten Kernel-Image** nachgewiesen. Vollständige eingebettete Konfiguration: `build/phase11_7_1-logs/ikconfig-extracted-11.7.1.txt`.

## 8. AF_PACKET-Test (VERIFIZIERT — indirekt, aber praktisch)

Ein isolierter `socket(AF_PACKET, SOCK_RAW, …)`-Test wurde **nicht separat** programmiert. Der Nachweis erfolgt über die reale Funktion:

- Derselbe NetworkManager-DHCP-Client, der in Phase 11.7 mit `EAFNOSUPPORT` scheiterte, erhielt in allen drei Läufen dieser Phase vollständige DHCP-Leases (Laufzeit 1799–1800 s).
- Zusätzlich funktionieren `ping` (ICMP) zum Gateway und zu `1.1.1.1`, Auflösung per DNS und ein HTTP-Abruf mit Status 200 (Lauf C).

Damit ist AF_PACKET im praktischen Betrieb belegt; die Abwesenheit der Adressfamilie war zuvor die einzige Fehlerursache und ist es jetzt nicht mehr.

## 9. RootFS-Änderungen (AUSGEFÜHRT, VERIFIZIERT)

Das Phase-11.6-RootFS blieb **unverändert**. Es wurde eine eigene Kopie erstellt:

`build/output/rootfs-6.18.62-nova-11.7.1` (788 MB, 12.557 Dateien, `cp -a`, Rechte erhalten)

Enthalten:
- neuer Kernel `vmlinuz-6.18.62-nova` (`e9be2ec4…`), `System.map`, `config`
- 98 neu gebaute Module (`modules_install` + `depmod`, rc=0), Vermagic `6.18.62-nova SMP preempt`
- **K1** aus Phase 11.7 (`99-nova-managed-ethernet.conf`) — Ethernet wird von NetworkManager verwaltet
- **K2** (neu, nach Lauf A/B): `99-nova-dns.conf` mit `[main] dns=default`; der tote Symlink `/etc/resolv.conf` auf `systemd-resolved` wurde durch eine reguläre Datei ersetzt
- Kennzeichnung erhalten: `class=technical-test-rootfs`, `independent=nova-package-base-missing`, `ID_LIKE=ubuntu`, `TESTROOTFS` in `os-release`; ergänzt um
  `kernel-packet-fix=11.7.1 CONFIG_PACKET=y kernel-sha256=e9be2ec4…` und `dns-fix=k2-networkmanager-dns-default`

Damit ist das System weiterhin ausdrücklich ein technisches Test-RootFS, keine unabhängige NOVA-Paketbasis.

## 10. Initramfs-Status (VERIFIZIERT — unverändert wiederverwendet)

| Prüfung | Ergebnis |
|---|---|
| SHA-256 vor/nach | `cad8910f89334496eb96950142ad5d2a7175edec4914a7d37b22f4e0f42b158d` — **unverändert** |
| Vermagic alt (11.5.1-Module) | `6.18.62-nova SMP preempt` |
| Vermagic neu (11.7.1-Module) | `6.18.62-nova SMP preempt` — **identisch** |
| `CONFIG_MODVERSIONS` | nicht gesetzt → keine Symbol-CRC-Abhängigkeit |
| Wiederverwendung | ja, in allen drei Läufen ohne Anpassung gebootet (`Run /init as init process`, `initrd-switch-target` sauber) |

`CONFIG_PACKET=y` ist Built-in und wird von der Initramfs nicht benötigt; eine Neuerzeugung war daher nicht erforderlich und wurde unterlassen. Die beiden im Image enthaltenen Module (`hid-apple`, `led-class`) bleiben durch das identische Vermagic kompatibel.

## 11. VMware-Testlauf A (AUSGEFÜHRT, VERIFIZIERT)

Testumgebung: neue VM `build/vm-boottest-11.7.1-A/` — BIOS, 2 vCPU, 5120 MB, SATA-Platte (1,0 GiB, ext4, UUID `aacab139-052d-4f97-9f54-efa4aa1f0b01`), e1000/NAT, COM1 → Datei. Platten-SHA-256 `3e5b4b970e9737ba8b7e0cda42947ce8aa81ef9740de12c001a31b5d8392d74a`, Hostkopie identisch.

| Prüfung | Ergebnis |
|---|---|
| Kernel | `Linux nova-test 6.18.62-nova #1 SMP PREEMPT_DYNAMIC Fri Nov 13 21:18:30 CET 2026 x86_64` |
| PID 1 | `systemd` (`--switched-root --system`) |
| RootFS | `/dev/sda1` ext4, UUID `aacab139…` |
| Ethernet | `enp2s1` erkannt, Treiber `e1000` |
| NetworkManager | `active`, Gerät `enp2s1:ethernet:connected:Wired connection 1` |
| DHCP | **erfolgreich** → `192.168.43.133/24`, `valid_lft 1799s` |
| Route | `default via 192.168.43.2 dev enp2s1 proto dhcp metric 100` |
| Gateway-Ping | OK |
| Internet (IP) | `ping 1.1.1.1` erreichbar |
| HTTP per Name | `000` (DNS fehlt — Ursache siehe Abschnitt 13) |
| Fehlgeschlagene Units | 0 |

## 12. VMware-Testlauf B (AUSGEFÜHRT, VERIFIZIERT — reproduzierbar)

Eigene VM `build/vm-boottest-11.7.1-B/`, eigene Platte (UUID `1cc2d1df-c717-4856-b062-d940ba7333f7`, SHA-256 `d545e495d2518d81f433fdee7a1b1ca8b34dc2dc40ef5f85f89988eccb72b133`), identische Konfiguration, **ohne** jede Änderung am RootFS gegenüber Lauf A.

| Prüfung | Ergebnis |
|---|---|
| Kernel | `6.18.62-nova #1` (identischer Build) |
| Ethernet/NM | `enp2s1:ethernet:connected:Wired connection 1` |
| DHCP | **erfolgreich** → `192.168.43.134/24`, `valid_lft 1800s` |
| Route | `default via 192.168.43.2 … proto dhcp` |
| Gateway-Ping | OK |
| Internet (IP) | erreichbar |
| HTTP per Name | `000` (DNS, wie in A) |
| Fehlgeschlagene Units | 0 |

Die DHCP-Ergebnisse sind reproduzierbar; unterschiedliche Adressen (`.133` / `.134`) belegen echte, unabhängige Leases statt einer zwischengespeicherten Konfiguration.

## 13. DHCP-Ergebnisse (VERIFIZIERT)

| Lauf | Gerät | Zustand | Adresse | Lease | Route |
|---|---|---|---|---|---|
| A | `enp2s1` | connected | `192.168.43.133/24` | 1799 s | `default via 192.168.43.2` |
| B | `enp2s1` | connected | `192.168.43.134/24` | 1800 s | `default via 192.168.43.2` |
| C | `enp2s1` | connected | `192.168.43.135/24` | 1800 s | `default via 192.168.43.2` |

Vor der Kernel-Korrektur (Phase 11.7, identische Userspace-Konfiguration): kein Lease, `error -97`. Damit ist die Ursache-Wirkungs-Kette geschlossen.

**Zweiter Defekt, in A/B sichtbar (behoben):** Namensauflösung schlug fehl, weil NetworkManager über `/usr/lib/NetworkManager/conf.d/10-dns-resolved.conf` auf `dns=systemd-resolved` stand, `systemd-resolved` im Test-RootFS aber nicht installiert ist und `/etc/resolv.conf` auf den nicht existierenden Stub `127.0.0.53` zeigte. **Korrektur K2** (`dns=default`) behebt das; in Lauf C nachgewiesen (Abschnitt 15).

## 14. IPv4-Adresse und Standardroute (VERIFIZIERT)

Alle drei Läufe: `ip -o -4 addr show` enthält `2: enp2s1 inet 192.168.4x.13x/24 … scope global dynamic noprefixroute`, `ip route` enthält die Default-Route mit `proto dhcp` und die Link-Route `192.168.43.0/24 … proto kernel`. Keine manuelle Konfiguration, keine statische Adresse — die Adressen kamen ausschließlich per DHCP vom VMware-NAT (`vmnet8`).

## 15. DNS- und Verbindungstest (VERIFIZIERT in Lauf C)

Lauf C (`build/vm-boottest-11.7.1-C/`, Platte UUID `4b7820b3-5bab-46c9-b188-c972d8cf53b7`, SHA-256 `6bba0a83b277d8bf2c11d0dd4f8341bc4413835a7673bcc6f1751626700ccf05`) enthält K2 und nutzt einen **Timer-basierten Harness** (45 s nach Boot), damit der Bootsstatus unbeeinflusst gemessen wird.

| Prüfung | Ergebnis |
|---|---|
| `enp2s1` | `connected:Wired connection 1`, `192.168.43.135/24` |
| `/etc/resolv.conf` | `search localdomain` / `nameserver 192.168.43.2` (von NetworkManager geschrieben) |
| Gateway-Ping | OK |
| Internet per IP | erreichbar |
| **HTTP per Name** | **200** (`curl http://archive.ubuntu.com/ubuntu/`) |
| Fehlgeschlagene Units | 0 |

Damit sind DNS-Auflösung und eine echte externe Verbindung über NAT nachgewiesen.

## 16. systemd-Status (VERIFIZIERT)

| Lauf | `is-system-running` | offene Jobs | fehlgeschlagene Units |
|---|---|---|---|
| A | `starting` | 4 (graphical.target, multi-user.target, systemd-update-utmp-runlevel, Harness selbst) | 0 |
| B | `starting` | 4 (dieselben) | 0 |
| C | **`running`** | 1 (nur der Harness selbst) | 0 |

**Ursachenklärung (Korrektur der Deutung aus Phase 11.7):** In A/B war der Harness mit `WantedBy=multi-user.target` verknüpft und lief als `Type=oneshot` über zwei Minuten. `multi-user.target` kann erst abgeschlossen werden, wenn seine Wants fertig sind — **der Testaufbau blockierte also sich selbst**. Die früher beobachteten `eth0`-Device-Units traten nach dem Kernel-Fix nicht mehr auf. In Lauf C startet der Harness per Timer nach abgeschlossenem Boot, und der Status ist wie erwartet `running`.

Messwerte aus Lauf C (`systemd-analyze`):

```
Startup finished in 29.599s (kernel) + 1.778s (initrd) + 2.762s (userspace) = 34.140s
graphical.target reached after 2.746s in userspace.
```

Zusätzlich geprüft: `systemctl get-default` = `graphical.target`, erreichte Ziele umfassen `basic`, `multi-user`, `graphical`, `network`, `getty`, `timers`, `sockets`, `local-fs`; `systemctl --failed` leer; `NetworkManager` = `active`; `nmcli connection show --active` → `Wired connection 1`. Es wurde **keine** Unit deaktiviert oder maskiert.

## 17. Bekannte Einschränkungen (NICHT VERIFIZIERT / offen)

1. **Kein expliziter `socket(AF_PACKET, SOCK_RAW)`-Einzeltest** — AF_PACKET ist über die Funktion (DHCP, Ping, HTTP) belegt, nicht über ein separates Testprogramm.
2. **`CONFIG_BRIDGE` / `CONFIG_TUN` bleiben deaktiviert** — bewusst, für diesen Test nicht erforderlich; für Container/VPN in späteren Phasen nötig.
3. **`autofs4`-Modul fehlt weiterhin** (`systemd: Failed to find module 'autofs4'`) — folgenlos, Autofs wird nicht genutzt.
4. **`regulatory.db` fehlt** (`wireless-regdb` nicht installiert) — ohne WLAN-Treiber folgenlos.
5. **udev-ACL-Warnungen** für `renderD128`/`card0`/`rfkill` (`Failed to apply ACL`) — kosmetisch.
6. **`[Firmware Bug]: … APIC520 …`** — Meldung der VMware-BIOS-Emulation.
7. **Kein Test auf physischer Hardware, kein Secure Boot, keine Produktions-ISO.**
8. **Test-RootFS bleibt Ubuntu-basiert** — weiterhin ausdrücklich als technisches Test-RootFS gekennzeichnet, keine unabhängige NOVA-Paketbasis.
9. **Nur NAT-Netzwerk getestet** — Bridged/Host-Only und IPv6 nicht geprüft.

## 18. Vollständige Liste der erzeugten Artefakte

**Kernel-Build** (`build/kernel-build/phase11_7_1/`):
`linux-6.18.62/` (Quellbaum mit Objekten), `arch/x86/boot/bzImage` (9.970.688 B, `e9be2ec4…`), `.config` (5.185 Zeilen), `System.map`, `kbuild-6.18.62-packetfix.log` (273.737 B), `olddefconfig.log`, `verify-packetfix.out`, `ikconfig-extracted-11.7.1.txt`, `vmlinux-extrahiert`, `build-done.txt`.

**RootFS** (`build/output/`): `rootfs-6.18.62-nova-11.7.1/` (788 MB, neuer Kernel `e9be2ec4…`, 98 Module, K1 + K2), `phase11_7_1-rootfs.out`, `phase11_7_1-fix-k2.out`.
Unverändert geblieben: `rootfs-6.18.62-nova/`, `initramfs-6.18.62-nova.img` (`cad8910f…`), `sysroot/`, `sysroot-drivers/`.

**Testdatenträger** (`build/output/boottest-11.7.1-{A,B,C}/`): drei Rohimages à 1,0 GiB mit SHA-256 `3e5b4b97…` (A), `d545e495…` (B), `6bba0a83…` (C) sowie `phase11_7_1-diskbuild-{A,B,C}.out`.

**VMs auf dem Host** (`build/vm-boottest-11.7.1-{A,B,C}/`): je `*.vmx`, `*-disk.vmdk` (monolithicFlat) + Flat-Datei (Hostkopie jeweils hashgleich mit dem Gast), `serial0-*.log`, `vmware.log`. Alle drei VMs wurden nach dem Test durch das System selbst heruntergefahren.

**Skripte im Repo:** `build/phase11_7_1_build_verify.sh`, `phase11_7_1_rootfs_copy.sh`, `phase11_7_1_diskbuild.sh`, `phase11_7_1_diskbuild_C.sh`, `phase11_7_1_fix_k2.sh`, `phase11_7_bootcheck_v3.sh` (Harness).

**Logs** (`build/phase11_7_1-logs/`): `kbuild-6.18.62-packetfix.log`, `verify-packetfix.out`, `ikconfig-extracted-11.7.1.txt`, `olddefconfig.log`, `phase11_7_1-rootfs.out`, `phase11_7_1-fix-k2.out`, `phase11_7_1-diskbuild-{A,B,C}.out`, `serial-lauf-{A,B,C}.txt` (je ≈96 KB), `harness-lauf-{A,B,C}.txt`.

**Unverändert / nicht angetastet:** Phase-11.7-Test-VMs und -Images, `build/output/sysroot`, `build/output/sysroot-drivers`, `build/output/rootfs-6.18.62-nova`, `build/output/initramfs-6.18.62-nova.img`, `~/nova_os`, Ubuntu-VM (`7.0.0-42-generic`), Host-Kernel. Keine `chown -R`/`chmod -R`-Aktionen.

---

## Abnahmekriterien (Abschnitt 11 des Auftrags)

| Kriterium | Status |
|---|---|
| neuer Kernel tatsächlich gebaut | **VERIFIZIERT** (MAKE_RC=0, bzImage `e9be2ec4…`) |
| `CONFIG_PACKET=y` nachweisbar | **VERIFIZIERT** (eingebettete Konfiguration, Zeile 1003) |
| AF_PACKET funktioniert | **VERIFIZIERT** (DHCP/Ping/HTTP mit identischem Userspace, vorher EAFNOSUPPORT) |
| VMware-Ethernet erkannt | **VERIFIZIERT** (e1000, `enp2s1`, alle drei Läufe) |
| DHCP in beiden unabhängigen Testläufen | **VERIFIZIERT** (A `.133`, B `.134`, zusätzlich C `.135`) |
| IPv4 + Standardroute vorhanden | **VERIFIZIERT** |
| NetworkManager meldet aktive Verbindung | **VERIFIZIERT** (`connected:Wired connection 1`) |
| keine kritischen Bootfehler | **VERIFIZIERT** (0 failed Units, geordnetes Shutdown, `is-system-running=running` in C) |

**Phase 11.7.1 ist erfolgreich abgeschlossen.**

Der Kernel-Fix war notwendig, aber nicht ausreichend: erst K1 (Gerät verwaltbar) + `CONFIG_PACKET=y` (Raw-Sockets) + K2 (DNS) ergeben eine vollständig funktionierende Netzwerkkette. Alle drei Ursachen sind mit Vorher/Nachher-Beleg dokumentiert, keine wurde geraten.

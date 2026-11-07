# SECURITY.md - NOVA OS Sicherheitsrichtlinien & Architektur

Dieses Dokument beschreibt das umfassende Sicherheitskonzept von **NOVA OS**.
Sicherheit ist in NOVA OS ein fundamentales architektonisches Kernziel ("Security by Design") und nicht nur eine nachgelagerte Konfiguration.

---

## 1. Mandatory Access Control (AppArmor)

NOVA OS erzwingt strikte **AppArmor**-Profile für kritische Systemdienste, Netzwerkdämonen und Desktop-Applikationen:

- **Erzwingungsmodus**: Alle Profile laufen im `enforce`-Modus.
- **Kernprofile**:
  - `usr.sbin.NetworkManager`: Begrenzt Dateizugriff auf `/etc/NetworkManager` und DBus-Schnittstellen.
  - `usr.bin.pipewire`: Beschränkt Audio-Puffer und Geräte-Nodes, blockiert unberechtigten Dateisystemzugriff.
  - `usr.bin.dnf5`: Verhindert Schreibzugriffe außerhalb der Paketdatenbank und des Paket-Caches.
  - `nova-store`: Strikte Isolation heruntergeladener Drittanbieter-Dateien vor der Verifikation.
  - Standard-Desktop-Profil für Webbrowser und Multimedia-Player.

---

## 2. Firewall-Architektur (nftables)

Das Netzwerk ist standardmäßig vollständig geschützt:

- **Standard-Regelwerk (`security/nftables/nova.nft`)**:
  ```nftables
  table inet filter {
      chain input {
          type filter hook input priority filter; policy drop;

          # Etablierte und zugehörige Verbindungen erlauben
          ct state established,related accept

          # Ungültige Pakete sofort verwerfen
          ct state invalid drop

          # Loopback-Schnittstelle vollständig erlauben
          iif "lo" accept

          # ICMP / ICMPv6 für Netzwerkdiagnose und IPv6-Neighbor-Discovery erlauben
          ip protocol icmp accept
          ip6 nexthdr ipv6-icmp accept

          # DHCP Client Antworten zulassen
          udp sport 67 udp dport 68 accept
          udp sport 547 udp dport 546 accept

          # Alles andere wird verworfen und optional protokolliert
          counter drop
      }

      chain forward {
          type filter hook forward priority filter; policy drop;
      }

      chain output {
          type filter hook output priority filter; policy accept;
      }
  }
  ```

---

## 3. Benutzer- und Rechteverwaltung

- **Least-Privilege-Prinzip**: Der Standardbenutzer ist ein reguläres, unprivilegiertes Benutzerkonto in den Gruppen `wheel`, `video`, `audio`, `storage`.
- **Root-Rechte**:
  - Direkter Login als `root` (sowohl am Desktop als auch via SSH) ist standardmäßig **deaktiviert**.
  - Administrative Aufgaben erfordern Authentifizierung über `sudo` oder `polkit`.
  - Polkit-Regeln fordern für systemkritische Aktionen (z. B. Paketinstallation, Festplattenformatierung) eine explizite Passwort-Eingabe.
- **Passwort-Hashing**:
  - Es wird standardmäßig **yescrypt** mit hohen Work-Faktoren (`ENCRYPT_METHOD YESCRYPT` in `/etc/login.defs`) verwendet.

---

## 4. Paket- & Update-Sicherheit

- **Kryptografische Signatur**:
  - Jedes offizielle RPM-Paket wird mit dem offiziellen NOVA OS Release-GPG-Schlüssel signiert (RSA 4096-bit).
  - Repositories (`repomd.xml`) enthalten SHA-256-Prüfsummen aller Metadaten und sind signiert.
  - `dnf5` ist so konfiguriert, dass `gpgcheck=1` und `repo_gpgcheck=1` zwingend vorgeschrieben sind. Pakete ohne valide Signatur werden niemals installiert.
- **Transaktionale Integrität**:
  - Vor jeder Systemaktualisierung erstellt `nova-update` automatisch einen Btrfs-Snapshot (`@snapshots/pre-update-<TIMESTAMP>`).
  - Sollte eine Transaktion abbrechen oder das System nach einem Update nicht mehr starten, wird das System automatisch auf den vorherigen Snapshot zurückgesetzt.

---

## 5. Secure Boot & Boot-Kette

- **UEFI Secure Boot**:
  - Verwendung eines validierten EFI-Bootloaders (Shim / GRUB 2).
  - Kernel und essentielle Bootmodule werden signiert.
  - Schlüsselverwaltung über Machine Owner Key (MOK) für benutzerdefinierte Kernel-Module (DKMS).

---

## 6. Compiler- & Kernel-Härtung

- **Toolchain-Flags**:
  - `-fstack-protector-strong`: Schutz gegen Stack-Buffer-Overflows.
  - `-D_FORTIFY_SOURCE=3`: Erweiterte Laufzeit- und Compile-Time-Pufferüberprüfung.
  - `-fcf-protection=full`: Intel CET / AMD Shadow Stack Unterstützung (Control-Flow Enforcement).
  - `-Wl,-z,relro,-z,now`: Read-Only Relocations und sofortiges dynamisches Binden gegen GOT-Overwrite-Angriffe.
  - `-fPIE -pie`: Vollständige Position Independent Executables für Address Space Layout Randomization (ASLR).
- **Kernel-Härtung (`kernel/configs/nova_defconfig`)**:
  - `CONFIG_SECURITY_APPARMOR=y`
  - `CONFIG_PAGE_TABLE_ISOLATION=y` (Meltdown-Mitigation)
  - `CONFIG_RANDOMIZE_BASE=y` (KASLR)
  - `CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y` & `CONFIG_INIT_ON_FREE_DEFAULT_ON=y`
  - `CONFIG_STRICT_DEVMEM=y` & `CONFIG_IO_STRICT_DEVMEM=y`

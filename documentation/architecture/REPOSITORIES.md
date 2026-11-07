# REPOSITORIES.md - NOVA OS Repository- & Paketierungs-Architektur

Dieses Dokument beschreibt das Repository- und Paketverwaltungssystem von **NOVA OS**.

---

## 1. Die drei Release-Kanäle

NOVA OS betreibt drei getrennte, kryptografisch signierte RPM-Repositories:

```
[Development-Kanal] ──(Automatisierte Integrationstests)──▶ [Testing-Kanal] ──(Stresstests & VM-Validierung)──▶ [Stable-Kanal]
      ^                                                            ^                                                 ^
      │                                                            │                                                 │
Bleeding-Edge Builds                                      Release-Kandidaten                               Produktionsreife Pakete
```

| Kanal | Verzeichnis | Update-Frequenz | Validierungsanforderung |
| :--- | :--- | :--- | :--- |
| **Stable** | `repositories/stable/x86_64/` | Konservativ | Bestandene Tests 01 bis 19, min. 7 Tage Stabilität im Testing-Kanal |
| **Testing** | `repositories/testing/x86_64/` | Wöchentlich | Erfolgreicher Build, keine Abhängigkeitsbrüche, automatisierter VM-Boot |
| **Development** | `repositories/development/x86_64/` | Täglich / CI | Erfolgreicher Compile aller Targets, experimentelle Toolchains |

---

## 2. Metadaten- & Verzeichnisstruktur

Jedes Repository folgt dem standardisierten RPM-Metadatenformat (`repomd.xml`), lesbar durch `libsolv` und `dnf5`:

```
repositories/stable/x86_64/
├── repodata/
│   ├── repomd.xml                 (Master-Index mit SHA-256 Checksummen aller XML-Indizes)
│   ├── repomd.xml.asc             (GPG-Ablösesignatur)
│   ├── <hash>-primary.xml.gz      (Paketnamen, Versionen, Provides, Requires, Dateilisten)
│   ├── <hash>-filelists.xml.gz    (Vollständige Pfad-Indizes aller installierten Dateien)
│   └── <hash>-other.xml.gz        (Changelog- und Lizenz-Metadaten)
├── Packages/
│   ├── systemd-256.7-1.nova.x86_64.rpm
│   ├── glibc-2.40-1.nova.x86_64.rpm
│   └── nova-shell-1.0.0-1.nova.x86_64.rpm
```

---

## 3. Kryptografische Signierung (GPG 4096-bit RSA)

1. **Paketsignatur**:
   Jedes einzelne `.rpm`-Paket wird während des Build-Prozesses im Header signiert (`rpmsign --addsign`).
2. **Repository-Signatur**:
   Die Master-Indexdatei `repomd.xml` wird mit dem offiziellen NOVA OS Master-Key signiert:
   ```bash
   gpg --batch --yes --detach-sign --armor --default-key release@nova-os.org repodata/repomd.xml
   ```
3. **DNF5-Durchsetzung**:
   In der DNF5-Konfiguration (`/etc/dnf/dnf.conf` bzw. `/etc/yum.repos.d/nova.repo`) ist gesetzt:
   ```ini
   gpgcheck=1
   repo_gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-NOVA-OS
   ```
   Pakete mit verletzter Signatur oder nicht auflösbaren Abhängigkeiten werden von DNF5 sofort blockiert.

---

## 4. Flatpak-Integration

Flatpak dient als Ergänzung für Desktop-Software:
- Standardmäßig vorkonfiguriertes Remote: `flathub` (`https://dl.flathub.org/repo/flathub.flatpakrepo`).
- Vollständige Integration in den **NOVA Store** und `xdg-desktop-portal-nova`.
- Strikte Trennung: Systemnahe Komponenten und Desktop-Dienste stammen ausschließlich aus den NOVA RPM-Repositories; Drittanbieter-GUI-Programme können wahlweise via RPM oder isoliertem Flatpak bezogen werden.


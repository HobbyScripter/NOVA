# NOVA Bootstrap Architecture

**Document Date**: 2026-11-08
**Phase**: Phase 11.2 - Independent Build Architecture
**Status**: DESIGN DOCUMENTATION

---

## 1. Executive Summary

Dieses Dokument definiert die **unabhängige Build-Architektur** für NOVA OS. Phase 11 verwendet eine vereinfachte Strategie (Distribution als Basis), aber Phase 12+ soll zur echten Unabhängigkeit übergehen.

**Phase 11 (Aktuell)**: Distribution-basiertes Rootfs
- Ubuntu 24.04 LTS als Build-Host
- debootstrap für Rootfs-Erstellung
- Keine echte Unabhängigkeit

**Phase 12+ (Geplant)**: Zweistufiges Bootstrap
- Eigene Toolchain (GCC, binutils, glibc)
- Eigene Paket-Management (RPM/DNF5)
- Echte Unabhängigkeit

---

## 2. Bootstrap-Strategie

### 2.1 Aktuelle Strategie (Phase 11)

**Ansatz**: Distribution als Basis verwenden

**Vorteile**:
- Schneller zu implementieren
- Bewährte Pakete
- Schneller Proof-of-Concept

**Nachteile**:
- Keine echte Unabhängigkeit
- Abhängig von Distribution-Policy
- Nicht reproduzierbar über Zeit

**Komponenten**:
- Build-Host: Ubuntu 24.04 LTS
- Toolchain: Ubuntu GCC 13.2, glibc 2.39
- Rootfs: Ubuntu-Pakete via debootstrap
- Bootloader: GRUB 2 aus Ubuntu

**Abhängigkeiten**:
- Ubuntu Repositories
- Ubuntu Release-Zyklus
- Ubuntu Security-Policy

### 2.2 Geplante Strategie (Phase 12+)

**Ansatz**: Zweistufiges Bootstrap nach Linux From Scratch (LFS) Prinzip

**Vorteile**:
- Echte Unabhängigkeit
- Reproduzierbar
- Vollständige Kontrolle
- Langfristig nachhaltbar

**Nachteile**:
- Hoher Implementierungsaufwand
- Längere Build-Zeiten
- Komplexeres Wartung

**Komponenten**:
- Build-Host: Beliebige Distribution (Ubuntu 24.04 LTS empfohlen)
- Toolchain: Selbst kompiliert (GCC 13.x, binutils 2.42, glibc 2.38)
- Rootfs: Selbst erstellt aus kompilierten Komponenten
- Bootloader: Selbst kompiliert (GRUB 2)
- Paket-System: RPM v4 mit DNF5

**Abhängigkeiten**:
- Kernel.org (Quellen)
- GNU (Quellen)
- Nur Upstream-Quellen

---

## 3. Zweistufiges Bootstrap Design

### 3.1 Stage 1: Temporäre Toolchain

**Ziel**: Isolierte Toolchain erstellen, die keine Host-Bibliotheken verwendet

**Verzeichnis**: `/tools`

**Reihenfolge**:

1. **Linux Headers**
   - Quelle: kernel.org
   - Extrahieren: `make headers_install INSTALL_HDR_PATH=/tools/include`
   - Keine Kompilation, nur Header

2. **Binutils**
   - Version: 2.42
   - Konfiguration: `--prefix=/tools --with-sysroot=/tools --disable-nls --disable-werror`
   - Kompilieren: `make configure && make && make install`

3. **GCC Core (Cross-Compiler)**
   - Version: 13.2
   - Konfiguration: `--prefix=/tools --with-sysroot=/tools --disable-nls --disable-libstdcxx-pch`
   - Kompilieren: `make all-gcc`
   - Symlink: `ln -s gcc /tools/bin/cc`

4. **glibc**
   - Version: 2.38
   - Konfiguration: `--prefix=/tools --host=x86_64-nova-linux-gnu`
   - Kompilieren: `make`
   - Installation: `make install`

5. **GCC Full**
   - Version: 13.2
   - Konfiguration: Mit C++ Unterstützung
   - Kompilieren: `make all-gcc all-target-libgcc`
   - Installation: `make install`

6. **libstdc++**
   - Kompilieren: `make target-libstdc++-v3`
   - Installation: `make install`

**Ergebnis**: `/tools` enthält vollständig isolierte Toolchain

### 3.2 Stage 2: Target-Root

**Ziel**: Zielsystem in Chroot mit eigener Toolchain bauen

**Verzeichnis**: `/sysroot`

**Reihenfolge**:

1. **Mounten von virtuellen Dateisystemen**
   ```bash
   mount -v --bind /tools /sysroot/tools
   mount -v --bind /dev /sysroot/dev
   mount -v --bind /dev/pts /sysroot/dev/pts
   mount -v -vt proc /sysroot/proc
   mount -v -vt sysfs /sysroot/sys
   ```

2. **Erstellen von Verzeichnisstruktur**
   ```bash
   mkdir -p /sysroot/{bin,boot,dev,etc,home,lib,media,mnt,opt,proc,root,sbin,srv,sys,tmp,usr,var}
   mkdir -p /sysroot/usr/{bin,include,lib,local,sbin,share,src}
   ln -s -s usr/bin /sysroot/bin
   ln -s -s usr/sbin /sysroot/sbin
   ln -s -s usr/lib /sysroot/lib
   ln -s -s usr/lib64 /sysroot/lib64
   ```

3. **Installieren von glibc**
   - Chroot in `/sysroot`
   - Bauen mit eigener Toolchain
   - Installieren nach `/sysroot`

4. **Installieren von Coreutils**
   - Coreutils 9.4
   - Bauen mit eigener Toolchain
   - Installieren nach `/sysroot`

5. **Installieren von Bash**
   - Bash 5.2
   - Bauen mit eigener Toolchain
   - Installieren nach `/sysroot`

6. **Installieren von systemd**
   - systemd 253+
   - Bauen mit eigener Toolchain
   - Installieren nach `/sysroot`

7. **Installieren von GRUB 2**
   - GRUB 2.06+
   - Bauen mit eigener Toolchain
   - Installieren nach `/sysroot`

8. **Installieren von RPM/DNF5**
   - RPM 4.18+
   - DNF5 5.0+
   - libsolv
   - Bauen mit eigener Toolchain
   - Installieren nach `/sysroot`

**Ergebnis**: `/sysroot enthält vollständig unabhängiges System

---

## 4. Paket-Build-System

### 4.1 Paketformat: RPM v4

**Entscheidung**: RPM v4 statt DEB

**Gründe**:
- Erfahreneres Format mit besseren Abhängigkeitsauflösung
- Bessere Unterstützung für delta-updates
- Bessere Signierung-Mechanismen
- Kompatibel mit größeren Enterprise-Distributionen (RHEL, SUSE)
- libsolv bietet sehr gute Abhängigkeitsauflösung

### 4.2 Paket-Manager: DNF5

**Entscheidung**: DNF5 statt dnf (Python-basiert)

**Gründe**:
- C++ Implementierung (schneller als Python)
- Bessere Performance
- libsolv-Integration
- Modularer Aufbau
- Activeentwicklung

### 4.3 Dependency Resolver: libsolv

**Entscheidung**: libsolv statt SAT

**Gründe**:
- Schnellere Abhängigkeitsauflösung
- Bessere Multi-Repository-Unterstützung
- Aktive Entwicklung
- Bessere C-API

---

## 5. Repository-Struktur

### 5.1 Repository-Kanäle

```
repo.nova-os.org/
├── stable/        # Produktion (getestet, stabil)
├── testing/       # Integration (Kernel-Updates, neue Features)
└── development/   # Entwicklung (aktuelle Änderungen)
```

### 5.2 Repository-Metadaten

**Dateien**:
- `repomd.xml` - Repository-Metadaten
- `repomd.xml.asc` - GPG-Signatur
- `primary.xml.gz` - Paket-Metadaten
- `primary.xml.gz.asc` - GPG-Signatur
- `filelists.xml.gz` - Dateilisten
- `filelists.xml.gz.asc` - GPG-Signatur
- `comps.xml` - Gruppen-Metadaten

### 5.3 Paket-Metadaten

**Jedes RPM-Paket enthält**:
- Header: Paket-Informationen
- Payload: Aktuelle Dateien
- Signature: GPG-Signatur des Pakets

---

## 6. Paket-Signierung

### 6.1 GPG-Schlüssel

**NOVA OS GPG-Schlüssel**:
- Schlüssel-ID: NOVA OS Release Key
- Schlüsseltyp: RSA 4096-bit
- Zweck: Signieren von RPM-Paketen und Repository-Metadaten

**Schlüsselverwaltung**:
- Privater Schlüssel: Sicher auf Hardware-Token oder offline
- Öffentlicher Schlüssel: Auf Schlüsselserver veröffentlicht
- Schlüssel-Rotation: Jährlich oder bei Kompromittierung

### 6.2 Signatur-Strategie

**Ebenen der Signierung**:

1. **Quellcode-Signatur**
   - Git-Commits mit GPG signieren
   - Tarball signieren

2. **Paket-Signatur**
   - Jedes RPM-Paket mit GPG signieren
   - `rpm --addsign --key-id=KEYID package.rpm`

3. **Repository-Signatur**
   - `repomd.xml` signieren
   - `repomd.xml.asc` bereitstellen
   - `primary.xml.gz` und `filelists.xml.gz` signieren

### 6.3 Verifikation

**Client-Seite**:
- Import von NOVA OS GPG-Schlüssel
- Automatische Verifizierung bei `dnf install`
- Warnung bei ungültigen Signaturen
- Installation verweigern bei ungültigen Signaturen

---

## 7. Reproduzierbare Builds

### 7.1 Build-Umgebung

**Containerisierung**: Docker oder Podman
- Festes Build-Image mit allen Abhängigkeiten
- Reproduzierbare Toolchain-Versionen
- Isolierte Build-Umgebung

**Build-Image**: `nova-os-build:ubuntu-24.04-latest`

### 7.2 Toolchain-Fixierung

**GCC**: Version 13.2.0 exakt
- Release-Tag: gcc-13.2.0
- Keine Patches außer notwendigen Backports

**Binutils**: Version 2.42
- Release-Tag: binutils-2.42
- Keine Patches außer notwendigen Backports

**glibc**: Version 2.38
- Release-Tag: glibc-2.38
- Keine Patches außer notwendigen Backports

### 7.3 Quellcode-Fixierung

**Kernel**: Kernel.org
- Exakte Version: 6.12.x
- SHA256-Prüfsummen
- Signaturverifizierung

**GNU-Projekte**: GNU.org
- Release-Tags (z.B. coreutils-9.4)
- SHA256-Prüfsummen
- GPG-Signaturverifizierung

---

## 8. Abhängigkeitsverwaltung

### 8.1 Interne Abhängigkeiten

**NOVA-Komponenten**:
- libnova (C++ Library)
- NOVA Compositor (C++)
- NOVA Desktop-Komponenten (C++)

**Abhängigkeitsauflösung**:
- libsolv löst interne Abhängigkeiten auf
- Zyklische Abhängigkeiten werden erkannt
- Versionen werden konfliktfrei gelöst

### 8.2 Externe Abhängigkeiten

**Third-Party-Libraries**:
- Qt 6 (optional für GUI)
- wlroots (für Wayland Compositor)
- PipeWire (für Audio)
- NetworkManager (für Netzwerk)

**Version-Pinning**:
- Qt 6: 6.5.x (pinned in Phase 12)
- wlroots: 0.17.x (pinned in Phase 12)
- PipeWire: 1.0.x (pinned in Phase 12)

---

## 9. Phase 11 vs Phase 12+ Vergleich

| Aspekt | Phase 11 (Aktuell) | Phase 12+ (Geplant) |
|--------|---------------------|-------------------|
| **Toolchain** | Distribution GCC 13.2 | Eigene GCC 13.x |
| **glibc** | Distribution glibc 2.39 | Eigene glibc 2.38 |
| **Rootfs** | Ubuntu-Pakete via debootstrap | Selbst kompiliert |
| **Bootloader** | Distribution GRUB 2 | Selbst kompiliert |
| **Pakete** | Kein Paket-System | RPM v4 |
| **Repository** | Ubuntu Repositories | NOVA Repositories |
| **Signierung** | Distribution-Signaturen | NOVA GPG-Signatur |
| **Unabhängigkeit** | Ubuntu-Derivat | ECHT unabhängig |
| **Reproduzierbarkeit** | Limitiert | Vollständig |
| **Build-Zeit** | ~30 Minuten | ~4-6 Stunden |
| **Komplexität** | Niedrig | Hoch |

---

## 10. Phase 11 als Proof-of-Concept

### 10.1 Akzeptanz von Phase 11

**Phase 11 wird als proof-of-concept akzeptiert**, weil:

1. Bootfähiges System ist vorrangig
2. Echte Unabhängigkeit ist langfristiges Ziel
3. Phase 11 liefert funktionierendes System zum Testen
4. Phase 12+ kann auf Phase 11 aufbauen

### 10.2 Phase 11 Anforderungen

**Phase 11 muss**:
- ✅ Bootfähiges ISO erzeugen
- ✅ In VM booten
- ✅ Grundfunktionalität demonstrieren
- ✅ DOKUMENTIEREN, dass Ubuntu als Basis verwendet wird

**Phase 11 darf NICHT**:
- ❌ Behaupten, es sei unabhängig
- ❌ Ubuntu-Abhängigkeiten verschleiern
- ❌ Langfristig als Endzustand verwendet werden

### 10.3 Phase 12 Pflichten

**Phase 12 muss**:
- ❌ Phase 11-Rootfs durch eigenes Bootstrap ersetzen
- ❌ Paket-System implementieren
- ❌ Repository-Struktur aufbauen
- ❌ GPG-Signatur implementieren
- ❌ Echte Unabhängigkeit erreichen

---

## 11. Migration von Phase 11 zu Phase 12

### 11.1 Migration-Strategie

**Inkompatible Änderung**:
- Rootfs muss neu erstellt werden
- Pakete müssen in RPM konvertiert werden
- Bootloader neu installiert werden

**Kompatible Änderungen**:
- Kernel kann übernommen werden
- Konfigurationsdateien können übernommen werden
- Desktop-Komponenten können übernommen werden

### 11.2 Zeitplan

**Phase 11**:
- Bootfähiges System (30 Min Build)
- VM-Tests (2 Stunden)
- **GESAMT: ~3 Stunden**

**Phase 12 (erste Iteration)**:
- Bootstrap Stage 1 (2 Stunden)
- Bootstrap Stage 2 (4 Stunden)
- RPM-System (2 Stunden)
- Repository-Struktur (1 Stunde)
- **GESAMT: ~9 Stunden**

**Phase 12 (vollständig)**:
- Alle Komponenten in RPM
- Alle Dependencies aufgelöst
- Vollständige Tests
- **GESAMT: ~20-30 Stunden**

---

## 12. Risikoanalyse

### 12.1 Risiken bei Phase 11 Ansatz

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|----------------|------------|-----------|
| Ubuntu Policy-Änderung | Mittel | Hoch | LTS bis 2029 |
| Distribution-Abhängigkeit | Gewiss | Mittel | Phase 12 löst |
| Reproduzierbarkeit | Mittel | Mittel | Containerisierte Builds |
| Security-Patches | Mittel | Hoch | Regelmäßige Updates |

### 12.2 Risiken bei Phase 12 Ansatz

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|----------------|------------|-----------|
| Build-Komplexität | Hoch | Mittel | Gute Dokumentation |
| Build-Zeit | Gewiss | Mittel | Parallele Builds |
| Upstream-Änderungen | Mittel | Mittel | Versions-Pinning |
| Wartungsaufwand | Hoch | Mittel | Automatisierung |

---

## 13. Empfehlung

### 13.1 Für Phase 11

**Empfehlung**: Phase 11 mit dokumentierten Einschränkungen fortsetzen

**Gründe**:
- Schneller Bootfähiges System zum Testen
- VM-Kompatibilität prüfen
- Desktop-Komponenten entwickeln
- Erfahrung sammeln

**Voraussetzung**: Dokumentiert, dass Ubuntu als Basis verwendet wird

### 13.2 Für Phase 12

**Empfehlung**: Nach erfolgreichem Phase 11 mit echtem Bootstrap beginnen

**Gründe**:
- Echte Unabhängigkeit erforderlich
- Paket-System für Updates notwendig
- Langfristige Nachhaltigkeit
- Reproduzierbarkeit

**Zeitpunkt**: Nach Phase 11 Abschluss und VM-Tests

---

## 14. Konklusion

Phase 11 verwendet eine vereinfachte Strategie (Distribution als Basis), um schnell ein bootfähiges System zu erhalten. Dies ist als proof-of-concept akzeptabel, aber **nicht als Endzustand**.

Phase 12+ wird die geplante zweistufige Bootstrap-Strategie implementieren, um echte Unabhängigkeit zu erreichen.

**Klarstellung**: NOVA OS ist in Phase 11 ein Ubuntu-Derivat. Echte Unabhängigkeit wird in Phase 12+ erreicht.

---

**END OF DOCUMENT**

# BOOTSTRAP.md - NOVA OS Zweistufiges Bootstrap-Konzept

Dieses Dokument beschreibt das technische Design des deterministischen, zweistufigen Bootstrap-Verfahrens von **NOVA OS**.
Ziel ist es, ein vollständiges Betriebssystem autonom aus den Upstream-Quelltexten aufzubauen, ohne Abhängigkeit von einer bestehenden Binärdistribution.

---

## 1. Das Drei-Stufen-Modell

```
[Host-Betriebssystem]
        │
        ├──▶ STAGE 0: Host-Verifikation & Arbeitsbereich
        │    • Überprüfung aller Host-Werkzeuge (Compiler, Make, Python)
        │    • Validierung der Quelltext-Archive (SHA-256)
        │    • Initialisierung des isolierten Build-Verzeichnisbaums
        │
        ├──▶ STAGE 1: Hermetische Cross-Toolchain (/build/tools)
        │    • Prefix: x86_64-nova-linux-gnu
        │    • Linux-API-Header aus offiziellem Kernel 6.12
        │    • Binutils 2.43.1 (Assembler, Linker ld.bfd)
        │    • GCC 14.2.0 (Core C-Compiler)
        │    • glibc 2.40 (Cross-kompiliert)
        │    • GCC Full (C & C++ Runtime libstdc++)
        │    • Isolierung: Kein Zugriff auf /usr/lib oder /lib des Hosts
        │
        └──▶ STAGE 2: Target-Chroot Basisbetriebssystem (/build/sysroot)
             • Chroot in das neu kompilierte Target-Sysroot
             • Kompilierung von Coreutils, Bash, Sed, Gawk, Make
             • Kompilierung von systemd (PID 1, udev, journald)
             • Kompilierung von RPM 4.20 und libsolv
             • Kompilierung von DNF5 C++-Engine
             • Installation des Linux-Kernels und Generierung des Initramfs via dracut
             • Umwandlung des Sysroots in native RPM-Pakete
```

---

## 2. Detaillierte Ablaufbeschreibung

### Stage 0: Host-Verifikation
- Skript: `bootstrap/stage0/check_host.py`
- Prüft:
  1. Vorhandensein von GCC/Clang, Make, CMake, Python 3, Binutils, Zstd.
  2. Verfügbarkeit von mindestens 16 GB freiem Festplattenspeicher.
  3. Gültigkeit aller in `dependencies.json` hinterlegten SHA-256 Prüfsummen.

### Stage 1: Hermetische Cross-Toolchain
1. **Linux API Headers**:
   ```bash
   make mrproper
   make headers_install INSTALL_HDR_PATH=$TOOLS_DIR/include
   ```
2. **Binutils (Pass 1)**:
   ```bash
   ../configure --prefix=$TOOLS_DIR \
                --with-sysroot=$SYSROOT_DIR \
                --target=x86_64-nova-linux-gnu \
                --disable-nls \
                --disable-werror \
                --enable-default-hash-style=gnu
   make -j$(nproc) && make install
   ```
3. **GCC Core (Pass 1)**:
   ```bash
   ../configure --target=x86_64-nova-linux-gnu \
                --prefix=$TOOLS_DIR \
                --with-glibc-version=2.40 \
                --with-sysroot=$SYSROOT_DIR \
                --with-newlib \
                --without-headers \
                --disable-nls \
                --disable-shared \
                --disable-multilib \
                --disable-threads \
                --disable-libatomic \
                --disable-libgomp \
                --disable-libquadmath \
                --disable-libssp \
                --disable-libvtv \
                --disable-libstdcxx \
                --enable-languages=c
   make -j$(nproc) all-gcc all-target-libgcc && make install-gcc install-target-libgcc
   ```
4. **glibc 2.40**:
   ```bash
   ../configure --prefix=/usr \
                --host=x86_64-nova-linux-gnu \
                --build=$(../scripts/config.guess) \
                --enable-kernel=6.12.0 \
                --with-headers=$TOOLS_DIR/include \
                libc_cv_slibdir=/usr/lib
   make -j$(nproc) && make install DESTDIR=$SYSROOT_DIR
   ```
5. **GCC Full (Pass 2)**:
   ```bash
   ../configure --target=x86_64-nova-linux-gnu \
                --prefix=$TOOLS_DIR \
                --with-sysroot=$SYSROOT_DIR \
                --enable-languages=c,c++ \
                --disable-nls \
                --disable-multilib \
                --enable-default-pie \
                --enable-default-ssp
   make -j$(nproc) && make install
   ```

### Stage 2: Target-Chroot & DNF5-Bootstrap
- Mit der fertigen Toolchain in `$TOOLS_DIR` wird in das `$SYSROOT_DIR` gewechselt.
- Die Basispakete werden nativ für NOVA OS übersetzt.
- Die finale Target-RPM-Datenbank wird initialisiert (`rpm --initdb --root=$SYSROOT_DIR`).
- DNF5 wird konfiguriert und übernimmt ab diesem Zeitpunkt die Paketverwaltung.

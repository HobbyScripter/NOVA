# Phase 11: Minimal Linux System Design

**Document Date**: 2026-11-08
**Phase**: Phase 11 - Linux Foundation & First Boot
**Status**: DESIGN COMPLETE

---

## 1. Minimal System Definition

### 1.1 Goal

Create a **minimal, bootable Linux system** that can:
- Boot from ISO in VirtualBox/VMware
- Reach a functional systemd target
- Display system information
- Provide a foundation for Wayland compositor

### 1.2 Scope (Phase 11)

**INCLUDED**:
- Linux kernel (6.12.x stable)
- glibc (C library)
- systemd (init system)
- Basic GNU tools (coreutils, bash, etc.)
- GRUB 2 bootloader
- dracut initramfs
- Btrfs filesystem support
- Network support (basic)
- Essential firmware and drivers

**EXCLUDED (Phase 12+)**:
- Complete package management (DNF5/RPM)
- Full desktop environment
- NOVA-specific applications
- Advanced system tools

---

## 2. Minimal System Components

### 2.1 Kernel

**Source**: kernel.org (6.12.x stable)
**Configuration**: Based on existing `kernel/configs/nova_defconfig`
**Required Built-in Features**:
- x86_64 architecture support
- EFI boot support
- Btrfs filesystem (built-in)
- ext4 filesystem (built-in)
- NVMe support (built-in)
- SATA/AHCI support (built-in)
- USB mass storage (built-in)
- Basic network support
- Console framebuffer

**Required Modules**:
- Graphics drivers (vboxvideo, vmwgfx)
- Input drivers (evdev, keyboard, mouse)
- Sound drivers (ALSA, HDA)
- Network drivers (virtio-net, e1000)

**Build Commands**:
```bash
# Download kernel
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.x.tar.xz
tar -xf linux-6.12.x.tar.xz
cd linux-6.12.x

# Copy NOVA config
cp $NOVA_ROOT/kernel/configs/nova_defconfig .config

# Build kernel
make -j$(nproc)
make modules_install INSTALL_MOD_PATH=$NOVA_ROOT/install
make install INSTALL_PATH=$NOVA_ROOT/install/boot
```

### 2.2 C Library (glibc)

**Source**: GNU glibc (2.38+)
**Configuration**: Standard x86_64-linux-gnu
**Build Method**: Cross-compile from stage 1 toolchain or use distribution package

**For Phase 11**: Use distribution glibc from build system (Fedora/Ubuntu)
**Reason**: Building glibc from scratch is complex and time-consuming; use distribution package for initial minimal system

### 2.3 systemd

**Source**: systemd (253+)
**Required Components**:
- systemd (PID 1)
- systemd-udevd (device management)
- systemd-journald (logging)
- systemd-networkd (networking)
- systemd-tmpfiles (temporary files)

**Configuration**: Minimal configuration for boot

**Unit Files Required**:
- `default.target` (multi-user.target)
- `sysinit.target`
- `basic.target`
- `network.target`
- `local-fs.target`

**For Phase 11**: Use distribution systemd, configure minimal services

### 2.4 GNU Core Tools

**Required Packages**:
- coreutils (ls, cp, mv, rm, etc.)
- bash (shell)
- util-linux (fdisk, mount, etc.)
- e2fsprogs (ext4 tools)
- btrfs-progs (Btrfs tools)
- kmod (module management)
- systemd (init system)

**For Phase 11**: Use distribution packages

### 2.5 Bootloader (GRUB 2)

**Version**: GRUB 2.06+
**Configuration**:
- UEFI boot support
- BIOS boot support (legacy)
- Kernel boot parameters
- Initramfs loading

**GRUB Configuration**:
```grub
set timeout=5
set default=0

menuentry "NOVA OS" {
    linux /boot/vmlinuz-nova root=UUID=<uuid> ro quiet
    initrd /boot/initramfs-nova.img
}

menuentry "NOVA OS (Recovery)" {
    linux /boot/vmlinuz-nova root=UUID=<uuid> ro single
    initrd /boot/initramfs-nova.img
}
```

### 2.6 Initramfs (dracut)

**Version**: dracut 059+
**Purpose**: Load kernel modules and mount root filesystem
**Configuration**: Minimal dracut config

**dracut.conf**:
```conf
# Minimal dracut configuration for NOVA OS
hostonly="no"
compress="zstd"
drivers="vboxvideo vmwgfx amdgpu i915 nouveau"
filesystems="btrfs ext4 vfat"
```

**Build Command**:
```bash
dracut --force --kver 6.12.x-nova /boot/initramfs-nova.img
```

---

## 3. Filesystem Layout

### 3.1 Minimal Directory Structure

```
/
├── bin/           # Essential binaries (symlinks to /usr/bin)
├── boot/          # Kernel and initramfs
│   ├── vmlinuz-nova
│   └── initramfs-nova.img
├── dev/           # Device files (created by kernel)
├── etc/           # Configuration files
│   ├── fstab
│   ├── hostname
│   ├── os-release
│   ├── systemd/
│   └── dracut.conf.d/
├── home/          # User directories
├── lib/           # Essential libraries (symlinks to /usr/lib)
├── lib64/         # 64-bit libraries (symlinks to /usr/lib64)
├── proc/          # Kernel information (mounted)
├── root/          # Root user home
├── run/           # Runtime data
├── sbin/          # System binaries (symlinks to /usr/sbin)
├── sys/           # Kernel information (mounted)
├── tmp/           # Temporary files
├── usr/           # User programs and data
│   ├── bin/       # User binaries
│   ├── lib/       # User libraries
│   ├── lib64/     # 64-bit libraries
│   ├── sbin/      # System binaries
│   └── share/     # Shared data
└── var/           # Variable data
    ├── log/       # System logs
    └── tmp/       # Temporary files
```

### 3.2 Btrfs Subvolume Layout (Simplified for Phase 11)

For Phase 11, use a **single Btrfs partition** without subvolumes initially to simplify boot process.

**Phase 11 Layout**:
- Single Btrfs partition mounted at `/`
- No subvolumes (simplifies boot process)

**Phase 12+ Layout** (from architecture):
- `@` → `/`
- `@home` → `/home`
- `@snapshots` → `/.snapshots`
- `@var_log` → `/var/log`
- `@swap` → `/swap`

### 3.3 Partition Layout (UEFI)

```
Partition 1: EFI System Partition (ESP)
- Size: 512 MB
- Type: EFI System
- Mount: /boot/efi
- Format: FAT32

Partition 2: NOVA System Partition
- Size: Remaining space
- Type: Linux filesystem
- Mount: /
- Format: Btrfs
```

### 3.4 /etc/fstab

```fstab
# /etc/fstab for NOVA OS minimal system
UUID=<root-uuid> / btrfs defaults,relatime 0 1
UUID=<esp-uuid>  /boot/efi vfat defaults 0 2
```

---

## 4. Essential Configuration Files

### 4.1 /etc/os-release

```ini
NAME="NOVA OS"
ID=nova
PRETTY_NAME="NOVA OS"
VERSION_ID="0.1"
VERSION="0.1 (Phase 11 - Minimal System)"
ID_LIKE=linux
HOME_URL="https://nova-os.org"
SUPPORT_URL="https://nova-os.org/support"
```

### 4.2 /etc/hostname

```
nova-minimal
```

### 4.3 /etc/systemd/system/default.target

```ini
[Unit]
Description=Multi-User System
Documentation=man:systemd.special(7)
Requires=basic.target
Wants=network.target
After=basic.target network.target
AllowIsolate=yes

[Install]
Alias=default.target
```

### 4.4 /etc/systemd/system/nova-boot.service

```ini
[Unit]
Description=NOVA OS Boot Information
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/echo "NOVA OS Phase 11 Minimal System Booted Successfully"
ExecStart=/usr/bin/uname -a
ExecStart=/usr/bin/systemctl --version
StandardOutput=tty

[Install]
WantedBy=multi-user.target
```

---

## 5. Build Process

### 5.1 Build Strategy

**Approach**: Use distribution packages as foundation, add NOVA-specific components

**Rationale**:
- Building entire toolchain from scratch (LFS-style) is complex and time-consuming
- Distribution packages provide stable, tested components
- Focus Phase 11 on bootable system, not complete independence
- Phase 12+ can work toward full independence

### 5.2 Build Steps

#### Step 1: Create Root Filesystem

```bash
# Create root directory
mkdir -p $NOVA_ROOT/rootfs

# Install base packages using distribution package manager
# For Fedora:
sudo dnf --installroot=$NOVA_ROOT/rootfs --releasever=39 install \
    systemd glibc coreutils bash util-linux \
    e2fsprogs btrfs-progs kmod dracut grub2 \
    vim-minimal sudo shadow-utils

# For Ubuntu:
sudo debootstrap --variant=minbase noble $NOVA_ROOT/rootfs
sudo chroot $NOVA_ROOT/rootfs apt-get install \
    systemd glibc coreutils bash util-linux \
    e2fsprogs btrfs-progs kmod dracut grub2
```

#### Step 2: Build and Install Kernel

```bash
# Build kernel (see section 2.1)
# Install to rootfs
sudo make INSTALL_MOD_PATH=$NOVA_ROOT/rootfs modules_install
sudo make INSTALL_PATH=$NOVA_ROOT/rootfs/boot install
```

#### Step 3: Configure System

```bash
# Copy configuration files
sudo cp etc/os-release $NOVA_ROOT/rootfs/etc/
sudo cp etc/hostname $NOVA_ROOT/rootfs/etc/
sudo cp etc/fstab $NOVA_ROOT/rootfs/etc/

# Install systemd services
sudo cp etc/systemd/system/*.service $NOVA_ROOT/rootfs/etc/systemd/system/
```

#### Step 4: Generate Initramfs

```bash
# Generate initramfs
sudo dracut --rootfs $NOVA_ROOT/rootfs \
    --kver 6.12.x-nova \
    --include /usr/lib/udev/rules.d/50-udev-default.rules \
    --include /usr/lib/udev/rules.d/60-persistent-storage.rules \
    --force \
    $NOVA_ROOT/rootfs/boot/initramfs-nova.img
```

#### Step 5: Install GRUB

```bash
# Install GRUB to rootfs
sudo grub-install --root-directory=$NOVA_ROOT/rootfs \
    --boot-directory=$NOVA_ROOT/rootfs/boot \
    --efi-directory=$NOVA_ROOT/rootfs/boot/efi \
    --target=x86_64-efi \
    --removable

# Generate GRUB config
sudo grub-mkconfig -o $NOVA_ROOT/rootfs/boot/grub/grub.cfg
```

---

## 6. ISO Creation

### 6.1 ISO Structure

```
nova-os-phase11.iso
├── boot/
│   ├── grub/
│   │   └── grub.cfg
│   ├── vmlinuz-nova
│   └── initramfs-nova.img
├── EFI/
│   └── BOOT/
│       └── BOOTX64.EFI
└── rootfs.squashfs (compressed root filesystem)
```

### 6.2 ISO Creation Commands

```bash
# Create squashfs of rootfs
sudo mksquashfs $NOVA_ROOT/rootfs $NOVA_ROOT/iso/rootfs.squashfs

# Create ISO with xorriso
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "NOVA-OS-Phase11" \
    -eltorito-boot boot/grub/efi.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-catalog boot/boot.cat \
    -output nova-os-phase11.iso \
    $NOVA_ROOT/iso
```

### 6.3 Hybrid ISO (UEFI + BIOS)

Create a hybrid ISO that supports both UEFI and BIOS boot:

```bash
# Convert to hybrid ISO
isohybrid nova-os-phase11.iso
```

---

## 7. Verification

### 7.1 Boot Verification Checklist

- [ ] ISO file created successfully
- [ ] ISO boots in VirtualBox (UEFI)
- [ ] ISO boots in VirtualBox (BIOS, if supported)
- [ ] Kernel loads without errors
- [ ] Initramfs loads successfully
- [ ] Root filesystem mounts
- [ ] systemd starts
- [ ] System reaches multi-user.target
- [ ] NOVA boot service runs
- [ ] System information displayed
- [ ] Reboot works

### 7.2 Expected Boot Output

```
NOVA OS Phase 11 - Minimal System
Kernel 6.12.x-nova loading...
[    0.000000] Linux version 6.12.x-nova (gcc@13.2.1)
[    0.000000] Command line: root=UUID=<uuid> ro quiet
[    0.123456] Btrfs loaded
[    0.234567] systemd[1]: Starting system...
[    1.234567] systemd[1]: Reached target Multi-User System.
[    2.345678] nova-boot.service: NOVA OS Phase 11 Minimal System Booted Successfully
[    2.345679] nova-boot.service: Linux nova-minimal 6.12.x-nova #1 SMP
[    2.345680] nova-boot.service: systemd 253
```

---

## 8. Phase 11 Deliverables

### 8.1 Files to Create

1. **Build Scripts**:
   - `build/phase11_build_kernel.sh` - Kernel build script
   - `build/phase11_create_rootfs.sh` - Root filesystem creation
   - `build/phase11_generate_initramfs.sh` - Initramfs generation
   - `build/phase11_create_iso.sh` - ISO creation

2. **Configuration Files**:
   - `system/filesystem-skeleton/etc/os-release` - OS identification
   - `system/filesystem-skeleton/etc/hostname` - Hostname
   - `system/filesystem-skeleton/etc/fstab` - Filesystem table
   - `system/filesystem-skeleton/etc/systemd/system/nova-boot.service` - Boot service

3. **Documentation**:
   - `PHASE_11_BUILD_ENVIRONMENT.md` - Build environment setup
   - `PHASE_11_MINIMAL_SYSTEM.md` - This document
   - `PHASE_11_BOOT_RESULTS.md` - Boot test results

### 8.2 Artifacts

1. **Kernel**: `vmlinuz-nova` (6.12.x)
2. **Initramfs**: `initramfs-nova.img`
3. **Root Filesystem**: `rootfs.squashfs`
4. **ISO**: `nova-os-phase11.iso`

---

## 9. Dependencies on Existing NOVA OS

### 9.1 Reusing Existing Components

The following existing NOVA OS components will be reused:

1. **Kernel Configuration**: `kernel/configs/nova_defconfig`
2. **Filesystem Skeleton**: `system/filesystem-skeleton/`
3. **Architecture**: Based on `ARCHITECTURE.md`

### 9.2 Modifications Required

1. **Kernel Config**: Ensure minimal required features are built-in
2. **Filesystem Skeleton**: Add minimal configuration files
3. **Build System**: Create Phase 11 specific build scripts

---

## 10. Known Limitations (Phase 11)

### 10.1 What Phase 11 Does NOT Include

- Complete package management (DNF5/RPM)
- Full independence from distribution packages
- Wayland compositor
- Desktop environment
- NOVA-specific applications
- Advanced system tools
- Btrfs subvolumes (single partition for simplicity)

### 10.2 Phase 12+ Work

Phase 12 will build on Phase 11 to add:
- Complete package management system
- Btrfs subvolume layout
- Wayland compositor with wlroots
- Desktop components
- NOVA-specific tools

---

## 11. Success Criteria

Phase 11 is successful when:

1. ✅ Build environment is set up (Linux VM or WSL2)
2. ✅ Kernel builds successfully
3. ✅ Root filesystem is created
4. ✅ Initramfs is generated
5. ✅ GRUB is configured
6. ✅ ISO is created
7. ✅ ISO boots in VirtualBox
8. ✅ System reaches multi-user.target
9. ✅ NOVA boot service runs and displays information
10. ✅ System can reboot

---

**END OF DOCUMENT**

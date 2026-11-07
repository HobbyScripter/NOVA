Name:           linux-kernel
Version:        6.12.10
Release:        1.nova%{?dist}
Summary:        The Official Linux Kernel for NOVA OS
License:        GPL-2.0-only WITH Linux-syscall-note
URL:            https://www.kernel.org/
Source0:        https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-%{version}.tar.xz
Source1:        nova_defconfig
BuildRequires:  gcc >= 14.0, binutils, bison, flex, elfutils-libelf-devel, openssl-devel, bc, zstd
Requires:       dracut, grub2, kmod, btrfs-progs
Provides:       kernel = %{version}
Provides:       kernel-core = %{version}

%description
The Linux Kernel is the core of NOVA OS. This package contains the
stable Linux kernel configured specifically for NOVA OS with built-in
support for Btrfs, ext4, NVMe, AHCI, AppArmor, and modular DRM drivers
for modern PCs, Oracle VirtualBox (VMSVGA) and VMware Workstation (SVGA II).

%prep
%setup -q -n linux-%{version}
cp %{SOURCE1} .config

%build
make %{?_smp_mflags} bzImage
make %{?_smp_mflags} modules

%install
mkdir -p %{buildroot}/boot
mkdir -p %{buildroot}/usr/lib/modules/%{version}-nova-stable

install -m 644 arch/x86/boot/bzImage %{buildroot}/boot/vmlinuz-nova-%{version}
make modules_install INSTALL_MOD_PATH=%{buildroot}/usr

%post
# Generate Dracut initramfs
dracut --force --zstd --kver %{version}-nova-stable /boot/initramfs-nova-%{version}.img

# Update boot retention: current vs previous
if [ -f /boot/vmlinuz-nova-current ]; then
    cp -f /boot/vmlinuz-nova-current /boot/vmlinuz-nova-previous
    cp -f /boot/initramfs-nova-current.img /boot/initramfs-nova-previous.img
fi
cp -f /boot/vmlinuz-nova-%{version} /boot/vmlinuz-nova-current
cp -f /boot/initramfs-nova-%{version}.img /boot/initramfs-nova-current.img

# Update GRUB
if [ -x /usr/sbin/grub-mkconfig ]; then
    /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg
fi

%files
/boot/vmlinuz-nova-%{version}
/usr/lib/modules/%{version}-nova-stable

%changelog
* Fri Nov 07 2026 NOVA OS Development Team <dev@nova-os.org> - 6.12.10-1.nova
- Official stable kernel 6.12.10 build for NOVA OS

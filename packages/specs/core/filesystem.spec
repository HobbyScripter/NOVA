Name:           filesystem
Version:        1.0.0
Release:        1.nova%{?dist}
Summary:        NOVA OS Root Filesystem Layout and FHS 3.0 Structure
License:        GPL-2.0-only
URL:            https://nova-os.org/
BuildArch:      x86_64
Provides:       filesystem = %{version}-%{release}

%description
The filesystem package is one of the basic packages that is installed
on a NOVA OS system. Filesystem contains the basic directory layout
for a Linux operating system, including the UsrMerge structure conforming
to the Filesystem Hierarchy Standard (FHS) 3.0.

%prep
# No source unpacking needed for basic layout

%build
# Static directory structure

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/{dev,proc,sys,run,tmp,home,root,boot/efi,.snapshots,swap}
mkdir -p %{buildroot}/usr/{bin,sbin,lib,lib64,include,share/licenses,share/doc}
mkdir -p %{buildroot}/var/{log,cache,lib,spool,tmp}
mkdir -p %{buildroot}/etc/{dnf,yum.repos.d,sysctl.d,security,pam.d,systemd/system}

# Compatibility symlinks for UsrMerge
ln -sf usr/bin %{buildroot}/bin
ln -sf usr/sbin %{buildroot}/sbin
ln -sf usr/lib %{buildroot}/lib
ln -sf usr/lib64 %{buildroot}/lib64

%files
%dir /
/bin
/sbin
/lib
/lib64
/dev
/proc
/sys
/run
/tmp
/home
/root
/boot
/.snapshots
/swap
/usr
/var
/etc

%changelog
* Fri Nov 07 2026 NOVA OS Development Team <dev@nova-os.org> - 1.0.0-1.nova
- Initial package for NOVA OS 1.0 (Supernova)

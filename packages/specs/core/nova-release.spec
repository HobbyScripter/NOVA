Name:           nova-release
Version:        1.0.0
Release:        1.nova%{?dist}
Summary:        NOVA OS Release Files, Keys and Repository Configurations
License:        GPL-2.0-only
URL:            https://nova-os.org/
Requires:       filesystem >= 1.0.0
Provides:       system-release = %{version}
Provides:       os-release = %{version}

%description
This package contains the official os-release, system identification files,
and official GPG keys and DNF repository configurations for NOVA OS.

%install
mkdir -p %{buildroot}/etc/yum.repos.d
mkdir -p %{buildroot}/etc/pki/rpm-gpg
mkdir -p %{buildroot}/usr/lib

install -m 644 %{_sourcedir}/os-release %{buildroot}/usr/lib/os-release
ln -sf ../usr/lib/os-release %{buildroot}/etc/os-release
install -m 644 %{_sourcedir}/nova.repo %{buildroot}/etc/yum.repos.d/nova.repo

%files
/usr/lib/os-release
/etc/os-release
/etc/yum.repos.d/nova.repo

%changelog
* Fri Nov 07 2026 NOVA OS Development Team <dev@nova-os.org> - 1.0.0-1.nova
- Initial release package for NOVA OS 1.0 Supernova

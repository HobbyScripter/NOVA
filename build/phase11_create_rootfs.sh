#!/bin/bash
# Phase 11: Root Filesystem Creation Script for NOVA OS
# Creates minimal root filesystem using distribution packages

set -e

# Configuration
NOVA_ROOT="${NOVA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOTFS_DIR="$NOVA_ROOT/rootfs"
DISTRIBUTION="${DISTRIBUTION:-ubuntu}"  # fedora or ubuntu
RELEASEVER="${RELEASEVER:-24.04}"  # Ubuntu 24.04 LTS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect distribution
detect_distribution() {
    echo_info "Detecting host distribution..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        HOST_DISTRO="$ID"
        echo_info "Host distribution: $HOST_DISTRO"
    else
        echo_error "Cannot detect distribution"
        exit 1
    fi
}

# Create rootfs directory
create_rootfs_dir() {
    echo_info "Creating rootfs directory: $ROOTFS_DIR"

    if [ -d "$ROOTFS_DIR" ]; then
        echo_warn "Rootfs directory already exists, removing..."
        rm -rf "$ROOTFS_DIR"
    fi

    mkdir -p "$ROOTFS_DIR"
}

# Install packages using dnf (Fedora/RHEL)
install_packages_fedora() {
    echo_info "Installing packages using dnf..."

    local packages=(
        systemd
        glibc
        coreutils
        bash
        util-linux
        e2fsprogs
        btrfs-progs
        kmod
        dracut
        grub2-pc
        grub2-efi-x64
        grub2-efi-x64-modules
        shim-x64
        vim-minimal
        sudo
        shadow-utils
        NetworkManager
        wpa_supplicant
        dhcp-client
        iproute
        iputils
        openssh-clients
        curl
        wget
        less
        gzip
        xz
        tar
        ca-certificates
    )

    dnf --installroot="$ROOTFS_DIR" \
        --releasever="$RELEASEVER" \
        --setopt=install_weak_deps=False \
        install -y "${packages[@]}"
}

# Install packages using debootstrap (Debian/Ubuntu)
install_packages_ubuntu() {
    echo_info "Installing packages using debootstrap..."

    # Install debootstrap if not present
    if ! command -v debootstrap &> /dev/null; then
        echo_info "Installing debootstrap..."
        apt-get update
        apt-get install -y debootstrap
    fi

    # Create minimal Ubuntu system
    echo_info "Running debootstrap..."
    debootstrap --variant=minbase "$RELEASEVER" "$ROOTFS_DIR" || {
        echo_error "debootstrap failed"
        exit 1
    }

    # Install additional packages with error handling
    echo_info "Installing additional packages in chroot..."

    # Prepare chroot environment
    mount --bind /dev "$ROOTFS_DIR/dev"
    mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"
    mount --bind /proc "$ROOTFS_DIR/proc"
    mount --bind /sys "$ROOTFS_DIR/sys"

    # Copy DNS configuration
    cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

    local packages=(
        systemd
        coreutils
        bash
        util-linux
        e2fsprogs
        btrfs-progs
        kmod
        dracut
        grub2-common
        grub-pc-bin
        grub-efi-amd64
        grub-efi-amd64-signed
        shim-signed
        vim
        sudo
        shadow
        network-manager
        wpasupplicant
        isc-dhcp-client
        iproute2
        iputils-ping
        openssh-client
        curl
        wget
        less
        gzip
        xz-utils
        tar
        ca-certificates
    )

    if ! chroot "$ROOTFS_DIR" apt-get update; then
        echo_error "apt-get update failed in chroot"
        cleanup_mounts
        exit 1
    fi

    if ! chroot "$ROOTFS_DIR" apt-get install -y "${packages[@]}"; then
        echo_error "apt-get install failed in chroot"
        cleanup_mounts
        exit 1
    fi

    cleanup_mounts
}

# Cleanup mount points
cleanup_mounts() {
    echo_info "Cleaning up mount points..."

    # Unmount in reverse order
    umount "$ROOTFS_DIR/sys" 2>/dev/null || true
    umount "$ROOTFS_DIR/proc" 2>/dev/null || true
    umount "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
    umount "$ROOTFS_DIR/dev" 2>/dev/null || true
}

# Cleanup hook
trap cleanup_mounts EXIT

# Copy NOVA configuration files
copy_config_files() {
    echo_info "Copying NOVA configuration files..."

    # Copy os-release
    if [ -f "$NOVA_ROOT/system/filesystem-skeleton/etc/os-release" ]; then
        cp "$NOVA_ROOT/system/filesystem-skeleton/etc/os-release" "$ROOTFS_DIR/etc/"
    else
        # Create minimal os-release
        cat > "$ROOTFS_DIR/etc/os-release" << 'EOF'
NAME="NOVA OS"
ID=nova
PRETTY_NAME="NOVA OS"
VERSION_ID="0.1"
VERSION="0.1 (Phase 11 - Minimal System)"
ID_LIKE=linux
HOME_URL="https://nova-os.org"
SUPPORT_URL="https://nova-os.org/support"
EOF
    fi

    # Copy hostname
    if [ -f "$NOVA_ROOT/system/filesystem-skeleton/etc/hostname" ]; then
        cp "$NOVA_ROOT/system/filesystem-skeleton/etc/hostname" "$ROOTFS_DIR/etc/"
    else
        echo "nova-minimal" > "$ROOTFS_DIR/etc/hostname"
    fi

    # Create hosts file
    cat > "$ROOTFS_DIR/etc/hosts" << 'EOF'
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
127.0.1.1   nova-minimal.localdomain nova-minimal
EOF

    # Create machine-id
    echo "00000000000000000000000000000000" > "$ROOTFS_DIR/etc/machine-id"
    chmod 444 "$ROOTFS_DIR/etc/machine-id"
}

# Create systemd units
create_systemd_units() {
    echo_info "Creating systemd units..."

    mkdir -p "$ROOTFS_DIR/etc/systemd/system"

    # Create nova-boot service
    cat > "$ROOTFS_DIR/etc/systemd/system/nova-boot.service" << 'EOF'
[Unit]
Description=NOVA OS Boot Information
After=network.target
WantedBy=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/echo "NOVA OS Phase 11 Minimal System Booted Successfully"
ExecStart=/usr/bin/uname -a
ExecStart=/usr/bin/systemctl --version
StandardOutput=tty
EOF

    # Enable the service
    mkdir -p "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants"
    ln -sf /etc/systemd/system/nova-boot.service "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/nova-boot.service"
}

# Create fstab
create_fstab() {
    echo_info "Creating /etc/fstab (placeholder - will be updated during installation)..."

    cat > "$ROOTFS_DIR/etc/fstab" << 'EOF'
# /etc/fstab for NOVA OS
# UUIDs will be replaced during installation
UUID=<root-uuid> / btrfs defaults,relatime 0 1
UUID=<esp-uuid>  /boot/efi vfat defaults 0 2
EOF
}

# Setup root password
setup_root_user() {
    echo_info "Setting up root user..."

    # Use environment variables for passwords (default: nova)
    local root_password="${ROOT_PASSWORD:-nova}"
    local nova_password="${NOVA_PASSWORD:-nova}"

    # Set root password
    chroot "$ROOTFS_DIR" sh -c "echo 'root:$root_password' | chpasswd"

    # Create nova user
    chroot "$ROOTFS_DIR" useradd -m -s /bin/bash nova
    chroot "$ROOTFS_DIR" sh -c "echo 'nova:$nova_password' | chpasswd"
    chroot "$ROOTFS_DIR" usermod -aG wheel nova

    # Enable sudo for wheel group
    echo "%wheel ALL=(ALL) ALL" > "$ROOTFS_DIR/etc/sudoers.d/wheel"
    chmod 440 "$ROOTFS_DIR/etc/sudoers.d/wheel"

    echo_warn "Default passwords set: root='$root_password', nova='$nova_password'"
    echo_warn "Change passwords on first boot!"
}

# Setup network
setup_network() {
    echo_info "Setting up network configuration..."

    mkdir -p "$ROOTFS_DIR/etc/systemd/network"

    # Create simple network configuration
    cat > "$ROOTFS_DIR/etc/systemd/network/20-wired.network" << 'EOF'
[Match]
Name=en*

[Network]
DHCP=yes
EOF

    # Enable NetworkManager
    mkdir -p "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants"
    ln -sf /usr/lib/systemd/system/NetworkManager.service "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
}

# Verify rootfs
verify_rootfs() {
    echo_info "Verifying rootfs..."

    if [ ! -d "$ROOTFS_DIR/bin" ]; then
        echo_error "Rootfs /bin directory not found"
        exit 1
    fi

    if [ ! -d "$ROOTFS_DIR/usr/bin" ]; then
        echo_error "Rootfs /usr/bin directory not found"
        exit 1
    fi

    if [ ! -f "$ROOTFS_DIR/etc/os-release" ]; then
        echo_error "Rootfs /etc/os-release not found"
        exit 1
    fi

    local dir_count=$(find "$ROOTFS_DIR" -type d | wc -l)
    local file_count=$(find "$ROOTFS_DIR" -type f | wc -l)

    echo_info "Rootfs verification complete"
    echo_info "Directories: $dir_count"
    echo_info "Files: $file_count"
}

# Clean up
cleanup() {
    echo_info "Cleaning up..."

    # Remove package manager cache
    if [ "$DISTRIBUTION" = "fedora" ]; then
        rm -rf "$ROOTFS_DIR/var/cache/dnf"
    elif [ "$DISTRIBUTION" = "ubuntu" ]; then
        rm -rf "$ROOTFS_DIR/var/cache/apt"
    fi
}

# Main execution
main() {
    echo_info "=== NOVA OS Phase 11: Root Filesystem Creation ==="
    echo_info "Distribution: $DISTRIBUTION"
    echo_info "Release: $RELEASEVER"
    echo_info "Rootfs directory: $ROOTFS_DIR"
    echo ""

    check_root
    detect_distribution
    create_rootfs_dir

    if [ "$DISTRIBUTION" = "fedora" ]; then
        install_packages_fedora
    elif [ "$DISTRIBUTION" = "ubuntu" ]; then
        install_packages_ubuntu
    else
        echo_error "Unsupported distribution: $DISTRIBUTION"
        echo "Supported: fedora, ubuntu"
        exit 1
    fi

    copy_config_files
    create_systemd_units
    create_fstab
    setup_root_user
    setup_network
    verify_rootfs
    cleanup

    echo_info "=== Root filesystem creation successful ==="
    echo_info "Rootfs location: $ROOTFS_DIR"
    echo_info "Root password: nova"
    echo_info "User: nova / Password: nova"
}

# Run main function
main "$@"

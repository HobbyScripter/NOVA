#!/bin/bash
# Phase 11: Initramfs Generation Script for NOVA OS
# Generates initramfs using dracut

set -e

# Configuration
NOVA_ROOT="${NOVA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ROOTFS_DIR="$NOVA_ROOT/rootfs"
INSTALL_DIR="$NOVA_ROOT/install"
KERNEL_VERSION="${KERNEL_VERSION:-6.12.5}"
DRACUT_CONF_DIR="$NOVA_ROOT/system/filesystem-skeleton/etc/dracut.conf.d"

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

# Check prerequisites
check_prerequisites() {
    echo_info "Checking prerequisites..."

    if ! command -v dracut &> /dev/null; then
        echo_error "dracut not found"
        echo "Install with: sudo apt install dracut (Ubuntu) or sudo dnf install dracut (Fedora)"
        exit 1
    fi

    if [ ! -d "$ROOTFS_DIR" ]; then
        echo_error "Rootfs directory not found: $ROOTFS_DIR"
        echo "Run phase11_create_rootfs.sh first"
        exit 1
    fi

    echo_info "All prerequisites satisfied"
}

# Determine kernel version
determine_kernel_version() {
    echo_info "Determining kernel version..."

    if [ -f "$INSTALL_DIR/boot/vmlinuz-nova" ]; then
        # Try to extract version from kernel image
        local version=$(strings "$INSTALL_DIR/boot/vmlinuz-nova" | grep -oP 'Linux version \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ -n "$version" ]; then
            KERNEL_VERSION="$version"
            echo_info "Detected kernel version: $KERNEL_VERSION"
        fi
    fi

    if [ ! -d "$INSTALL_DIR/lib/modules/$KERNEL_VERSION-nova" ]; then
        echo_error "Kernel modules not found for version: $KERNEL_VERSION-nova"
        echo "Run phase11_build_kernel.sh first"
        exit 1
    fi
}

# Create dracut configuration
create_dracut_config() {
    echo_info "Creating dracut configuration..."

    if [ ! -d "$ROOTFS_DIR" ]; then
        echo_error "Rootfs directory not found: $ROOTFS_DIR"
        echo "Run phase11_create_rootfs.sh first"
        exit 1
    fi

    mkdir -p "$ROOTFS_DIR/etc/dracut.conf.d"

    # Check if directory creation succeeded
    if [ ! -d "$ROOTFS_DIR/etc/dracut.conf.d" ]; then
        echo_error "Failed to create dracut config directory: $ROOTFS_DIR/etc/dracut.conf.d"
        echo "Check permissions"
        exit 1
    fi

    cat > "$ROOTFS_DIR/etc/dracut.conf.d/10-nova.conf" << 'EOF'
# NOVA OS dracut configuration

# Do not use hostonly mode
hostonly="no"

# Use zstd compression
compress="zstd"

# Required drivers
drivers+=" vboxvideo vmwgfx amdgpu i915 nouveau "
drivers+=" nvme ahci "
drivers+=" virtio_net e1000 "
drivers+=" usbhid hid_generic "
drivers+=" xhci_hcd ehci_hcd "

# Required filesystems
filesystems+=" btrfs ext4 vfat "

# Add additional modules
add_drivers+=" crc32c "
add_drivers+=" btrfs "

# Include udev rules
install_items+=" /usr/lib/udev/rules.d/50-udev-default.rules "
install_items+=" /usr/lib/udev/rules.d/60-persistent-storage.rules "
install_items+="usr/lib/udev/rules.d/60-persistent-storage-tape.rules "
install_items+=" /usr/lib/udev/rules.d/64-btrfs.rules "

# Include firmware
fw_dir+=" /lib/firmware "

# Enable early KMS
early_cpio="yes"

# Strip binaries
strip="yes"

# Verbosity
# stdloglvl=3
# sysloglvl=3
EOF

    echo_info "Dracut configuration created"
}

# Generate initramfs
generate_initramfs() {
    echo_info "Generating initramfs for kernel $KERNEL_VERSION-nova..."

    mkdir -p "$INSTALL_DIR/boot"

    # Use dracut to generate initramfs
    dracut \
        --rootfs "$ROOTFS_DIR" \
        --kver "$KERNEL_VERSION-nova" \
        --force \
        --verbose \
        "$INSTALL_DIR/boot/initramfs-nova.img"

    echo_info "Initramfs generation complete"
}

# Verify initramfs
verify_initramfs() {
    echo_info "Verifying initramfs..."

    if [ ! -f "$INSTALL_DIR/boot/initramfs-nova.img" ]; then
        echo_error "Initramfs not found"
        exit 1
    fi

    local initramfs_size=$(stat -c%s "$INSTALL_DIR/boot/initramfs-nova.img")
    echo_info "Initramfs size: $initramfs_size bytes"

    # Check if initramfs is a valid gzip/zstd file
    if file "$INSTALL_DIR/boot/initramfs-nova.img" | grep -q "gzip\|zstd"; then
        echo_info "Initramfs compression valid"
    else
        echo_warn "Initramfs may not be properly compressed"
    fi

    echo_info "Initramfs verification complete"
}

# List initramfs contents (optional)
list_initramfs_contents() {
    echo_info "Listing initramfs contents (first 20 files)..."

    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"

    # Extract initramfs
    if file "$INSTALL_DIR/boot/initramfs-nova.img" | grep -q "gzip"; then
        zcat "$INSTALL_DIR/boot/initramfs-nova.img" | cpio -t | head -20
    elif file "$INSTALL_DIR/boot/initramfs-nova.img" | grep -q "zstd"; then
        zstd -d "$INSTALL_DIR/boot/initramfs-nova.img" -o - | cpio -t | head -20
    else
        echo_warn "Unknown compression format"
    fi

    cd - > /dev/null
    rm -rf "$tmp_dir"
}

# Main execution
main() {
    echo_info "=== NOVA OS Phase 11: Initramfs Generation ==="
    echo_info "Kernel version: $KERNEL_VERSION"
    echo_info "Rootfs directory: $ROOTFS_DIR"
    echo_info "Install directory: $INSTALL_DIR"
    echo ""

    check_prerequisites
    determine_kernel_version
    create_dracut_config
    generate_initramfs
    verify_initramfs

    # Optional: list contents
    # list_initramfs_contents

    echo_info "=== Initramfs generation successful ==="
    echo_info "Initramfs: $INSTALL_DIR/boot/initramfs-nova.img"
}

# Run main function
main "$@"

#!/bin/bash
# Phase 11: ISO Creation Script for NOVA OS
# Creates bootable ISO image with kernel, initramfs, and rootfs

set -e

# Configuration
NOVA_ROOT="${NOVA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOTFS_DIR="$NOVA_ROOT/rootfs"
INSTALL_DIR="$NOVA_ROOT/install"
ISO_DIR="$NOVA_ROOT/iso"
ISO_OUTPUT="$NOVA_ROOT/nova-os-phase11.iso"
KERNEL_VERSION="${KERNEL_VERSION:-6.12.5}"

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

    local required_tools=("xorriso" "mksquashfs" "grub-mkrescue")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo_error "Missing required tool: $tool"
            echo "Install with: sudo apt install xorriso squashfs-tools grub2-common grub-efi-amd64-bin (Ubuntu)"
            exit 1
        fi
    done

    # Check for GRUB EFI modules
    if [ ! -d "/usr/lib/grub/x86_64-efi" ]; then
        echo_error "GRUB EFI modules not found: /usr/lib/grub/x86_64-efi"
        echo "Install with: sudo apt install grub-efi-amd64-bin"
        exit 1
    fi

    if [ ! -d "/usr/lib/grub/i386-pc" ]; then
        echo_error "GRUB BIOS modules not found: /usr/lib/grub/i386-pc"
        echo "Install with: sudo apt install grub-pc-bin"
        exit 1
    fi

    if [ ! -f "$INSTALL_DIR/boot/vmlinuz-nova" ]; then
        echo_error "Kernel not found: $INSTALL_DIR/boot/vmlinuz-nova"
        echo "Run phase11_build_kernel.sh first"
        exit 1
    fi

    # Echte Artefakte erzwingen: Textplatzhalter dürfen nie in ein ISO gelangen.
    local kernel_size
    kernel_size=$(stat -c%s "$INSTALL_DIR/boot/vmlinuz-nova")
    if [ "$kernel_size" -lt 1000000 ]; then
        echo_error "Kernel is a placeholder (${kernel_size} Bytes, expected > 1 MB): $INSTALL_DIR/boot/vmlinuz-nova"
        exit 1
    fi
    if ! file -b "$INSTALL_DIR/boot/vmlinuz-nova" | grep -qE "ELF|Linux kernel"; then
        echo_error "Kernel has no ELF/bzImage signature: $INSTALL_DIR/boot/vmlinuz-nova"
        exit 1
    fi

    if [ ! -f "$INSTALL_DIR/boot/initramfs-nova.img" ]; then
        echo_error "Initramfs not found: $INSTALL_DIR/boot/initramfs-nova.img"
        echo "Run phase11_generate_initramfs.sh first"
        exit 1
    fi

    local initramfs_size
    initramfs_size=$(stat -c%s "$INSTALL_DIR/boot/initramfs-nova.img")
    if [ "$initramfs_size" -lt 100000 ]; then
        echo_error "Initramfs is a placeholder (${initramfs_size} Bytes, expected > 100 kB)"
        exit 1
    fi
    if ! file -b "$INSTALL_DIR/boot/initramfs-nova.img" | grep -qiE "gzip|zstandard|xz|lz4|cpio"; then
        echo_error "Initramfs has no archive signature: $INSTALL_DIR/boot/initramfs-nova.img"
        exit 1
    fi

    if [ ! -d "$ROOTFS_DIR" ]; then
        echo_error "Rootfs not found: $ROOTFS_DIR"
        echo "Run phase11_create_rootfs.sh first"
        exit 1
    fi

    echo_info "All prerequisites satisfied"
}

# Create ISO directory structure
create_iso_structure() {
    echo_info "Creating ISO directory structure..."

    if [ -d "$ISO_DIR" ]; then
        echo_warn "ISO directory already exists, removing..."
        rm -rf "$ISO_DIR"
    fi

    mkdir -p "$ISO_DIR/boot/grub"
    mkdir -p "$ISO_DIR/EFI/BOOT"
    mkdir -p "$ISO_DIR/EFI/NOVA"
}

# Copy kernel and initramfs
copy_kernel_images() {
    echo_info "Copying kernel and initramfs..."

    cp "$INSTALL_DIR/boot/vmlinuz-nova" "$ISO_DIR/boot/vmlinuz"
    cp "$INSTALL_DIR/boot/initramfs-nova.img" "$ISO_DIR/boot/initramfs.img"
}

# Create GRUB configuration
create_grub_config() {
    echo_info "Creating GRUB configuration..."

    cat > "$ISO_DIR/boot/grub/grub.cfg" << 'EOF'
# GRUB configuration for NOVA OS Phase 11

set timeout=5
set default=0

# Graphical theme (optional)
# set theme=/boot/grub/themes/starfield/theme.txt

menuentry "NOVA OS Phase 11 - Boot" {
    linux /boot/vmlinuz root=UUID=<placeholder-uuid> ro quiet
    initrd /boot/initramfs.img
}

menuentry "NOVA OS Phase 11 - Boot (Verbose)" {
    linux /boot/vmlinuz root=UUID=<placeholder-uuid> ro
    initrd /boot/initramfs.img
}

menuentry "NOVA OS Phase 11 - Boot (Recovery)" {
    linux /boot/vmlinuz root=UUID=<placeholder-uuid> ro single
    initrd /boot/initramfs.img
}
EOF

    echo_info "GRUB configuration created"
    echo_warn "Note: UUID must be replaced during installation or use LABEL= for boot"
}

# Create squashfs of rootfs
create_squashfs() {
    echo_info "Creating squashfs of rootfs (this may take a while)..."

    mksquashfs "$ROOTFS_DIR" "$ISO_DIR/rootfs.squashfs" \
        -comp zstd \
        -Xcompression-level 6 \
        -b 1M \
        -noappend

    local squashfs_size=$(stat -c%s "$ISO_DIR/rootfs.squashfs")
    echo_info "Squashfs size: $squashfs_size bytes"

    if [ "$squashfs_size" -lt 100000 ] || [ "$(head -c4 "$ISO_DIR/rootfs.squashfs")" != "hsqs" ]; then
        echo_error "SquashFS invalid or too small: $ISO_DIR/rootfs.squashfs"
        exit 1
    fi
}

# Create EFI boot image
create_efi_boot() {
    echo_info "Creating EFI boot image..."

    # Create EFI boot directory structure
    mkdir -p "$ISO_DIR/EFI/BOOT"

    # Copy GRUB EFI files (these will be created by grub-mkrescue)
    # For now, we'll use grub-mkrescue which handles EFI automatically
}

# Create ISO using xorriso
create_iso() {
    echo_info "Creating ISO image using xorriso..."

    # grub-mkrescue erzeugt BIOS- und UEFI-Boot gemeinsam (benötigt mtools + xorriso).
    # Die früheren Optionen --grub-mkrescue-core/--xorriso existieren nicht und
    # führten zu einem Abbruch vor der eigentlichen ISO-Erzeugung.
    grub-mkrescue --output="$ISO_OUTPUT" "$ISO_DIR"

    # Alternative: pure xorriso (if grub-mkrescue has issues)
    # xorriso -as mkisofs \
    #     -iso-level 3 \
    #     -full-iso9660-filenames \
    #     -volid "NOVA-OS-Phase11" \
    #     -eltorito-boot boot/grub/efi.img \
    #     -no-emul-boot \
    #     -boot-load-size 4 \
    #     -boot-info-table \
    #     -eltorito-catalog boot/boot.cat \
    #     -output "$ISO_OUTPUT" \
    #     "$ISO_DIR"

    echo_info "ISO creation complete"
}

# Make ISO hybrid (if using xorriso directly)
make_hybrid() {
    echo_info "Making ISO hybrid (UEFI + BIOS)..."

    if command -v isohybrid &> /dev/null; then
        isohybrid "$ISO_OUTPUT"
        echo_info "ISO made hybrid"
    else
        echo_warn "isohybrid not found, ISO may not be hybrid"
        echo "Install with: sudo apt install syslinux-utils (Ubuntu)"
    fi
}

# Verify ISO
verify_iso() {
    echo_info "Verifying ISO..."

    if [ ! -f "$ISO_OUTPUT" ]; then
        echo_error "ISO not found: $ISO_OUTPUT"
        exit 1
    fi

    local iso_size=$(stat -c%s "$ISO_OUTPUT")
    local iso_size_mb=$((iso_size / 1024 / 1024))

    echo_info "ISO size: $iso_size_mb MB"

    if [ "$iso_size" -lt 5000000 ]; then
        echo_error "ISO too small (${iso_size} Bytes) - build did not include real content"
        exit 1
    fi

    if ! file -b "$ISO_OUTPUT" | grep -q "ISO 9660"; then
        echo_error "Not an ISO 9660 image: $ISO_OUTPUT"
        exit 1
    fi

    if ! xorriso -indev "$ISO_OUTPUT" -report_el_torito plain 2>/dev/null | grep -q "El Torito"; then
        echo_error "No El Torito boot information - ISO is not bootable: $ISO_OUTPUT"
        exit 1
    fi

    echo_info "ISO boot information:"
    xorriso -indev "$ISO_OUTPUT" -report_el_torito plain 2>/dev/null | head -12

    echo_info "ISO verification complete"
}

# Generate checksums
generate_checksums() {
    echo_info "Generating checksums..."

    cd "$NOVA_ROOT"

    sha256sum "$ISO_OUTPUT" > "$ISO_OUTPUT.sha256"
    md5sum "$ISO_OUTPUT" > "$ISO_OUTPUT.md5"

    echo_info "Checksums generated:"
    cat "$ISO_OUTPUT.sha256"
}

# Clean up
cleanup() {
    echo_info "Cleaning up..."

    # Keep ISO directory for inspection, but could remove it
    # rm -rf "$ISO_DIR"

    echo_info "Cleanup complete"
}

# Main execution
main() {
    echo_info "=== NOVA OS Phase 11: ISO Creation ==="
    echo_info "Rootfs directory: $ROOTFS_DIR"
    echo_info "Install directory: $INSTALL_DIR"
    echo_info "ISO directory: $ISO_DIR"
    echo_info "ISO output: $ISO_OUTPUT"
    echo ""

    check_prerequisites
    create_iso_structure
    copy_kernel_images
    create_grub_config
    create_squashfs
    create_efi_boot
    create_iso
    make_hybrid
    verify_iso
    generate_checksums
    cleanup

    echo_info "=== ISO creation successful ==="
    echo_info "ISO image: $ISO_OUTPUT"
    echo_info "SHA256: $ISO_OUTPUT.sha256"
    echo_info "MD5: $ISO_OUTPUT.md5"
    echo ""
    echo_info "To test in VirtualBox:"
    echo_info "  VBoxManage createvm --name NOVA-OS-Phase11 --register"
    echo_info "  VBoxManage modifyvm NOVA-OS-Phase11 --memory 4096 --cpus 2"
    echo_info "  VBoxManage storagectl NOVA-OS-Phase11 --name SATA --add sata"
    echo_info "  VBoxManage storageattach NOVA-OS-Phase11 --storagectl SATA --port 0 --device 0 --type hdd --medium $(pwd)/nova-os-phase11.iso"
    echo_info "  VBoxManage startvm NOVA-OS-Phase11"
}

# Run main function
main "$@"

#!/bin/bash
# Phase 11: Kernel Build Script for NOVA OS
# Builds Linux kernel 6.12.x with NOVA configuration

set -e

# Configuration
KERNEL_VERSION="6.12.5"  # Adjust to latest stable
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
NOVA_ROOT="${NOVA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BUILD_DIR="$NOVA_ROOT/build/kernel"
INSTALL_DIR="$NOVA_ROOT/install"
KERNEL_CONFIG="$NOVA_ROOT/kernel/configs/nova_defconfig"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

    # Check for required tools (distribution-agnostic)
    local required_tools=("gcc" "make" "bc" "bison" "flex" "openssl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo_error "Missing required tool: $tool"
            echo "Install with: sudo apt install $tool (Ubuntu) or sudo dnf install $tool (Fedora)"
            exit 1
        fi
    done

    # Check for development libraries (distribution-specific)
    if [ -f /etc/debian_version ] || [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        echo_info "Detected Debian/Ubuntu-based system"
        local lib_packages=("zlib1g-dev" "libssl-dev")
        for pkg in "${lib_packages[@]}"; do
            if ! dpkg -l "$pkg" &> /dev/null; then
                echo_error "Missing library: $pkg"
                echo "Install with: sudo apt install $pkg"
                exit 1
            fi
        done
    elif [ -f /etc/fedora-release ]; then
        # Fedora/RHEL
        echo_info "Detected Fedora/RHEL-based system"
        local lib_packages=("zlib-devel" "openssl-devel")
        for pkg in "${lib_packages[@]}"; do
            if ! rpm -q "$pkg" &> /dev/null; then
                echo_error "Missing library: $pkg"
                echo "Install with: sudo dnf install $pkg"
                exit 1
            fi
        done
    else
        echo_warn "Unable to detect distribution, skipping library checks"
    fi

    echo_info "All prerequisites satisfied"
}

# Download kernel source
download_kernel() {
    echo_info "Downloading Linux kernel ${KERNEL_VERSION}..."

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Download kernel source
    if [ -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
        echo_warn "Kernel source already downloaded, skipping download"
    else
        echo_info "Downloading kernel from kernel.org..."
        wget "$KERNEL_URL"
    fi

    # Download kernel signature
    if [ ! -f "linux-${KERNEL_VERSION}.tar.xz.sign" ]; then
        echo_info "Downloading kernel signature..."
        wget "${KERNEL_URL}.sign"
    fi

    # Download SHA256 checksums
    if [ ! -f "sha256sums.asc" ]; then
        echo_info "Downloading SHA256 checksums..."
        wget "https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc"
    fi

    # Verify kernel signature
    echo_info "Verifying kernel signature..."
    if command -v gpg &> /dev/null; then
        gpg --verify "linux-${KERNEL_VERSION}.tar.xz.sign" 2>/dev/null || {
            echo_error "Kernel signature verification failed (GPG)"
            echo "This could indicate a tampered or corrupted download"
            echo "You may need to import kernel.org GPG keys:"
            echo "  gpg --recv-keys 647F28654894E34545E22EA474685789A3F554B4A"
            exit 1
        }
        echo_info "Kernel signature verified successfully"
    else
        echo_warn "GPG not found, skipping signature verification"
        echo "Install with: sudo apt install gnupg (Ubuntu) or sudo dnf install gnupg2 (Fedora)"
    fi

    # Verify SHA256 checksum
    echo_info "Verifying SHA256 checksum..."
    grep "linux-${KERNEL_VERSION}.tar.xz" sha256sums.asc > sha256sums
    sha256sum -c sha256sums || {
        echo_error "Kernel SHA256 verification failed"
        echo "This could indicate a corrupted download"
        exit 1
    }
    echo_info "SHA256 checksum verified successfully"

    # Extract kernel source
    if [ -d "linux-${KERNEL_VERSION}" ]; then
        echo_warn "Kernel source already extracted, skipping extraction"
    else
        echo_info "Extracting kernel source..."
        tar -xf "linux-${KERNEL_VERSION}.tar.xz"
    fi
}

# Configure kernel
configure_kernel() {
    echo_info "Configuring kernel with NOVA defconfig..."

    cd "$BUILD_DIR/linux-${KERNEL_VERSION}"

    if [ ! -f "$KERNEL_CONFIG" ]; then
        echo_error "NOVA kernel config not found: $KERNEL_CONFIG"
        exit 1
    fi

    # Copy NOVA config
    cp "$KERNEL_CONFIG" .config

    # Update kernel version in localversion
    echo "-nova" > localversion

    # Run olddefconfig to handle new options
    make olddefconfig

    echo_info "Kernel configuration complete"
}

# Build kernel
build_kernel() {
    echo_info "Building kernel (this may take a while)..."

    cd "$BUILD_DIR/linux-${KERNEL_VERSION}"

    # Get number of CPU cores
    local cores=$(nproc)
    echo_info "Using $cores parallel jobs"

    # Build kernel and modules
    make -j"$cores"

    echo_info "Kernel build complete"
}

# Install kernel
install_kernel() {
    echo_info "Installing kernel to $INSTALL_DIR..."

    mkdir -p "$INSTALL_DIR/boot"
    mkdir -p "$INSTALL_DIR/lib/modules"

    cd "$BUILD_DIR/linux-${KERNEL_VERSION}"

    # Install kernel image
    cp arch/x86/boot/bzImage "$INSTALL_DIR/boot/vmlinuz-nova"

    # Install System.map
    cp System.map "$INSTALL_DIR/boot/System.map-nova"

    # Install modules
    make INSTALL_MOD_PATH="$INSTALL_DIR" modules_install

    # Create symlinks
    cd "$INSTALL_DIR/boot"
    ln -sf vmlinuz-nova vmlinuz
    ln -sf System.map-nova System.map

    echo_info "Kernel installation complete"
}

# Verify installation
verify_installation() {
    echo_info "Verifying kernel installation..."

    if [ ! -f "$INSTALL_DIR/boot/vmlinuz-nova" ]; then
        echo_error "Kernel image not found"
        exit 1
    fi

    if [ ! -d "$INSTALL_DIR/lib/modules/${KERNEL_VERSION}-nova" ]; then
        echo_error "Kernel modules not found"
        exit 1
    fi

    local kernel_size=$(stat -c%s "$INSTALL_DIR/boot/vmlinuz-nova")
    echo_info "Kernel image size: $kernel_size bytes"

    local module_count=$(find "$INSTALL_DIR/lib/modules/${KERNEL_VERSION}-nova" -name "*.ko" | wc -l)
    echo_info "Kernel modules installed: $module_count"

    echo_info "Kernel verification complete"
}

# Main execution
main() {
    echo_info "=== NOVA OS Phase 11: Kernel Build ==="
    echo_info "Kernel version: ${KERNEL_VERSION}"
    echo_info "Build directory: $BUILD_DIR"
    echo_info "Install directory: $INSTALL_DIR"
    echo ""

    check_prerequisites
    download_kernel
    configure_kernel
    build_kernel
    install_kernel
    verify_installation

    echo_info "=== Kernel build successful ==="
    echo_info "Kernel image: $INSTALL_DIR/boot/vmlinuz-nova"
    echo_info "Kernel modules: $INSTALL_DIR/lib/modules/${KERNEL_VERSION}-nova"
}

# Run main function
main "$@"

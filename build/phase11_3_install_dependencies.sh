#!/bin/bash
# Phase 11.3: Build-Abhängigkeiten Installation für NOVA OS
# Installiert alle erforderlichen Build-Abhängigkeiten in Ubuntu 24.04 LTS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Output file
REPORT_FILE="phase11_3_dependencies_install.log"

echo "=== Phase 11.3: Build-Abhängigkeiten Installation ===" > "$REPORT_FILE"
echo "Installationsdatum: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo_error "Dieses Skript muss als root ausgeführt werden (sudo)"
        exit 1
    fi
}

# Update system
update_system() {
    echo_header "System-Update"

    echo_info "Aktualisiere Paketlisten..."
    apt-get update | tee -a "$REPORT_FILE"

    echo_info "Aktualisiere installierte Pakete..."
    apt-get upgrade -y | tee -a "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
}

# Install build tools
install_build_tools() {
    echo_header "Installiere Build-Tools"

    local build_tools=(
        build-essential
        gcc
        g++
        clang
        lld
        cmake
        ninja-build
        meson
        pkg-config
        git
        bc
        bison
        flex
        openssl
        zlib1g-dev
        libssl-dev
    )

    echo_info "Installiere Pakete: ${build_tools[@]}"
    apt-get install -y "${build_tools[@]}" | tee -a "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
}

# Install Rust
install_rust() {
    echo_header "Installiere Rust"

    if command -v rustc &> /dev/null; then
        echo_info "Rust ist bereits installiert"
        rustc --version | tee -a "$REPORT_FILE"
    else
        echo_info "Installiere Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        rustc --version | tee -a "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
}

# Install Qt 6
install_qt6() {
    echo_header "Installiere Qt 6"

    local qt6_packages=(
        qt6-base-dev
        qt6-wayland
        qt6-declarative-dev
    )

    echo_info "Installiere Qt 6 Pakete: ${qt6_packages[@]}"
    apt-get install -y "${qt6_packages[@]}" | tee -a "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
}

# Install Wayland and wlroots
install_wayland() {
    echo_header "Installiere Wayland und wlroots"

    local wayland_packages=(
        libwayland-dev
        wayland-protocols
        libwlroots-dev
    )

    echo_info "Installiere Wayland Pakete: ${wayland_packages[@]}"
    apt-get install -y "${wayland_packages[@]}" | tee -a "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
}

# Install input and display libraries
install_display_libs() {
    echo_header "Installiere Display- und Input-Libraries"

    local display_libs=(
        libinput-dev
        libdrm-dev
        libxkbcommon-dev
        libgbm-dev
        libgl1-mesa-dev
        libegl1-mesa-dev
        libgbm-dev
    )

    echo_info "Installiere Display-Libraries: ${display_libs[@]}"
    apt-get install -y "${display_libs[@]}" | tee -a "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
}

# Install Vulkan (optional)
install_vulkan() {
    echo_header "Installiere Vulkan (optional)"

    local vulkan_packages=(
        libvulkan-dev
        vulkan-tools
    )

    echo_info "Installiere Vulkan Pakete: ${vulkan_packages[@]}"
    apt-get install -y "${vulkan_packages[@]}" | tee -a "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
}

# Install system tools
install_system_tools() {
    echo_header "Installiere System-Tools"

    local system_tools=(
        grub2-common
        grub-pc-bin
        grub-efi-amd64
        grub-efi-amd64-signed
        shim-signed
        dracut
        btrfs-progs
        squashfs-tools
        xorriso
        debootstrap
        shellcheck
    )

    echo_info "Installiere System-Tools: ${system_tools[@]}"
    apt-get install -y "${system_tools[@]}" | tee -a "$REPORT_FILE"

    echo "" >> "$REPORT_FILE"
}

# Verify installations
verify_installations() {
    echo_header "Verifiziere Installationen"

    echo_info "=== Version Check ===" | tee -a "$REPORT_FILE"

    local tools=(
        "gcc"
        "g++"
        "clang"
        "cmake"
        "ninja"
        "meson"
        "rustc"
        "cargo"
        "dracut"
        "btrfs"
    )

    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local version=$($tool --version 2>/dev/null | head -1 || echo "unknown")
            echo_info "$tool: $version"
            echo "$tool: $version" >> "$REPORT_FILE"
        else
            echo_error "$tool: Nicht installiert"
            echo "$tool: Nicht installiert" >> "$REPORT_FILE"
        fi
    done

    # Check Qt 6
    if pkg-config --exists Qt6Core; then
        local qt_version=$(pkg-config --modversion Qt6Core)
        echo_info "Qt6: $qt_version"
        echo "Qt6: $qt_version" >> "$REPORT_FILE"
    else
        echo_error "Qt6: Nicht installiert"
        echo "Qt6: Nicht installiert" >> "$REPORT_FILE"
    fi

    # Check Wayland
    if pkg-config --exists wayland-client; then
        local wayland_version=$(pkg-config --modversion wayland-client)
        echo_info "Wayland: $wayland_version"
        echo "Wayland: $wayland_version" >> "$REPORT_FILE"
    else
        echo_error "Wayland: Nicht installiert"
        echo "Wayland: Nicht installiert" >> "$REPORT_FILE"
    fi

    # Check wlroots
    if pkg-config --exists wlroots; then
        local wlroots_version=$(pkg-config --modversion wlroots)
        echo_info "wlroots: $wlroots_version"
        echo "wlroots: $wlroots_version" >> "$REPORT_FILE"
    else
        echo_error "wlroots: Nicht installiert"
        echo "wlroots: Nicht installiert" >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
}

# Document package sources
document_sources() {
    echo_header "Dokumentiere Paketquellen"

    echo_info "=== Paketquellen ===" | tee -a "$REPORT_FILE"
    cat /etc/apt/sources.list | tee -a "$REPORT_FILE"

    if [ -d /etc/apt/sources.list.d ]; then
        echo_info "=== Additional Sources ===" | tee -a "$REPORT_FILE"
        ls -la /etc/apt/sources.list.d/ | tee -a "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
}

# Main execution
main() {
    echo_info "=== Phase 11.3: Build-Abhängigkeiten Installation ==="
    echo ""

    check_root
    update_system
    install_build_tools
    install_rust
    install_qt6
    install_wayland
    install_display_libs
    install_vulkan
    install_system_tools
    verify_installations
    document_sources

    echo_header "Installation abgeschlossen"
    echo_info "Bericht gespeichert in: $REPORT_FILE"
    echo ""
    echo_info "Alle Build-Abhängigkeiten wurden installiert."
}

# Run main function
main "$@"

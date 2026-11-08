#!/bin/bash
# Phase 11.3: Projektprüfung für NOVA OS Build
# Prüft Projektverzeichnis, Dateiberechtigungen und Build-Skripte

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

# Configuration
NOVA_ROOT="${NOVA_ROOT:-$(pwd)}"
export NOVA_ROOT   # Kindprozess (phase11_2_automated_tests.sh) muss denselben Pfad sehen
REPORT_FILE="$NOVA_ROOT/phase11_3_project_check.log"

echo "=== Phase 11.3: Projektprüfung ===" > "$REPORT_FILE"
echo "Prüfungsdatum: $(date)" >> "$REPORT_FILE"
echo "NOVA_ROOT: $NOVA_ROOT" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Test 1: Projektverzeichnis
test_project_dir() {
    echo_header "Test 1: Projektverzeichnis"

    if [ -d "$NOVA_ROOT" ]; then
        echo_info "✓ Projektverzeichnis existiert: $NOVA_ROOT"
        echo "Projektverzeichnis: $NOVA_ROOT" >> "$REPORT_FILE"
    else
        echo_error "✗ Projektverzeichnis nicht gefunden: $NOVA_ROOT"
        echo "Projektverzeichnis: Nicht gefunden" >> "$REPORT_FILE"
        exit 1
    fi

    # Check for key directories
    local required_dirs=("build" "kernel" "desktop" "applications" "documentation")
    for dir in "${required_dirs[@]}"; do
        if [ -d "$NOVA_ROOT/$dir" ]; then
            echo_info "✓ $dir/ existiert"
            echo "$dir/: existiert" >> "$REPORT_FILE"
        else
            echo_error "✗ $dir/ fehlt"
            echo "$dir/: fehlt" >> "$REPORT_FILE"
        fi
    done
    echo "" >> "$REPORT_FILE"
    echo ""
}

# Test 2: Dateiberechtigungen
test_permissions() {
    echo_header "Test 2: Dateiberechtigungen"

    local scripts=(
        "build/phase11_build_kernel.sh"
        "build/phase11_create_rootfs.sh"
        "build/phase11_generate_initramfs.sh"
        "build/phase11_create_iso.sh"
        "build/phase11_2_automated_tests.sh"
        "build/phase11_3_system_check.sh"
        "build/phase11_3_install_dependencies.sh"
        "build/phase11_3_project_check.sh"
        "virtualization/vmware/phase11_create_test_vm.sh"
    )

    local failed=0
    for script in "${scripts[@]}"; do
        local script_path="$NOVA_ROOT/$script"
        if [ -f "$script_path" ]; then
            if [ -x "$script_path" ]; then
                echo_info "✓ $script ist ausführbar"
                echo "$script: ausführbar" >> "$REPORT_FILE"
            else
                echo_warn "⚠ $script ist nicht ausführbar"
                echo "$script: nicht ausführbar" >> "$REPORT_FILE"
                failed=1
            fi
        else
            echo_error "✗ $script fehlt"
            echo "$script: fehlt" >> "$REPORT_FILE"
            failed=1
        fi
    done

    if [ $failed -eq 0 ]; then
        echo_info "✓ Alle Skripte haben korrekte Berechtigungen"
    else
        echo_error "✗ Einige Skripte haben falsche Berechtigungen"
    fi
    echo "" >> "$REPORT_FILE"
    echo ""
}

# Test 3: Build-Skripte
test_build_scripts() {
    echo_header "Test 3: Build-Skripte"

    local kernel_script="$NOVA_ROOT/build/phase11_build_kernel.sh"
    local rootfs_script="$NOVA_ROOT/build/phase11_create_rootfs.sh"
    local initramfs_script="$NOVA_ROOT/build/phase11_generate_initramfs.sh"
    local iso_script="$NOVA_ROOT/build/phase11_create_iso.sh"

    # Check kernel script
    if [ -f "$kernel_script" ]; then
        if grep -q "gpg --verify" "$kernel_script"; then
            echo_info "✓ Kernel-Skript hat GPG-Verifizierung"
        else
            echo_error "✗ Kernel-Skript fehlt GPG-Verifizierung"
        fi
        if grep -q "sha256sum -c" "$kernel_script"; then
            echo_info "✓ Kernel-Skript hat SHA256-Prüfung"
        else
            echo_error "✗ Kernel-Skript fehlt SHA256-Prüfung"
        fi
    fi

    # Check rootfs script
    if [ -f "$rootfs_script" ]; then
        if grep -q "cleanup_mounts" "$rootfs_script"; then
            echo_info "✓ Rootfs-Skript hat Mount-Cleanup"
        else
            echo_error "✗ Rootfs-Skript fehlt Mount-Cleanup"
        fi
        if grep -q "ROOT_PASSWORD" "$rootfs_script"; then
            echo_info "✓ Rootfs-Skript verwendet Umgebungsvariablen"
        else
            echo_error "✗ Rootfs-Skript verwendet keine Umgebungsvariablen"
        fi
    fi

    # Check initramfs script
    if [ -f "$initramfs_script" ]; then
        if grep -q "if \[ ! -d.*ROOTFS_DIR" "$initramfs_script"; then
            echo_info "✓ Initramfs-Skript prüft ROOTFS_DIR"
        else
            echo_error "✗ Initramfs-Skript prüft nicht ROOTFS_DIR"
        fi
    fi

    # Check ISO script
    if [ -f "$iso_script" ]; then
        if grep -q "placeholder-uuid" "$iso_script"; then
            echo_info "✓ ISO-Skript verwendet placeholder UUID"
        else
            echo_error "✗ ISO-Skript verwendet keine placeholder UUID"
        fi
        if grep -q "/usr/lib/grub/x86_64-efi" "$iso_script"; then
            echo_info "✓ ISO-Skript prüft EFI-Module"
        else
            echo_error "✗ ISO-Skript prüft nicht EFI-Module"
        fi
    fi

    echo "" >> "$REPORT_FILE"
    echo ""
}

# Test 4: Kernel-Konfiguration
test_kernel_config() {
    echo_header "Test 4: Kernel-Konfiguration"

    local kernel_config="$NOVA_ROOT/kernel/configs/nova_defconfig"

    if [ -f "$kernel_config" ]; then
        echo_info "✓ Kernel-Konfiguration existiert"

        # Check for critical drivers
        local required_configs=(
            "CONFIG_DRM_VMWGFX"
            "CONFIG_DRM_VBOXVIDEO"
            "CONFIG_BTRFS_FS"
            "CONFIG_EXT4_FS"
            "CONFIG_DRM"
            "CONFIG_DRM_KMS_HELPER"
        )

        for config in "${required_configs[@]}"; do
            if grep -q "$config" "$kernel_config"; then
                echo_info "✓ $config vorhanden"
                echo "$config: vorhanden" >> "$REPORT_FILE"
            else
                echo_error "✗ $config fehlt"
                echo "$config: fehlt" >> "$REPORT_FILE"
            fi
        done
    else
        echo_error "✗ Kernel-Konfiguration nicht gefunden"
        echo "Kernel-Konfiguration: nicht gefunden" >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
    echo ""
}

# Test 5: Downloadquellen
test_download_sources() {
    echo_header "Test 5: Downloadquellen"

    local kernel_script="$NOVA_ROOT/build/phase11_build_kernel.sh"

    if [ -f "$kernel_script" ]; then
        # Check kernel.org URL
        if grep -q "cdn.kernel.org" "$kernel_script"; then
            echo_info "✔ Verwendet kernel.org CDN"
            echo "Kernel-Quelle: kernel.org CDN" >> "$REPORT_FILE"
        else
            echo_error "✗ Keine kernel.org Quelle gefunden"
        fi

        # Check for signature verification
        if grep -q "gpg --verify" "$kernel_script"; then
            echo_info "✔ Verwendet GPG-Signaturverifizierung"
            echo "Signatur-Verifizierung: GPG" >> "$REPORT_FILE"
        else
            echo_error "✗ Keine GPG-Signaturverifizierung"
        fi

        # Check for checksum verification
        if grep -q "sha256sum" "$kernel_script"; then
            echo_info "✔ Verwendet SHA256-Prüfsummen"
            echo "Prüfsummen: SHA256" >> "$REPORT_FILE"
        else
            echo_error "✗ Keine SHA256-Prüfsummen"
        fi
    fi

    echo "" >> "$REPORT_FILE"
    echo ""
}

# Test 6: Dokumentation
test_documentation() {
    echo_header "Test 6: Dokumentation"

    local docs=(
        "PHASE_11_BUILD_ENVIRONMENT.md"
        "PHASE_11_MINIMAL_SYSTEM.md"
        "PHASE_11_REMAINING_WORK.md"
        "PHASE_11_VMWARE_TEST_PLATFORM.md"
        "PHASE_11_BUILD_READINESS_REPORT.md"
        "PHASE_11_2_FIX_REPORT.md"
        "PHASE_11_2_TEST_RESULTS.md"
        "NOVA_BOOTSTRAP_ARCHITECTURE.md"
    )

    for doc in "${docs[@]}"; do
        if [ -f "$NOVA_ROOT/$doc" ]; then
            echo_info "✓ $doc existiert"
            echo "$doc: existiert" >> "$REPORT_FILE"
        else
            echo_error "✗ $doc fehlt"
            echo "$doc: fehlt" >> "$REPORT_FILE"
        fi
    done

    echo "" >> "$REPORT_FILE"
    echo ""
}

# Test 7: Automatisierte Tests erneut ausführen
test_automated_tests() {
    echo_header "Test 7: Automatisierte Tests"

    local test_script="$NOVA_ROOT/build/phase11_2_automated_tests.sh"

    if [ -f "$test_script" ]; then
        echo_info "Führe automatisierte Tests aus..."
        # set -e darf das Skript hier nicht abbrechen, sonst wird ein Testergebnis
        # niemals ausgewertet und die restlichen Prüfungen laufen nicht mehr.
        local test_result=0
        bash "$test_script" || test_result=$?

        if [ $test_result -eq 0 ]; then
            echo_info "✓ Alle automatisierten Tests bestanden"
            echo "Automatisierte Tests: bestanden" >> "$REPORT_FILE"
        else
            echo_error "✗ Einige automatisierte Tests fehlgeschlagen"
            echo "Automatisierte Tests: fehlgeschlagen" >> "$REPORT_FILE"
        fi
    else
        echo_error "✗ Automatisiertes Test-Skript nicht gefunden"
        echo "Automatisierte Tests: Skript fehlt" >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
    echo ""
}

# Test 8: Speicherplatz
test_disk_space() {
    echo_header "Test 8: Speicherplatz"

    local free_space=$(df -BG "$NOVA_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//')

    echo_info "Freier Speicher in $NOVA_ROOT: ${free_space} GB"
    echo "Freier Speicher: ${free_space} GB" >> "$REPORT_FILE"

    if [ "$free_space" -ge 80 ]; then
        echo_info "✓ Ausreichend Speicherplatz (>80 GB)"
    else
        echo_warn "⚠ Weniger als 80 GB freier Speicher (empfohlen: 80 GB+)"
    fi

    echo "" >> "$REPORT_FILE"
    echo ""
}

# Main execution
main() {
    echo_info "=== Phase 11.3: Projektprüfung für NOVA OS Build ==="
    echo ""

    test_project_dir
    test_permissions
    test_build_scripts
    test_kernel_config
    test_download_sources
    test_documentation
    test_automated_tests
    test_disk_space

    echo_header "Prüfungsbericht"
    echo_info "Bericht gespeichert in: $REPORT_FILE"
    echo ""
    echo_info "Projektprüfung abgeschlossen. Bitte überprüfen Sie den Bericht."
}

# Run main function
main "$@"

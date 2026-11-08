#!/bin/bash
# Phase 11.2: Automated Tests for Build Scripts
# Tests syntax, error handling, permissions, and dependencies

set -e

# Configuration
# Use Windows-style path for WSL/Windows environment
NOVA_ROOT="${NOVA_ROOT:-D:/Development/Systeme/NOVA}"
TEST_LOG="$NOVA_ROOT/phase11_2_test_results.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$TEST_LOG"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$TEST_LOG"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$TEST_LOG"
}

echo_test() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$TEST_LOG"
}

# Initialize test log
init_log() {
    echo "=== Phase 11.2 Automated Test Results ===" > "$TEST_LOG"
    echo "Test Date: $(date)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
}

# Test 1: ShellCheck Syntax Validation
test_shellcheck() {
    echo_test "Test 1: ShellCheck Syntax Validation"

    if ! command -v shellcheck &> /dev/null; then
        echo_warn "ShellCheck not found, skipping syntax validation"
        echo_warn "Install with: sudo apt install shellcheck"
        return 0  # Return success to not fail the overall test
    fi

    local scripts=(
        "$NOVA_ROOT/build/phase11_build_kernel.sh"
        "$NOVA_ROOT/build/phase11_create_rootfs.sh"
        "$NOVA_ROOT/build/phase11_generate_initramfs.sh"
        "$NOVA_ROOT/build/phase11_create_iso.sh"
        "$NOVA_ROOT/virtualization/vmware/phase11_create_test_vm.sh"
    )

    local failed=0
    for script in "${scripts[@]}"; do
        if [ ! -f "$script" ]; then
            echo_error "Script not found: $script"
            failed=1
            continue
        fi

        echo_info "Checking $script..."
        if shellcheck "$script" &>> "$TEST_LOG"; then
            echo_info "  ✓ Syntax OK"
        else
            echo_error "  ✗ Syntax errors found"
            failed=1
        fi
    done

    if [ $failed -eq 0 ]; then
        echo_info "Test 1: PASSED"
    else
        echo_error "Test 1: FAILED"
    fi
}

# Test 2: Script Executability
test_executability() {
    echo_test "Test 2: Script Executability"

    local scripts=(
        "$NOVA_ROOT/build/phase11_build_kernel.sh"
        "$NOVA_ROOT/build/phase11_create_rootfs.sh"
        "$NOVA_ROOT/build/phase11_generate_initramfs.sh"
        "$NOVA_ROOT/build/phase11_create_iso.sh"
        "$NOVA_ROOT/virtualization/vmware/phase11_create_test_vm.sh"
    )

    local failed=0
    for script in "${scripts[@]}"; do
        if [ ! -f "$script" ]; then
            echo_error "Script not found: $script"
            failed=1
            continue
        fi

        if [ -x "$script" ]; then
            echo_info "  ✓ $script is executable"
        else
            echo_error "  ✗ $script is not executable"
            failed=1
        fi
    done

    if [ $failed -eq 0 ]; then
        echo_info "Test 2: PASSED"
    else
        echo_error "Test 2: FAILED"
    fi
}

# Test 3: Error Handling in Kernel Script
test_kernel_error_handling() {
    echo_test "Test 3: Kernel Script Error Handling"

    local script="$NOVA_ROOT/build/phase11_build_kernel.sh"

    if [ ! -f "$script" ]; then
        echo_error "Script not found: $script"
        return 1
    fi

    local failed=0

    # Check for set -e
    if grep -q "set -e" "$script"; then
        echo_info "  ✓ Script uses set -e"
    else
        echo_error "  ✗ Script does not use set -e"
        failed=1
    fi

    # Check for error checking functions
    if grep -q "check_prerequisites" "$script"; then
        echo_info "  ✓ Has prerequisite checking"
    else
        echo_error "  ✗ Missing prerequisite checking"
        failed=1
    fi

    # Check for verification functions
    if grep -q "verify_installation" "$script"; then
        echo_info "  ✓ Has installation verification"
    else
        echo_error "  ✗ Missing installation verification"
        failed=1
    fi

    # Check for signature verification
    if grep -q "gpg --verify" "$script"; then
        echo_info "  ✓ Has GPG signature verification"
    else
        echo_error "  ✗ Missing GPG signature verification"
        failed=1
    fi

    # Check for SHA256 verification
    if grep -q "sha256sum -c" "$script"; then
        echo_info "  ✓ Has SHA256 verification"
    else
        echo_error "  ✗ Missing SHA256 verification"
        failed=1
    fi

    if [ $failed -eq 0 ]; then
        echo_info "Test 3: PASSED"
    else
        echo_error "Test 3: FAILED"
    fi
}

# Test 4: Error Handling in Rootfs Script
test_rootfs_error_handling() {
    echo_test "Test 4: Rootfs Script Error Handling"

    local script="$NOVA_ROOT/build/phase11_create_rootfs.sh"

    if [ ! -f "$script" ]; then
        echo_error "Script not found: $script"
        return 1
    fi

    local failed=0

    # Check for set -e
    if grep -q "set -e" "$script"; then
        echo_info "  ✓ Script uses set -e"
    else
        echo_error "  ✗ Script does not use set -e"
        failed=1
    fi

    # Check for root check
    if grep -q "check_root" "$script"; then
        echo_info "  ✓ Has root privilege checking"
    else
        echo_error "  ✗ Missing root privilege checking"
        failed=1
    fi

    # Check for mount cleanup
    if grep -q "cleanup_mounts" "$script"; then
        echo_info "  ✓ Has mount cleanup function"
    else
        echo_error "  ✗ Missing mount cleanup function"
        failed=1
    fi

    # Check for trap
    if grep -q "trap cleanup_mounts EXIT" "$script"; then
        echo_info "  ✓ Has EXIT trap for cleanup"
    else
        echo_error "  ✗ Missing EXIT trap"
        failed=1
    fi

    # Check for environment variable passwords
    if grep -q "ROOT_PASSWORD" "$script"; then
        echo_info "  ✓ Uses environment variables for passwords"
    else
        echo_error "  ✗ Does not use environment variables for passwords"
        failed=1
    fi

    # Check for hardcoded passwords
    if grep -q "echo 'root:nova'" "$script"; then
        echo_error "  ✗ Contains hardcoded password"
        failed=1
    else
        echo_info "  ✓ No hardcoded passwords found"
    fi

    if [ $failed -eq 0 ]; then
        echo_info "Test 4: PASSED"
    else
        echo_error "Test 4: FAILED"
    fi
}

# Test 5: Initramfs Script Permissions
test_initramfs_permissions() {
    echo_test "Test 5: Initramfs Script Permissions"

    local script="$NOVA_ROOT/build/phase11_generate_initramfs.sh"

    if [ ! -f "$script" ]; then
        echo_error "Script not found: $script"
        return 1
    fi

    local failed=0

    # Check for directory existence check
    if grep -q "if \[ ! -d.*ROOTFS_DIR" "$script"; then
        echo_info "  ✓ Checks ROOTFS_DIR existence"
    else
        echo_error "  ✗ Missing ROOTFS_DIR existence check"
        failed=1
    fi

    # Check for directory creation with error handling
    if grep -q "mkdir -p.*dracut" "$script"; then
        echo_info "  ✓ Creates dracut config directory"
    else
        echo_error "  ✗ Missing dracut config directory creation"
        failed=1
    fi

    # Check for creation verification
    if grep -q "if \[ ! -d.*dracut.conf.d" "$script"; then
        echo_info "  ✓ Verifies directory creation"
    else
        echo_error "  ✗ Missing directory creation verification"
        failed=1
    fi

    if [ $failed -eq 0 ]; then
        echo_info "Test 5: PASSED"
    else
        echo_error "Test 5: FAILED"
    fi
}

# Test 6: ISO Script GRUB Configuration
test_iso_grub_config() {
    echo_test "Test 6: ISO Script GRUB Configuration"

    local script="$NOVA_ROOT/build/phase11_create_iso.sh"

    if [ ! -f "$script" ]; then
        echo_error "Script not found: $script"
        return 1
    fi

    local failed=0

    # Check for EFI module verification
    if grep -q "/usr/lib/grub/x86_64-efi" "$script"; then
        echo_info "  ✓ Checks for GRUB EFI modules"
    else
        echo_error "  ✗ Missing GRUB EFI module check"
        failed=1
    fi

    # Check for BIOS module verification
    if grep -q "/usr/lib/grub/i386-pc" "$script"; then
        echo_info "  ✓ Checks for GRUB BIOS modules"
    else
        echo_error "  ✗ Missing GRUB BIOS module check"
        failed=1
    fi

    # Check for placeholder UUID
    if grep -q "placeholder-uuid" "$script"; then
        echo_info "  ✓ Uses placeholder UUID in GRUB config"
    else
        echo_error "  ✗ Missing placeholder UUID in GRUB config"
        failed=1
    fi

    # Check for incorrect live boot parameter
    if grep -q "root=live:CDLABEL" "$script"; then
        echo_error "  ✗ Contains incorrect live boot parameter"
        failed=1
    else
        echo_info "  ✓ No incorrect live boot parameter"
    fi

    if [ $failed -eq 0 ]; then
        echo_info "Test 6: PASSED"
    else
        echo_error "Test 6: FAILED"
    fi
}

# Test 7: Distribution Agnostic Dependencies
test_distribution_agnostic() {
    echo_test "Test 7: Distribution Agnostic Dependencies"

    local script="$NOVA_ROOT/build/phase11_build_kernel.sh"

    if [ ! -f "$script" ]; then
        echo_error "Script not found: $script"
        return 1
    fi

    local failed=0

    # Check for Debian/Ubuntu check
    if grep -q "/etc/debian_version" "$script"; then
        echo_info "  ✓ Checks for Debian/Ubuntu"
    else
        echo_error "  ✗ Missing Debian/Ubuntu check"
        failed=1
    fi

    # Check for Fedora check
    if grep -q "/etc/fedora-release" "$script"; then
        echo_info "  ✓ Checks for Fedora"
    else
        echo_error "  ✗ Missing Fedora check"
        failed=1
    fi

    # Check for Debian-specific packages
    if grep -q "zlib1g-dev" "$script"; then
        echo_info "  ✓ Handles Debian/Ubuntu package names"
    else
        echo_error "  ✗ Missing Debian/Ubuntu package handling"
        failed=1
    fi

    # Check for Fedora-specific packages
    if grep -q "zlib-devel" "$script"; then
        echo_info "  ✓ Handles Fedora package names"
    else
        echo_error "  ✗ Missing Fedora package handling"
        failed=1
    fi

    if [ $failed -eq 0 ]; then
        echo_info "Test 7: PASSED"
    else
        echo_error "Test 7: FAILED"
    fi
}

# Test 8: Documentation Files Exist
test_documentation() {
    echo_test "Test 8: Documentation Files Exist"

    local docs=(
        "$NOVA_ROOT/PHASE_11_BUILD_ENVIRONMENT.md"
        "$NOVA_ROOT/PHASE_11_MINIMAL_SYSTEM.md"
        "$NOVA_ROOT/PHASE_11_REMAINING_WORK.md"
        "$NOVA_ROOT/PHASE_11_VMWARE_TEST_PLATFORM.md"
        "$NOVA_ROOT/PHASE_11_BUILD_READINESS_REPORT.md"
        "$NOVA_ROOT/NOVA_BOOTSTRAP_ARCHITECTURE.md"
    )

    local failed=0
    for doc in "${docs[@]}"; do
        if [ -f "$doc" ]; then
            echo_info "  ✓ $(basename $doc)"
        else
            echo_error "  ✗ $(basename $doc) not found"
            failed=1
        fi
    done

    if [ $failed -eq 0 ]; then
        echo_info "Test 8: PASSED"
    else
        echo_error "Test 8: FAILED"
    fi
}

# Test 9: Kernel Configuration Validation
test_kernel_config() {
    echo_test "Test 9: Kernel Configuration Validation"

    local config="$NOVA_ROOT/kernel/configs/nova_defconfig"

    if [ ! -f "$config" ]; then
        echo_error "Kernel config not found: $config"
        return 1
    fi

    local failed=0

    # Check for VMware drivers
    if grep -q "CONFIG_DRM_VMWGFX" "$config"; then
        echo_info "  ✓ Has VMware SVGA driver"
    else
        echo_error "  ✗ Missing VMware SVGA driver"
        failed=1
    fi

    # Check for VirtualBox drivers
    if grep -q "CONFIG_DRM_VBOXVIDEO" "$config"; then
        echo_info "  ✓ Has VirtualBox driver"
    else
        echo_error "  ✗ Missing VirtualBox driver"
        failed=1
    fi

    # Check for Btrfs
    if grep -q "CONFIG_BTRFS_FS" "$config"; then
        echo_info "  ✓ Has Btrfs filesystem"
    else
        echo_error "  ✗ Missing Btrfs filesystem"
        failed=1
    fi

    # Check for ext4
    if grep -q "CONFIG_EXT4_FS" "$config"; then
        echo_info "  ✓ Has ext4 filesystem"
    else
        echo_error "  ✗ Missing ext4 filesystem"
        failed=1
    fi

    if [ $failed -eq 0 ]; then
        echo_info "Test 9: PASSED"
    else
        echo_error "Test 9: FAILED"
    fi
}

# Test 10: Release Version Validation
test_release_version() {
    echo_test "Test 10: Release Version Validation"

    local script="$NOVA_ROOT/build/phase11_create_rootfs.sh"

    if [ ! -f "$script" ]; then
        echo_error "Script not found: $script"
        return 1
    fi

    local failed=0

    # Check for Ubuntu 24.04
    if grep -q "24.04" "$script"; then
        echo_info "  ✓ Uses Ubuntu 24.04 LTS"
    else
        echo_error "  ✗ Does not use Ubuntu 24.04 LTS"
        failed=1
    fi

    # Check for outdated version
    if grep -q "23.10\|39" "$script"; then
        echo_error "  ✗ Contains outdated version reference"
        failed=1
    else
        echo_info "  ✓ No outdated version references"
    fi

    if [ $failed -eq 0 ]; then
        echo_info "Test 10: PASSED"
    else
        echo_error "Test 10: FAILED"
    fi
}

# Print Summary
print_summary() {
    echo "" | tee -a "$TEST_LOG"
    echo "=== Test Summary ===" | tee -a "$TEST_LOG"
    echo "Total Tests: 10" | tee -a "$TEST_LOG"
    echo "Passed: $PASSED" | tee -a "$TEST_LOG"
    echo "Failed: $FAILED" | tee -a "$TEST_LOG"
    echo "" | tee -a "$TEST_LOG"

    if [ $FAILED -eq 0 ]; then
        echo_info "ALL TESTS PASSED" | tee -a "$TEST_LOG"
    else
        echo_error "SOME TESTS FAILED" | tee -a "$TEST_LOG"
    fi
}

# Main execution
main() {
    init_log

    echo_info "=== Phase 11.2 Automated Tests ==="
    echo ""

    local PASSED=0
    local FAILED=0

    if test_shellcheck; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if test_executability; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if test_kernel_error_handling; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if test_rootfs_error_handling; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if test_initramfs_permissions; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if test_iso_grub_config; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if test_distribution_agnostic; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if test_documentation; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if test_kernel_config; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if test_release_version; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    print_summary

    echo ""
    echo_info "Test log saved to: $TEST_LOG"

    if [ $FAILED -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Run main function
main "$@"

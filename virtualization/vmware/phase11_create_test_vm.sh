#!/bin/bash
# Phase 11: VMware Test VM Creation Script
# Creates a VMware Workstation VM for testing NOVA OS Phase 11 ISO

set -e

# Configuration
NOVA_ROOT="${NOVA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ISO_PATH="${NOVA_ROOT}/nova-os-phase11.iso"
VM_DIR="${NOVA_ROOT}/vmware-test"
VM_NAME="NOVA-OS-Phase11-Test"
DISK_SIZE="20G"
DISK_PATH="${VM_DIR}/${VM_NAME}-disk.vmdk"

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

    # Check for VMware Workstation
    if ! command -v vmware &> /dev/null; then
        echo_error "VMware Workstation not found in PATH"
        echo "Please install VMware Workstation Pro"
        echo "Download from: https://www.vmware.com/products/workstation-pro.html"
        exit 1
    fi

    echo_info "VMware Workstation found: $(vmware --version 2>/dev/null || echo 'version unknown')"

    # Check for vmware-vdiskmanager (for disk creation)
    if ! command -v vmware-vdiskmanager &> /dev/null; then
        echo_warn "vmware-vdiskmanager not found, will use VMware's built-in disk creation"
    fi

    # Check for ISO
    if [ ! -f "$ISO_PATH" ]; then
        echo_error "ISO not found: $ISO_PATH"
        echo "Please run build/phase11_create_iso.sh first"
        exit 1
    fi

    local iso_size=$(stat -c%s "$ISO_PATH" 2>/dev/null || stat -f%z "$ISO_PATH" 2>/dev/null)
    local iso_size_mb=$((iso_size / 1024 / 1024))
    echo_info "ISO found: $ISO_PATH (${iso_size_mb} MB)"
}

# Create VM directory
create_vm_directory() {
    echo_info "Creating VM directory: $VM_DIR"

    if [ -d "$VM_DIR" ]; then
        echo_warn "VM directory already exists, removing..."
        rm -rf "$VM_DIR"
    fi

    mkdir -p "$VM_DIR"
}

# Create virtual disk
create_virtual_disk() {
    echo_info "Creating virtual disk: $DISK_PATH (${DISK_SIZE})"

    # Try using vmware-vdiskmanager if available
    if command -v vmware-vdiskmanager &> /dev/null; then
        vmware-vdiskmanager -c -s "$DISK_SIZE" -a lsilogic -t 0 "$DISK_PATH"
    else
        # Fallback: create minimal VMDK header, VMware will create the actual disk
        echo_warn "Creating placeholder VMDK, VMware will create actual disk on first boot"
        cat > "$DISK_PATH" << 'EOF'
# Disk DescriptorFile
version=1
CID=fffffffe
parentCID=ffffffff
createType="sparse"

# Extent description
RW 41943040 SPARSE "nova-os-phase11-test-disk-flat.vmdk"

# The Disk Data Base
#DDB

ddb.adapterType = "lsilogic"
ddb.geometry.bios = "cylinders=0,heads=0,sectors=0"
ddb.geometry.biosOffset = "0"
ddb.virtualHWVersion = "21"
EOF
    fi

    echo_info "Virtual disk created"
}

# Generate VMX configuration
generate_vmx() {
    echo_info "Generating VMX configuration..."

    local vmx_file="${VM_DIR}/${VM_NAME}.vmx"

    cat > "$vmx_file" << EOF
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "21"
displayName = "${VM_NAME}"
guestOS = "other-64"
memsize = "4096"
numvcpus = "2"

# Firmware: UEFI
firmware = "efi"

# Video: VMware SVGA II (no 3D for initial tests)
svga.autodetect = "TRUE"
svga.vramSize = "134217728"
mks.enable3d = "FALSE"

# Storage: SATA (simpler than NVMe for initial tests)
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.fileName = "${DISK_PATH}"
sata0:0.deviceType = "scsi-hardDisk"

# CD/DVD: NOVA OS ISO
sata0:1.present = "TRUE"
sata0:1.fileName = "${ISO_PATH}"
sata0:1.deviceType = "cdrom-image"
sata0:1.autodetect = "TRUE"

# Network: e1000 (simpler than VMXNET3 for initial tests)
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "e1000"
ethernet0.wakeOnPktRcv = "FALSE"

# Audio: HD Audio
sound.present = "TRUE"
sound.virtualDev = "hdaudio"
sound.fileName = "-1"
sound.autodetect = "TRUE"

# USB Controller
usb.present = "TRUE"
ehci.present = "TRUE"

# General Settings
ehci:0.present = "TRUE"
ehci:0.deviceType = "ehci"
ehci:0.pcislotnumber = "34"

# Disable VMware Tools auto-upgrade
tools.upgrade.policy = "manual"

# Miscellaneous
uuid.location = "56 4d 58 43 54 58 4a 44-4d 8b 88 1e 1e 3e 2b 23 3e 8b"
uuid.bios = "56 4d 58 43 54 58 4a 44-4d 8b 88 1e 1e 3e 2b 23 3e 8b"
vc.pv = "FALSE"
checkpoint.vmState = ""
cleanShutdown = "TRUE"
softPowerOff = "TRUE"
extendedConfigFile = "${VM_NAME}.vmxf"
EOF

    echo_info "VMX configuration created: $vmx_file"
}

# Generate VMXF file (VMware extension)
generate_vmxf() {
    echo_info "Generating VMXF configuration..."

    local vmxf_file="${VM_DIR}/${VM_NAME}.vmxf"

    cat > "$vmxf_file" << EOF
<?xml version="1.0"?>
<VMWARETEAM type="Team" displayName="${VM_NAME}" version="1.0">
  <COLLABORATION/>
</VMWARETEAM>
EOF

    echo_info "VMXF configuration created: $vmxf_file"
}

# Print summary
print_summary() {
    echo ""
    echo_info "=== VMware Test VM Creation Complete ==="
    echo ""
    echo "VM Name: $VM_NAME"
    echo "VM Directory: $VM_DIR"
    echo "VMX File: ${VM_DIR}/${VM_NAME}.vmx"
    echo "ISO: $ISO_PATH"
    echo "Disk: $DISK_PATH"
    echo ""
    echo "VM Configuration:"
    echo "  CPUs: 2"
    echo "  RAM: 4 GB"
    echo "  Disk: $DISK_SIZE (SATA)"
    echo "  Network: e1000 (NAT)"
    echo "  Graphics: VMware SVGA II (no 3D)"
    echo "  Firmware: UEFI"
    echo ""
    echo "To start the VM, run:"
    echo "  vmware \"$VM_DIR/${VM_NAME}.vmx\""
    echo ""
    echo "Or open the VMX file in VMware Workstation:"
    echo "  File → Open → Select: $VM_DIR/${VM_NAME}.vmx"
    echo ""
}

# Main execution
main() {
    echo_info "=== NOVA OS Phase 11: VMware Test VM Creation ==="
    echo ""

    check_prerequisites
    create_vm_directory
    create_virtual_disk
    generate_vmx
    generate_vmxf
    print_summary

    echo_info "VM creation complete. Ready for testing."
}

# Run main function
main "$@"

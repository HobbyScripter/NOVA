#!/bin/bash
# Phase 11.3: System Prüfung für NOVA OS Build Environment
# Prüft Systemvoraussetzungen in Ubuntu 24.04 LTS VMware VM

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
REPORT_FILE="phase11_3_system_check.log"

echo "=== Phase 11.3: System Prüfung ===" > "$REPORT_FILE"
echo "Prüfungsdatum: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Test 1: Ubuntu-Version
test_ubuntu_version() {
    echo_header "Test 1: Ubuntu-Version"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo_info "Distribution: $NAME"
        echo_info "Version: $VERSION"
        echo_info "ID: $ID"
        echo_info "ID_LIKE: $ID_LIKE"

        echo "Distribution: $NAME" >> "$REPORT_FILE"
        echo "Version: $VERSION" >> "$REPORT_FILE"
        echo "ID: $ID" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        if [[ "$ID" == "ubuntu" ]]; then
            echo_info "✓ Ubuntu erkannt"
            if [[ "$VERSION_ID" == "24.04" ]]; then
                echo_info "✓ Ubuntu 24.04 LTS bestätigt"
            else
                echo_warn "⚠ Nicht Ubuntu 24.04 LTS (aktuell: $VERSION_ID)"
            fi
        else
            echo_error "✗ Kein Ubuntu System"
        fi
    else
        echo_error "✗ /etc/os-release nicht gefunden"
    fi
    echo ""
}

# Test 2: Kernelversion
test_kernel_version() {
    echo_header "Test 2: Kernelversion"

    local kernel_version=$(uname -r)
    local kernel_release=$(uname -v)

    echo_info "Kernel-Version: $kernel_version"
    echo_info "Kernel-Release: $kernel_release"

    echo "Kernel-Version: $kernel_version" >> "$REPORT_FILE"
    echo "Kernel-Release: $kernel_release" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    # Check if kernel is 6.x or newer
    local kernel_major=$(echo $kernel_version | cut -d. -f1)
    if [ "$kernel_major" -ge 6 ]; then
        echo_info "✓ Kernel ist 6.x oder neuer"
    else
        echo_warn "⚠ Kernel ist älter als 6.x (empfohlen: 6.x+)"
    fi
    echo ""
}

# Test 3: CPU und RAM
test_cpu_ram() {
    echo_header "Test 3: CPU und RAM"

    local cpu_cores=$(nproc)
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    local available_mem=$(free -g | awk '/^Mem:/{print $7}')

    echo_info "CPU-Kerne: $cpu_cores"
    echo_info "CPU-Modell: $cpu_model"
    echo_info "Gesamtspeicher: ${total_mem} GB"
    echo_info "Verfügbarer Speicher: ${available_mem} GB"

    echo "CPU-Kerne: $cpu_cores" >> "$REPORT_FILE"
    echo "CPU-Modell: $cpu_model" >> "$REPORT_FILE"
    echo "Gesamtspeicher: ${total_mem} GB" >> "$REPORT_FILE"
    echo "Verfügbarer Speicher: ${available_mem} GB" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    if [ "$cpu_cores" -ge 4 ]; then
        echo_info "✓ Mindestens 4 CPU-Kerne verfügbar"
    else
        echo_warn "⚠ Weniger als 4 CPU-Kerne (empfohlen: 4-6)"
    fi

    if [ "$total_mem" -ge 8 ]; then
        echo_info "✓ Mindestens 8 GB RAM verfügbar"
    else
        echo_error "✗ Weniger als 8 GB RAM (erforderlich: 8 GB)"
    fi
    echo ""
}

# Test 4: Freier Speicherplatz
test_disk_space() {
    echo_header "Test 4: Freier Speicherplatz"

    local root_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    local total_space=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')

    echo_info "Gesamtspeicher: ${total_space} GB"
    echo_info "Freier Speicher: ${root_space} GB"

    echo "Gesamtspeicher: ${total_space} GB" >> "$REPORT_FILE"
    echo "Freier Speicher: ${root_space} GB" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    if [ "$root_space" -ge 80 ]; then
        echo_info "✓ Mindestens 80 GB freier Speicher verfügbar"
    else
        echo_warn "⚠ Weniger als 80 GB freier Speicher (empfohlen: 80 GB+)"
    fi
    echo ""
}

# Test 5: Netzwerkverbindung
test_network() {
    echo_header "Test 5: Netzwerkverbindung"

    if ping -c 1 -W 2 kernel.org &> /dev/null; then
        echo_info "✓ Netzwerkverbindung zu kernel.org"
        echo "Netzwerk: Verbunden mit kernel.org" >> "$REPORT_FILE"
    else
        echo_error "✗ Keine Netzwerkverbindung zu kernel.org"
        echo "Netzwerk: Nicht verbunden" >> "$REPORT_FILE"
    fi

    if ping -c 1 -W 2 archive.ubuntu.com &> /dev/null; then
        echo_info "✓ Netzwerkverbindung zu Ubuntu Archive"
        echo "Ubuntu Archive: Verbunden" >> "$REPORT_FILE"
    else
        echo_error "✗ Keine Netzwerkverbindung zu Ubuntu Archive"
        echo "Ubuntu Archive: Nicht verbunden" >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
    echo ""
}

# Test 6: UEFI-Unterstützung
test_uefi() {
    echo_header "Test 6: UEFI-Unterstützung"

    if [ -d /sys/firmware/efi ]; then
        echo_info "✓ UEFI-Boot aktiviert"
        echo "UEFI: Aktiviert" >> "$REPORT_FILE"
    else
        echo_error "✗ System bootet im BIOS-Modus (UEFI empfohlen)"
        echo "UEFI: Nicht aktiviert" >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
    echo ""
}

# Test 7: System-Informationen
test_system_info() {
    echo_header "Test 7: System-Informationen"

    local hostname=$(hostname)
    local uptime=$(uptime -p)
    local loadavg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

    echo_info "Hostname: $hostname"
    echo_info "Uptime: $uptime"
    echo_info "Load Average: $loadavg"

    echo "Hostname: $hostname" >> "$REPORT_FILE"
    echo "Uptime: $uptime" >> "$REPORT_FILE"
    echo "Load Average: $loadavg" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo ""
}

# Main execution
main() {
    echo_info "=== Phase 11.3: System Prüfung für NOVA OS Build Environment ==="
    echo ""

    test_ubuntu_version
    test_kernel_version
    test_cpu_ram
    test_disk_space
    test_network
    test_uefi
    test_system_info

    echo_header "Prüfungsbericht"
    echo_info "Bericht gespeichert in: $REPORT_FILE"
    echo ""
    echo_info "Prüfung abgeschlossen. Bitte überprüfen Sie den Bericht."
}

# Run main function
main "$@"

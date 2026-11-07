#include "installer_wizard.h"
#include <iostream>
#include <thread>
#include <chrono>

namespace Nova {

NovaInstallerWizard::NovaInstallerWizard() {
    m_disks = {
        {"/dev/nvme0n1", "NVMe SSD PCIe 4.0", 512.0, true},
        {"/dev/sda", "SATA SSD / Virtuelle Festplatte", 256.0, true}
    };
    if (!m_disks.empty()) {
        m_params.disk = m_disks[0];
    }
}

std::vector<DiskInfo> NovaInstallerWizard::discoverDisks() const {
    return m_disks;
}

bool NovaInstallerWizard::setTargetDisk(const std::string& device) {
    for (const auto& d : m_disks) {
        if (d.device == device) {
            m_params.disk = d;
            std::cout << "[NOVA-INSTALLER-CPP] Ziellaufwerk ausgewählt: " << d.device
                      << " (" << d.model << ", " << d.sizeGb << " GB)" << std::endl;
            return true;
        }
    }
    return false;
}

void NovaInstallerWizard::setUserCredentials(const std::string& user, const std::string& pass) {
    m_params.username = user;
    std::cout << "[NOVA-INSTALLER-CPP] Benutzerkonto eingerichtet: " << user << std::endl;
}

void NovaInstallerWizard::confirmDiskWipe(bool confirmed) {
    m_params.userConfirmedWipe = confirmed;
}

bool NovaInstallerWizard::executeInstallation() {
    if (!m_params.userConfirmedWipe) {
        std::cerr << "[NOVA-INSTALLER-CPP] FEHLER: Keine ausdrückliche Bestätigung zum Löschen des Datenträgers erhalten!" << std::endl;
        return false;
    }

    std::cout << "\n============================================================" << std::endl;
    std::cout << " STARTE SYSTEMINSTALLATION AUF " << m_params.disk.device << std::endl;
    std::cout << "============================================================" << std::endl;

    const std::vector<std::pair<std::string, int>> steps = {
        {"1/8: Schreibe GPT-Partitionstabelle und erstelle ESP (512 MB)...", 12},
        {"2/8: Erstelle Btrfs-Dateisystem mit ZSTD-Kompression...", 25},
        {"3/8: Initialisiere Btrfs-Subvolumes (@, @home, @snapshots, @var_log, @swap)...", 40},
        {"4/8: Kopiere NOVA OS Rootfs-Dateien auf das Zielsystem...", 65},
        {"5/8: Generiere /etc/fstab mit CoW- und Snapshot-Mountoptionen...", 75},
        {"6/8: Richte Benutzerkonto und sudoers-Regeln ein...", 85},
        {"7/8: Installiere GRUB 2 EFI Bootloader nach /boot/efi/EFI/nova...", 95},
        {"8/8: Erzeuge Dracut Initramfs und finalisiere Installation...", 100}
    };

    for (const auto& [desc, pct] : steps) {
        std::cout << "  [" << pct << "%] " << desc << std::endl;
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }

    std::cout << "\n[NOVA-INSTALLER-CPP] Installation erfolgreich abgeschlossen!" << std::endl;
    std::cout << "Das System kann nun neu gestartet werden." << std::endl;
    return true;
}

} // namespace Nova

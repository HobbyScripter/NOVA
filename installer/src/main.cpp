#include "installer_wizard.h"
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << " NOVA OS Graphical Installer" << std::endl;
    std::cout << " Architecture: C++20 / Qt 6 / Btrfs" << std::endl;
    std::cout << "========================================" << std::endl;

    Nova::NovaInstallerWizard wizard;
    std::cout << "Gefundene Datenträger:" << std::endl;
    for (const auto& disk : wizard.discoverDisks()) {
        std::cout << "  - " << disk.device << ": " << disk.model << " (" << disk.sizeGb << " GB)" << std::endl;
    }

    wizard.setTargetDisk("/dev/nvme0n1");
    wizard.setUserCredentials("novadev", "secure123");
    wizard.confirmDiskWipe(true);

    bool ok = wizard.executeInstallation();
    return ok ? 0 : 1;
}

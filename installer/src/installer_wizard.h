#pragma once

#include <string>
#include <vector>

namespace Nova {

struct DiskInfo {
    std::string device;
    std::string model;
    double sizeGb;
    bool isSsd;
};

struct InstallParameters {
    DiskInfo disk;
    std::string filesystem{"btrfs"};
    bool useUefi{true};
    std::string username{"nova"};
    std::string hostname{"nova-pc"};
    std::string locale{"de_DE.UTF-8"};
    std::string timezone{"Europe/Berlin"};
    bool userConfirmedWipe{false};
};

class NovaInstallerWizard {
public:
    NovaInstallerWizard();
    ~NovaInstallerWizard() = default;

    std::vector<DiskInfo> discoverDisks() const;
    bool setTargetDisk(const std::string& device);
    void setUserCredentials(const std::string& user, const std::string& pass);
    void confirmDiskWipe(bool confirmed);

    bool executeInstallation();

private:
    InstallParameters m_params;
    std::vector<DiskInfo> m_disks;
};

} // namespace Nova

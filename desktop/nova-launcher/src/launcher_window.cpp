#include "launcher_window.h"
#include <iostream>
#include <algorithm>

namespace Nova {

static std::string toLower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::tolower(c); });
    return s;
}

NovaLauncherWindow::NovaLauncherWindow() {
    initApplications();
}

void NovaLauncherWindow::initApplications() {
    m_apps = {
        {"org.nova.files", "NOVA Files", "System", "nova-files", "system-file-manager", {"dateien", "btrfs", "ordner"}},
        {"org.nova.settings", "Systemeinstellungen", "Settings", "nova-settings", "preferences-system", {"audio", "display", "netzwerk"}},
        {"org.nova.store", "NOVA Store", "System", "nova-store", "system-software-install", {"apps", "rpm", "flatpak"}},
        {"org.nova.update", "NOVA Update", "System", "nova-update", "system-software-update", {"kernel", "upgrade"}},
        {"org.nova.recovery", "NOVA Recovery", "System", "nova-recovery", "system-reboot", {"snapshot", "rollback"}},
        {"org.nova.hardware", "NOVA Hardware-Info", "System", "nova-hardware", "cpu", {"cpu", "gpu", "ram"}},
        {"org.nova.driver", "NOVA Treibermanager", "System", "nova-driver", "video-display", {"nvidia", "amd", "intel"}},
        {"org.nova.terminal", "NOVA Terminal", "Development", "nova-terminal", "utilities-terminal", {"bash", "konsole"}},
        {"org.nova.text", "NOVA Texteditor", "Productivity", "nova-text", "accessories-text-editor", {"code", "notizen"}}
    };
}

std::vector<ApplicationItem> NovaLauncherWindow::search(const std::string& query) const {
    if (query.empty()) return m_apps;
    std::string q = toLower(query);
    std::vector<ApplicationItem> results;

    for (const auto& app : m_apps) {
        if (toLower(app.name).find(q) != std::string::npos ||
            toLower(app.category).find(q) != std::string::npos) {
            results.push_back(app);
            continue;
        }
        for (const auto& kw : app.keywords) {
            if (toLower(kw).find(q) != std::string::npos) {
                results.push_back(app);
                break;
            }
        }
    }
    return results;
}

std::vector<ApplicationItem> NovaLauncherWindow::getByCategory(const std::string& category) const {
    std::string cat = toLower(category);
    std::vector<ApplicationItem> results;
    for (const auto& app : m_apps) {
        if (toLower(app.category) == cat) {
            results.push_back(app);
        }
    }
    return results;
}

void NovaLauncherWindow::launch(const std::string& appId) const {
    for (const auto& app : m_apps) {
        if (app.id == appId) {
            std::cout << "[NOVA-LAUNCHER] Starte Anwendung via D-Bus / posix_spawn: " << app.exec << std::endl;
            return;
        }
    }
}

} // namespace Nova


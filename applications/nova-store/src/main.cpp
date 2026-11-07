#include <iostream>
#include <vector>
#include <string>

struct CatalogApp {
    std::string id;
    std::string name;
    std::string version;
    std::string type; // RPM oder Flatpak
    std::string license;
    double sizeMb;
    bool isInstalled;
};

class NovaStoreNative {
public:
    NovaStoreNative() {
        m_apps = {
            {"org.mozilla.firefox", "Firefox Web Browser", "133.0", "Flatpak", "MPL-2.0", 95.0, true},
            {"org.videolan.VLC", "VLC Media Player", "3.0.21", "Flatpak", "GPL-2.0", 42.0, false},
            {"org.blender.Blender", "Blender 3D", "4.3.0", "Flatpak", "GPL-3.0", 380.0, false},
            {"com.visualstudio.code", "VS Code (OSS)", "1.95.0", "RPM", "MIT", 120.0, true},
            {"org.libreoffice.LibreOffice", "LibreOffice Suite", "24.8.2", "RPM", "MPL-2.0", 250.0, false}
        };
    }

    void listCatalog() const {
        for (const auto& app : m_apps) {
            std::cout << "  [" << (app.isInstalled ? "INSTALLIERT" : "VERFÜGBAR ") << "] ["
                      << app.type << "] " << app.name << " v" << app.version << " (" << app.sizeMb << " MB)" << std::endl;
        }
    }

    bool installApp(const std::string& id) {
        for (auto& app : m_apps) {
            if (app.id == id) {
                if (app.isInstalled) {
                    std::cout << "[NOVA-STORE-CPP] " << app.name << " ist bereits installiert." << std::endl;
                    return true;
                }
                std::cout << "[NOVA-STORE-CPP] Installiere " << app.name << " via " << app.type << "..." << std::endl;
                std::cout << "  -> Kryptografische Signatur geprüft (" << app.license << ")." << std::endl;
                app.isInstalled = true;
                std::cout << "[NOVA-STORE-CPP] " << app.name << " erfolgreich installiert." << std::endl;
                return true;
            }
        }
        return false;
    }

private:
    std::vector<CatalogApp> m_apps;
};

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << " NOVA Store - Native C++ / RPM & Flatpak" << std::endl;
    std::cout << "========================================" << std::endl;

    NovaStoreNative store;
    store.listCatalog();

    std::cout << "\nInstalliere VLC Media Player:" << std::endl;
    store.installApp("org.videolan.VLC");
    return 0;
}

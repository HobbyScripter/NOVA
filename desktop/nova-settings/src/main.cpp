#include "settings_window.h"
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << " NOVA Settings - Control Panel" << std::endl;
    std::cout << " Architecture: C++20 / Qt 6 / Wayland" << std::endl;
    std::cout << "========================================" << std::endl;

    Nova::NovaSettingsWindow settings;
    settings.printOverview();

    std::cout << "\nÄndere Einstellungen..." << std::endl;
    settings.setResolution("2560x1440", 1.25);
    settings.setVolume(85);
    settings.setPowerProfile("performance");
    settings.setThemeMode(Nova::ThemeMode::Light);

    std::cout << "\nAktualisierte Übersicht:" << std::endl;
    settings.printOverview();
    return 0;
}

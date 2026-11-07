#include "launcher_window.h"
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << " NOVA Launcher - Application Navigation" << std::endl;
    std::cout << " Architecture: C++20 / Qt 6 / Wayland" << std::endl;
    std::cout << "========================================" << std::endl;

    Nova::NovaLauncherWindow launcher;
    std::cout << "Suche nach 'kernel':" << std::endl;
    for (const auto& app : launcher.search("kernel")) {
        std::cout << "  -> " << app.name << " (" << app.category << ") [" << app.exec << "]" << std::endl;
    }

    std::cout << "\nKategorie 'Development':" << std::endl;
    for (const auto& app : launcher.getByCategory("Development")) {
        std::cout << "  -> " << app.name << " [" << app.exec << "]" << std::endl;
    }

    launcher.launch("org.nova.terminal");
    return 0;
}

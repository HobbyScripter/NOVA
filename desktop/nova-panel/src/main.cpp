#include "panel_window.h"
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << " NOVA Panel - Wayland Top/Bottom Bar" << std::endl;
    std::cout << " Architecture: C++20 / Qt 6 / Wayland" << std::endl;
    std::cout << "========================================" << std::endl;

    Nova::NovaPanelWindow panel(44);

    std::vector<Nova::TaskbarItem> items = {
        {1001, "NOVA Files", "org.nova.files", true},
        {1002, "Systemeinstellungen", "org.nova.settings", false},
        {1003, "NOVA Terminal", "org.nova.terminal", false}
    };

    panel.updateTaskbar(items);
    panel.setWorkspace(1);
    panel.render();

    return 0;
}


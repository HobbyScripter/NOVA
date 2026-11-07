#include "nova_compositor.h"
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << " NOVA Compositor - Wayland Display Server" << std::endl;
    std::cout << " Architecture: C++ / wlroots / Qt 6" << std::endl;
    std::cout << "========================================" << std::endl;

    Nova::NovaCompositor compositor;
    if (!compositor.initialize()) {
        std::cerr << "Fehler bei der Initialisierung des Compositors!" << std::endl;
        return 1;
    }

    uint32_t shellWin = compositor.createWindow("org.nova.shell", "NOVA Shell", 1920, 1080);
    uint32_t panelWin = compositor.createWindow("org.nova.panel", "NOVA Panel", 1920, 48);

    std::cout << "[NOVA-COMPOSITOR] Desktop-Surfaces aktiv. Ereignisschleife läuft." << std::endl;
    return 0;
}


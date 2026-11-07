#include "panel_window.h"
#include <iostream>
#include <ctime>
#include <iomanip>
#include <sstream>

namespace Nova {

NovaPanelWindow::NovaPanelWindow(int height)
    : m_height(height) {
    refreshTray();
}

void NovaPanelWindow::updateTaskbar(const std::vector<TaskbarItem>& items) {
    m_taskbar = items;
}

void NovaPanelWindow::setWorkspace(int ws) {
    m_currentWorkspace = ws;
}

void NovaPanelWindow::refreshTray() {
    auto now = std::chrono::system_clock::now();
    std::time_t now_c = std::chrono::system_clock::to_time_t(now);
    std::tm* tm_ptr = std::localtime(&now_c);

    std::ostringstream oss;
    oss << std::put_time(tm_ptr, "%H:%M  %d.%m.%Y");
    m_tray.timeString = oss.str();
}

void NovaPanelWindow::render() const {
    std::cout << "[NOVA-PANEL] Rendere Wayland Layer-Shell Surface (Höhe: " << m_height << "px)..." << std::endl;
    std::cout << "  Workspace: [" << m_currentWorkspace << "/4]" << std::endl;
    std::cout << "  Taskbar Einträge: ";
    if (m_taskbar.empty()) {
        std::cout << "(keine aktiven Fenster)";
    } else {
        for (const auto& item : m_taskbar) {
            std::cout << "[" << (item.isActive ? "*" : "") << item.title << "] ";
        }
    }
    std::cout << std::endl;
    std::cout << "  System-Tray: " << m_tray.networkStatus << " | " << m_tray.audioStatus
              << " | " << m_tray.batteryStatus << " | " << m_tray.timeString << std::endl;
}

} // namespace Nova

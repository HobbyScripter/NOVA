#pragma once

#include <string>
#include <vector>
#include <chrono>
#include "nova/libnova.h"

namespace Nova {

struct TaskbarItem {
    uint32_t windowId;
    std::string title;
    std::string appId;
    bool isActive{false};
};

struct SystemTrayState {
    std::string networkStatus{"Ethernet Connected (1000 Mbps)"};
    std::string audioStatus{"PipeWire (75%)"};
    std::string batteryStatus{"AC Connected"};
    std::string timeString;
};

class NovaPanelWindow {
public:
    NovaPanelWindow(int height = 44);
    ~NovaPanelWindow() = default;

    void updateTaskbar(const std::vector<TaskbarItem>& items);
    void setWorkspace(int ws);
    int currentWorkspace() const { return m_currentWorkspace; }

    void refreshTray();
    const SystemTrayState& trayState() const { return m_tray; }
    const std::vector<TaskbarItem>& taskbarItems() const { return m_taskbar; }

    void render() const;

private:
    int m_height;
    int m_currentWorkspace{1};
    std::vector<TaskbarItem> m_taskbar;
    SystemTrayState m_tray;
};

} // namespace Nova

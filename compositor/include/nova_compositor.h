#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include "nova/libnova.h"

namespace Nova {

class Workspace {
public:
    explicit Workspace(int id, const std::string& name);
    int id() const { return m_id; }
    std::string name() const { return m_name; }

    void addWindow(uint32_t windowId);
    void removeWindow(uint32_t windowId);
    const std::vector<uint32_t>& windows() const { return m_windows; }

private:
    int m_id;
    std::string m_name;
    std::vector<uint32_t> m_windows;
};

class NovaCompositor {
public:
    NovaCompositor();
    ~NovaCompositor();

    bool initialize(const std::string& socketName = "wayland-nova-0");
    void shutdown();

    // Output & Resolution Management (wlr-output)
    void addOutput(const OutputDisplay& output);
    void setOutputResolution(const std::string& name, int width, int height, double scale = 1.0);
    const std::vector<OutputDisplay>& outputs() const { return m_outputs; }

    // Window Management (xdg-shell)
    uint32_t createWindow(const std::string& appId, const std::string& title, int width, int height);
    void closeWindow(uint32_t windowId);
    void focusWindow(uint32_t windowId);
    void minimizeWindow(uint32_t windowId);
    void moveWindow(uint32_t windowId, int x, int y);

    // Workspace & Virtual Desktops
    void switchToWorkspace(int workspaceId);
    int currentWorkspace() const { return m_currentWorkspace; }
    size_t workspaceCount() const { return m_workspaces.size(); }

    // State Inspection
    bool isRunning() const { return m_running; }
    const std::map<uint32_t, WindowMetadata>& windows() const { return m_windows; }

private:
    bool m_running{false};
    std::string m_socketName;
    std::vector<OutputDisplay> m_outputs;
    std::vector<std::unique_ptr<Workspace>> m_workspaces;
    int m_currentWorkspace{1};
    std::map<uint32_t, WindowMetadata> m_windows;
    uint32_t m_nextWindowId{1001};
};

} // namespace Nova


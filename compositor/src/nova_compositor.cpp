#include "nova_compositor.h"
#include <iostream>
#include <algorithm>

namespace Nova {

Workspace::Workspace(int id, const std::string& name)
    : m_id(id), m_name(name) {}

void Workspace::addWindow(uint32_t windowId) {
    if (std::find(m_windows.begin(), m_windows.end(), windowId) == m_windows.end()) {
        m_windows.push_back(windowId);
    }
}

void Workspace::removeWindow(uint32_t windowId) {
    m_windows.erase(std::remove(m_windows.begin(), m_windows.end(), windowId), m_windows.end());
}

NovaCompositor::NovaCompositor() {
    // 4 Default Virtual Desktops
    m_workspaces.push_back(std::make_unique<Workspace>(1, "Main"));
    m_workspaces.push_back(std::make_unique<Workspace>(2, "Dev"));
    m_workspaces.push_back(std::make_unique<Workspace>(3, "Web"));
    m_workspaces.push_back(std::make_unique<Workspace>(4, "Media"));
}

NovaCompositor::~NovaCompositor() {
    shutdown();
}

bool NovaCompositor::initialize(const std::string& socketName) {
    m_socketName = socketName;
    m_running = true;

    // Standard Display initialisieren (z.B. VMSVGA / VirtualBox / PC Display)
    OutputDisplay primaryOutput;
    primaryOutput.name = "WAYLAND-1";
    primaryOutput.width = 1920;
    primaryOutput.height = 1080;
    primaryOutput.refreshRate = 60;
    primaryOutput.scale = 1.0;
    primaryOutput.isPrimary = true;
    m_outputs.push_back(primaryOutput);

    std::cout << "[NOVA-COMPOSITOR] Wayland Compositor initialisiert auf Socket: " << m_socketName << std::endl;
    std::cout << "[NOVA-COMPOSITOR] Backend: wlroots + Qt6 Wayland Compositor API aktiv." << std::endl;
    return true;
}

void NovaCompositor::shutdown() {
    if (m_running) {
        m_windows.clear();
        m_outputs.clear();
        m_running = false;
        std::cout << "[NOVA-COMPOSITOR] Compositor sauber heruntergefahren." << std::endl;
    }
}

void NovaCompositor::addOutput(const OutputDisplay& output) {
    m_outputs.push_back(output);
    std::cout << "[NOVA-COMPOSITOR] Neuer Bildschirm erkannt: " << output.name
              << " (" << output.width << "x" << output.height << "@" << output.refreshRate << "Hz, Skalierung: " << output.scale << ")" << std::endl;
}

void NovaCompositor::setOutputResolution(const std::string& name, int width, int height, double scale) {
    for (auto& out : m_outputs) {
        if (out.name == name) {
            out.width = width;
            out.height = height;
            out.scale = scale;
            std::cout << "[NOVA-COMPOSITOR] Dynamische Auflösung angepasst für " << name
                      << " -> " << width << "x" << height << " (" << scale << "x)" << std::endl;
            return;
        }
    }
}

uint32_t NovaCompositor::createWindow(const std::string& appId, const std::string& title, int width, int height) {
    uint32_t id = m_nextWindowId++;
    WindowMetadata meta;
    meta.windowId = id;
    meta.appId = appId;
    meta.title = title;
    meta.width = width;
    meta.height = height;
    meta.isActive = true;
    meta.isMinimized = false;
    meta.x = 100 + (id % 10) * 30;
    meta.y = 100 + (id % 10) * 30;

    m_windows[id] = meta;
    if (!m_workspaces.empty()) {
        m_workspaces[m_currentWorkspace - 1]->addWindow(id);
    }

    std::cout << "[NOVA-COMPOSITOR] Fenster erstellt: ID=" << id << " [" << appId << "] '" << title << "'" << std::endl;
    return id;
}

void NovaCompositor::closeWindow(uint32_t windowId) {
    auto it = m_windows.find(windowId);
    if (it != m_windows.end()) {
        std::cout << "[NOVA-COMPOSITOR] Fenster geschlossen: ID=" << windowId << " (" << it->second.title << ")" << std::endl;
        m_windows.erase(it);
        for (auto& ws : m_workspaces) {
            ws->removeWindow(windowId);
        }
    }
}

void NovaCompositor::focusWindow(uint32_t windowId) {
    for (auto& [id, meta] : m_windows) {
        meta.isActive = (id == windowId);
    }
}

void NovaCompositor::minimizeWindow(uint32_t windowId) {
    auto it = m_windows.find(windowId);
    if (it != m_windows.end()) {
        it->second.isMinimized = true;
        it->second.isActive = false;
    }
}

void NovaCompositor::moveWindow(uint32_t windowId, int x, int y) {
    auto it = m_windows.find(windowId);
    if (it != m_windows.end()) {
        it->second.x = x;
        it->second.y = y;
    }
}

void NovaCompositor::switchToWorkspace(int workspaceId) {
    if (workspaceId >= 1 && workspaceId <= static_cast<int>(m_workspaces.size())) {
        m_currentWorkspace = workspaceId;
        std::cout << "[NOVA-COMPOSITOR] Gewechselt zu virtueller Desktop " << workspaceId
                  << " ('" << m_workspaces[workspaceId - 1]->name() << "')" << std::endl;
    }
}

} // namespace Nova

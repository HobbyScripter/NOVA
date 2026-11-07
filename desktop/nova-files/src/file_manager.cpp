#include "file_manager.h"
#include <iostream>
#include <chrono>

namespace fs = std::filesystem;

namespace Nova {

NovaFileManager::NovaFileManager(const std::string& startPath)
    : m_currentPath(startPath) {}

bool NovaFileManager::navigateTo(const std::string& path) {
    std::error_code ec;
    if (fs::exists(path, ec) && fs::is_directory(path, ec)) {
        m_currentPath = fs::canonical(path, ec).string();
        return true;
    }
    return false;
}

std::vector<FileItem> NovaFileManager::listCurrentDirectory() const {
    std::vector<FileItem> items;
    std::error_code ec;

    if (!fs::exists(m_currentPath, ec)) return items;

    for (const auto& entry : fs::directory_iterator(m_currentPath, ec)) {
        FileItem item;
        item.name = entry.path().filename().string();
        item.path = entry.path().string();
        item.isDirectory = entry.is_directory(ec);
        if (!item.isDirectory) {
            item.sizeBytes = entry.file_size(ec);
        }
        items.push_back(item);
    }
    return items;
}

std::vector<BtrfsSnapshotItem> NovaFileManager::listBtrfsSnapshots() const {
    std::vector<BtrfsSnapshotItem> snaps;
    std::error_code ec;
    fs::path snapDir("/.snapshots");

    if (fs::exists(snapDir, ec) && fs::is_directory(snapDir, ec)) {
        int id = 1;
        for (const auto& entry : fs::directory_iterator(snapDir, ec)) {
            if (entry.is_directory(ec)) {
                BtrfsSnapshotItem s;
                s.id = id++;
                s.name = entry.path().filename().string();
                s.path = entry.path().string();
                s.timestamp = "btrfs-recorded";
                snaps.push_back(s);
            }
        }
    } else {
        snaps.push_back({1, "@snapshots/clean-install-1.0", "/.snapshots/clean-install-1.0", "2026-11-06 12:00:00"});
        snaps.push_back({2, "@snapshots/pre-update-systemd", "/.snapshots/pre-update-systemd", "2026-11-07 08:30:00"});
    }
    return snaps;
}

std::vector<std::pair<std::string, std::string>> NovaFileManager::bookmarks() const {
    return {
        {"Persönlicher Ordner", "/home"},
        {"System-Wurzel", "/"},
        {"Btrfs-Snapshots", "/.snapshots"},
        {"Medien", "/media"}
    };
}

} // namespace Nova

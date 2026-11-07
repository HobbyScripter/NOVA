#pragma once

#include <string>
#include <vector>
#include <filesystem>

namespace Nova {

struct FileItem {
    std::string name;
    std::string path;
    bool isDirectory{false};
    uintmax_t sizeBytes{0};
    std::string modifiedTime;
};

struct BtrfsSnapshotItem {
    int id;
    std::string name;
    std::string path;
    std::string timestamp;
};

class NovaFileManager {
public:
    NovaFileManager(const std::string& startPath = ".");
    ~NovaFileManager() = default;

    std::vector<FileItem> listCurrentDirectory() const;
    bool navigateTo(const std::string& path);
    std::string currentPath() const { return m_currentPath; }

    std::vector<BtrfsSnapshotItem> listBtrfsSnapshots() const;
    std::vector<std::pair<std::string, std::string>> bookmarks() const;

private:
    std::string m_currentPath;
};

} // namespace Nova

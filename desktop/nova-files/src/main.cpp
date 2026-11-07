#include "file_manager.h"
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << " NOVA Files - File Manager & Btrfs Navigator" << std::endl;
    std::cout << " Architecture: C++20 / Qt 6 / Btrfs API" << std::endl;
    std::cout << "========================================" << std::endl;

    Nova::NovaFileManager fm(".");
    std::cout << "Aktueller Pfad: " << fm.currentPath() << std::endl;

    std::cout << "\nLesezeichen:" << std::endl;
    for (const auto& [label, path] : fm.bookmarks()) {
        std::cout << "  - " << label << " -> " << path << std::endl;
    }

    std::cout << "\nBtrfs-Snapshots (Zeitreise-Navigation):" << std::endl;
    for (const auto& snap : fm.listBtrfsSnapshots()) {
        std::cout << "  [Snapshot #" << snap.id << "] " << snap.name << " (" << snap.timestamp << ")" << std::endl;
    }

    std::cout << "\nInhalt des Arbeitsverzeichnisses (Erste 5 Einträge):" << std::endl;
    auto items = fm.listCurrentDirectory();
    size_t count = 0;
    for (const auto& item : items) {
        if (count++ >= 5) break;
        std::cout << "  [" << (item.isDirectory ? "DIR " : "FILE") << "] " << item.name
                  << " (" << item.sizeBytes << " Bytes)" << std::endl;
    }

    return 0;
}

#!/usr/bin/env python3
"""
NOVA Launcher - Application Search & Category Navigator
Durchsucht installierte Applikationen (.desktop), bietet Schnellsuche und Kategorien.
"""

import sys
from pathlib import Path
from typing import Dict, List, Any

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(WORKSPACE_ROOT))

class ApplicationEntry:
    def __init__(self, app_id: str, name: str, category: str, exec_cmd: str, icon: str, keywords: List[str]):
        self.app_id = app_id
        self.name = name
        self.category = category
        self.exec_cmd = exec_cmd
        self.icon = icon
        self.keywords = keywords

class NovaLauncher:
    def __init__(self):
        self.apps = self._load_default_applications()

    def _load_default_applications(self) -> List[ApplicationEntry]:
        return [
            ApplicationEntry("org.nova.files", "NOVA Files", "System", "nova-files", "system-file-manager", ["dateien", "btrfs", "explorer", "ordner"]),
            ApplicationEntry("org.nova.settings", "Systemeinstellungen", "Settings", "nova-settings", "preferences-system", ["einstellungen", "netzwerk", "audio", "display"]),
            ApplicationEntry("org.nova.store", "NOVA Store", "System", "nova-store", "system-software-install", ["software", "apps", "flatpak", "rpm", "installieren"]),
            ApplicationEntry("org.nova.update", "NOVA Update", "System", "nova-update", "system-software-update", ["update", "aktualisieren", "kernel", "upgrade"]),
            ApplicationEntry("org.nova.recovery", "NOVA Recovery", "System", "nova-recovery", "system-reboot", ["recovery", "rollback", "btrfs", "snapshot", "wiederherstellung"]),
            ApplicationEntry("org.nova.hardware", "NOVA Hardware-Info", "System", "nova-hardware", "cpu", ["cpu", "gpu", "ram", "festplatte", "info"]),
            ApplicationEntry("org.nova.driver", "NOVA Treibermanager", "System", "nova-driver", "video-display", ["treiber", "nvidia", "amd", "intel"]),
            ApplicationEntry("org.nova.terminal", "NOVA Terminal", "Development", "nova-terminal", "utilities-terminal", ["konsole", "bash", "shell", "cmd"]),
            ApplicationEntry("org.nova.text", "NOVA Texteditor", "Productivity", "nova-text", "accessories-text-editor", ["notizen", "code", "editor"])
        ]

    def search(self, query: str) -> List[Dict[str, Any]]:
        """Fuzzy Suche über App-Namen, IDs und Schlüsselwörter."""
        q = query.lower().strip()
        if not q:
            return [{"id": a.app_id, "name": a.name, "category": a.category, "icon": a.icon} for a in self.apps]

        matches = []
        for a in self.apps:
            score = 0
            if q == a.name.lower():
                score += 100
            elif q in a.name.lower():
                score += 50
            elif any(q in kw for kw in a.keywords):
                score += 30
            elif q in a.category.lower():
                score += 10

            if score > 0:
                matches.append((score, {"id": a.app_id, "name": a.name, "category": a.category, "icon": a.icon, "exec": a.exec_cmd}))

        matches.sort(key=lambda x: x[0], reverse=True)
        return [m[1] for m in matches]

    def get_by_category(self, category: str) -> List[Dict[str, Any]]:
        return [
            {"id": a.app_id, "name": a.name, "icon": a.icon, "exec": a.exec_cmd}
            for a in self.apps if a.category.lower() == category.lower()
        ]

def main() -> int:
    launcher = NovaLauncher()
    print("=" * 60)
    print(" NOVA Launcher - Schnellsuche & Kategorien")
    print("=" * 60)
    print("Suche nach 'update':")
    for r in launcher.search("update"):
        print(f"  -> {r['name']} ({r['category']}) [{r['exec']}]")

    print("\nSuche nach 'btrfs':")
    for r in launcher.search("btrfs"):
        print(f"  -> {r['name']} ({r['category']}) [{r['exec']}]")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())

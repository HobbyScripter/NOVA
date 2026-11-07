#!/usr/bin/env python3
"""
NOVA OS - Stage 0: Host Environment Validator
Prüft die Verfügbarkeit notwendiger Build-Tools, Systemressourcen und Pfade.
"""

import sys
import os
import shutil
import platform
import json
import shutil
from pathlib import Path
from typing import Dict, List, Any, Tuple

REQUIRED_TOOLS = [
    ("git", "2.30.0"),
    ("python3", "3.10.0"),
    ("cmake", "3.20.0"),
]

OPTIONAL_TOOLS = [
    ("gcc", "12.0.0"),
    ("clang", "15.0.0"),
    ("make", "4.3"),
    ("ninja", "1.10.0"),
    ("rustc", "1.75.0"),
    ("cargo", "1.75.0"),
    ("VBoxManage", "7.0.0"),
    ("qemu-system-x86_64", "7.0.0"),
]

MIN_DISK_SPACE_GB = 15.0

def get_disk_free_gb(path: str = ".") -> float:
    total, used, free = shutil.disk_usage(path)
    return free / (1024 ** 3)

def check_command_exists(cmd: str) -> Tuple[bool, str]:
    loc = shutil.which(cmd)
    if loc:
        return True, loc
    # On Windows also check .exe
    if platform.system() == "Windows":
        loc_exe = shutil.which(f"{cmd}.exe")
        if loc_exe:
            return True, loc_exe
        # Check standard paths for VirtualBox
        if cmd == "VBoxManage":
            vbox_path = r"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
            if os.path.exists(vbox_path):
                return True, vbox_path
    return False, ""

def validate_host_environment() -> Dict[str, Any]:
    results: Dict[str, Any] = {
        "os": platform.system(),
        "os_release": platform.release(),
        "arch": platform.machine(),
        "python_version": platform.python_version(),
        "disk_free_gb": round(get_disk_free_gb(), 2),
        "disk_sufficient": get_disk_free_gb() >= MIN_DISK_SPACE_GB,
        "required_tools": {},
        "optional_tools": {},
        "overall_success": True,
        "warnings": [],
        "errors": []
    }

    # Check required tools
    for tool, min_ver in REQUIRED_TOOLS:
        cmd = "python" if tool == "python3" and platform.system() == "Windows" else tool
        found, path = check_command_exists(cmd)
        results["required_tools"][tool] = {"found": found, "path": path, "min_version": min_ver}
        if not found:
            results["overall_success"] = False
            results["errors"].append(f"Erforderliches Werkzeug '{tool}' nicht im PATH gefunden.")

    # Check optional tools
    for tool, min_ver in OPTIONAL_TOOLS:
        found, path = check_command_exists(tool)
        results["optional_tools"][tool] = {"found": found, "path": path, "min_version": min_ver}
        if not found:
            results["warnings"].append(f"Optionales Werkzeug '{tool}' nicht gefunden. Manche Tests/Buildschritte könnten eingeschränkt sein.")

    # Check disk space
    if not results["disk_sufficient"]:
        results["overall_success"] = False
        results["errors"].append(f"Ungenügender freier Festplattenspeicher: {results['disk_free_gb']} GB verfügbar, {MIN_DISK_SPACE_GB} GB erforderlich.")

    return results

def main() -> int:
    print("=" * 60)
    print(" PROJECT NOVA OS - Stage 0: Host-Umgebungsvalidierung")
    print("=" * 60)

    report = validate_host_environment()
    print(f"Betriebssystem   : {report['os']} ({report['arch']})")
    print(f"Python-Version   : {report['python_version']}")
    print(f"Freier Speicher  : {report['disk_free_gb']} GB (Min: {MIN_DISK_SPACE_GB} GB)")
    print("-" * 60)
    print("Erforderliche Werkzeuge:")
    for tool, data in report["required_tools"].items():
        status = "OK" if data["found"] else "FEHLT"
        print(f"  [{status}] {tool:15} -> {data['path']}")

    print("-" * 60)
    print("Optionale Werkzeuge / Hypervisoren:")
    for tool, data in report["optional_tools"].items():
        status = "OK" if data["found"] else "FEHLT"
        print(f"  [{status}] {tool:18} -> {data['path']}")

    print("=" * 60)
    if report["errors"]:
        print("FEHLER:")
        for err in report["errors"]:
            print(f"  - {err}")

    if report["warnings"]:
        print("HINWEISE:")
        for warn in report["warnings"]:
            print(f"  - {warn}")

    print("=" * 60)
    status_str = "ERFOLGREICH" if report["overall_success"] else "FEHLGESCHLAGEN"
    print(f"Gesamtstatus Stage 0: {status_str}")

    # Write report file
    report_path = Path("bootstrap/stage0/host_report.json")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    return 0 if report["overall_success"] else 1

if __name__ == "__main__":
    sys.exit(main())


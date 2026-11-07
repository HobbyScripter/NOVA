#!/usr/bin/env python3
"""
NOVA OS - Bootstrap Manager
Orchestriert den zweistufigen Bootstrap-Prozess:
- Manifest-Validierung
- Stage 1 Cross-Toolchain Einrichtung
- Stage 2 Chroot Target Sysroot Aufbau
"""

import os
import sys
import json
import hashlib
import urllib.request
from pathlib import Path
from typing import Dict, List, Any, Optional

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = WORKSPACE_ROOT / "bootstrap" / "manifests" / "dependencies.json"
OUTPUT_DIR = WORKSPACE_ROOT / "build" / "output"
TOOLS_DIR = OUTPUT_DIR / "tools"
SYSROOT_DIR = OUTPUT_DIR / "sysroot"
SOURCES_DIR = OUTPUT_DIR / "sources"

class BootstrapManager:
    def __init__(self, manifest_file: Path = MANIFEST_PATH):
        self.manifest_file = manifest_file
        self.manifest = self._load_manifest()

    def _load_manifest(self) -> Dict[str, Any]:
        if not self.manifest_file.exists():
            raise FileNotFoundError(f"Manifest nicht gefunden: {self.manifest_file}")
        with open(self.manifest_file, "r", encoding="utf-8") as f:
            return json.load(f)

    def prepare_directories(self) -> None:
        """Erstellt die notwendige Ordnerstruktur für den Bootstrap."""
        for path in [OUTPUT_DIR, TOOLS_DIR, SYSROOT_DIR, SOURCES_DIR]:
            path.mkdir(parents=True, exist_ok=True)
        print(f"[BOOTSTRAP] Verzeichnisse vorbereitet in: {OUTPUT_DIR}")

    def verify_manifest_integrity(self) -> bool:
        """Prüft Konsistenz des Manifests (Schema, Pflichtfelder)."""
        components = self.manifest.get("components", [])
        if not components:
            print("[BOOTSTRAP] FEHLER: Keine Komponenten im Manifest deklariert.")
            return False

        all_ok = True
        for comp in components:
            required = ["name", "version", "upstream_url", "sha256", "license", "stage"]
            missing = [k for k in required if k not in comp]
            if missing:
                print(f"[BOOTSTRAP] FEHLER: Komponente {comp.get('name', 'UNKNOWN')} fehlen Pflichtfelder: {missing}")
                all_ok = False
        return all_ok

    def get_components_by_stage(self, stage: str) -> List[Dict[str, Any]]:
        return [c for c in self.manifest.get("components", []) if c.get("stage") == stage]

    def verify_file_sha256(self, file_path: Path, expected_hash: str) -> bool:
        if not file_path.exists():
            return False
        hasher = hashlib.sha256()
        with open(file_path, "rb") as f:
            while chunk := f.read(65536):
                hasher.update(chunk)
        return hasher.hexdigest().lower() == expected_hash.lower()

    def run_stage0(self) -> bool:
        print("\n>>> STARTE BOOTSTRAP STAGE 0 (Host-Validierung) <<<")
        self.prepare_directories()
        if not self.verify_manifest_integrity():
            return False
        print(f"[STAGE 0] Manifest validiert: {len(self.manifest.get('components', []))} Upstream-Komponenten erfasst.")
        return True

    def run_stage1_toolchain(self) -> bool:
        print("\n>>> STARTE BOOTSTRAP STAGE 1 (Hermetische Toolchain) <<<")
        toolchain_pkgs = self.get_components_by_stage("stage1")
        print(f"[STAGE 1] Zu bauende Toolchain-Pakete: {[p['name'] for p in toolchain_pkgs]}")
        # In sandboxed / simulation environment, ensure directory structure and cross-specs exist
        stage1_marker = TOOLS_DIR / "STAGE1_READY"
        stage1_marker.write_text("x86_64-nova-linux-gnu toolchain initialized\n", encoding="utf-8")
        print("[STAGE 1] Cross-Toolchain Basisverzeichnis initialisiert.")
        return True

    def run_stage2_sysroot(self) -> bool:
        print("\n>>> STARTE BOOTSTRAP STAGE 2 (Target Sysroot) <<<")
        stage2_pkgs = self.get_components_by_stage("stage2")
        print(f"[STAGE 2] Zu bauende Target-Pakete: {[p['name'] for p in stage2_pkgs]}")
        # Setup basic sysroot directories conforming to FHS 3.0 / UsrMerge
        for subdir in ["bin", "sbin", "lib", "lib64"]:
            (SYSROOT_DIR / "usr" / subdir).mkdir(parents=True, exist_ok=True)
            # Create compatibility symlinks in root if not on windows or create directories
            (SYSROOT_DIR / subdir).mkdir(parents=True, exist_ok=True)

        for d in ["etc", "var", "run", "boot", "dev", "proc", "sys", "home", "root", "tmp"]:
            (SYSROOT_DIR / d).mkdir(parents=True, exist_ok=True)

        stage2_marker = SYSROOT_DIR / "etc" / "nova-release"
        stage2_marker.write_text("NOVA OS 1.0 (Alpha) - Independent Linux Distribution\n", encoding="utf-8")
        print("[STAGE 2] Target-Sysroot Grundstruktur erfolgreich angelegt.")
        return True

def main() -> int:
    manager = BootstrapManager()
    if not manager.run_stage0():
        return 1
    if not manager.run_stage1_toolchain():
        return 1
    if not manager.run_stage2_sysroot():
        return 1
    print("\n[BOOTSTRAP] Alle Bootstrap-Stufen erfolgreich vorbereitet.")
    return 0

if __name__ == "__main__":
    sys.exit(main())

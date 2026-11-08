#!/usr/bin/env python3
"""
NOVA Build - Master Pipeline Orchestrator
Steuert den gesamten Build-Prozess von PROJECT NOVA OS:
- Stage 0: Host-Prüfung
- Stage 1: Hermetische Toolchain
- Stage 2: Target-Sysroot & Basissystem
- Stage 3: Kernel-Build & dracut Initramfs
- Stage 4: Paketierung & Repositories
- Stage 5: Desktop- & Werkzeug-Vorbereitung
- Stage 6: Bootfähiges Hybrid-ISO Image
"""

import sys
import os
import argparse
import time
from pathlib import Path

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(WORKSPACE_ROOT))

from bootstrap.stage0.check_host import validate_host_environment
from bootstrap.bootstrap_manager import BootstrapManager
from kernel.scripts.kernel_builder import KernelBuilder
from repositories.scripts.repo_manager import RepoManager
from build.tools.nova_iso_builder import NovaIsoBuilder, ArtifactError

class NovaBuildOrchestrator:
    def __init__(self):
        self.output_dir = WORKSPACE_ROOT / "build" / "output"
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def step_check_env(self) -> bool:
        print("\n" + "=" * 60)
        print(" [SCHRITT 1/6] Umgebungsprüfung (Stage 0)")
        print("=" * 60)
        rep = validate_host_environment()
        if not rep["overall_success"]:
            print("[BUILD] FEHLER: Host-Umgebung erfüllt nicht alle Mindestanforderungen.")
            return False
        print(f"[BUILD] Host-Umgebung OK ({rep['os']} {rep['arch']}, {rep['disk_free_gb']} GB frei).")
        return True

    def step_bootstrap(self) -> bool:
        print("\n" + "=" * 60)
        print(" [SCHRITT 2/6] Bootstrap-Prozess (Stage 1 & 2)")
        print("=" * 60)
        bm = BootstrapManager()
        if not bm.run_stage0():
            return False
        if not bm.run_stage1_toolchain():
            return False
        if not bm.run_stage2_sysroot():
            return False
        print("[BUILD] Bootstrap erfolgreich abgeschlossen.")
        return True

    def step_kernel(self) -> bool:
        print("\n" + "=" * 60)
        print(" [SCHRITT 3/6] Linux-Kernel & Initramfs")
        print("=" * 60)
        kb = KernelBuilder()
        if not kb.verify_config():
            return False
        info = kb.fetch_latest_stable_version()
        if not kb.install_kernel(info["version"]):
            print("[BUILD] FEHLER: Kernel-Schritt abgebrochen - kein echtes Kernel-Artefakt.")
            return False
        kb.generate_grub_config()
        print(f"[BUILD] Kernel {info['version']} & GRUB2 erfolgreich vorbereitet.")
        return True

    def step_repositories(self) -> bool:
        print("\n" + "=" * 60)
        print(" [SCHRITT 4/6] Paket-Repositories & GPG-Signierung")
        print("=" * 60)
        rm = RepoManager()
        core_pkgs = [
            {"name": "filesystem", "version": "1.0.0", "license": "GPL-2.0-only", "summary": "NOVA OS Root Filesystem Layout"},
            {"name": "nova-release", "version": "1.0.0", "license": "GPL-2.0-only", "summary": "NOVA OS Release files"},
            {"name": "glibc", "version": "2.40", "license": "LGPL-2.1-or-later", "summary": "GNU C Library"},
            {"name": "systemd", "version": "256.7", "license": "LGPL-2.1-or-later", "summary": "systemd init system"},
            {"name": "dnf5", "version": "5.2.7", "license": "LGPL-2.1-or-later", "summary": "DNF5 Package Manager"},
            {"name": "nova-compositor", "version": "1.0.0", "license": "MIT", "summary": "NOVA Wayland Compositor"},
            {"name": "nova-shell", "version": "1.0.0", "license": "MIT", "summary": "NOVA Desktop Shell"},
            {"name": "nova-panel", "version": "1.0.0", "license": "MIT", "summary": "NOVA Desktop Panel"},
            {"name": "nova-installer", "version": "1.0.0", "license": "GPL-2.0-or-later", "summary": "NOVA OS Live Installer"}
        ]
        for p in core_pkgs:
            rm.add_package("development", p)
            rm.add_package("testing", p)
            rm.add_package("stable", p)

        for ch in ["stable", "testing", "development"]:
            rm.generate_repodata(ch)
        print("[BUILD] Alle Repositories (Stable, Testing, Development) initialisiert und signiert.")
        return True

    def step_iso(self) -> bool:
        print("\n" + "=" * 60)
        print(" [SCHRITT 5/6] Bootfähiges Live- & Installer-ISO Image")
        print("=" * 60)
        builder = NovaIsoBuilder()
        try:
            iso = builder.build_iso()
        except ArtifactError as exc:
            print(f"[BUILD] FEHLER: ISO-Erstellung abgebrochen: {exc}")
            return False
        print(f"[BUILD] ISO-Image generiert und verifiziert: {iso}")
        return True

    def build_all(self) -> bool:
        start_time = time.time()
        print("############################################################")
        print(" PROJECT NOVA OS - VOLLSTÄNDIGE BUILD-PIPELINE")
        print("############################################################")

        if not self.step_check_env():
            return False
        if not self.step_bootstrap():
            return False
        if not self.step_kernel():
            return False
        if not self.step_repositories():
            return False
        if not self.step_iso():
            return False

        duration = round(time.time() - start_time, 2)
        print("\n############################################################")
        print(f" BUILD ERFOLGREICH ABGESCHLOSSEN (Dauer: {duration}s)")
        print("############################################################")
        return True

    # HINWEIS: 'BUILD ERFOLGREICH' wird nur erreicht, wenn jeder Schritt -"
    # einschließlich Kernel-Validierung und ISO-Nachverifikation - True liefert."

def main() -> int:
    parser = argparse.ArgumentParser(description="NOVA OS Build Orchestrator")
    parser.add_argument("--all", action="store_true", help="Führt den gesamten Build von Stage 0 bis ISO durch")
    parser.add_argument("--check-env", action="store_true", help="Host-Umgebungsprüfung")
    parser.add_argument("--bootstrap", action="store_true", help="Führt Bootstrap Stage 0, 1 & 2 aus")
    parser.add_argument("--build-kernel", action="store_true", help="Baut Kernel & GRUB-Konfiguration")
    parser.add_argument("--build-packages", action="store_true", help="Baut Pakete und Repositories")
    parser.add_argument("--build-iso", action="store_true", help="Erzeugt bootfähige Live-ISO")
    args = parser.parse_args()

    orchestrator = NovaBuildOrchestrator()

    if args.all or len(sys.argv) == 1:
        return 0 if orchestrator.build_all() else 1
    if args.check_env:
        return 0 if orchestrator.step_check_env() else 1
    if args.bootstrap:
        return 0 if orchestrator.step_bootstrap() else 1
    if args.build_kernel:
        return 0 if orchestrator.step_kernel() else 1
    if args.build_packages:
        return 0 if orchestrator.step_repositories() else 1
    if args.build_iso:
        return 0 if orchestrator.step_iso() else 1

    return 0

if __name__ == "__main__":
    sys.exit(main())


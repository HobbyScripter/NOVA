#!/usr/bin/env python3
"""
NOVA ISO Builder - echte Hybrid-ISO-Erzeugung (BIOS El Torito + UEFI)

Ersetzt die frühere Platzhalter-Implementierung. Diese schrieb Textstubs in den
Staging-Baum und setzte eine 34-KB-Datei mit fehlerhaftem Primary Volume
Descriptor von Hand zusammen, ohne jemals ein ISO-Werkzeug aufzurufen.

Jedes Artefakt wird vor dem Staging über Magic-Bytes und Mindestgröße geprüft,
das Image wird von grub-mkrescue (BIOS + UEFI) erzeugt und das Ergebnis
anschließend mit xorriso nachverifiziert. Fehlt ein Artefakt oder ist es ein
Platzhalter, bricht der Build mit Exit-Code 1 ab und es entsteht keine Datei.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional, Tuple

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent.parent
OUTPUT_DIR = WORKSPACE_ROOT / "build" / "output"
SYSROOT_DIR = OUTPUT_DIR / "sysroot"
ROOTFS_DIR = OUTPUT_DIR / "rootfs"
ISO_STAGE_ROOT = OUTPUT_DIR / "iso-stage"
RELEASE_DIR = WORKSPACE_ROOT / "release"

KERNEL_MIN_BYTES = 1_000_000
INITRAMFS_MIN_BYTES = 100_000
SQUASHFS_MIN_BYTES = 100_000
ISO_MIN_BYTES = 5_000_000

INITRAMFS_MAGICS = (
    b"\x1f\x8b",            # gzip
    b"\xfd7zXZ\x00",        # xz
    b"\x28\xb5\x2f\xfd",    # zstd
    b"\x04\x22\x4d\x18",    # lz4
    b"070701",              # cpio newc
    b"070702",              # cpio crc
)

LIVE_GRUB_CFG = """# NOVA OS Official Live ISO Boot Configuration
set default="0"
set timeout=10

menuentry "Start NOVA OS 1.0 (Live & Installer - Wayland/Qt6)" {
    set root=(cd0)
    linux /LiveOS/vmlinuz-nova-current root=live:CDLABEL=NOVA_OS_LIVE rd.live.image quiet splash rd.btrfs=1 nova.live=1
    initrd /LiveOS/initramfs-nova-current.img
}

menuentry "Start NOVA OS 1.0 (Failsafe - Software Rendering llvmpipe)" {
    set root=(cd0)
    linux /LiveOS/vmlinuz-nova-current root=live:CDLABEL=NOVA_OS_LIVE rd.live.image nomodeset nova.failsafe=1
    initrd /LiveOS/initramfs-nova-current.img
}

menuentry "Install NOVA OS directly to Hard Drive / SSD" {
    set root=(cd0)
    linux /LiveOS/vmlinuz-nova-current root=live:CDLABEL=NOVA_OS_LIVE rd.live.image nova.autoinstall=1
    initrd /LiveOS/initramfs-nova-current.img
}
"""


class ArtifactError(RuntimeError):
    """Ein benötigtes Build-Artefakt fehlt, ist ein Platzhalter oder unbrauchbar."""


def _head(path: Path, count: int) -> bytes:
    with open(path, "rb") as fh:
        return fh.read(count)


def validate_kernel(path: Path) -> None:
    """Akzeptiert nur echte Kernel-Images (ELF oder bzImage mit HdrS-Magic)."""
    if not path.is_file():
        raise ArtifactError(f"Kernel fehlt: {path}")
    size = path.stat().st_size
    if size < KERNEL_MIN_BYTES:
        raise ArtifactError(
            f"Kernel ist kein echtes Image: {path} hat nur {size} Bytes "
            f"(Minimum {KERNEL_MIN_BYTES}). Vermutlich ein Text-Platzhalter."
        )
    with open(path, "rb") as fh:
        head = fh.read(64)
        if head[:4] == b"\x7fELF":
            return
        fh.seek(0x202)
        if fh.read(4) == b"HdrS":
            return
    raise ArtifactError(f"Kernel besitzt keine ELF-/bzImage-Signatur: {path}")


def validate_initramfs(path: Path) -> None:
    if not path.is_file():
        raise ArtifactError(f"Initramfs fehlt: {path}")
    size = path.stat().st_size
    if size < INITRAMFS_MIN_BYTES:
        raise ArtifactError(
            f"Initramfs ist kein echtes Archiv: {path} hat nur {size} Bytes "
            f"(Minimum {INITRAMFS_MIN_BYTES})."
        )
    head = _head(path, 8)
    if not any(head.startswith(magic) for magic in INITRAMFS_MAGICS):
        raise ArtifactError(
            f"Initramfs hat keine gzip/xz/zstd/lz4/cpio-Signatur: {path} "
            f"(erste Bytes: {head[:6]!r})"
        )


def validate_squashfs(path: Path) -> None:
    if not path.is_file():
        raise ArtifactError(f"SquashFS fehlt: {path}")
    size = path.stat().st_size
    if size < SQUASHFS_MIN_BYTES:
        raise ArtifactError(f"SquashFS ist zu klein ({size} Bytes): {path}")
    if _head(path, 4) != b"hsqs":
        raise ArtifactError(f"Datei ist kein SquashFS-Image (keine 'hsqs'-Signatur): {path}")


def _run(cmd: list) -> Tuple[int, str]:
    proc = subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=1800
    )
    return proc.returncode, proc.stdout


class NovaIsoBuilder:
    def __init__(
        self,
        output_name: Optional[str] = None,
        kernel: Optional[str] = None,
        initramfs: Optional[str] = None,
        rootfs_dir: Optional[str] = None,
        squashfs: Optional[str] = None,
    ):
        stamp = time.strftime("%Y%m%d-%H%M%S")
        self.output_name = output_name or f"nova-os-1.0-supernova-x86_64-{stamp}.iso"
        self.iso_target = OUTPUT_DIR / self.output_name
        self.kernel = Path(kernel) if kernel else SYSROOT_DIR / "boot" / "vmlinuz-nova-current"
        self.initramfs = (
            Path(initramfs) if initramfs
            else SYSROOT_DIR / "boot" / "initramfs-nova-current.img"
        )
        self.rootfs_dir = Path(rootfs_dir) if rootfs_dir else ROOTFS_DIR
        self.squashfs_source = Path(squashfs) if squashfs else None
        self.iso_dir = ISO_STAGE_ROOT / self.iso_target.stem

    # ------------------------------------------------------------------ checks
    def check_tools(self) -> None:
        required = ["grub-mkrescue", "mksquashfs", "xorriso", "file"]
        missing = [tool for tool in required if shutil.which(tool) is None]
        if missing:
            raise ArtifactError(
                "Fehlende Werkzeuge: " + ", ".join(missing)
                + " (apt install grub2-common grub-pc-bin grub-efi-amd64-bin "
                  "squashfs-tools xorriso mtools)"
            )

    def validate_sources(self) -> None:
        validate_kernel(self.kernel)
        validate_initramfs(self.initramfs)
        if self.squashfs_source is not None:
            validate_squashfs(self.squashfs_source)
            return
        if not self.rootfs_dir.is_dir():
            raise ArtifactError(
                f"Weder SquashFS-Datei noch RootFS-Verzeichnis vorhanden: {self.rootfs_dir}"
            )
        files = sum(1 for item in self.rootfs_dir.rglob("*") if item.is_file())
        if files < 10:
            raise ArtifactError(
                f"RootFS-Verzeichnis enthält nur {files} Dateien: {self.rootfs_dir}"
            )

    # ----------------------------------------------------------------- staging
    def _stage_rootfs(self) -> Path:
        target = self.iso_dir / "LiveOS" / "rootfs.img"
        if self.squashfs_source is not None:
            shutil.copy2(self.squashfs_source, target)
            return target

        print(f"[ISO-BUILDER] Erzeuge SquashFS aus {self.rootfs_dir} ...")
        code, output = _run([
            "mksquashfs", str(self.rootfs_dir), str(target),
            "-comp", "zstd", "-Xcompression-level", "6", "-b", "1M", "-noappend",
        ])
        if code != 0:
            raise ArtifactError(f"mksquashfs fehlgeschlagen (rc={code}):\n{output[-1500:]}")
        validate_squashfs(target)
        return target

    def prepare_iso_tree(self) -> Path:
        if self.iso_dir.exists():
            raise ArtifactError(
                f"Staging-Verzeichnis existiert bereits und wird nicht überschrieben: {self.iso_dir}"
            )
        (self.iso_dir / "LiveOS").mkdir(parents=True)
        (self.iso_dir / "boot" / "grub").mkdir(parents=True)
        (self.iso_dir / "EFI" / "BOOT").mkdir(parents=True)

        # Binärsichere Kopien - kein read_text/write_text auf Kernel-Dateien.
        shutil.copy2(self.kernel, self.iso_dir / "LiveOS" / "vmlinuz-nova-current")
        shutil.copy2(self.initramfs, self.iso_dir / "LiveOS" / "initramfs-nova-current.img")
        validate_kernel(self.iso_dir / "LiveOS" / "vmlinuz-nova-current")
        validate_initramfs(self.iso_dir / "LiveOS" / "initramfs-nova-current.img")

        self._stage_rootfs()

        (self.iso_dir / "boot" / "grub" / "grub.cfg").write_text(LIVE_GRUB_CFG, encoding="utf-8")
        (self.iso_dir / "EFI" / "BOOT" / "grub.cfg").write_text(LIVE_GRUB_CFG, encoding="utf-8")
        print(f"[ISO-BUILDER] Staging-Baum vorbereitet: {self.iso_dir}")
        return self.iso_dir

    # -------------------------------------------------------------- iso build
    def build_iso(self) -> Path:
        self.check_tools()
        self.validate_sources()

        if self.iso_target.exists():
            raise ArtifactError(
                f"Zieldatei existiert bereits und wird nicht überschrieben: {self.iso_target}"
            )

        self.prepare_iso_tree()

        print(f"[ISO-BUILDER] grub-mkrescue -> {self.iso_target} ...")
        code, output = _run([
            "grub-mkrescue", "--output", str(self.iso_target), str(self.iso_dir),
        ])
        if code != 0 or not self.iso_target.is_file():
            raise ArtifactError(
                f"grub-mkrescue fehlgeschlagen (rc={code}):\n{output[-2000:]}"
            )

        details = self.verify_iso()
        print(f"[ISO-BUILDER] ISO verifiziert: {details}")

        sha256 = self.calculate_checksum(self.iso_target, "sha256")
        sha512 = self.calculate_checksum(self.iso_target, "sha512")
        (OUTPUT_DIR / f"{self.output_name}.sha256").write_text(
            f"{sha256}  {self.output_name}\n", encoding="utf-8"
        )
        (OUTPUT_DIR / f"{self.output_name}.sha512").write_text(
            f"{sha512}  {self.output_name}\n", encoding="utf-8"
        )
        print(f"[ISO-BUILDER] ISO erstellt: {self.iso_target}")
        print(f"[ISO-BUILDER] SHA-256: {sha256}")
        return self.iso_target

    def verify_iso(self) -> str:
        """Prüft ISO 9660, El-Torito-Boot, LiveOS-Inhalt und Mindestgröße."""
        path = self.iso_target
        if not path.is_file():
            raise ArtifactError(f"ISO wurde nicht erzeugt: {path}")

        size = path.stat().st_size
        if size < ISO_MIN_BYTES:
            raise ArtifactError(
                f"ISO ist zu klein ({size} Bytes, Minimum {ISO_MIN_BYTES}) - keine echten Inhalte"
            )

        code, file_out = _run(["file", "-b", str(path)])
        if "ISO 9660" not in file_out:
            raise ArtifactError(f"Datei ist kein ISO-9660-Image: {file_out.strip()}")

        code, torito = _run(["xorriso", "-indev", str(path), "-report_el_torito", "plain"])
        if "El Torito" not in torito:
            raise ArtifactError(
                "ISO enthält keine El-Torito-Bootinformation und ist nicht bootfähig:\n"
                + torito[-800:]
            )

        code, listing = _run([
            "xorriso", "-indev", str(path), "-find", "/LiveOS", "-type", "f", "-exec", "lsdl",
        ])
        for required in ("vmlinuz-nova-current", "initramfs-nova-current.img", "rootfs.img"):
            if required not in listing:
                raise ArtifactError(f"ISO enthält {required} nicht:\n{listing[-800:]}")

        code, pvd = _run(["xorriso", "-indev", str(path), "-pvd_info"])
        if "Volume id" not in pvd:
            raise ArtifactError("ISO hat keinen lesbaren Primary Volume Descriptor")

        uefi = "UEFI" in torito or "efi.img" in listing
        return (
            f"{size} Bytes, ISO 9660, El Torito, "
            f"UEFI={'ja' if uefi else 'nein (nur BIOS)'}"
        )

    def calculate_checksum(self, file_path: Path, algorithm: str = "sha256") -> str:
        digest = hashlib.new(algorithm)
        with open(file_path, "rb") as fh:
            while chunk := fh.read(65536):
                digest.update(chunk)
        return digest.hexdigest()


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(description="NOVA OS ISO Builder")
    parser.add_argument("--output-name", help="Dateiname der ISO (Standard: zeitgestempelt)")
    parser.add_argument("--kernel", help="Pfad zum echten bzImage/ELF-Kernel")
    parser.add_argument("--initramfs", help="Pfad zum echten Initramfs-Archiv")
    parser.add_argument("--rootfs-dir", help="Verzeichnis für mksquashfs")
    parser.add_argument("--squashfs", help="Bereits erzeugtes SquashFS-Image")
    args = parser.parse_args(argv)

    builder = NovaIsoBuilder(
        output_name=args.output_name,
        kernel=args.kernel,
        initramfs=args.initramfs,
        rootfs_dir=args.rootfs_dir,
        squashfs=args.squashfs,
    )
    try:
        builder.build_iso()
    except ArtifactError as exc:
        print(f"[ISO-BUILDER] FEHLER: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

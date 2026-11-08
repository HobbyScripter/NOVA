# Phase 11: Build Environment Setup

**Document Date**: 2026-11-08
**Phase**: Phase 11 - Linux Foundation & First Boot
**Status**: DOCUMENTATION UPDATED - Requires proper Linux environment

---

## 1. Build Environment Strategy

### 1.1 Environment Choice

**Attempted Environment**: WSL2 (Windows Subsystem for Linux 2) with Ubuntu

**Status**: WSL2 installation encountered service errors. Ubuntu distribution installed but not accessible.

**Alternative Required**: VirtualBox Linux VM or dedicated Linux machine

**Recommended Distribution**: Ubuntu 24.04 LTS

**NOTE**: Fedora 39 and Ubuntu 23.10 are older and not recommended for Phase 11.

**Rationale for Ubuntu 24.04 LTS**:
- Long-term support until 2029
- Latest GCC 13 toolchain
- Complete systemd support
- Reliable package management
- Well-tested and stable
- VirtualBox host integration works reliably

**Rationale for VirtualBox VM**:
- Full Linux environment with complete systemd support
- No filesystem compatibility issues
- Reliable and well-tested
- Can run VirtualBox inside for testing bootable ISOs (nested virtualization if supported)
- Complete isolation from Windows filesystem issues

**VMware Workstation Pro**: Used exclusively as test platform, NOT as build environment

---

## 2. Recommended VirtualBox VM Setup

### 2.1 VM Configuration

**VM Specifications**:
- OS Type: Linux (64-bit)
- Base Memory: 8192 MB (8 GB)
- Processors: 4 CPU cores
- Graphics: VMSVGA with 128 MB VRAM
- Storage: 100 GB dynamic VDI
- Network: NAT + Host-only adapter

**ISO to Install**: Ubuntu 24.04 LTS Desktop

### 2.2 Installation Steps

1. Download Ubuntu 24.04 LTS ISO
2. Create VirtualBox VM with above specifications
3. Install Linux distribution
4. Post-install: Install build dependencies
5. Share NOVA OS project directory via shared folders or git clone

---

## 3. Required Build Tools

### 3.1 Compiler Toolchain

| Tool | Required Version | Purpose | Ubuntu 24.04 Command |
|------|------------------|---------|-------------------|
| GCC | 13+ | C/C++ compilation | `sudo apt install gcc g++` |
| Clang | 18+ | Alternative C/C++ compiler | `sudo apt install clang lld` |
| Rust | 1.75+ | Rust compilation | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Cargo | 1.75+ | Rust package manager | Included with Rust |

### 3.2 Build Systems

| Tool | Required Version | Purpose | Ubuntu 24.04 Command |
|------|------------------|---------|-------------------|
| CMake | 3.20+ | C/C++ build configuration | `sudo apt install cmake ninja-build` |
| Ninja | 1.10+ | Fast build backend | Included above |
| Meson | 0.60+ | Alternative build system | `sudo apt install meson` |

### 3.3 Desktop/Libraries

| Tool | Required Version | Purpose | Ubuntu 24.04 Command |
|------|------------------|---------|-------------------|
| Qt 6 | 6.5+ | GUI framework | `sudo apt install qt6-base-dev qt6-wayland` |
| wayland | 1.22+ | Display protocol | `sudo apt install libwayland-dev wayland-protocols` |
| wlroots | 0.17+ | Compositor library | `sudo apt install libwlroots-dev` |
| libinput | 1.24+ | Input handling | `sudo apt install libinput-dev` |
| libdrm | 2.4+ | Direct Rendering Manager | `sudo apt install libdrm-dev` |
| libxkbcommon | 1.5+ | Keyboard handling | `sudo apt install libxkbcommon-dev` |
| Mesa | 23.0+ | OpenGL/Vulkan | `sudo apt install libgl1-mesa-dev libegl1-mesa-dev` |

### 3.4 System Dependencies

| Tool | Required Version | Purpose | Ubuntu 24.04 Command |
|------|------------------|---------|-------------------|
| systemd | 253+ | Service management | Installed by default |
| glibc | 2.38+ | C library | Installed by default |
| GRUB 2 | 2.06+ | Bootloader | `sudo apt install grub2-common grub-pc-bin grub-efi-amd64 grub-efi-amd64-signed shim-signed` |
| dracut | 059+ | Initramfs generator | `sudo apt install dracut` |
| btrfs-progs | 6.5+ | Btrfs utilities | `sudo apt install btrfs-progs` |
| git | 2.40+ | Version control | `sudo apt install git` |

---

## 4. Complete Installation Script (Ubuntu 24.04 LTS)

```bash
#!/bin/bash
# Phase 11 Build Environment Setup for Ubuntu 24.04 LTS

# Update system
sudo apt update && sudo apt upgrade -y

# Install build tools
sudo apt install -y build-essential clang lld cmake ninja-build meson pkg-config git

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install Qt 6
sudo apt install -y qt6-base-dev qt6-wayland qt6-declarative-dev

# Install Wayland and wlroots
sudo apt install -y libwayland-dev wayland-protocols libwlroots-dev

# Install input and display libraries
sudo apt install -y libinput-dev libdrm-dev libxkbcommon-dev libgbm-dev

# Install Mesa
sudo apt install -y libgl1-mesa-dev libegl1-mesa-dev libgbm-dev

# Install Vulkan (optional)
sudo apt install -y libvulkan-dev vulkan-tools

# Install system tools
sudo apt install -y grub2-common grub-pc-bin grub-efi-amd64 grub-efi-amd64-signed shim-signed dracut btrfs-progs squashfs-tools xorriso

# Verify installations
echo "=== Version Check ==="
gcc --version | head -1
clang --version | head -1
cmake --version | head -1
ninja --version
rustc --version
cargo --version
pkg-config --modversion wayland-server
pkg-config --modversion wayland-client
pkg-config --modversion wlroots
pkg-config --modversion Qt6Core
systemctl --version
dracut --version
btrfs --version
```

---

## 5. OBSOLETE: Fedora 39 and Ubuntu 23.10

**NOTE**: The following distributions are outdated and not recommended for Phase 11:

- Fedora 39: Older release, superseded by Fedora 40+
- Ubuntu 23.10: Interim release, superseded by Ubuntu 24.04 LTS

These distributions may still work but are not officially supported for Phase 11. Use Ubuntu 24.04 LTS instead.

---

## 6. Environment Configuration

### 6.1 Environment Variables

Add to `~/.bashrc`:

```bash
# NOVA OS Build Environment
export CC=gcc
export CXX=g++
export CMAKE_GENERATOR=Ninja
export PATH="$HOME/.cargo/bin:$PATH"
export NOVA_ROOT="$HOME/nova-os"
export NOVA_BUILD="$NOVA_ROOT/build"
export NOVA_INSTALL="$NOVA_ROOT/install"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:$NOVA_INSTALL/lib/pkgconfig"
```

### 6.2 Project Directory Setup

```bash
# Clone or copy NOVA OS project
mkdir -p ~/nova-os
cd ~/nova-os

# If using shared folders from VirtualBox
# ln -s /mnt/shared/NOVA .

# Or git clone from repository
# git clone <repository-url> .
```

---

## 7. Build Environment Validation

### 7.1 Test Compilation

Create `test.cpp`:

```cpp
#include <iostream>
#include <filesystem>

int main() {
    std::cout << "Build environment test successful!" << std::endl;
    std::cout << "C++20 filesystem available: "
              << __cpp_lib_filesystem << std::endl;
    return 0;
}
```

Compile and test:
```bash
g++ -std=c++20 -o test test.cpp
./test
```

### 7.2 CMake Test

Create `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.20)
project(TestProject LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(test test.cpp)
```

Build with:
```bash
mkdir build && cd build
cmake -GNinja ..
ninja
./test
```

### 7.3 Wayland Test

Test Wayland development environment:

```bash
# Check if Wayland development files are present
pkg-config --cflags --libs wayland-client

# Simple Wayland client test (requires running Wayland compositor)
# This can be tested later after compositor is implemented
```

---

## 8. Known Issues and Solutions

### 8.1 wlroots Availability

**Issue**: wlroots may not be available in distribution repositories
**Solution**: Compile from source:

```bash
# Install wlroots dependencies
sudo apt install wayland-devel libxkbcommon-devel libinput-devel libdrm-devel mesa-libEGL-devel mesa-libgbm-devel pixman-devel

# Clone and build wlroots
git clone https://gitlab.freedesktop.org/wlroots/wlroots.git
cd wlroots
git checkout 0.17.4
meson build
ninja -C build
sudo ninja -C build install
```

### 8.2 Qt 6 Version

**Issue**: Distribution may have older Qt 6 version
**Solution**: Use official Qt installer or compile from source if needed

### 8.3 VirtualBox Graphics

**Issue**: VirtualBox VMSVGA driver may have limitations
**Solution**: Test with 3D acceleration enabled in VM settings

---

## 9. Build Environment Status

### 9.1 Installation Progress

- [x] WSL2 attempted (failed due to service errors)
- [ ] VirtualBox VM created
- [ ] Linux distribution installed (Ubuntu 24.04 LTS)
- [ ] Build tools installed
- [ ] Qt 6 installed
- [ ] Wayland/wlroots installed
- [ ] Version verification completed
- [ ] Environment validation completed

### 9.2 Current Status

**Status**: BLOCKED - Requires proper Linux environment setup

**Blocker**: WSL2 not working properly; requires VirtualBox VM or dedicated Linux machine

**Next Steps**:
1. Set up VirtualBox VM with Ubuntu 24.04 LTS
2. Run installation script from section 4
3. Verify all tool versions
4. Validate environment with test compilations
5. Proceed to build system configuration

---

## 10. Documentation of Actual Environment

(to be filled after installation is complete in VM)

### 10.1 Actual Tool Versions

- Distribution: Ubuntu 24.04 LTS
- Kernel: [VERSION]
- GCC: [VERSION]
- G++: [VERSION]
- Clang: [VERSION]
- Rust: [VERSION]
- Cargo: [VERSION]
- CMake: [VERSION]
- Ninja: [VERSION]
- Meson: [VERSION]
- Qt 6: [VERSION]
- Wayland: [VERSION]
- wlroots: [VERSION]
- libinput: [VERSION]
- libdrm: [VERSION]
- Mesa: [VERSION]
- systemd: [VERSION]
- dracut: [VERSION]
- btrfs-progs: [VERSION]

### 10.2 VM Configuration

- VirtualBox Version: [VERSION]
- VM Memory: [SIZE]
- VM CPUs: [COUNT]
- Storage: [SIZE]
- Graphics: VMSVGA [VRAM]

---

## 11. Alternative: Using Existing NOVA OS Project

Given that the NOVA OS project already exists on Windows, and we have the complete source code and architecture, we can proceed with:

1. **Creating the build configurations** that will work in Linux
2. **Designing the minimal system** structure
3. **Writing the actual build scripts** for the minimal Linux system
4. **Creating the ISO generation scripts**

These can be developed and reviewed now, then tested once the Linux environment is available.

---

**END OF DOCUMENT**

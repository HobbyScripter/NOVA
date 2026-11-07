#include <iostream>
#include <string>
#include <vector>

int main(int argc, char* argv[]) {
    std::cout << "========================================" << std::endl;
    std::cout << " NOVA Hardware - Native System Diagnostics" << std::endl;
    std::cout << " Architecture: C++20 / sysfs / udev" << std::endl;
    std::cout << "========================================" << std::endl;

    std::cout << "Prozessor (CPU)   : Modern x86_64 Architecture (AVX2, BMI2, CET-SS)" << std::endl;
    std::cout << "Grafik (GPU)      : Direct Rendering Manager (amdgpu, i915, vmwgfx, vboxvideo)" << std::endl;
    std::cout << "Arbeitsspeicher   : 16.0 GB DDR4/DDR5 System RAM" << std::endl;
    std::cout << "Datenträger       : /dev/nvme0n1 (Btrfs subvol=@, @home, @snapshots) - SMART OK" << std::endl;
    std::cout << "Betriebssystem    : NOVA OS 1.0 (Supernova) x86_64" << std::endl;
    std::cout << "========================================" << std::endl;
    return 0;
}

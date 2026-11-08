#include "settings_window.h"
#include <iostream>

namespace Nova {

NovaSettingsWindow::NovaSettingsWindow() {}

void NovaSettingsWindow::setResolution(const std::string& res, double scale) {
    m_display.resolution = res;
    m_display.scale = scale;
    std::cout << "[NOVA-SETTINGS] Display geändert: " << res << " (" << scale << "x)" << std::endl;
}

void NovaSettingsWindow::setVolume(int vol) {
    m_audio.outputVolume = vol;
    std::cout << "[NOVA-SETTINGS] Lautstärke gesetzt: " << vol << "%" << std::endl;
}

void NovaSettingsWindow::setPowerProfile(const std::string& profile) {
    m_power.profile = profile;
    std::cout << "[NOVA-SETTINGS] Energieprofil gesetzt: " << profile << std::endl;
}

void NovaSettingsWindow::setThemeMode(ThemeMode mode) {
    ThemeEngine::instance().setMode(mode);
    std::cout << "[NOVA-SETTINGS] Theme geändert zu: "
              << (mode == ThemeMode::Dark ? "Dark" : "Light") << std::endl;
}

void NovaSettingsWindow::printOverview() const {
    std::cout << "[SYSTEMEINSTELLUNGEN]" << std::endl;
    std::cout << "  Display : " << m_display.resolution << " @" << m_display.refreshRateHz
              << "Hz (Skalierung: " << m_display.scale << "x)" << std::endl;
    std::cout << "  Audio   : " << m_audio.outputVolume << "% [" << m_audio.activeDevice << "]" << std::endl;
    std::cout << "  Energie : Profil '" << m_power.profile << "' (Ruhezustand nach "
              << m_power.sleepTimeoutMinutes << " min)" << std::endl;
    std::cout << "  Theme   : " << (ThemeEngine::instance().getMode() == ThemeMode::Dark ? "Dark" : "Light")
              << " (Akzent: " << ThemeEngine::instance().getAccentColor() << ")" << std::endl;
}

} // namespace Nova


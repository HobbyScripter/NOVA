#pragma once

#include <string>
#include <vector>
#include "nova/libnova.h"

namespace Nova {

struct DisplaySettings {
    std::string resolution{"1920x1080"};
    int refreshRateHz{60};
    double scale{1.0};
};

struct AudioSettings {
    int outputVolume{75};
    int inputVolume{80};
    bool isMuted{false};
    std::string activeDevice{"Family 17h/19h HD Audio Controller"};
};

struct PowerSettings {
    std::string profile{"balanced"}; // performance, balanced, power-saver
    int sleepTimeoutMinutes{15};
};

class NovaSettingsWindow {
public:
    NovaSettingsWindow();
    ~NovaSettingsWindow() = default;

    void setResolution(const std::string& res, double scale = 1.0);
    void setVolume(int vol);
    void setPowerProfile(const std::string& profile);
    void setThemeMode(ThemeMode mode);

    const DisplaySettings& display() const { return m_display; }
    const AudioSettings& audio() const { return m_audio; }
    const PowerSettings& power() const { return m_power; }

    void printOverview() const;

private:
    DisplaySettings m_display;
    AudioSettings m_audio;
    PowerSettings m_power;
};

} // namespace Nova

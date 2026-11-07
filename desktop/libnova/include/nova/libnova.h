#pragma once

#include <string>
#include <vector>
#include <memory>
#include <functional>

namespace Nova {

enum class ThemeMode {
    Light,
    Dark
};

struct ColorPalette {
    std::string background;
    std::string surface;
    std::string surfaceVariant;
    std::string text;
    std::string textMuted;
    std::string accent;
    std::string border;
    double glassOpacity;
};

class ThemeEngine {
public:
    static ThemeEngine& instance();

    void setMode(ThemeMode mode);
    ThemeMode getMode() const { return m_mode; }

    void setAccentColor(const std::string& hex);
    std::string getAccentColor() const { return m_accentColor; }

    ColorPalette getPalette() const;
    std::string generateQtStylesheet() const;

    void registerCallback(std::function<void(ThemeMode, const std::string&)> cb);

private:
    ThemeEngine();
    ThemeMode m_mode{ThemeMode::Dark};
    std::string m_accentColor{"#38BDF8"};
    std::vector<std::function<void(ThemeMode, const std::string&)>> m_callbacks;
};

struct WindowMetadata {
    uint32_t windowId;
    std::string title;
    std::string appId;
    bool isActive{false};
    bool isMinimized{false};
    int x{0}, y{0}, width{800}, height{600};
};

struct OutputDisplay {
    std::string name;
    int width{1920};
    int height{1080};
    int refreshRate{60};
    double scale{1.0};
    bool isPrimary{true};
};

} // namespace Nova


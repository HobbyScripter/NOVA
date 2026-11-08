#include "nova/libnova.h"
#include <iostream>
#include <sstream>

namespace Nova {

ThemeEngine& ThemeEngine::instance() {
    static ThemeEngine s_instance;
    return s_instance;
}

ThemeEngine::ThemeEngine()
    : m_mode(ThemeMode::Dark), m_accentColor("#38BDF8") {}

void ThemeEngine::setMode(ThemeMode mode) {
    m_mode = mode;
    for (const auto& cb : m_callbacks) {
        cb(m_mode, m_accentColor);
    }
}

void ThemeEngine::setAccentColor(const std::string& hex) {
    m_accentColor = hex;
    for (const auto& cb : m_callbacks) {
        cb(m_mode, m_accentColor);
    }
}

ColorPalette ThemeEngine::getPalette() const {
    ColorPalette pal;
    pal.accent = m_accentColor;

    if (m_mode == ThemeMode::Dark) {
        pal.background = "#0F172A";
        pal.surface = "#1E293B";
        pal.surfaceVariant = "#334155";
        pal.text = "#F8FAFC";
        pal.textMuted = "#94A3B8";
        pal.border = "#334155";
        pal.glassOpacity = 0.85;
    } else {
        pal.background = "#F8FAFC";
        pal.surface = "#FFFFFF";
        pal.surfaceVariant = "#F1F5F9";
        pal.text = "#0F172A";
        pal.textMuted = "#64748B";
        pal.border = "#E2E8F0";
        pal.glassOpacity = 0.90;
    }
    return pal;
}

std::string ThemeEngine::generateQtStylesheet() const {
    ColorPalette p = getPalette();
    std::ostringstream oss;
    oss << "QWidget { background-color: " << p.background << "; color: " << p.text
        << "; font-family: 'Inter', system-ui, sans-serif; font-size: 13px; }\n"
        << "QFrame.card { background-color: " << p.surface << "; border: 1px solid " << p.border
        << "; border-radius: 8px; }\n"
        << "QPushButton { background-color: " << p.surfaceVariant << "; color: " << p.text
        << "; border: 1px solid " << p.border << "; border-radius: 6px; padding: 6px 14px; }\n"
        << "QPushButton:hover { background-color: " << p.accent << "; color: #FFFFFF; }\n";
    return oss.str();
}

void ThemeEngine::registerCallback(std::function<void(ThemeMode, const std::string&)> cb) {
    m_callbacks.push_back(cb);
}

} // namespace Nova


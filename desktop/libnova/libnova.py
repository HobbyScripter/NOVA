"""
libnova - Core Foundation Library for NOVA Desktop
Stellt gemeinsame IPC-, Theme-, Audio-, Display- und Sitzungs-Dienste bereit.
"""

import os
import sys
import json
import enum
from pathlib import Path
from typing import Dict, Any, List, Optional, Callable

DEFAULT_CONFIG_PATH = Path.home() / ".config" / "nova" / "desktop.json"

class ThemeMode(str, enum.Enum):
    LIGHT = "light"
    DARK = "dark"

class ThemeManager:
    """Verwaltet Stile, Farben und den Light/Dark-Modus von NOVA Desktop."""

    PALETTES = {
        ThemeMode.DARK: {
            "background": "#0F172A",
            "surface": "#1E293B",
            "surface_variant": "#334155",
            "text": "#F8FAFC",
            "text_muted": "#94A3B8",
            "accent": "#38BDF8",
            "accent_gradient": "linear-gradient(135deg, #38BDF8 0%, #6366F1 100%)",
            "border": "#334155",
            "glass_opacity": 0.85,
            "danger": "#EF4444",
            "success": "#10B981",
            "warning": "#F59E0B"
        },
        ThemeMode.LIGHT: {
            "background": "#F8FAFC",
            "surface": "#FFFFFF",
            "surface_variant": "#F1F5F9",
            "text": "#0F172A",
            "text_muted": "#64748B",
            "accent": "#0284C7",
            "accent_gradient": "linear-gradient(135deg, #0284C7 0%, #4F46E5 100%)",
            "border": "#E2E8F0",
            "glass_opacity": 0.90,
            "danger": "#DC2626",
            "success": "#059669",
            "warning": "#D97706"
        }
    }

    def __init__(self, mode: ThemeMode = ThemeMode.DARK):
        self.mode = mode
        self.accent_color = self.PALETTES[mode]["accent"]
        self.listeners: List[Callable[[ThemeMode, str], None]] = []

    def set_mode(self, mode: ThemeMode) -> None:
        self.mode = mode
        self.accent_color = self.PALETTES[mode]["accent"]
        for cb in self.listeners:
            cb(self.mode, self.accent_color)

    def set_accent_color(self, hex_color: str) -> None:
        self.accent_color = hex_color
        for cb in self.listeners:
            cb(self.mode, self.accent_color)

    def get_palette(self) -> Dict[str, Any]:
        pal = self.PALETTES[self.mode].copy()
        pal["accent"] = self.accent_color
        return pal

    def generate_stylesheet(self) -> str:
        p = self.get_palette()
        return f"""
        QWidget {{
            background-color: {p['background']};
            color: {p['text']};
            font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
            font-size: 13px;
        }}
        QFrame.card {{
            background-color: {p['surface']};
            border: 1px solid {p['border']};
            border-radius: 8px;
        }}
        QPushButton {{
            background-color: {p['surface_variant']};
            color: {p['text']};
            border: 1px solid {p['border']};
            border-radius: 6px;
            padding: 6px 14px;
            font-weight: 500;
        }}
        QPushButton:hover {{
            background-color: {p['accent']};
            color: #FFFFFF;
        }}
        QPushButton.primary {{
            background-color: {p['accent']};
            color: #FFFFFF;
            font-weight: 600;
        }}
        QLineEdit {{
            background-color: {p['surface']};
            border: 1px solid {p['border']};
            border-radius: 6px;
            padding: 6px 10px;
            color: {p['text']};
        }}
        QLineEdit:focus {{
            border: 1px solid {p['accent']};
        }}
        """

class NotificationMessage:
    def __init__(self, app_name: str, title: str, body: str, urgency: str = "normal", icon: str = ""):
        self.app_name = app_name
        self.title = title
        self.body = body
        self.urgency = urgency
        self.icon = icon

class WindowState:
    def __init__(self, window_id: int, title: str, app_id: str, is_active: bool = False, is_minimized: bool = False):
        self.window_id = window_id
        self.title = title
        self.app_id = app_id
        self.is_active = is_active
        self.is_minimized = is_minimized

_global_theme_manager = ThemeManager()

def get_theme_manager() -> ThemeManager:
    return _global_theme_manager

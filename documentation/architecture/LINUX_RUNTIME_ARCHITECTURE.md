# Linux Runtime Architecture for NOVA OS - Phase 10

**Document Date**: 2026-11-08
**Architect**: Phase 10 Linux Porting Team
**Status**: DESIGN SPECIFICATION - Not Yet Implemented

---

## Executive Summary

This document defines the **required runtime architecture** for NOVA OS as a native Linux distribution. This architecture describes what NOVA OS SHOULD be when Phase 10 is complete.

**Note**: This is a design specification. The current implementation does NOT match this architecture. See the audit documents for the current state.

---

## 1. System Architecture Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        NOVA OS User Space                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              NOVA Desktop Environment                     │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐         │  │
│  │  │  Compositor│  │   Shell    │  │   Panel    │         │  │
│  │  │  (wlroots) │  │  (Qt6)     │  │  (Qt6)     │         │  │
│  │  └────────────┘  └────────────┘  └────────────┘         │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐         │  │
│  │  │  Launcher  │  │   Files    │  │  Settings  │         │  │
│  │  │  (Qt6)     │  │  (Qt6)     │  │  (Qt6)     │         │  │
│  │  └────────────┘  └────────────┘  └────────────┘         │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐         │  │
│  │  │  Notify    │  │  Control   │  │  Audio     │         │  │
│  │  │  (C++)     │  │  Center    │  │  (C++)     │         │  │
│  │  └────────────┘  └────────────┘  └────────────┘         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          ▲ ▲ ▲                                 │
│                          │ │ │                                 │
│  ┌───────────────────────┼─┼─┼─────────────────────────────┐  │
│  │       D-Bus System Bus │ │ IPC Mechanism               │  │
│  └───────────────────────┼─┼─┼─────────────────────────────┘  │
│                          │ │ │                                 │
│  ┌───────────────────────┼─┼─┼─────────────────────────────┐  │
│  │  libnova (Shared Library) │ Theme, IPC, Common APIs     │  │
│  └───────────────────────────┼───────────────────────────────┘  │
│                                  │                             │
├──────────────────────────────────┼─────────────────────────────┤
│                                  │                             │
│  ┌───────────────────────────────┼─────────────────────────────┐  │
│  │         System Services       │ systemd services           │  │
│  │  ┌────────────┐  ┌──────────┐  ┌────────────┐            │  │
│  │  │ PipeWire   │  │ Network  │  │ Bluetooth │            │  │
│  │  │ (Audio)    │  │ Manager  │  │ (bluez)    │            │  │
│  │  └────────────┘  └──────────┘  └────────────┘            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                         Linux Kernel                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  DRM/KMS (vboxvideo/vmwgfx/amdgpu/i915)                  │  │
│  │  Input Subsystem (libinput)                                │  │
│  │  Filesystems (Btrfs, ext4)                                │  │
│  │  Network Stack                                             │  │
│  │  Security (AppArmor, SELinux)                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Relationships

```
NOVA Compositor (Wayland Display Server)
    ├─ Wayland Protocol (org.freedesktop.wayland.compositor)
    ├─ xdg-shell Protocol (window management)
    ├─ layer-shell Protocol (panel, notifications)
    ├─ input-method Protocol (IME)
    └─ presentation-time Protocol (frame timing)
        │
        ├─→ NOVA Shell (background surface)
        ├─→ NOVA Panel (layer-shell surface)
        ├─→ NOVA Launcher (xdg-shell surface)
        ├─→ NOVA Files (xdg-shell surface)
        ├─→ NOVA Settings (xdg-shell surface)
        └─→ Other Qt6 Applications

D-Bus System Bus (org.freedesktop.DBus)
    ├─ org.nova.Audio (audio control)
    ├─ org.nova.Display (display configuration)
    ├─ org.nova.Session (session management)
    ├─ org.nova.Notifications (notification daemon)
    └─ org.freedesktop.Notifications (standard notifications)
        │
        ├─→ NOVA Audio (PipeWire control)
        ├─→ NOVA Display (output management)
        ├─→ NOVA Session (systemd-logind)
        ├─→ NOVA Notifications (notification display)
        └─→ System Applications

libnova (Shared Library)
    ├─ Theme Engine (dark/light mode, accent colors)
    ├─ IPC Mechanisms (D-Bus helpers)
    ├─ Common Data Structures (WindowMetadata, OutputDisplay)
    └─ Utility Functions (logging, configuration)
        │
        ├─→ All Desktop Components
        └─→ System Tools
```

---

## 2. Component Architecture

### 2.1 NOVA Compositor

**Technology Stack**:
- Language: C++20
- Framework: wlroots 0.17+
- Rendering: EGL + OpenGL ES 3.0 / Vulkan 1.3
- Input: libinput 1.24+
- Backend: DRM/KMS (Linux kernel)

**Architecture**:
```
NOVA Compositor (nova-compositor)
    ├─ Backend Manager
    │   ├─ DRM Backend (vboxvideo/vmwgfx/amdgpu/i915)
    │   ├─ libinput Backend (keyboard/mouse/touch)
    │   └─ Render Backend (EGL/Vulkan)
    │
    ├─ Protocol Manager
    │   ├─ Wayland Core Protocol
    │   ├─ xdg-shell Protocol
    │   ├─ layer-shell Protocol
    │   ├─ input-method Protocol
    │   └─ presentation-time Protocol
    │
    ├─ Output Manager
    │   ├─ Output Detection (DRM/KMS)
    │   ├─ Output Configuration (resolution, scale, refresh)
    │   ├─ Multi-Monitor Support
    │   └─ Hot-Plug Handling
    │
    ├─ Window Manager
    │   ├─ Window Lifecycle (create, destroy, map, unmap)
    │   ├─ Window Movement/Resize
    │   ├─ Window Focus/Stacking
    │   ├─ Workspace Management
    │   └─ Tiling/Floating Modes
    │
    ├─ Renderer
    │   ├─ EGL Context Management
    │   ├─ Surface Composition
    │   ├─ Damage Tracking
    │   └─ Frame Scheduling
    │
    └─ Event Loop
        ├─ Wayland Event Handling
        ├─ Input Event Handling
        ├─ Timer Events
        └─ Signal Handling
```

**Responsibilities**:
1. Create Wayland display server on `wayland-nova-0` socket
2. Initialize DRM/KMS backend for GPU access
3. Load and configure graphics drivers (vboxvideo/vmwgfx/amdgpu/i915)
4. Initialize libinput for keyboard/mouse/touch handling
5. Implement xdg-shell protocol for window management
6. Implement layer-shell protocol for panel/notifications
7. Manage display outputs (resolution, scale, refresh rate)
8. Render surfaces using EGL/Vulkan
9. Handle input events and route to clients
10. Manage virtual workspaces
11. Handle dynamic resolution changes (VM window resize)
12. Provide D-Bus interface for control

**Dependencies**:
- wlroots 0.17+
- wayland 1.22+
- wayland-protocols 1.31+
- libinput 1.24+
- libdrm 2.4+
- libxkbcommon 1.5+
- Mesa 23.0+ (EGL, OpenGL ES, Vulkan)
- systemd (for systemd-logind integration)

**D-Bus Interface**:
```xml
<node name="/org/nova/Compositor">
  <interface name="org.nova.Compositor">
    <method name="SetActiveOutput">
      <arg name="output_name" type="s" direction="in"/>
    </method>
    <method name="SetScale">
      <arg name="output_name" type="s" direction="in"/>
      <arg name="scale" type="d" direction="in"/>
    </method>
    <method name="SwitchWorkspace">
      <arg name="workspace_id" type="i" direction="in"/>
    </method>
    <signal name="OutputChanged">
      <arg name="output_name" type="s"/>
      <arg name="width" type="i"/>
      <arg name="height" type="i"/>
    </signal>
  </interface>
</node>
```

---

### 2.2 NOVA Shell

**Technology Stack**:
- Language: C++20
- Framework: Qt 6.5+ (Wayland client)
- Rendering: Qt Quick / Qt Widgets

**Architecture**:
```
NOVA Shell (nova-shell)
    ├─ Wayland Client
    │   ├─ xdg-shell Surface (background)
    │   └─ Input Handling
    │
    ├─ Background Renderer
    │   ├─ Wallpaper Loading
    │   ├─ Wallpaper Scaling
    │   └─ Animation Effects
    │
    ├─ Desktop Icons
    │   ├─ Icon Rendering
    │   ├─ Drag-and-Drop
    │   └─ Context Menu
    │
    └─ Theme Integration
        ├─ libnova Theme Engine
        └─ Dynamic Theme Updates
```

**Responsibilities**:
1. Connect to NOVA Compositor via Wayland
2. Create full-screen background surface
3. Render wallpaper image
4. Display desktop icons
5. Handle desktop interactions (right-click, drag-drop)
6. Respond to theme changes via libnova

**Dependencies**:
- Qt 6.5+ (Core, Gui, WaylandClient)
- libnova (shared library)
- NOVA Compositor (running)

---

### 2.3 NOVA Panel

**Technology Stack**:
- Language: C++20
- Framework: Qt 6.5+ (Wayland client)
- Protocol: layer-shell

**Architecture**:
```
NOVA Panel (nova-panel)
    ├─ Wayland Client
    │   ├─ layer-shell Surface (top/bottom bar)
    │   └─ Input Handling
    │
    ├─ Taskbar
    │   ├─ Window List
    │   ├─ Window Switching
    │   └─ Window Minimize/Close
    │
    ├─ System Tray
    │   ├─ Status Icons
    │   ├─ Popup Menus
    │   └─ Notification Badges
    │
    ├─ Workspace Pager
    │   ├─ Workspace List
    │   ├─ Workspace Switching
    │   └─ Workspace Preview
    │
    ├─ System Clock
    │   ├─ Time Display
    │   ├─ Date Display
    │   └─ Calendar Popup
    │
    └─ Theme Integration
        ├─ libnova Theme Engine
        └─ Dynamic Theme Updates
```

**Responsibilities**:
1. Connect to NOVA Compositor via Wayland layer-shell
2. Create top/bottom panel surface
3. Display running applications in taskbar
4. Display system tray icons
5. Display workspace pager
6. Display system clock
7. Handle window switching
8. Handle workspace switching
9. Respond to theme changes via libnova

**Dependencies**:
- Qt 6.5+ (Core, Gui, WaylandClient)
- libnova (shared library)
- NOVA Compositor (running)
- D-Bus (for system tray integration)

---

### 2.4 NOVA Launcher

**Technology Stack**:
- Language: C++20
- Framework: Qt 6.5+ (Wayland client)
- Protocol: xdg-shell

**Architecture**:
```
NOVA Launcher (nova-launcher)
    ├─ Wayland Client
    │   ├─ xdg-shell Surface (popup window)
    │   └─ Input Handling
    │
    ├─ Application Database
    │   ├─ Desktop File Parsing
    │   ├─ Application Indexing
    │   └─ Application Caching
    │
    ├─ Search Engine
    │   ├─ Fuzzy Search
    │   ├─ Category Filtering
    │   └─ Keyword Matching
    │
    ├─ UI Components
    │   ├─ Search Input
    │   ├─ Application List
    │   ├─ Category Grid
    │   └─ Application Icons
    │
    └─ Application Launcher
        ├─ D-Bus Activation
        ├─ posix_spawn
        └─ Process Management
```

**Responsibilities**:
1. Connect to NOVA Compositor via Wayland xdg-shell
2. Parse .desktop files from /usr/share/applications
3. Index applications for fast search
4. Display search UI
5. Implement fuzzy search
6. Launch applications via D-Bus or posix_spawn
7. Respond to theme changes via libnova

**Dependencies**:
- Qt 6.5+ (Core, Gui, WaylandClient)
- libnova (shared library)
- NOVA Compositor (running)
- D-Bus (for application activation)

---

### 2.5 NOVA Files

**Technology Stack**:
- Language: C++20
- Framework: Qt 6.5+ (Wayland client)
- Filesystem: std::filesystem (C++17)

**Architecture**:
```
NOVA Files (nova-files)
    ├─ Wayland Client
    │   ├─ xdg-shell Surface (main window)
    │   └─ Input Handling
    │
    ├─ File Browser
    │   ├─ Directory Tree
    │   ├─ File List
    │   ├─ File Icons
    │   └─ File Details
    │
    ├─ File Operations
    │   ├─ Copy/Move/Delete
    │   ├─ Rename
    │   ├─ Create Folder
    │   └─ File Properties
    │
    ├─ Btrfs Integration
    │   ├─ Snapshot List
    │   ├─ Snapshot Browse
    │   ├─ Time Travel
    │   └─ Snapshot Restore
    │
    ├─ Bookmarks
    │   ├─ User Bookmarks
    │   ├─ System Bookmarks
    │   └─ Recent Locations
    │
    └─ Theme Integration
        ├─ libnova Theme Engine
        └─ Dynamic Theme Updates
```

**Responsibilities**:
1. Connect to NOVA Compositor via Wayland xdg-shell
2. Browse filesystem directories
3. Perform file operations (copy, move, delete, rename)
4. Display file icons and thumbnails
5. Manage bookmarks
6. Browse Btrfs snapshots
7. Navigate to previous file versions (time travel)
8. Respond to theme changes via libnova

**Dependencies**:
- Qt 6.5+ (Core, Gui, WaylandClient)
- libnova (shared library)
- NOVA Compositor (running)
- btrfs-progs (for snapshot operations)

---

### 2.6 NOVA Settings

**Technology Stack**:
- Language: C++20
- Framework: Qt 6.5+ (Wayland client)

**Architecture**:
```
NOVA Settings (nova-settings)
    ├─ Wayland Client
    │   ├─ xdg-shell Surface (main window)
    │   └─ Input Handling
    │
    ├─ Settings Modules
    │   ├─ Display Settings
    │   ├─ Audio Settings
    │   ├─ Network Settings
    │   ├─ Power Settings
    │   ├─ User Settings
    │   └─ Theme Settings
    │
    ├─ D-Bus Integration
    │   ├─ org.nova.Audio
    │   ├─ org.nova.Display
    │   ├─ org.nova.Network
    │   └─ org.nova.Theme
    │
    └─ Theme Integration
        ├─ libnova Theme Engine
        └─ Dynamic Theme Updates
```

**Responsibilities**:
1. Connect to NOVA Compositor via Wayland xdg-shell
2. Display settings UI with multiple modules
3. Configure display settings via D-Bus
4. Configure audio settings via D-Bus
5. Configure network settings via D-Bus
6. Configure power settings
7. Configure user settings
8. Configure theme settings
9. Respond to theme changes via libnova

**Dependencies**:
- Qt 6.5+ (Core, Gui, WaylandClient)
- libnova (shared library)
- NOVA Compositor (running)
- D-Bus (for settings control)

---

### 2.7 NOVA Notifications

**Technology Stack**:
- Language: C++20
- Framework: None (system daemon)
- Protocol: D-Bus

**Architecture**:
```
NOVA Notifications (nova-notifications)
    ├─ D-Bus Service
    │   ├─ org.freedesktop.Notifications
    │   └─ org.nova.Notifications
    │
    ├─ Notification Queue
    │   ├─ Notification Storage
    │   ├─ Notification History
    │   └─ Notification Expiry
    │
    ├─ Notification Display
    │   ├─ Popup Windows
    │   ├─ Notification Positioning
    │   ├─ Animation Effects
    │   └─ Action Buttons
    │
    ├─ Notification Actions
    │   ├─ Default Action
    │   ├─ Action Buttons
    │   └─ Inline Reply
    │
    └─ Theme Integration
        ├─ libnova Theme Engine
        └─ Dynamic Theme Updates
```

**Responsibilities**:
1. Implement org.freedesktop.Notifications D-Bus interface
2. Receive notification requests from applications
3. Display notification popups
4. Handle notification actions
5. Maintain notification history
6. Expiry notifications after timeout
7. Respond to theme changes via libnova

**Dependencies**:
- D-Bus (system bus)
- libnova (shared library)
- NOVA Compositor (for rendering)

**D-Bus Interface**:
```xml
<node name="/org/freedesktop/Notifications">
  <interface name="org.freedesktop.Notifications">
    <method name="Notify">
      <arg name="app_name" type="s" direction="in"/>
      <arg name="replaces_id" type="u" direction="in"/>
      <arg name="app_icon" type="s" direction="in"/>
      <arg name="summary" type="s" direction="in"/>
      <arg name="body" type="s" direction="in"/>
      <arg name="actions" type="as" direction="in"/>
      <arg name="hints" type="a{sv}" direction="in"/>
      <arg name="expire_timeout" type="i" direction="in"/>
      <arg name="id" type="u" direction="out"/>
    </method>
    <method name="CloseNotification">
      <arg name="id" type="u" direction="in"/>
    </method>
    <signal name="NotificationClosed">
      <arg name="id" type="u"/>
      <arg name="reason" type="u"/>
    </signal>
    <signal name="ActionInvoked">
      <arg name="id" type="u"/>
      <arg name="action_key" type="s"/>
    </signal>
  </interface>
</node>
```

---

### 2.8 NOVA Control Center

**Technology Stack**:
- Language: C++20
- Framework: Qt 6.5+ (Wayland client)
- Protocol: layer-shell

**Architecture**:
```
NOVA Control Center (nova-controlcenter)
    ├─ Wayland Client
    │   ├─ layer-shell Surface (popup)
    │   └─ Input Handling
    │
    ├─ Quick Toggles
    │   ├─ Wi-Fi Toggle
    │   ├─ Bluetooth Toggle
    │   ├─ Airplane Mode Toggle
    │   ├─ Dark Mode Toggle
    │   ├─ Night Light Toggle
    │   └─ Do Not Disturb Toggle
    │
    ├─ Sliders
    │   ├─ Brightness Slider
    │   ├─ Volume Slider
    │   └─ Media Playback Slider
    │
    ├─ D-Bus Integration
    │   ├─ org.nova.Audio
    │   ├─ org.nova.Display
    │   ├─ org.nova.Network
    │   └─ org.nova.Theme
    │
    └─ Theme Integration
        ├─ libnova Theme Engine
        └─ Dynamic Theme Updates
```

**Responsibilities**:
1. Connect to NOVA Compositor via Wayland layer-shell
2. Display quick settings popup
3. Implement toggle buttons (Wi-Fi, Bluetooth, etc.)
4. Implement sliders (brightness, volume)
5. Control audio via D-Bus
6. Control display brightness via D-Bus
7. Control network via D-Bus
8. Control theme via D-Bus
9. Respond to theme changes via libnova

**Dependencies**:
- Qt 6.5+ (Core, Gui, WaylandClient)
- libnova (shared library)
- NOVA Compositor (running)
- D-Bus (for system control)

---

### 2.9 NOVA Audio

**Technology Stack**:
- Language: C++20
- Framework: None (system daemon)
- Backend: PipeWire 1.0+

**Architecture**:
```
NOVA Audio (nova-audio)
    ├─ PipeWire Integration
    │   ├─ PipeWire Connection
    │   ├─ WirePlumber Integration
    │   └─ Audio Device Discovery
    │
    ├─ Audio Control
    │   ├─ Volume Control
    │   ├─ Mute/Unmute
    │   ├─ Device Switching
    │   └─ Stream Routing
    │
    ├─ D-Bus Service
    │   ├─ org.nova.Audio
    │   └─ Audio Event Signals
    │
    └─ VM Audio Integration
        ├─ VirtualBox Audio (PulseAudio)
        └─ VMware Audio (PulseAudio)
```

**Responsibilities**:
1. Connect to PipeWire audio server
2. Discover audio devices (sinks, sources)
3. Control master volume
4. Mute/unmute audio
5. Switch default audio device
6. Route application streams
7. Expose control via D-Bus
8. Handle VM-specific audio (VirtualBox, VMware)

**Dependencies**:
- PipeWire 1.0+
- WirePlumber 0.4+
- pulseaudio (for VM compatibility)
- D-Bus (system bus)

**D-Bus Interface**:
```xml
<node name="/org/nova/Audio">
  <interface name="org.nova.Audio">
    <method name="SetVolume">
      <arg name="volume" type="i" direction="in"/>
    </method>
    <method name="ToggleMute">
      <arg name="muted" type="b" direction="out"/>
    </method>
    <method name="SetDefaultSink">
      <arg name="sink_name" type="s" direction="in"/>
    </method>
    <signal name="VolumeChanged">
      <arg name="volume" type="i"/>
    </signal>
    <signal name="DeviceChanged">
      <arg name="device_name" type="s"/>
    </signal>
  </interface>
</node>
```

---

### 2.10 NOVA Display

**Technology Stack**:
- Language: C++20
- Framework: None (system daemon)
- Backend: NOVA Compositor D-Bus

**Architecture**:
```
NOVA Display (nova-display)
    ├─ Output Management
    │   ├─ Output Discovery
    │   ├─ Output Configuration
    │   └─ Hot-Plug Handling
    │
    ├─ Resolution Control
    │   ├─ Resolution List
    │   ├─ Resolution Switching
    │   └─ Refresh Rate Control
    │
    ├─ Scaling Control
    │   ├─ Fractional Scaling
    │   └─ DPI Awareness
    │
    ├─ D-Bus Service
    │   ├─ org.nova.Display
    │   └─ Display Event Signals
    │
    └─ VM Display Integration
        ├─ VirtualBox Dynamic Resolution
        └─ VMware Dynamic Resolution
```

**Responsibilities**:
1. Discover display outputs via NOVA Compositor
2. Configure output resolution and refresh rate
3. Configure output scaling (fractional scaling)
4. Handle hot-plug events (monitor connect/disconnect)
5. Handle VM window resize events
6. Expose control via D-Bus
7. Integrate with VirtualBox Guest Additions
8. Integrate with VMware Open VM Tools

**Dependencies**:
- NOVA Compositor (D-Bus)
- VirtualBox Guest Additions (optional)
- Open VM Tools (optional)
- D-Bus (system bus)

**D-Bus Interface**:
```xml
<node name="/org/nova/Display">
  <interface name="org.nova.Display">
    <method name="SetResolution">
      <arg name="output_name" type="s" direction="in"/>
      <arg name="width" type="i" direction="in"/>
      <arg name="height" type="i" direction="in"/>
      <arg name="refresh_rate" type="i" direction="in"/>
    </method>
    <method name="SetScale">
      <arg name="output_name" type="s" direction="in"/>
      <arg name="scale" type="d" direction="in"/>
    </method>
    <signal name="OutputAdded">
      <arg name="output_name" type="s"/>
    </signal>
    <signal name="OutputRemoved">
      <arg name="output_name" type="s"/>
    </signal>
  </interface>
</node>
```

---

### 2.11 NOVA Theme

**Technology Stack**:
- Language: C++20
- Framework: None (library)
- Integration: libnova

**Architecture**:
```
NOVA Theme (nova-theme)
    ├─ Theme Engine
    │   ├─ Color Palettes
    │   ├─ Accent Colors
    │   ├─ Dark/Light Mode
    │   └─ Custom Themes
    │
    ├─ Theme Storage
    │   ├─ /usr/share/themes/nova
    │   ├─ ~/.local/share/themes/nova
    │   └─ Theme JSON Configuration
    │
    ├─ Theme Application
    │   ├─ Qt Stylesheets
    │   ├─ GTK Themes
    │   ├─ Icon Themes
    │   └─ Cursor Themes
    │
    ├─ D-Bus Service
    │   ├─ org.nova.Theme
    │   └─ Theme Change Signals
    │
    └─ libnova Integration
        ├─ Theme Engine API
        └─ Theme Callbacks
```

**Responsibilities**:
1. Manage color palettes (dark/light mode)
2. Manage accent colors
3. Load custom themes from disk
4. Apply themes to Qt applications
5. Apply themes to GTK applications
6. Apply icon themes
7. Apply cursor themes
8. Expose control via D-Bus
9. Notify components of theme changes via libnova

**Dependencies**:
- libnova (shared library)
- D-Bus (system bus)

**D-Bus Interface**:
```xml
<node name="/org/nova/Theme">
  <interface name="org.nova.Theme">
    <method name="SetMode">
      <arg name="mode" type="s" direction="in"/>
    </method>
    <method name="SetAccentColor">
      <arg name="color" type="s" direction="in"/>
    </method>
    <method name="LoadTheme">
      <arg name="theme_path" type="s" direction="in"/>
    </method>
    <signal name="ThemeChanged">
      <arg name="mode" type="s"/>
      <arg name="accent_color" type="s"/>
    </signal>
  </interface>
</node>
```

---

### 2.12 NOVA Session

**Technology Stack**:
- Language: C++20
- Framework: None (system daemon)
- Integration: systemd-logind

**Architecture**:
```
NOVA Session (nova-session)
    ├─ Session Management
    │   ├─ Session Start
    │   ├─ Session Stop
    │   ├─ Session Lock
    │   └─ Session Unlock
    │
    ├─ Process Management
    │   ├─ Compositor Start
    │   ├─ Desktop Components Start
    │   ├─ System Services Start
    │   └─ Process Monitoring
    │
    ├─ systemd-logind Integration
    │   ├─ Seat Management
    │   ├─ Session Tracking
    │   └─ Power Events
    │
    ├─ Power Management
    │   ├─ Suspend
    │   ├─ Hibernate
    │   ├─ Reboot
    │   └─ Shutdown
    │
    └─ D-Bus Service
        ├─ org.nova.Session
        └─ Session Event Signals
```

**Responsibilities**:
1. Start NOVA Compositor on session start
2. Start desktop components (shell, panel, launcher, etc.)
3. Start system services (audio, display, notifications)
4. Manage session lock/unlock
5. Integrate with systemd-logind
6. Handle power events (suspend, hibernate, reboot, shutdown)
7. Expose control via D-Bus

**Dependencies**:
- systemd (systemd-logind)
- D-Bus (system bus)
- NOVA Compositor
- All desktop components

**D-Bus Interface**:
```xml
<node name="/org/nova/Session">
  <interface name="org.nova.Session">
    <method name="Lock"/>
    <method name="Unlock"/>
    <method name="Reboot"/>
    <method name="Shutdown"/>
    <signal name="SessionLocked"/>
    <signal name="SessionUnlocked"/>
    <signal name="PowerEvent">
      <arg name="event" type="s"/>
    </signal>
  </interface>
</node>
```

---

## 3. System Services Architecture

### 3.1 PipeWire Audio

**Configuration**:
- `/etc/pipewire/pipewire.conf` - Main configuration
- `/etc/pipewire/pipewire-pulse.conf` - PulseAudio compatibility
- `/etc/wireplumber/main.lua.d/` - WirePlumber scripts

**Integration**:
- NOVA Audio daemon connects to PipeWire
- WirePlumber manages audio devices
- PulseAudio compatibility for VMs

### 3.2 NetworkManager

**Configuration**:
- `/etc/NetworkManager/NetworkManager.conf` - Main configuration
- `/etc/NetworkManager/system-connections/` - Connection profiles

**Integration**:
- NOVA Control Center controls NetworkManager via D-Bus
- NOVA Settings displays network status via D-Bus

### 3.3 Bluetooth (bluez)

**Configuration**:
- `/etc/bluetooth/main.conf` - Main configuration

**Integration**:
- NOVA Control Center controls bluez via D-Bus
- NOVA Settings displays Bluetooth status via D-Bus

### 3.4 systemd Services

**Required Services**:
```
nova-compositor.service - NOVA Compositor
nova-shell.service - NOVA Shell
nova-panel.service - NOVA Panel
nova-launcher.service - NOVA Launcher (on-demand)
nova-files.service - NOVA Files (on-demand)
nova-settings.service - NOVA Settings (on-demand)
nova-notifications.service - NOVA Notifications
nova-controlcenter.service - NOVA Control Center (on-demand)
nova-audio.service - NOVA Audio
nova-display.service - NOVA Display
nova-theme.service - NOVA Theme
nova-session.service - NOVA Session
```

**Service Example** (nova-compositor.service):
```ini
[Unit]
Description=NOVA Wayland Compositor
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
ExecStart=/usr/bin/nova-compositor
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
```

---

## 4. libnova Shared Library

### 4.1 Library Components

```
libnova.so
    ├─ Theme Engine
    │   ├─ ThemeMode enum (Light/Dark)
    │   ├─ ColorPalette struct
    │   ├─ ThemeEngine class
    │   └─ Theme callback system
    │
    ├─ IPC Helpers
    │   ├─ D-Bus connection helpers
    │   ├─ D-Bus method call helpers
    │   └─ D-Bus signal subscription helpers
    │
    ├─ Common Data Structures
    │   ├─ WindowMetadata
    │   ├─ OutputDisplay
    │   ├─ AudioDevice
    │   └─ DisplayOutput
    │
    └─ Utility Functions
        ├─ Logging
        ├─ Configuration
        └─ Error handling
```

### 4.2 API Example

```cpp
// Theme Engine
#include <nova/libnova.h>

// Get theme engine instance
Nova::ThemeEngine& theme = Nova::ThemeEngine::instance();

// Set theme mode
theme.setMode(Nova::ThemeMode::Dark);

// Set accent color
theme.setAccentColor("#38BDF8");

// Get color palette
Nova::ColorPalette palette = theme.getPalette();

// Register theme change callback
theme.registerCallback([](Nova::ThemeMode mode, const std::string& accent) {
    // Handle theme change
});

// Generate Qt stylesheet
std::string stylesheet = theme.generateQtStylesheet();
```

---

## 5. Security Architecture

### 5.1 Sandbox Architecture

**Component Sandboxing**:
- NOVA Compositor: No sandbox (needs full system access)
- Desktop Components: AppArmor profiles
- System Tools: SELinux/AppArmor confinement
- User Applications: Flatpak/containers

### 5.2 Privilege Separation

**Root Privileges**:
- NOVA Compositor: No (runs as user)
- NOVA Session: No (runs as user)
- NOVA Audio: No (runs as user, uses PipeWire)
- NOVA Display: No (runs as user, uses compositor D-Bus)
- System Tools: Yes (for privileged operations)

### 5.3 Secure Communication

**D-Bus Security**:
- System bus: System services only
- Session bus: User applications
- PolicyKit: Authorization for privileged operations

---

## 6. Performance Architecture

### 6.1 Rendering Performance

**Optimizations**:
- Damage tracking (only redraw changed regions)
- Direct scan-out ( bypass compositor for fullscreen)
- GPU acceleration (EGL/Vulkan)
- Frame pacing (presentation-time protocol)

### 6.2 Input Latency

**Optimizations**:
- libinput direct integration
- Input event batching
- Minimal input latency path

### 6.3 Memory Usage

**Optimizations**:
- Shared memory for Wayland buffers
- Texture compression
- Lazy resource loading

---

## 7. Boot Sequence

### 7.1 Boot Flow

```
1. Bootloader (GRUB)
   ↓
2. Linux Kernel
   ↓
3. systemd (init)
   ↓
4. systemd-logind (session manager)
   ↓
5. Display Manager (gdm/lightdm - optional)
   ↓
6. User Login
   ↓
7. nova-session.service starts
   ↓
8. nova-compositor.service starts
   ↓
9. Desktop components start
   ├─ nova-shell.service
   ├─ nova-panel.service
   ├─ nova-notifications.service
   ├─ nova-audio.service
   ├─ nova-display.service
   └─ nova-theme.service
   ↓
10. System services start
    ├─ PipeWire
    ├─ NetworkManager
    └─ bluez
   ↓
11. Desktop Environment Ready
```

---

## 8. Implementation Roadmap

### 8.1 Phase 10.1: Build Infrastructure
- Complete CMake configuration for all components
- Add pkg-config integration
- Set up CI/CD pipeline
- Verify builds on multiple distributions

### 8.2 Phase 10.2: Compositor Core
- Implement wlroots backend
- Add DRM/KMS initialization
- Implement libinput handling
- Create event loop
- Add xdg-shell protocol
- Implement basic rendering

### 8.3 Phase 10.3: Desktop Components
- Convert Python components to C++
- Add Qt6 Wayland client integration
- Implement D-Bus services
- Create component-compositor IPC

### 8.4 Phase 10.4: System Services
- Implement PipeWire integration
- Implement NetworkManager integration
- Implement bluez integration
- Create systemd service files

### 8.5 Phase 10.5: Integration Testing
- Test compositor with actual clients
- Verify component communication
- Test multi-monitor support
- Test dynamic resolution

### 8.6 Phase 10.6: VM Testing
- Build bootable ISO
- Test VirtualBox boot
- Test VMware boot
- Verify guest tools integration
- Test dynamic resolution

---

## 9. Conclusion

This document defines the **required runtime architecture** for NOVA OS as a native Linux distribution. The current implementation does NOT match this architecture.

**Key Requirements**:
1. All components must be native C++/Rust (no Python runtime dependencies)
2. Wayland compositor with full wlroots integration
3. Qt6 GUI for all desktop components
4. D-Bus for system services
5. systemd for service management
6. PipeWire for audio
7. Full VM compatibility (VirtualBox, VMware)

**Phase 10 Goal**: Transform the current stub implementations into this functional architecture.

---

**END OF DOCUMENT**

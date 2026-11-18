// App-layer internal header: the global state and the module interfaces that main.cpp, the tray, the
// menu, the polling worker and the command line share. Nothing outside src\app\ includes this; the
// app's modules are not a public interface.
#pragma once

#include <windows.h>

#include <map>
#include <string>
#include <vector>

#include "../core/devices.h"
#include "cli.h"
#include "menu.h"
#include "tray.h"
#include "worker.h"

// Window messages the app posts to itself.
constexpr UINT WM_TRAY = WM_APP + 1;
constexpr UINT WM_RESULTS = WM_APP + 2;
constexpr UINT WM_WIDGET_CLICK = WM_APP + 3;

// Window timers.
constexpr UINT_PTR TIMER_DEBOUNCE = 1;
constexpr UINT_PTR TIMER_WIDGET = 2;
constexpr UINT_PTR TIMER_BURST = 3;

// A device that just connected (a Bluetooth headset especially) becomes a device node before Windows
// publishes its battery, so look again a few times instead of waiting for the next minute-long poll.
constexpr DWORD kPollBurstDelays[] = { 1500, 7000, 20000, 45000 };

constexpr UINT PLACEHOLDER_ID = 1;

// ---- global state (defined in main.cpp) -------------------------------------------------------

extern HINSTANCE g_inst;
extern HWND g_hwnd;
extern HANDLE g_refreshEvt, g_stopEvt, g_worker;
extern UINT g_taskbarCreatedMsg;
extern bool g_lightTaskbar;
extern bool g_wantWidget;      // user's choice: taskbar widget (default) or tray icons
extern bool g_useWidget;       // what is actually shown right now
extern bool g_hideLastKnown;   // hide (last known) / asleep devices from taskbar and tray
extern std::wstring g_widgetMonitor;  // which taskbars show the widget: "all", "main" or one monitor id
extern int g_widgetBackground;  // opacity (0-100 %) of the plate behind the taskbar text, 0 = none
extern int g_burstStep;         // next entry of kPollBurstDelays, while a device-change burst is running
extern bool g_burstActive;
extern int g_widgetFailTicks;         // seconds the taskbar widget has been unavailable (see NotifyWidgetFallback)
extern bool g_widgetFailNotified;     // that hint is shown once per run
extern bool g_stacked;      // icon above the percentage (menu option)
extern bool g_brandColors;  // off by default; known brands get their color (Razer green, Logitech blue, ...)
extern std::map<std::wstring, TrayEntry> g_entries;
extern bool g_placeholder;
extern HICON g_placeholderIcon;
extern bool g_demo;  // `--demo`: sample devices instead of real ones (see worker.cpp)

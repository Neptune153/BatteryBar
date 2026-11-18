// BatteryBar - tray app showing the battery level of wireless mice, headsets and Bluetooth devices.
#include <windows.h>
#include <shellapi.h>
#include <dbt.h>
#include <initguid.h>
#include <hidclass.h>

#include <algorithm>
#include <climits>
#include <cstdio>
#include <map>
#include <set>
#include <string>
#include <vector>

#include "core/devices.h"
#include "text/i18n.h"
#include "text/labels.h"
#include "app/app_internal.h"
#include "app/settings.h"
#include "app/widget/widget.h"

using namespace settings;

const wchar_t* kAppName = L"BatteryBar";
const wchar_t* kRunValue = L"BatteryBar";

// ---- global state -----------------------------------------------------------------------------

HINSTANCE g_inst;
HWND g_hwnd;
HANDLE g_refreshEvt, g_stopEvt, g_worker;
UINT g_taskbarCreatedMsg;
bool g_lightTaskbar;
bool g_wantWidget = true;      // user's choice: taskbar widget (default) or tray icons
bool g_useWidget = false;      // what is actually shown right now
bool g_hideLastKnown = false;  // hide (last known) / asleep devices from taskbar and tray
std::wstring g_widgetMonitor = L"all";  // which taskbars show the widget: "all", "main" or one monitor id
int g_widgetBackground = 0;  // opacity (0-100 %) of the plate behind the taskbar text, 0 = none
int g_burstStep = 0;         // next entry of kPollBurstDelays, while a device-change burst is running
bool g_burstActive = false;
int g_widgetFailTicks = 0;         // seconds the taskbar widget has been unavailable (see NotifyWidgetFallback)
bool g_widgetFailNotified = false;  // that hint is shown once per run
bool g_stacked = false;      // icon above the percentage (menu option)
bool g_brandColors = false;  // off by default; known brands get their color (Razer green, Logitech blue, ...)
std::map<std::wstring, TrayEntry> g_entries;
bool g_placeholder = false;
HICON g_placeholderIcon = nullptr;
bool g_demo = false;  // `--demo`: sample devices instead of real ones (see worker.cpp)

// ---- window procedure -------------------------------------------------------------------------

LRESULT CALLBACK WndProc(HWND h, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == g_taskbarCreatedMsg && msg != 0) {  // Explorer restarted
        widget::Destroy();
        g_useWidget = false;
        RebuildTrayIcons();
        Reconcile();
        return 0;
    }
    switch (msg) {
        case WM_RESULTS: {
            auto* v = reinterpret_cast<std::vector<DeviceStatus>*>(lParam);
            OnResults(*v);
            delete v;
            return 0;
        }
        case WM_TRAY:
            switch (LOWORD(lParam)) {
                case WM_CONTEXTMENU:
                case NIN_SELECT:
                case NIN_KEYSELECT: ShowMenu(); break;
            }
            return 0;
        case WM_WIDGET_CLICK:
            ShowMenu();
            return 0;
        case WM_ENDSESSION:  // sign-out / shutdown / installer restart manager
            if (wParam) DestroyWindow(h);
            return 0;
        case WM_DEVICECHANGE:
            // DBT_DEVNODES_CHANGED is the system-wide "a device was added or removed" broadcast: it is
            // what a Bluetooth headset raises, and it is the only notification this app gets for one,
            // because only HID interfaces are registered for separately below.
            if (wParam == DBT_DEVICEARRIVAL || wParam == DBT_DEVICEREMOVECOMPLETE || wParam == DBT_DEVNODES_CHANGED)
                StartRefreshBurst();
            return TRUE;
        case WM_POWERBROADCAST:
            if (wParam == PBT_APMRESUMEAUTOMATIC) RefreshSoon(5000);
            return TRUE;
        case WM_TIMER:
            if (wParam == TIMER_DEBOUNCE) { KillTimer(h, TIMER_DEBOUNCE); SetEvent(g_refreshEvt); }
            if (wParam == TIMER_WIDGET) Reconcile();
            if (wParam == TIMER_BURST) {
                SetEvent(g_refreshEvt);
                if (g_burstStep + 1 < (int)ARRAYSIZE(kPollBurstDelays)) {
                    ++g_burstStep;
                    SetTimer(h, TIMER_BURST, kPollBurstDelays[g_burstStep] - kPollBurstDelays[g_burstStep - 1], nullptr);
                } else {
                    KillTimer(h, TIMER_BURST);
                    g_burstActive = false;
                }
            }
            return 0;
        case WM_SETTINGCHANGE:
            if (lParam && !lstrcmpW((LPCWSTR)lParam, L"ImmersiveColorSet")) {
                bool light = ReadLightTaskbar();
                if (light != g_lightTaskbar) { g_lightTaskbar = light; ApplyMenuTheme(light); RedrawAll(); widget::SetLightTheme(light); }
            }
            return 0;
        case WM_DESTROY:
            KillTimer(h, TIMER_WIDGET);
            widget::Destroy();
            SetEvent(g_stopEvt);
            if (g_worker) WaitForSingleObject(g_worker, 5000);
            for (auto& [k, e] : g_entries) {
                if (e.added) RemoveTrayIcon(e.uid);
                if (e.icon) DestroyIcon(e.icon);
            }
            if (g_placeholder) RemoveTrayIcon(PLACEHOLDER_ID);
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(h, msg, wParam, lParam);
}

// The taskbar child window and the tray icon both go through Explorer, which only accepts them
// from a process at its own integrity level. One started by a lower-privileged program can use
// neither, so say why instead of leaving a process running with nothing on screen.
static int IntegrityLevel() {
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return SECURITY_MANDATORY_MEDIUM_RID;
    DWORD size = 0;
    GetTokenInformation(token, TokenIntegrityLevel, nullptr, 0, &size);
    std::vector<BYTE> buf(size ? size : sizeof(TOKEN_MANDATORY_LABEL));
    int level = SECURITY_MANDATORY_MEDIUM_RID;
    if (GetTokenInformation(token, TokenIntegrityLevel, buf.data(), (DWORD)buf.size(), &size)) {
        auto* label = reinterpret_cast<TOKEN_MANDATORY_LABEL*>(buf.data());
        BYTE count = *GetSidSubAuthorityCount(label->Label.Sid);
        if (count > 0) level = (int)*GetSidSubAuthority(label->Label.Sid, count - 1);
    }
    CloseHandle(token);
    return level;
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE, PWSTR cmdLine, int) {
    if (cmdLine && wcsstr(cmdLine, L"--list")) return RunCommandLine(false);
    if (cmdLine && wcsstr(cmdLine, L"--dump")) return RunCommandLine(true);
    if (cmdLine && wcsstr(cmdLine, L"--quit")) {  // used by the installer before upgrading/uninstalling
        if (HWND w = FindWindowW(L"BatteryBarWnd", nullptr)) {
            PostMessageW(w, WM_CLOSE, 0, 0);
            for (int i = 0; i < 50 && FindWindowW(L"BatteryBarWnd", nullptr); i++) Sleep(100);
        }
        return 0;
    }
    g_inst = inst;
    g_demo = cmdLine && wcsstr(cmdLine, L"--demo");

    HANDLE mutex = CreateMutexW(nullptr, TRUE, L"Local\\BatteryBarTray");
    if (GetLastError() == ERROR_ALREADY_EXISTS) return 0;

    if (IntegrityLevel() < SECURITY_MANDATORY_MEDIUM_RID) {
        i18n::Init();  // the text below is localized, so pick the language before showing it
        MessageBoxW(nullptr,
                    T(L"Windows does not let a program started by a lower-privileged program use the taskbar or the notification area. Close it, then start it again from the Start menu, or by double-clicking it in File Explorer."),
                    T(L"Started with lower permissions"), MB_OK | MB_ICONWARNING | MB_TOPMOST | MB_SETFOREGROUND);
        return 0;
    }

    g_lightTaskbar = ReadLightTaskbar();
    ApplyMenuTheme(g_lightTaskbar);
    g_taskbarCreatedMsg = RegisterWindowMessageW(L"TaskbarCreated");

    WNDCLASSEXW wc{ sizeof(wc) };
    wc.lpfnWndProc = WndProc;
    wc.hInstance = inst;
    wc.lpszClassName = L"BatteryBarWnd";
    RegisterClassExW(&wc);
    // A hidden top-level window (not message-only) so it receives the TaskbarCreated broadcast.
    g_hwnd = CreateWindowExW(WS_EX_TOOLWINDOW, wc.lpszClassName, kAppName, WS_POPUP, 0, 0, 0, 0, nullptr, nullptr, inst, nullptr);
    if (!g_hwnd) return 1;

    DEV_BROADCAST_DEVICEINTERFACE_W filter{ sizeof(filter) };
    filter.dbcc_devicetype = DBT_DEVTYP_DEVICEINTERFACE;
    filter.dbcc_classguid = GUID_DEVINTERFACE_HID;
    HDEVNOTIFY notify = RegisterDeviceNotificationW(g_hwnd, &filter, DEVICE_NOTIFY_WINDOW_HANDLE);

    g_refreshEvt = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    g_stopEvt = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    g_wantWidget = LoadWidgetMode();
    g_hideLastKnown = LoadHideLastKnown();
    settings::MigrateFromOldName();
    g_widgetBackground = LoadWidgetBackground();
    g_brandColors = LoadBrandColors();
    g_stacked = LoadStacked();
    widget::SetStacked(g_stacked);
    widget::SetBackgroundOpacity(g_widgetBackground);  // remembered by the widget across re-creation
    i18n::Init();
    g_widgetMonitor = LoadWidgetMonitor();
    widget::SetMonitorChoice(g_widgetMonitor);
    LoadHidden();
    LoadOrder();
    Reconcile();
    UpdatePlaceholder();  // something to click on until the first poll finishes
    SetTimer(g_hwnd, TIMER_WIDGET, 1000, nullptr);
    g_worker = CreateThread(nullptr, 0, Worker, nullptr, 0, nullptr);

    MSG m;
    while (GetMessageW(&m, nullptr, 0, 0) > 0) {
        TranslateMessage(&m);
        DispatchMessageW(&m);
    }
    // drain results posted after shutdown started
    while (PeekMessageW(&m, nullptr, WM_RESULTS, WM_RESULTS, PM_REMOVE)) delete reinterpret_cast<std::vector<DeviceStatus>*>(m.lParam);
    if (notify) UnregisterDeviceNotification(notify);
    if (g_worker) CloseHandle(g_worker);
    ReleaseMutex(mutex);
    return 0;
}

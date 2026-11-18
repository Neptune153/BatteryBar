// The context menu of the tray icon and of the taskbar widget: builds the items, shows the menu and
// runs the command it returns.
#include <windows.h>
#include <shellapi.h>

#include <algorithm>
#include <string>
#include <vector>

#include "../text/i18n.h"
#include "app_internal.h"
#include "menu.h"
#include "settings.h"
#include "tray.h"
#include "widget/widget.h"

using namespace settings;

namespace {

enum MenuId : UINT {
    ID_REFRESH = 100, ID_AUTOSTART, ID_HIDE_LAST_KNOWN, ID_EXIT, ID_MODE_WIDGET, ID_MODE_TRAY, ID_SUPPORT,
    ID_BRAND_COLORS, ID_STACKED,
    ID_WIDGET_BG_FIRST = 130,  // "Background behind taskbar text": ID_WIDGET_BG_FIRST + opacity / 10
    ID_LANG_AUTO = 400, ID_LANG_ADD, ID_LANG_FIRST,  // "Language": ID_LANG_FIRST + 0..63
    ID_MONITOR_ALL = 300, ID_MONITOR_MAIN, ID_MONITOR_FIRST,  // "Show the widget on": ID_MONITOR_FIRST + 0..31
    ID_DEVICE_FIRST = 1000
};
enum DeviceCmd : UINT { DEV_TOGGLE, DEV_LEFT, DEV_RIGHT, DEV_STRIDE = 4 };

// What the ids of the menu that is currently up refer to: HandleCommand needs the same lists that
// built it. ShowMenu copies them out of its locals right before it dispatches, so a menu opened from
// inside a menu item handler cannot disturb the call that is still running.
struct MenuContext {
    std::vector<std::wstring> keys;  // device index -> device key; menu id ID_DEVICE_FIRST + index * DEV_STRIDE + command
    std::vector<widget::MonitorOption> monitors;
    std::vector<i18n::Language> languages;
} g_menu;

}  // namespace

void ShowMenu() {
    ApplyMenuTheme(g_lightTaskbar);
    HMENU m = CreatePopupMenu();
    std::vector<std::wstring> keys;  // device index -> device key; menu id ID_DEVICE_FIRST + index * DEV_STRIDE + command
    std::vector<TrayEntry*> all = OrderedEntries(false), shown = OrderedEntries(true);
    if (all.empty()) AppendMenuW(m, MF_STRING | MF_GRAYED, 0, T(L"No devices with battery info found"));
    else AppendMenuW(m, MF_STRING | MF_GRAYED, 0, T(L"Point at a device to show, hide or move it"));
    for (TrayEntry* e : all) {
        const std::wstring& k = e->st.key;
        UINT base = ID_DEVICE_FIRST + (UINT)keys.size() * DEV_STRIDE;
        auto pos = std::find(shown.begin(), shown.end(), e);
        bool canLeft = pos != shown.end() && pos != shown.begin();
        bool canRight = pos != shown.end() && pos + 1 != shown.end();
        HMENU sub = CreatePopupMenu();
        AppendMenuW(sub, MF_STRING | (IsHidden(k) ? 0 : MF_CHECKED), base + DEV_TOGGLE,
                    g_wantWidget ? T(L"Show on the taskbar") : T(L"Show in the tray"));
        AppendMenuW(sub, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(sub, MF_STRING | (canLeft ? 0 : MF_GRAYED), base + DEV_LEFT, g_wantWidget ? T(L"Move left") : T(L"Move up"));
        AppendMenuW(sub, MF_STRING | (canRight ? 0 : MF_GRAYED), base + DEV_RIGHT, g_wantWidget ? T(L"Move right") : T(L"Move down"));
        std::wstring line = e->st.name + L":  " + StatusText(*e) + L"   [" + T(e->st.via) + L"]";
        AppendMenuW(m, MF_POPUP | (IsHidden(k) ? 0 : MF_CHECKED), (UINT_PTR)sub, line.c_str());
        keys.push_back(k);
    }
    AppendMenuW(m, MF_STRING | (g_hideLastKnown ? MF_CHECKED : 0), ID_HIDE_LAST_KNOWN, T(L"Hide last known / asleep devices"));
    AppendMenuW(m, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(m, MF_STRING | (g_wantWidget ? MF_CHECKED : 0), ID_MODE_WIDGET, T(L"Show on the taskbar (icon + percentage)"));
    AppendMenuW(m, MF_STRING | (!g_wantWidget ? MF_CHECKED : 0), ID_MODE_TRAY, T(L"Show as tray icons"));
    CheckMenuRadioItem(m, ID_MODE_WIDGET, ID_MODE_TRAY, g_wantWidget ? ID_MODE_WIDGET : ID_MODE_TRAY, MF_BYCOMMAND);
    // How opaque the plate behind the text is; "None" keeps the old off state.
    {
        HMENU sub = CreatePopupMenu();
        UINT f = MF_STRING | (g_wantWidget ? 0 : MF_GRAYED);
        for (int pct = 0; pct <= 100; pct += 10) {
            std::wstring label = pct == 0 ? T(L"None") : std::to_wstring(pct) + L"%";
            AppendMenuW(sub, f, ID_WIDGET_BG_FIRST + pct / 10, label.c_str());
        }
        CheckMenuRadioItem(sub, ID_WIDGET_BG_FIRST, ID_WIDGET_BG_FIRST + 10, ID_WIDGET_BG_FIRST + g_widgetBackground / 10,
                           MF_BYCOMMAND);
        AppendMenuW(m, MF_POPUP | (g_wantWidget ? 0 : MF_GRAYED), (UINT_PTR)sub,
                    T(L"Background behind taskbar text (for transparent taskbars)"));
    }
    AppendMenuW(m, MF_STRING | (g_stacked ? MF_CHECKED : 0) | (g_wantWidget ? 0 : MF_GRAYED), ID_STACKED, T(L"Icons above percentages (narrower)"));
    // With more than one monitor: choose which taskbars show the widget (all, main only, or one monitor).
    auto monitors = widget::OtherMonitors();
    if (monitors.size() > 31) monitors.resize(31);
    if (!monitors.empty()) {
        HMENU sub = CreatePopupMenu();
        UINT f = MF_STRING | (g_wantWidget ? 0 : MF_GRAYED);
        AppendMenuW(sub, f, ID_MONITOR_ALL, T(L"All monitors"));
        AppendMenuW(sub, f, ID_MONITOR_MAIN, T(L"Main monitor only"));
        UINT checked = g_widgetMonitor == L"main" ? ID_MONITOR_MAIN : ID_MONITOR_ALL;
        bool found = g_widgetMonitor == L"all" || g_widgetMonitor == L"main";
        for (UINT i = 0; i < monitors.size(); i++) {
            AppendMenuW(sub, f, ID_MONITOR_FIRST + i, TF(L"{monitor} only", { { L"monitor", monitors[i].label } }).c_str());
            if (monitors[i].id == g_widgetMonitor) { checked = ID_MONITOR_FIRST + i; found = true; }
        }
        if (!found) {  // the chosen monitor is unplugged: the main taskbar shows the widget meanwhile
            AppendMenuW(sub, MF_STRING | MF_GRAYED, ID_MONITOR_FIRST + 31, T(L"Chosen monitor (not connected, shown on main)"));
            checked = ID_MONITOR_FIRST + 31;
        }
        CheckMenuRadioItem(sub, ID_MONITOR_ALL, ID_MONITOR_FIRST + 31, checked, MF_BYCOMMAND);
        AppendMenuW(m, MF_POPUP | (g_wantWidget ? 0 : MF_GRAYED), (UINT_PTR)sub, T(L"Show the widget on"));
    }
    AppendMenuW(m, MF_STRING | (g_brandColors ? MF_CHECKED : 0), ID_BRAND_COLORS, T(L"Brand colors (Razer green, Logitech blue, ...)"));
    AppendMenuW(m, MF_SEPARATOR, 0, nullptr);
    // Language: automatic, every built-in or user-added language (in its own name), and a way to add one.
    i18n::Init();  // picks up language files added since the last time
    auto languages = i18n::Available();
    if (languages.size() > 64) languages.resize(64);
    {
        HMENU sub = CreatePopupMenu();
        AppendMenuW(sub, MF_STRING, ID_LANG_AUTO, T(L"Automatic (Windows language)"));
        AppendMenuW(sub, MF_SEPARATOR, 0, nullptr);
        UINT checked = ID_LANG_AUTO;
        for (UINT i = 0; i < languages.size(); i++) {
            AppendMenuW(sub, MF_STRING, ID_LANG_FIRST + i, languages[i].name.c_str());
            if (!i18n::Choice().empty() && _wcsicmp(languages[i].code.c_str(), i18n::Choice().c_str()) == 0) checked = ID_LANG_FIRST + i;
        }
        CheckMenuRadioItem(sub, ID_LANG_AUTO, ID_LANG_FIRST + 63, checked, MF_BYCOMMAND);
        AppendMenuW(sub, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(sub, MF_STRING, ID_LANG_ADD, T(L"Add your own language..."));
        AppendMenuW(m, MF_POPUP, (UINT_PTR)sub, T(L"Language"));
    }
    AppendMenuW(m, MF_STRING, ID_REFRESH, T(L"Refresh now"));
    AppendMenuW(m, MF_STRING | (AutostartEnabled() ? MF_CHECKED : 0), ID_AUTOSTART, T(L"Start with Windows"));
    AppendMenuW(m, MF_STRING, ID_SUPPORT, T(L"Support the project..."));
    AppendMenuW(m, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(m, MF_STRING, ID_EXIT, T(L"Exit"));
    POINT pt;
    GetCursorPos(&pt);
    SetForegroundWindow(g_hwnd);
    UINT cmd = TrackPopupMenu(m, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON | (i18n::Rtl() ? TPM_LAYOUTRTL : 0), pt.x, pt.y, 0,
                              g_hwnd, nullptr);
    PostMessageW(g_hwnd, WM_NULL, 0, 0);
    DestroyMenu(m);
    g_menu.keys = keys;
    g_menu.monitors = monitors;
    g_menu.languages = languages;
    HandleCommand(cmd);
}

void HandleCommand(UINT id) {
    switch (id) {
        case ID_REFRESH: SetEvent(g_refreshEvt); break;
        case ID_AUTOSTART: SetAutostart(!AutostartEnabled()); break;
        case ID_HIDE_LAST_KNOWN: SetHideLastKnown(!g_hideLastKnown); break;
        case ID_MONITOR_ALL: SetWidgetMonitor(L"all"); break;
        case ID_LANG_AUTO: SetLanguage(L""); break;
        case ID_LANG_ADD: i18n::OpenUserFolder(); break;
        case ID_MONITOR_MAIN: SetWidgetMonitor(L"main"); break;
        case ID_BRAND_COLORS: SetBrandColors(!g_brandColors); break;
        case ID_STACKED: SetStacked(!g_stacked); break;
        case ID_MODE_WIDGET: SetMode(true); break;
        case ID_MODE_TRAY: SetMode(false); break;
        case ID_SUPPORT: ShellExecuteW(nullptr, L"open", L"https://github.com/sponsors/krisgfx9", nullptr, nullptr, SW_SHOWNORMAL); break;
        case ID_EXIT: DestroyWindow(g_hwnd); break;
        default:
            if (id >= ID_WIDGET_BG_FIRST && id <= ID_WIDGET_BG_FIRST + 10) {
                SetWidgetBackground((int)(id - ID_WIDGET_BG_FIRST) * 10);
            } else if (id >= ID_LANG_FIRST && id < ID_LANG_FIRST + g_menu.languages.size()) {
                SetLanguage(g_menu.languages[id - ID_LANG_FIRST].code);
            } else if (id >= ID_MONITOR_FIRST && id < ID_MONITOR_FIRST + g_menu.monitors.size()) {
                SetWidgetMonitor(g_menu.monitors[id - ID_MONITOR_FIRST].id);
            } else if (id >= ID_DEVICE_FIRST && id < ID_DEVICE_FIRST + g_menu.keys.size() * DEV_STRIDE) {
                std::wstring key = g_menu.keys[(id - ID_DEVICE_FIRST) / DEV_STRIDE];
                switch ((id - ID_DEVICE_FIRST) % DEV_STRIDE) {
                    case DEV_TOGGLE: ToggleHidden(key); break;
                    case DEV_LEFT:   MoveEntry(key, -1); break;
                    case DEV_RIGHT:  MoveEntry(key, +1); break;
                }
            }
    }
}

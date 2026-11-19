// The notification area: the tray icons for the devices, the placeholder icon shown while no device is
// known, the item list of the taskbar widget, and the fallback hint when the widget cannot be created.
#include <windows.h>
#include <shellapi.h>

#include <algorithm>
#include <climits>
#include <cstddef>
#include <cstring>
#include <map>
#include <string>
#include <vector>

#include "../core/devices.h"
#include "../text/brands.h"
#include "../text/i18n.h"
#include "../text/labels.h"
#include "app_internal.h"
#include "settings.h"
#include "tray.h"
#include "widget/widget.h"

using namespace settings;

namespace {

constexpr int LOW_BATTERY = 15;

// ---- helpers ----------------------------------------------------------------------------------

bool IsEntryHidden(const TrayEntry& e) {
    return IsHidden(e.st.key) || (g_hideLastKnown && (e.st.asleep || (e.st.percent < 0 && e.lastPct >= 0)));
}

// ---- tray icon --------------------------------------------------------------------------------
// The notification area holds a single icon: the app icon, and the menu behind it. Device levels
// live in the taskbar widget, so the tray no longer draws one icon per device.

HICON AppIcon() {
    const int size = GetSystemMetrics(SM_CXSMICON);
    HICON icon = static_cast<HICON>(
        LoadImageW(g_inst, MAKEINTRESOURCEW(1), IMAGE_ICON, size, size, LR_DEFAULTCOLOR | LR_SHARED));
    // This project does not define UNICODE, so IDI_APPLICATION expands to a narrow resource id.
    return icon ? icon : LoadIconW(nullptr, reinterpret_cast<LPCWSTR>(IDI_APPLICATION));
}

Accent AccentFor(const DeviceStatus& s) { return g_brandColors ? BrandOf(s) : Accent::None; }

// ---- tray management --------------------------------------------------------------------------

void CopyTip(wchar_t* dst, size_t cap, const std::wstring& s) {
    wcsncpy(dst, s.c_str(), cap - 1);
    dst[cap - 1] = 0;
}

bool SendTrayMessage(DWORD msg, UINT uid, HICON icon, const std::wstring& tip, const wchar_t* infoTitle = nullptr,
              const std::wstring& info = L"") {
    NOTIFYICONDATAW nid{ sizeof(nid) };
    nid.hWnd = g_hwnd;
    nid.uID = uid;
    nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
    nid.uCallbackMessage = WM_TRAY;
    nid.hIcon = icon;
    CopyTip(nid.szTip, ARRAYSIZE(nid.szTip), tip);
    if (infoTitle) {
        nid.uFlags |= NIF_INFO;
        CopyTip(nid.szInfoTitle, ARRAYSIZE(nid.szInfoTitle), infoTitle);
        CopyTip(nid.szInfo, ARRAYSIZE(nid.szInfo), info);
        nid.dwInfoFlags = NIIF_WARNING;
    }
    BOOL ok = Shell_NotifyIconW(msg, &nid);
    if (msg == NIM_ADD) {
        nid.uVersion = NOTIFYICON_VERSION_4;
        Shell_NotifyIconW(NIM_SETVERSION, &nid);
    }
    return ok != FALSE;
}

// The tooltip of the tray icon: one line per device that the widget shows.
std::wstring TrayTip() {
    std::wstring tip = L"BatteryBar";
    bool any = false;
    for (TrayEntry* e : OrderedEntries(true)) {
        tip += L"\n" + e->st.name + L": " + StatusText(*e);
        any = true;
    }
    if (!any) tip += std::wstring(L"\n") + T(L"No devices with battery info found");
    return tip;
}

// The notification area holds one icon, the way into the menu: added on the first poll, then kept up
// to date. Returns false while Windows refuses it (a lower-integrity process may not use the area).
bool UpdateTrayIcon() {
    std::wstring tip = TrayTip();
    if (g_trayIconAdded) return SendTrayMessage(NIM_MODIFY, kMenuIconId, AppIcon(), tip);
    if (!SendTrayMessage(NIM_ADD, kMenuIconId, AppIcon(), tip)) return false;
    g_trayIconAdded = true;
    return true;
}

// One balloon per device per run, shown on the tray icon.
void MaybeWarnLowBattery(TrayEntry& e) {
    const auto& s = e.st;
    if (s.charging || s.percent < 0 || s.percent > LOW_BATTERY + 10) e.lowWarned = false;
    if (s.charging || s.percent < 0 || s.percent > LOW_BATTERY || e.lowWarned || !g_trayIconAdded) return;
    e.lowWarned = true;
    SendTrayMessage(NIM_MODIFY, kMenuIconId, AppIcon(), TrayTip(), T(L"Low battery"),
                    TF(L"{name} is at {percent}%", { { L"name", s.name }, { L"percent", std::to_wstring(s.percent) } }));
}

int KindOrder(DeviceKind k) {  // default order: headset first, then mouse, ...
    switch (k) {
        case DeviceKind::Headset:  return 0;
        case DeviceKind::Mouse:    return 1;
        case DeviceKind::Keyboard: return 2;
        case DeviceKind::Gamepad:  return 3;
        case DeviceKind::Phone:    return 4;
        default:                   return 5;
    }
}

bool IsShown(const TrayEntry& e) { return e.st.connected && !IsEntryHidden(e); }

void UpdateWidget() {
    if (!g_useWidget) return;
    std::vector<TrayEntry*> list = OrderedEntries(true);
    // Two devices of one kind share an icon: give each a tiny caption so they can be told apart.
    std::vector<LabelInput> labelIn;
    for (auto* e : list) labelIn.push_back({ e->st.kind, e->st.name });
    std::vector<std::wstring> labels = ShortLabels(labelIn, 3);
    std::vector<WidgetItem> items;
    std::wstring tip;
    for (auto* e : list) {
        WidgetItem it;
        it.kind = e->st.kind;
        it.percent = e->st.percent >= 0 ? e->st.percent : e->lastPct;
        if (e->st.percent >= 0) it.text = T(e->st.levelText);
        it.charging = e->st.charging;
        it.dim = e->st.percent < 0;
        it.low = !it.charging && it.percent >= 0 && it.percent <= LOW_BATTERY;
        it.bluetooth = e->st.via == L"Bluetooth";
        it.label = labels[items.size()];
        it.accent = AccentFor(e->st);
        items.push_back(it);
        if (!tip.empty()) tip += L"\n";
        tip += e->st.name + L": " + StatusText(*e);
    }
    if (tip.empty()) tip = std::wstring(L"BatteryBar: ") + T(L"No devices with battery info found");
    widget::SetItems(items, tip);
}

// The widget is a child window of Explorer's taskbar, so Windows refuses to create it when this
// process runs with a lower integrity level than the taskbar (a launcher that drops it to Low) or
// while Explorer is down. Nothing would show up at all then, so say why instead of staying silent.
void NotifyWidgetFallback() {
    if (g_widgetFailNotified) return;
    // Set first: the message box runs its own message loop, in which the once-a-second timer keeps
    // firing, and the hint must not stack up copies of itself.
    g_widgetFailNotified = true;
    std::wstring body = T(L"Could not put the widget on the taskbar.");
    body += L"\n\n";
    body += T(L"This happens when the program was started by another program with lower permissions: close it, then start it again from the Start menu, or by double-clicking the program in File Explorer.");
    MessageBoxW(nullptr, body.c_str(), T(L"Taskbar widget unavailable"),
                MB_OK | MB_ICONWARNING | MB_TOPMOST | MB_SETFOREGROUND);
}

}  // namespace

// ---- exported to the rest of the app ----------------------------------------------------------

void SetWidgetMonitor(const std::wstring& v) {
    g_widgetMonitor = v;
    SaveWidgetMonitor(v);
    widget::SetMonitorChoice(v);
}

std::wstring StatusText(const TrayEntry& e) {
    const auto& s = e.st;
    if (!s.connected) return T(L"off / not connected");
    std::wstring t;
    if (!s.levelText.empty() && s.percent >= 0) t = T(s.levelText);
    else if (s.percent >= 0) t = std::to_wstring(s.percent) + L"%";
    else if (e.lastPct >= 0) t = TF(L"{percent}% (last known)", { { L"percent", std::to_wstring(e.lastPct) } });
    else t = T(L"unknown");
    if (!s.detail.empty() && s.percent >= 0) t += L" (" + s.detail + L")";
    if (s.charging) t += std::wstring(L", ") + T(L"charging");
    if (s.asleep) t += std::wstring(L", ") + T(L"asleep");
    return t;
}

void RemoveTrayIcon(UINT uid) {
    NOTIFYICONDATAW nid{ sizeof(nid) };
    nid.hWnd = g_hwnd;
    nid.uID = uid;
    Shell_NotifyIconW(NIM_DELETE, &nid);
}


// Entries in left-to-right order: the user's order first, then the rest by type and name. Works the
// same for every kind of device (receivers, Bluetooth, controllers, HeadsetControl) as it only uses
// the device key.
std::vector<TrayEntry*> OrderedEntries(bool shownOnly) {
    std::vector<TrayEntry*> list;
    for (auto& [k, e] : g_entries)
        if (!shownOnly || IsShown(e)) list.push_back(&e);
    auto rank = [](const TrayEntry* e) {
        auto it = std::find(OrderKeys().begin(), OrderKeys().end(), e->st.key);
        return it == OrderKeys().end() ? INT_MAX : (int)(it - OrderKeys().begin());
    };
    std::stable_sort(list.begin(), list.end(), [&](const TrayEntry* a, const TrayEntry* b) {
        int ra = rank(a), rb = rank(b);
        if (ra != rb) return ra < rb;
        int ka = KindOrder(a->st.kind), kb = KindOrder(b->st.kind);
        if (ka != kb) return ka < kb;
        return a->st.name != b->st.name ? a->st.name < b->st.name : a->st.key < b->st.key;  // same name: keep a fixed order
    });
    return list;
}

void OnResults(std::vector<DeviceStatus>& results) {
    std::map<std::wstring, bool> seen;
    for (auto& s : results) {
        auto& e = g_entries[s.key];
        e.st = s;
        if (s.percent >= 0) e.lastPct = s.percent;
        e.lastSeen = GetTickCount64();
        seen[s.key] = true;
        MaybeWarnLowBattery(e);
    }
    for (auto it = g_entries.begin(); it != g_entries.end();) {
        auto& e = it->second;
        // Some receivers drop sleeping devices from the link; keep showing the last value for a while.
        bool inGrace = !seen.count(it->first) && e.st.graceSec > 0 && e.st.connected &&
                       GetTickCount64() - e.lastSeen < (ULONGLONG)e.st.graceSec * 1000;
        if (inGrace) {
            e.st.percent = -1;
            e.st.asleep = true;
        }
        if (!seen.count(it->first) && !inGrace) {
            it = g_entries.erase(it);
        } else {
            ++it;
        }
    }
    UpdateTrayIcon();
    UpdateWidget();
}
// Keeps the widget on the taskbar; called once a second. The tray icon stays: it is the way into the
// menu, not a second display.
void Reconcile() {
    bool alive = widget::Alive();
    if (!alive) alive = widget::Create(g_inst, g_hwnd, WM_WIDGET_CLICK, g_lightTaskbar);
    // A few seconds of that is not Explorer starting up any more, it is this process not being
    // allowed in. Stop being silent about it (once per run).
    if (alive) {
        g_widgetFailTicks = 0;
    } else if (++g_widgetFailTicks >= 10) {
        NotifyWidgetFallback();
    }
    if (alive != g_useWidget) {
        g_useWidget = alive;
        UpdateTrayIcon();
        UpdateWidget();
    } else if (alive) {
        widget::Reposition();
    }
}


void SetWidgetBackground(int percent) {
    g_widgetBackground = percent < 0 ? 0 : (percent > 100 ? 100 : percent);
    SaveWidgetBackground(g_widgetBackground);
    widget::SetBackgroundOpacity(g_widgetBackground);
}

void SetHideLastKnown(bool on) {
    g_hideLastKnown = on;
    SaveHideLastKnown(on);
    UpdateTrayIcon();
    UpdateWidget();
}

void RebuildTrayIcons() {  // Explorer restarted: the icon has to be added again
    g_trayIconAdded = false;
    UpdateTrayIcon();
}

// Switches the UI language ("" = follow Windows) and redraws everything that shows text.
void SetLanguage(const std::wstring& code);

void RedrawAll() { UpdateTrayIcon(); }  // the tooltip carries the UI language and the device names

void SetLanguage(const std::wstring& code) {
    i18n::SetChoice(code);
    RedrawAll();  // tray tooltips and the placeholder text
    UpdateWidget();
}

void SetStacked(bool on) {
    g_stacked = on;
    SaveStacked(on);
    widget::SetStacked(on);
}

void SetBrandColors(bool on) {
    g_brandColors = on;
    SaveBrandColors(on);
    RedrawAll();
    UpdateWidget();
}

void ToggleHidden(const std::wstring& key) {
    if (!HiddenKeys().erase(key)) HiddenKeys().insert(key);
    SaveHidden();
    UpdateTrayIcon();
    UpdateWidget();
}

// Swaps a shown device with its neighbour (dir -1 = left, +1 = right) and remembers the new order.
void MoveEntry(const std::wstring& key, int dir) {
    std::vector<TrayEntry*> list = OrderedEntries(true);
    auto pos = std::find_if(list.begin(), list.end(), [&](const TrayEntry* e) { return e->st.key == key; });
    if (pos == list.end()) return;
    ptrdiff_t i = pos - list.begin(), j = i + dir;
    if (j < 0 || j >= (ptrdiff_t)list.size()) return;
    std::swap(list[i], list[j]);
    std::vector<std::wstring> order;
    for (auto* e : list) order.push_back(e->st.key);
    for (auto& k : OrderKeys())  // keep the places of devices that are not shown right now
        if (std::find(order.begin(), order.end(), k) == order.end()) order.push_back(k);
    OrderKeys() = order;
    SaveOrder();
    UpdateWidget();
}

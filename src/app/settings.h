// Everything this app remembers between runs: the registry keys (HKCU\Software\WirelessBattery), the
// hidden/ordered device lists, the taskbar theme and the autostart entry. No UI code lives here.
#pragma once

#include <windows.h>

#include <set>
#include <string>
#include <vector>

namespace settings {

// FNV-1a over a device key: tray icon ids stay the same across restarts.
unsigned StableId(const std::wstring& key);

bool ReadLightTaskbar();
void ApplyMenuTheme(bool light);
std::wstring ExePath();

// Devices the user hid, as a REG_MULTI_SZ of device keys.
void LoadHidden();
void SaveHidden();
bool IsHidden(const std::wstring& key);
std::set<std::wstring>& HiddenKeys();

// The user's left-to-right order; devices missing here follow in the default order.
void LoadOrder();
void SaveOrder();
std::vector<std::wstring>& OrderKeys();

bool LoadBoolSetting(const wchar_t* name, bool defaultValue);
void SaveBoolSetting(const wchar_t* name, bool on);
int LoadIntSetting(const wchar_t* name, int defaultValue);
void SaveIntSetting(const wchar_t* name, int value);

bool LoadWidgetMode();
void SaveWidgetMode(bool on);
bool LoadHideLastKnown();
void SaveHideLastKnown(bool on);
int LoadWidgetBackground();
void SaveWidgetBackground(int percent);
std::wstring LoadWidgetMonitor();
void SaveWidgetMonitor(const std::wstring& value);
bool LoadStacked();
void SaveStacked(bool on);
bool LoadBrandColors();
void SaveBrandColors(bool on);

bool AutostartEnabled();
void SetAutostart(bool on);

}  // namespace settings

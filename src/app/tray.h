#pragma once
// The notification-area side of the app: the tray icons (their rendering, tooltips and low-battery
// warnings), the placeholder icon shown while no device is known, the item list of the taskbar widget,
// and the fallback hint when the widget cannot be created. Used by the app layer only; see
// app_internal.h.
#include <windows.h>

#include <string>
#include <vector>

#include "../core/devices.h"

// One notification-area icon: the device it shows and the state of that icon.
struct TrayEntry {
    UINT uid = 0;
    DeviceStatus st;
    int lastPct = -1;        // last known percentage, kept while the device sleeps
    ULONGLONG lastSeen = 0;
    bool added = false;
    bool lowWarned = false;
    std::wstring iconSig;    // what the current icon shows, to avoid needless redraws
    HICON icon = nullptr;
};

// A poll finished: merges the results into the tray entries and redraws what changed.
void OnResults(std::vector<DeviceStatus>& results);
// Adds or removes the "no devices" placeholder icon after the entries changed.
void UpdatePlaceholder();
// Makes the actual display match the chosen mode; falls back to tray icons if the taskbar widget cannot
// be created (e.g. Explorer not ready yet). Called once a second.
void Reconcile();
// Forgets every icon and adds them all again, after Explorer restarted.
void RebuildTrayIcons();
// Redraws every icon and tooltip, after the taskbar theme or the UI language changed.
void RedrawAll();
void RemoveTrayIcon(UINT uid);

// The user's display choices, made in the menu.
void SetMode(bool useWidget);
void SetWidgetBackground(int percent);
void SetWidgetMonitor(const std::wstring& v);
void SetHideLastKnown(bool on);
void SetLanguage(const std::wstring& code);
void SetStacked(bool on);
void SetBrandColors(bool on);
void ToggleHidden(const std::wstring& key);
void MoveEntry(const std::wstring& key, int dir);

// Entries in left-to-right order (the user's order first), and the tooltip text of one entry; also
// used by the menu.
std::vector<TrayEntry*> OrderedEntries(bool shownOnly);
std::wstring StatusText(const TrayEntry& e);

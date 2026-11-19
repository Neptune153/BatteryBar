#pragma once
// The notification-area side of the app: the single tray icon (it lists the devices in its tooltip and
// is the way into the menu), the low-battery warnings, the item list of the taskbar widget, and the
// fallback hint when the widget cannot be created. Used by the app layer only; see app_internal.h.
#include <windows.h>

#include <string>
#include <vector>

#include "../core/devices.h"

// One device the app knows about, and the state that outlives a single poll.
struct TrayEntry {
    DeviceStatus st;
    int lastPct = -1;        // last known percentage, kept while the device sleeps
    ULONGLONG lastSeen = 0;
    bool lowWarned = false;  // the low-battery balloon has been shown for this charge
};

// A poll finished: merges the results into the tray entries and redraws what changed.
void OnResults(std::vector<DeviceStatus>& results);
// Keeps the widget on the taskbar and the tray tooltip up to date; called once a second.
void Reconcile();
// Adds the tray icon again after Explorer restarted.
void RebuildTrayIcons();
// Refreshes the tooltip, after the taskbar theme or the UI language changed.
void RedrawAll();
void RemoveTrayIcon(UINT uid);

// The user's display choices, made in the menu.
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

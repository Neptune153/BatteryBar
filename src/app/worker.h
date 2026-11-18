#pragma once
// The background poll: one thread that asks the drivers for every device's battery level, plus the
// short refresh bursts that follow a device change.
#include <windows.h>

// Thread procedure: polls, posts WM_RESULTS to the window, and exits when the stop event is set.
DWORD WINAPI Worker(LPVOID);
// Asks for a poll a little later; repeated calls push that deadline back (WM_TIMER debounce).
void RefreshSoon(UINT ms);
// Polls now and a few times more over the next three quarters of a minute, because a Bluetooth
// headset publishes its battery level only some seconds after it becomes a device node.
void StartRefreshBurst();

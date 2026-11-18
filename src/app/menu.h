#pragma once
// The context menu of the tray icon and of the taskbar widget, and what its items do.
#include <windows.h>

// Builds the menu for the current state, shows it at the cursor and runs the chosen item.
void ShowMenu();
// Runs one menu command (the id the menu returned). Menus only report a command and never raise
// WM_COMMAND, so ShowMenu calls this directly.
void HandleCommand(UINT id);

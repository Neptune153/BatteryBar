#pragma once
// The command line: --list (what the app finds) and --dump (every HID collection). Both print their
// result and exit without creating a window, so they are the only code path that touches no UI state.
int RunCommandLine(bool dump);

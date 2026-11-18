#pragma once
// Extra sections for `--dump`, written by dump.cpp: HID collections the app could not open, every USB
// device (including ones without a HID interface) and the Bluetooth devices Windows knows about.
#include <string>

namespace dump {

// The three sections, each with its heading line. Empty when SetupAPI reports nothing.
std::wstring Extras();

}  // namespace dump

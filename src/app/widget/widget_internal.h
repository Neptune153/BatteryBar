// Shared between the widget's window management (widget.cpp) and its view (paint.cpp). Nothing else
// in the app includes this: the public API is widget.h.
#pragma once

#include <windows.h>

#include <vector>

#include "widget.h"

namespace widget_internal {

// Sizes in device-independent pixels, scaled to the taskbar's DPI.
int Dpi();
int Px(int v);

bool LightTheme();         // the taskbar is light, so the strip draws dark text
int BackgroundPercent();   // opacity of the plate behind the text, 0 = no plate
bool StackedLayout();      // icon above the percentage
bool VerticalLayout();     // the primary taskbar is docked left or right

const std::vector<WidgetItem>& Items();

}  // namespace widget_internal

namespace widget_paint {

// Draws the strip into the layered window `wnd`, which sits on `taskbar`, and reports its size.
void Strip(HWND wnd, HWND taskbar, bool hover, SIZE& size);

}  // namespace widget_paint

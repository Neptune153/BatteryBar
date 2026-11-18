# Local build helpers

These scripts build the Windows app on the machine it was set up on. They are not needed to build
the project elsewhere: `make` (MSYS2 MinGW-w64) and `build.bat` (MinGW on `PATH`) in the repository
root are the regular entry points.

| File | Purpose |
| --- | --- |
| `build-msvc.bat` | Full build with MSVC 2022 + Windows SDK 10.0.22621 (`build\msvc\WirelessBattery.exe`) |

## Why MSVC here

The MinGW-w64 installed on this machine is from 2018 and lacks `devpkey.h` and
`windows.system.power.h`, so `make` and `build.bat` cannot compile the sources. The MSVC script
therefore:

- adds `/DNOMINMAX`, because MSVC defines the `min`/`max` macros that clash with `std::min`/`std::max`;
- rebuilds `build\languages.txt` from `lang\*.txt` before running `rc`, because the translations are
  compiled into `res\app.rc` as an `RCDATA` resource.

`build\` and `temp\` are git-ignored; only `tools\` is tracked.

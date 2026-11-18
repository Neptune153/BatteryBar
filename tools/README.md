# tools

构建、测试与资源脚本。

| 文件 | 说明 |
| --- | --- |
| `build-msvc.bat` | MSVC 2022 全量构建，输出 `build\msvc\BatteryBar.exe`。脚本自行定位 `vcvars64.bat`，把 `lang\*.txt` 合并为 `build\languages.txt`，编译 `src\` 下全部 `.cpp` 后链接。适用于未安装 CMake 或需要完全控制编译选项的情况。 |
| `gen-languages.cmake` | 由 `CMakeLists.txt` 调用的语言合并脚本。也可单独运行：`cmake -DLANG_DIR=lang -DOUT=build\languages.txt -P tools\gen-languages.cmake` |
| `run-tests.ps1` | 解析 `Makefile` 中 `TESTS` 表，逐个调用 `cl.exe` 编译并运行 `tests\` 下的用例；脚本内两行路径（`vcvars64.bat`、Windows SDK）需按本机调整。 |
| `make-icon.py` | 由 `res\app.svg` 生成 `res\app.ico` 与 `res\app_light.ico`，仅在更换图标时执行。 |

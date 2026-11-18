# tools

构建辅助与资源脚本。构建本身只走仓库根目录的 `CMakeLists.txt`（预设见 `CMakePresets.json`）。

| 文件 | 说明 |
| --- | --- |
| `gen-languages.cmake` | 由 `CMakeLists.txt` 调用的语言合并脚本，把 `lang\*.txt` 合并成 `languages.txt` 供 `res\app.rc` 引用。也可单独运行：`cmake -DLANG_DIR=lang -DOUT=build\languages.txt -P tools\gen-languages.cmake` |
| `make-icon.ps1` | 用 GDI+ 绘制电池图标，生成 `res\app.ico`（16/24/32/48/256 五档），仅在更换图标时执行；不依赖 Python 或 Pillow。 |

单元测试清单在 `tests\tests.txt`，由 `CMakeLists.txt` 注册到 ctest：

```powershell
cmake --preset ninja
cmake --build --preset ninja
ctest --test-dir build\ninja --output-on-failure
```

使用 `vs2022` 预设时改为 `ctest --test-dir build\vs2022 -C Release --output-on-failure`。

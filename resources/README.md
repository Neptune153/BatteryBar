# resources

`windres` 的输入，构建时由 `Makefile` 编成 `build/app_res.o` 并链进程序。

| 文件 | 说明 |
| --- | --- |
| `app.rc` | Windows 资源脚本：图标、清单、内嵌语言资源、版本信息 |
| `app.manifest` | 清单：comctl32 v6、Per-Monitor V2 DPI、`asInvoker` |
| `app.ico` | 应用图标，16/24/32/48/256 五档 |
| `make-icon.ps1` | 重新生成 `app.ico`（GDI+ 绘制，不依赖 Python 或 Pillow），仅在更换图标时执行 |

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File resources\make-icon.ps1
```

`lang\*.txt` 合并成 `build/languages.txt` 属于构建规则，由 `Makefile` 的一行命令完成，`app.rc` 直接引用生成结果。
单元测试清单在 `tests\tests.txt`，用 `make test` 逐条编译并运行。
# tools

资源脚本。构建入口是仓库根目录的 `build.bat` 与 `Makefile`。

| 文件 | 说明 |
| --- | --- |
| `make-icon.ps1` | 用 GDI+ 绘制电池图标，生成 `res\app.ico`（16/24/32/48/256 五档），仅在更换图标时执行；不依赖 Python 或 Pillow。 |

`lang\*.txt` 合并成 `build\languages.txt` 不是脚本，而是构建时的一行命令：`build.bat` 与 `Makefile`
各有一份相同的循环，`res\app.rc` 直接引用生成结果。

单元测试清单在 `tests\tests.txt`，由 `Makefile` 的 `test` 目标逐条编译并运行：

```bash
make test
```

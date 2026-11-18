# BatteryBar

在 Windows 任务栏上显示无线设备的电量：耳机、鼠标、键盘、手柄、手机，一个都不少。

![任务栏上的 BatteryBar](docs/screenshot.png)

BatteryBar 是 [Wireless Battery](https://github.com/krisgfx9/Wireless-Device-Battery-Monitor) 的本地分支，
针对个人使用做了简化：只保留简体中文、去掉联网上报与 Xbox 支持、项目结构重新分层、改用 CMake 构建。

## 功能

- 任务栏小组件：每个设备一个图标 + 百分比，紧贴托盘区域，跟随任务栏明暗主题
- 也可以只用托盘图标（更省地方）
- 支持圆角半透明底板，透明度可在 0–100% 之间自己调
- 品牌配色（Razer 绿、Logitech 蓝等），也可以关掉用单色
- 图标可横排，也可改成"图标在上、百分比在下"的窄版
- 右键菜单里点设备即可隐藏它，或用方向键调整顺序，顺序和隐藏状态会被记住
- 低电量提醒、充电状态、休眠/上次已知设备可隐藏
- 多显示器：可只显示在主任务栏，也可以跟随每一块显示器

## 支持的设备

通过三种方式读取电量，覆盖面比较广：

| 方式 | 说明 |
| --- | --- |
| 标准 HID 电量 | HID 规范里的 Battery Strength，多数现代鼠标键盘都有 |
| 厂商私有协议 | 罗技 HID++、雷蛇、赛睿、HyperX、ROCCAT、AULA/MCHOSE、雷柏、漫步者…… 共 70 多个驱动 |
| 蓝牙电量属性 | 系统的 `DEVPKEY_Bluetooth_Battery`，耳机、手机、蓝牙键鼠都走这条路 |

完整清单见 `src/core/drivers/`（一个文件对应一个厂商或协议）；README 不再逐个罗列型号，
新设备接入方法见下文。

已知不支持的例子：部分 2.4 GHz 接收器只在厂商自家软件里才暴露电量（例如 Yichip 方案的
`3151:3020` 接收器），这类设备需要先抓包分析协议才能支持。

## 任务栏小组件

小组件是一个贴进任务栏的透明子窗口（`WS_EX_LAYERED` + `UpdateLayeredWindow`），
不是悬浮窗，所以不会遮挡、也不会被"显示桌面"刮走。

右键托盘图标 → **任务栏文字背景（适用于透明任务栏）** 可以选：

- `无`：完全透明，只有图标和数字
- `10%` … `100%`：底板不透明度，默认 `60%`，比旧版本的固定深色淡很多

注意：小组件必须由**与任务栏相同权限级别**的进程创建。如果程序是被另一个权限更低的程序
（例如某些启动器、脚本宿主）拉起来的，Windows 会拒绝把窗口挂进任务栏，此时程序会弹一次
提示，并退回托盘图标显示。直接双击 `BatteryBar.exe` 或从开始菜单启动即可。

## 安装

- **安装包**：`dist\BatteryBar-Setup-<版本>.zip`，解压后双击 `install.bat`。
  会安装到 `%LOCALAPPDATA%\Programs\BatteryBar`，创建开始菜单快捷方式，并登记到"应用和功能"。
  卸载运行同目录下的 `uninstall.bat`。
- **便携版**：`BatteryBar.exe` 单独一个文件就能跑（蓝牙耳机额外需要 `headsetcontrol.exe`）。
- **开机自启**：菜单里的「开机启动」。

## 命令行

```
BatteryBar.exe --list      列出检测到的设备和电量
BatteryBar.exe --dump      把 HID 设备信息写到 %TEMP%\BatteryBar-dump.txt（提 issue 时附上）
BatteryBar.exe --demo      用假的设备预览小组件外观
BatteryBar.exe --quit      让正在运行的实例退出
```

## 从源码构建

需要 **Visual Studio 2022**（含 C++ 桌面开发和 Windows SDK 10），CMake 随 VS 一起装好。

```bat
cmake -S . -B build\cmake
cmake --build build\cmake --config Release
```

产物在 `build\cmake\Release\BatteryBar.exe`。用 Visual Studio 打开 `build\cmake\BatteryBar.sln`
也可以直接调试。

不用 CMake 时的兜底脚本（本机验证用的就是它）：

```bat
tools\build-msvc.bat
```

它会自己找 `vcvars64.bat`、合并语言文件、编译并链接到 `build\msvc\BatteryBar.exe`。

想用 MinGW 的话，`build.bat` 和 `Makefile` 仍然可用，但需要较新的 mingw-w64
（旧版缺 `devpkey.h` 和 WinRT 头文件，会编译失败）。

构建脚本会自动收集 `src/` 下的所有 `.cpp`，新增驱动不需要改构建文件。

## 目录结构

```
src/
  main.cpp              入口：消息循环、托盘、菜单、聚合显示
  app/
    settings.*          注册表读写（含旧名字的设置迁移）
    widget/
      widget.cpp        任务栏窗口的创建、定位、交互
      paint.cpp         纯绘制：字体、遮罩、圆角底板、布局
      widget_internal.h 绘制层与窗口层之间的访问器
  core/
    devices.*           设备轮询总入口
    hid.*               HID 枚举与读写封装
    dump.*              --dump 的附加信息
    drivers/            厂商驱动（+ drivers.h 框架，protocol/ 里是纯协议头）
  text/
    i18n.*              翻译查找
    labels.*            短标签生成
    brands.*            品牌配色
res/                    图标、清单、资源脚本
lang/                   UTF-8 翻译文件（`English = 中文`）
tools/                  构建与测试脚本
tests/                  驱动单元测试（模拟 HID 传输）
docs/                   协议笔记与截图
installer/              安装包脚本（无 Inno Setup 的本地版）
```

## 新增一个设备

1. `src/core/drivers/` 下新建一个 `.cpp`，实现 `void PollSomething(PollContext& ctx)`；
2. 在 `src/core/drivers/drivers.h` 里声明；
3. 在 `src/core/devices.cpp` 的 `PollAllDevices()` 里调用（顺序有讲究，先匹配的会 `Claim` 掉设备）；
4. 在 `tests/` 里加一个用模拟 HID 传输的测试；
5. 更新本文档。

驱动守则：**只读**、精确匹配（只跟确认为该设备的厂商集合通信）、每个集合必须有超时（≤4 秒）、
注明协议来源。细节见 `CONTRIBUTING.md`。

## 已知限制

- 只支持 Windows 10/11（x64）
- 没有 Windows 商店签名，首次运行会出现 SmartScreen 提示，点「更多信息 → 仍要运行」
- 部分 2.4 GHz 接收器（未公开协议）无法读取电量
- 蓝牙耳机的电量依赖系统属性，刚连上时可能要等一两秒才出现（本版会在设备变化后短时间高频重试）

## 许可

GPL-3.0，见 `LICENSE`。

上游项目由 [krisgfx9](https://github.com/krisgfx9) 编写，图标由 [nik-txt](https://github.com/nik-txt) 绘制，
本分支在此表示感谢。

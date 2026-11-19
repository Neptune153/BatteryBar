# 参与贡献

## 反馈设备是否可用

大部分驱动依据协议文档编写，无法在每个型号上逐一验证。提交 issue 时请附上：

- 设备名称，以及连接方式（接收器、有线或蓝牙）
- `BatteryBar.exe --list` 的输出
- `BatteryBar.exe --dump` 的输出
- 厂商自带软件显示的电量

## 新增设备

1. 运行 `BatteryBar.exe --dump`，找到设备的 vendor id 与 product id，以及厂商自定义集合（usage page 为 `FFxx`）及其报文长度。
2. 查找电量协议。可参考的项目有 HeadsetControl、OpenRazer、Solaar、rivalcfg、OpenRGB、OpenLinkHub，也可以抓取厂商软件与设备之间的 USB 通信（Wireshark + USBPcap）。
3. 若 `src/core/drivers/` 下已有该厂商的驱动，在其中补充 product id 与型号差异；否则新建 `src/core/drivers/<vendor>.cpp`：

   ```cpp
   #include "drivers.h"

   void PollAcme(PollContext& ctx) {
       for (auto [vid, pid] : ctx.Products(0x1234)) {           // 该厂商尚未被认领的产品
           for (const HidCollection* c : ctx.Find(vid, pid, [](const HidCollection& c) { return c.page() == 0xFF00; })) {
               HidDev d;
               if (!d.Open(*c)) continue;
               std::vector<BYTE> r;
               if (!d.Write({ 0x01, 0x02 }) || d.Read(r, 500) < 3) continue;   // 与 hidapi 相同的调用方式
               DeviceStatus s;
               s.key = L"acme:" + Hex4(pid);
               s.name = HidProduct(*c);
               s.kind = DeviceKind::Mouse;
               s.via = L"2.4 GHz receiver";
               s.percent = Clamp100(r[2]);
               ctx.Add(s, vid, pid);
               break;
           }
       }
   }
   ```

4. 在 `src/core/drivers/drivers.h` 中声明该函数，并在 `src/core/devices.cpp` 的 `PollAllDevices()` 中调用，位置放在通用兜底驱动之前。构建脚本会递归收集 `src` 下的所有 `.cpp`，新增驱动不需要改构建文件。
5. 更新 `README.md` 中的设备表。

### 驱动编写规则

- **只读**：只发送读取状态的请求，不得修改设置、灯效或工作模式。
- **精确匹配**：只与通过 vendor id 与 product id 识别出的设备通信，或通过该协议独有的厂商集合匹配。
- **必须设置超时**：设备缺失时，单次轮询的阻塞时间不得超过约 1 秒。被动上报类协议需要覆盖文档给出的上报间隔，可适当放宽（例如 Delux、Rapoo）；对每个匹配集合保持单一的绝对截止时间，最长 4 秒，不得因无关报文重新计时，并在文件中说明放宽的原因。
- **注明来源**：在文件顶部注释中标明协议出处。

## 多语言

一种语言对应 `lang/` 下的一个 UTF-8 文本文件：复制 `lang/_template.txt`，填写 `@code`、`@name` 与各条短语，构建时自动打包进程序。本分支只内置 `lang/zh-CN.txt`；增加语言时把文件放进 `lang/`，程序按系统显示语言自动选择，也可用同名文件放在 `%APPDATA%\BatteryBar\lang` 覆盖内置文本。

界面文案统一通过 `T(L"...")` 输出；含变量时使用 `TF(L"... {name} ...", { { L"name", value } })`。不得把整句拆成片段拼接。新增短语后同步补进 `lang/_template.txt`。

## 代码风格

C++17，仅使用 Win32 API，不引入第三方依赖。保持程序体积小。格式与现有代码一致：4 空格缩进，每行 120 列。

## 安全检查

上游用自动扫描检查每个 pull request，下列改动会被标记：网络访问、启动外部程序、读取键盘与剪贴板与屏幕、写入开机启动项、提交二进制文件、改动构建与发布流程。本分支已移除该扫描脚本（`.github/workflows` 与 `scripts/pr-safety.sh`），这些约束仍然适用。

可以使用 AI 工具协助写作，但请删除提交信息中为它们署名的 `Co-authored-by` 行，例如 `Co-authored-by: Claude ...`。

## 提交信息

使用 Conventional Commits 格式：`type(scope): 摘要`，正文说明改动原因与影响范围，例如：

```text
fix(widget): 任务栏小组件按不透明度绘制背景
```

常用类型：`feat`、`fix`、`refactor`、`docs`、`build`、`chore`、`test`。

# docs

这个目录只放"给人看"的材料，代码和构建输入都不在这里。

```
docs/
  img/screenshot.png     README 首图（500×96，任务栏实拍）
  drivers/*.md           厂商协议笔记：抓包来源、请求/回复字节布局、字段含义
```

## 协议笔记

接一个新设备时，先看看同类设备是不是已经有人啃下来了：

| 文件 | 内容 |
| --- | --- |
| `drivers/rapoo.md` | 雷柏（Rapoo）2.4 GHz 接收器：查询帧、回复布局、键盘/鼠标两个电量字段 |
| `drivers/areson.md` | Areson 方案（多个品牌共用同款接收器）的抓包记录与字段说明 |
| `drivers/machenike.md` | 机械师鼠标私有协议，`src/core/drivers/machenike.cpp` 直接引用本文件 |
| `drivers/vaxee.md` | VAXEE 鼠标协议，来源 `stuffz/mouse-battery-monitor` |
| `drivers/ardor_fury_v2.md` | Ardor Fury V2 鼠标协议要点 |

### 新增一份笔记的约定

1. 写清设备标识：`VID:PID`、接口名、集合（usage page / usage）；
2. 写清抓包工具与方式（USBPcap + Wireshark，或厂商软件的日志）；
3. 请求与回复用十六进制表格列出，标明每个字节的含义和取值范围；
4. 注明来源（issue 编号、别人的仓库、自己的抓包），方便以后复核；
5. 文件名用驱动名或厂商名的小写，和 `src/core/drivers/` 里的实现对应。

`CONTRIBUTING.md` 里的驱动守则同样适用于这些笔记：只记录只读查询，不要写会改动设备状态的命令。

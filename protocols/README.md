# protocols

本目录存放设备的私有协议记录：采集来源、请求与应答的字节布局、字段定义。这些笔记不参与编译，供后续维护与新增设备时参考。

## 协议笔记

| 文件 | 设备 | 内容 |
| --- | --- | --- |
| `rapoo.md` | Rapoo 2.4 GHz 接收器 | 查询帧、应答布局、键盘与鼠标电量字段 |
| `areson.md` | Areson 方案接收器（多品牌共用） | 采集记录与字段说明 |
| `machenike.md` | Machenike 鼠标 | 私有协议，`src/core/drivers/machenike.cpp` 引用 |
| `vaxee.md` | VAXEE 鼠标 | 协议，来源 `stuffz/mouse-battery-monitor` |
| `ardor_fury_v2.md` | Ardor Fury V2 鼠标 | 协议要点 |

## 编写要求

新增笔记时按以下格式组织：

1. 设备标识：`VID:PID`、接口、usage page 与 usage；
2. 采集方式：USBPcap + Wireshark，或厂商软件导出的日志；
3. 请求与应答：十六进制表格，逐字节标注含义与取值范围；
4. 来源：issue 编号、参考仓库或抓包文件路径；
5. 命名：与 `src/core/drivers/` 中对应实现同名，小写。

驱动守则同样适用：只记录只读查询，不记录会改变设备状态的命令。

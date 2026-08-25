<div align="center">

# 🚀 H5000M / AP3000M / X86_64 定制固件说明书

*基于 ImmortalWrt 主线源码，为 Hiveton H5000M 5G CPE、Airpi AP3000M 与 X86_64 设备提供的定制化编译配置*

</div>

<br>

## 🚀 快速开始（云编译）

本项目使用 GitHub Actions 自动编译固件，无需本地搭建环境。所有工作流位于 `.github/workflows/`：

| 工作流 | 触发方式 | 作用 |
| :--- | :--- | :--- |
| **WRT-BUILD** | 手动 `workflow_dispatch` | 手动编译 / 预览配置。可选配置、源码、分支，默认仅生成配置不编译（`TEST=true`） |
| **MTK-AUTO** | 每天随 `Auto-Clean` 完成后自动触发，亦可手动 | 自动编译 `H5000M-WIFI-YES` + `AP3000M` 并发布 Release |
| **OWRT-ALL** | 每天随 `Auto-Clean` 完成后自动触发，亦可手动 | 自动编译 `X86`（x86_64）并发布 Release |
| **Auto-Clean** | 每天定时 + 手动 | 清理旧 Release 与 Workflow 运行记录（保留最近 1 个 Release、30 天运行记录） |
| **Cache-Clean** | 每周定时 + 手动 | 清理 GitHub Actions 编译缓存 |

**手动编译步骤：** 仓库页面 → `Actions` → 选择 `WRT-BUILD` → `Run workflow` → 选择配置与源码 → 如需真正编译请把 `TEST` 设为 `false`。

**说明：** `TEST=true`（默认）只生成 `.config` 配置用于校验，不会消耗资源编译；`TEST=false` 才会完整编译并发布固件。

<br>

## 📂 项目结构

```
OpenWRT-CI/
├── .github/workflows/        # 云编译工作流
│   ├── WRT-CORE.yml          # 公用编译核心（被调用）
│   ├── WRT-BUILD.yml         # 手动编译入口
│   ├── MTK-AUTO.yml          # 定时自动编译 H5000M-WIFI-YES
│   ├── OWRT-ALL.yml          # 定时自动编译 X86
│   ├── Auto-Clean.yml        # 清理旧 Release / 运行记录
│   └── Cache-Clean.yml       # 清理编译缓存
├── Config/                   # 编译配置
│   ├── GENERAL.txt           # 全设备通用插件与内核配置
│   ├── H5000M-WIFI-YES.txt   # Hiveton H5000M（带 Wi-Fi）
│   ├── AP3000M.txt           # AirPi AP3000M（Wi-Fi）
│   └── X86.txt               # X86_64 通用设备
├── AP3000M-EEPROM/           # AP3000M EEPROM 自动初始化
│   ├── mt7981_eeprom_mt7976_dbdc.bin  # iPAiLNA EEPROM 模板（已校准）
│   └── 99-ap3000m-eeprom            # uci-defaults 首次启动脚本
├── Scripts/                  # 编译前自定义脚本
│   ├── Packages.sh           # 拉取第三方插件与主题
│   ├── Handles.sh            # HomeProxy 资源预置与主题 / 组件修复
│   └── Settings.sh           # 默认 IP / 主机名 / Wi-Fi / 主题
├── LICENSE
└── README.md
```

<br>

## 🎯 支持的编译配置

| 配置 | 目标平台 | 设备 | Wi-Fi |
| :--- | :--- | :--- | :--- |
| `H5000M-WIFI-YES` | MediaTek Filogic | Hiveton H5000M | ✅ 开启 |
| `AP3000M` | MediaTek Filogic | Airpi AP3000M (MT7981B) | ✅ 开启 |
| `X86` | x86_64 | 标准 X86_64 设备 | 不适用 |

> `X86` 配置生成 64 位 x86 镜像，包含 ISO、EFI、GRUB 与 VMDK 格式，可用于支持 x86_64 的标准 BIOS 或 UEFI 设备。32 位 x86 设备不适用该配置。
>
> **AP3000M 特殊说明**：AP3000M (MT7981B, eMMC 存储无 SPI-NOR) 使用 ImmortalWrt 主线 mt76 开源驱动。设备出厂时 `mmcblk0p2` factory 分区为空，导致 NVMEM 框架读取 EEPROM 失败、Wi-Fi 无法初始化。本项目内置闭源固件备份的 iPAiLNA EEPROM 模板（已校准，Tx-Power 28-29dBm），编译时通过 `Handles.sh` 注入 `files/` 目录，首次启动时由 `99-ap3000m-eeprom` 脚本自动从 eth0 读取设备 MAC、写入 factory 分区并修正 radio1 为 5GHz 模式。

<br>

## ⚙️ 默认配置

固件刷入后默认配置如下（可通过各工作流 `env` 中的 `WRT_*` 变量调整，由 `Scripts/Settings.sh` 在编译时写入）：

| 项目 | 默认值 |
| :--- | :--- |
| Wi-Fi SSID（2.4G / 5G） | `OWRT` |
| Wi-Fi 密码 | `12345678` |
| 加密方式 | WPA-PSK / WPA2-PSK Mixed Mode |
| 管理地址 | `192.168.10.1` |
| 主机名 | `OWRT` |
| 国家码 | `CN` |
| 2.4G 频宽 | 40MHz |
| 5G 频宽 | 160MHz |
| 时区 | `CST-8`（`Asia/Shanghai`） |

<br>

## 💖 鸣谢与致敬

本固件的高效自动化编译、底层系统的稳定性以及对特定 5G 模组的完美适配，离不开开源社区开发者的无私奉献。在此特别感谢以下作者及其开源项目：

> **🐧 源码上游：[ImmortalWrt](https://github.com/immortalwrt/immortalwrt/)**
>
> 感谢 ImmortalWrt 团队提供的最新主线源码。其卓越的路由性能和丰富的本地化特性，为固件的开发提供了无比坚实的底层源码基础。
> * 🔗 **项目链接**：[immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt/)

> **👤 基础底包、插件优化与编译框架：[VIKINGYFY](https://github.com/VIKINGYFY)**
>
> 感谢作者提供的 OpenWRT-CI 项目。作者不仅打造了高效的云端自动化编译框架，更为本项目提供了稳定可靠的**基础底包固件配置**、**深度的插件细节优化**，以及**大量优质实用的额外插件支持**，极大降低了固件定制门槛并全面提升了路由器的整体体验和可玩性。
> * 🔗 **项目链接**：[OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI)

> **👤 CPE 核心插件支持：[FAN789](https://github.com/FAN789)**
>
> 感谢作者为 Hiveton H5000M 及 MT5700M 模组开发的系列核心控制插件，赋予了该设备真正的 5G CPE 灵魂。
> * 🔗 **主页链接**：[https://github.com/FAN789](https://github.com/FAN789)
> * 📦 **5G 模组控制**：[luci-app-mt5700m](https://github.com/LianXia233/luci-app-mt5700m)
> * ❄️ **智能风扇温控**：[luci-app-h5000m-fancontrol](https://github.com/FAN789/luci-app-h5000m-fancontrol)
> * 🔀 **网络模式切换**：[luci-app-h5000m-netmode](https://github.com/FAN789/luci-app-h5000m-netmode)

---

## 📡 一、 硬件平台与固件底层概述

**Hiveton H5000M** 是一款高性能的 5G CPE（Customer Premises Equipment）路由器，致力于将高速的 5G 移动网络转化为稳定可靠的局域网 Wi-Fi 或有线网络。

| 核心特征 | 详情描述 |
| :--- | :--- |
| 🏗️ **固件底包** | **基于 ImmortalWrt 主线最新源码构建**。内核层面已开启硬件加解密优化（`kmod-cryptodev`, `kmod-tls`），为科学分流和安全组网提供底层加速。 |
| 🖥️ **基础架构** | 采用 **联发科 (MediaTek) Filogic** 平台 (如 MT7986 系列)，具备强大的网络数据转发能力与 Wi-Fi 7 性能。 |
| 📶 **核心模组** | 深度集成 **MT5700M 5G 模组**，支持直接插卡上网，实现 5G 高速蜂窝接入。 |
| ❄️ **散热设计** | 针对 5G 模组高负载下的发热特性，设备配备了**主动散热风扇**，专为高负载网络转化设计，确保极限性能下不降频。 |

---

## 🧩 二、 核心专属插件详解

固件包含网络模式切换与 MT5700M 模组控制等全设备通用插件；风扇温控仅编入 H5000M 固件。以下是三大核心插件的功能说明：

### 1. MT5700M 5G 模组支持 (`luci-app-mt5700m`)
MT5700M 是本台 CPE 的数据吞吐核心，该插件为其提供了系统级驱动支持与直观的图形化管理界面 (LuCI)。

* **📊 状态监控**：在后台实时呈现 5G 信号强度、SA/NSA 网络制式、当前频段、运营商及 IMEI/IMSI 等关键状态。
* **🔌 连接管理**：兼容 QMI/NCM 等多种拨号协议，实现高速稳定的蜂窝联网。
* **⚙️ AT 指令交互**：内置 `ubus-at-daemon`，支持通过 Web 界面向模组发送 AT 指令，便于进行高级网络调试或频段锁定。
* **✉️ 短信功能**：集成 `sms-tool`，支持通过路由器后台接收与发送运营商短信，方便接收流量提醒。

### 2. 硬件级风扇温控 (`luci-app-h5000m-fancontrol`)
仅 Hiveton H5000M 固件包含此插件。5G 高速传输伴随显著发热，该插件确保设备在满负荷运作下的温控稳定。

* **🌡️ 智能监测**：实时读取 CPU 和 MT5700M 模组的双路温度传感器数据。
* **🌀 多档调速**：根据设定的温度阈值（如阈值 A、B、C），自动调节风扇的 PWM 转速百分比，兼顾低负载静音与高负载散热。
* **🛠️ 自定义配置**：用户可自由调整启动温度、目标温度，打造个性化的散热策略。

### 3. 网络模式无缝切换 (`luci-app-h5000m-netmode`)
所有配置均包含此插件，用于应对复杂的网络接入环境（5G 蜂窝与传统有线宽带双接入），提供极简的管理体验。

* **🔄 一键切换**：支持在“仅 5G 模式”、“仅有线宽带模式”及“负载均衡/故障转移模式”间快速切换，告别复杂的接口配置。
* **⚡ 链路检测**：搭配 mwan3，实时监测链路连通状态，主链路故障时实现毫秒级无缝切换，确保网络永不掉线。

---

## 🛠️ 三、 固件底层组件与扩展支持

得益于 ImmortalWrt 优秀的底包基础，Hiveton H5000M 不仅具备卓越的基础路由性能，还将扩展性推向极致：

* **内核级加解密加速**：开启 `kmod-cryptodev` 与 `kmod-tls`，大幅提升代理工具（如 HomeProxy、OpenClash）和加密隧道的吞吐量，降低 CPU 占用。
* **USB 驱动栈扩展**：包含 `kmod-usb-core`, `kmod-usb3` 及 `kmod-usb-net-qmi-wwan` 等丰富驱动，确保系统准确识别各类移动通信模组。
* **轻量级 NAS 存储**：支持 NVMe 固态硬盘（`kmod-nvme`）挂载，结合 BTRFS 文件系统与 Samba4 共享，轻松打造家庭数据中心。
* **安全异地组网**：内置 EasyTier、Tailscale 等主流 SD-WAN 工具，轻松实现内网设备的远程安全访问。

<br>

> 📅 *文档更新日期：2026年8月*
> 💡 *本说明文档由项目编译配置与社区开源信息整合生成。*

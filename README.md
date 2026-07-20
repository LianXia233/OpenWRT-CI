<div align="center">

# 🚀 Hiveton H5000M (MT5700M) 定制固件说明书

*基于 ImmortalWrt 主线源码，专为联发科 Filogic 平台 5G CPE 打造的定制化编译配置与模组解析*

</div>

<br>

## 💖 鸣谢与致敬

本固件的高效自动化编译、底层系统的稳定性以及对特定 5G 模组的完美适配，离不开开源社区开发者的无私奉献。在此特别感谢以下作者及其开源项目：

> **🐧 固件底包源码：[ImmortalWrt](https://github.com/immortalwrt/immortalwrt/)**
> 
> 感谢 ImmortalWrt 团队提供的最新主线源码。本项目采用了其作为基础底包固件，凭借其卓越的路由性能和丰富的本地化特性，为本固件提供了无比坚实、稳定的底层基础。
> * 🔗 **项目链接**：[immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt/)

> **👤 编译框架支持：[VIKINGYFY](https://github.com/VIKINGYFY)**
> 
> 感谢作者提供的 OpenWRT-CI 云端自动化编译框架，使得复杂的交叉编译过程在云端得以轻松实现，大幅降低了定制固件的门槛。
> * 🔗 **项目链接**：[OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI)

> **👤 CPE 核心插件支持：[FAN789](https://github.com/FAN789)**
> 
> 感谢作者为 Hiveton H5000M 及 MT5700M 模组开发的系列核心控制插件，赋予了该设备真正的 5G CPE 灵魂。
> * 🔗 **主页链接**：[https://github.com/FAN789](https://github.com/FAN789)
> * 📦 **5G 模组控制**：[luci-app-mt5700m](https://github.com/FAN789/luci-app-mt5700m)
> * ❄️ **智能风扇温控**：[luci-app-h5000m-fancontrol](https://github.com/FAN789/luci-app-h5000m-fancontrol)
> * 🔀 **网络模式切换**：[luci-app-h5000m-netmode](https://github.com/FAN789/luci-app-h5000m-netmode)

---

## 📡 一、 硬件平台与固件底层概述

**Hiveton H5000M** 是一款高性能的 5G CPE（Customer Premises Equipment）路由器，致力于将高速的 5G 移动网络转化为稳定可靠的局域网 Wi-Fi 或有线网络。

| 核心特征 | 详情描述 |
| :--- | :--- |
| 🏗️ **固件底包** | **基于 ImmortalWrt 主线最新源码构建**，融合了最新的内核更新、性能优化及更友好的国内本地化体验。 |
| 🖥️ **基础架构** | 采用 **联发科 (MediaTek) Filogic** 平台 (如 MT7981/MT7986 系列)，具备强大的网络数据转发能力与 Wi-Fi 6 性能。 |
| 📶 **核心模组** | 深度集成 **MT5700M 5G 模组**，支持直接插卡上网，实现真正的 5G 高速蜂窝接入。 |
| ❄️ **散热设计** | 针对 5G 模组高负载下的发热特性，设备配备了**主动散热风扇**，确保极限性能下不降频。 |

---

## 🧩 二、 核心专属插件详解

通过整合 FAN789 提供的定制插件，H5000M 能够在 ImmortalWrt 环境下完美发挥其 5G 硬件潜力。以下是三大核心插件的功能剖析：

### 1. MT5700M 5G 模组支持 (`luci-app-mt5700m`)
MT5700M 是本台 CPE 的数据吞吐核心，该插件为其提供了系统级驱动支持与直观的图形化管理界面 (LuCI)。

* **📊 状态监控**：在后台实时呈现 5G 信号强度、SA/NSA 网络制式、当前频段、运营商及 IMEI/IMSI 等关键状态。
* **🔌 连接管理**：兼容 QMI/NCM 等多种拨号协议，实现高速稳定的蜂窝联网。
* **⚙️ AT 指令交互**：内置 `ubus-at-daemon`，支持通过 Web 界面向模组发送 AT 指令，便于进行高级网络调试或频段锁定。
* **✉️ 短信功能**：集成 `sms-tool`，支持通过路由器后台接收与发送运营商短信，方便接收流量提醒。

### 2. 硬件级风扇温控 (`luci-app-h5000m-fancontrol`)
5G 高速传输伴随显著发热，该插件确保了设备在满负荷运作下的温控稳定。

* **🌡️ 智能监测**：实时读取 CPU 和 MT5700M 模组的双路温度传感器数据。
* **🌀 多档调速**：根据设定的温度阈值（如阈值 A、B、C），自动调节风扇的 PWM 转速百分比，兼顾低负载静音与高负载散热。
* **🛠️ 自定义配置**：用户可自由调整启动温度、目标温度，打造个性化的散热策略。

### 3. 网络模式无缝切换 (`luci-app-h5000m-netmode`)
应对复杂的网络接入环境（5G 蜂窝与传统有线宽带双接入），提供极简的管理体验。

* **🔄 一键切换**：支持在“仅 5G 模式”、“仅有线宽带模式”及“负载均衡/故障转移模式”间快速切换，告别复杂的接口配置。
* **⚡ 链路检测**：搭配 mwan3，实时监测链路连通状态，主链路故障时实现毫秒级无缝切换，确保网络永不掉线。

---

## 🛠️ 三、 固件底层组件与扩展支持

得益于 ImmortalWrt 优秀的底包基础，固件不仅发挥了 CPE 的本职工作，还将扩展性推向极致：

* **USB 驱动栈扩展**：包含 `kmod-usb-core`, `kmod-usb3` 及 `kmod-usb-net-qmi-wwan` 等丰富驱动，确保系统准确识别各类移动通信模组。
* **轻量级 NAS 存储**：支持 NVMe 固态硬盘（`kmod-nvme`）挂载，结合 BTRFS 文件系统与 Samba4 共享，轻松打造家庭数据中心。
* **科学分流与组网**：内嵌 HomeProxy、OpenClash 等高性能代理客户端，利用硬件加解密引擎 (`kmod-cryptodev`) 加速传输；内置 EasyTier、Tailscale，轻松实现异地组网。

<br>

> 📅 *文档更新日期：2026年7月*
> 💡 *本说明文档由项目编译配置与社区开源信息整合生成。*

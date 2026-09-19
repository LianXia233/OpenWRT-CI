<div align="center">

# 🚀 H5000M / AP3000M / X86_64 定制固件说明书

**基于 ImmortalWrt 深度定制 · 专为 5G CPE、Wi-Fi 路由器与软路由量身打造**

[![Source: VIKINGYFY](https://img.shields.io/badge/Source-VIKINGYFY%2Fimmortalwrt-blue?logo=openwrt&logoColor=white)](#)
[![Source: Master](https://img.shields.io/badge/Source-immortalwrt%2Fmaster-brightgreen?logo=openwrt&logoColor=white)](#)
[![Platform: Filogic](https://img.shields.io/badge/Platform-MediaTek%20Filogic-orange)](#)
[![Platform: x86_64](https://img.shields.io/badge/Platform-x86__64-informational)](#)
[![Workflow: CI](https://img.shields.io/badge/Build-GitHub%20Actions-success?logo=githubactions&logoColor=white)](#)

*适配 Hiveton H5000M 5G CPE（MT7986 + MT5700M）、AirPi AP3000M（MT7981B）与通用 X86_64 架构设备*

---

</div>

## 📌 支持机型与底层架构

| 目标配置 | 硬件平台 / SoC | 适配机型 | 源码分支 | Wi-Fi 支持 | 镜像格式 |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `H5000M-WIFI-YES` | MediaTek Filogic (MT7986) | Hiveton H5000M 5G CPE | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ 开启 | Sysupgrade / Factory |
| `AP3000M` | MediaTek Filogic (MT7981B) | AirPi AP3000M | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ 开启 | Sysupgrade / Factory |
| `X86` | 标准 x86_64 处理器 | 通用 64 位 PC / 工控机 / 软路由 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) (`master`) | — | ISO / EFI / GRUB / VMDK |

> [!TIP]
> **源码拉取说明**：自动化编译工作流中，`H5000M-WIFI-YES` 与 `AP3000M` 固定拉取 `VIKINGYFY/immortalwrt` 的 `owrt` 分支；`X86-MT-AUTO` 拉取 `immortalwrt/immortalwrt` 的 `master` 分支。手动触发 `WRT-BUILD` 时，可通过界面下拉框自由切换源码上游与分支。

> [!IMPORTANT]
> **AP3000M EEPROM 缺失自动修复机制**：
> AP3000M 采用 eMMC 存储架构，出厂时 `mmcblk0p2` factory 分区为空，会导致 mt76 开源驱动无法加载校验参数，Wi-Fi 彻底瘫痪。
> 本固件已内置校准版 iPAiLNA EEPROM 模板（发射功率达 28~29 dBm），并在编译时通过 `Handles.sh` 注入文件系统；路由器**首次启动**时将由 `99-ap3000m-eeprom` 脚本自动提取 `eth0` 真实 MAC、写入 factory 分区并将 radio1 修正为 5GHz 频段。

---

## ⚙️ 固件默认参数

系统刷入完成后的默认出厂网络参数如下（可在各编译工作流的 `env` 变量中预先调整，编译期由 `Scripts/Settings.sh` 自动写入）：

| 配置项 | 默认出厂值 | 说明 |
| :--- | :--- | :--- |
| **后台管理地址** | `192.168.10.1` | Web 管理界面默认 IP |
| **主机名 (Hostname)** | `OWRT` | 系统网络标识 |
| **Wi-Fi SSID** | `OWRT` | 2.4G 与 5G 频段共用此名称 |
| **Wi-Fi 密码** | `12345678` | 默认无线接入密钥 |
| **无线加密方式** | `WPA-PSK / WPA2-PSK Mixed Mode` | 兼顾设备兼容性与安全性 |
| **频宽设置** | **2.4G**: `40MHz` \| **5G**: `160MHz` | 跑满满血无线吞吐 |
| **国家码 / 时区** | `CN` / `CST-8` (`Asia/Shanghai`) | 避免时钟同步异常 |

---

## 🧩 核心专属功能与模组生态

### 1. 5G 模组驱动与控制 (`luci-app-mt5700m` / `luci-app-mt5700`)
针对 CPE 的数据通信核心提供完整的系统级交互能力：
- 📊 **运行状态大屏**：实时呈现 5G 信号质量（RSRP/RSRQ/SINR）、SA/NSA 制式、当前驻留频段、运营商标识及 IMEI/IMSI。
- 🔌 **全协议拨号**：支持 QMI、NCM 等高速拨号通道，满足不同场景下的低延迟高吞吐联网需求。
- ⚙️ **在线 AT 交互**：后台集成 `ubus-at-daemon`，无需串口即可直接在 LuCI 界面下发 AT 指令，轻松锁频、锁小区。
- ✉️ **短信收发平台**：集成 `sms-tool_q`，可在网页端直接查收流量卡余额、套餐提醒及验证码短信。

### 2. 硬件级智能风扇温控 (`luci-app-h5000m-fancontrol`)
*（仅编入 Hiveton H5000M 固件）*
- 🌡️ **双温区采集**：底层同时轮询 CPU 核心与 MT5700M 模组温感数据。
- 🌀 **PWM 阶梯变速**：根据设定的阶梯温度阈值动态调整风扇占空比，兼顾低负载静音与极端工况下的高效散热。

### 3. 多网络智能切换 (`luci-app-h5000m-netmode`)
*（全机型通用）*
- 🔄 **接入模式切换**：支持“仅 5G 蜂窝”、“仅 WAN 有线”及“双链路负载均衡 / 主备故障转移”一键调度。
- ⚡ **毫秒级容灾切换**：联动 `mwan3` 状态探针，当检测到主链路中断时瞬间切流，确保业务持续在线。

---

## 🛡️ MT 插件模式矩阵与驱动冲突防护

为满足不同用户的插件偏好，固件引入了独立的 `MT_MODE` 配置层，**不与硬件机型强绑定**：

| MT_MODE | 编入插件包 | 依赖组件 | 明确排除内容 | 驱动来源 |
| :--- | :--- | :--- | :--- | :--- |
| **`MT5700M`** *(方案 A)* | `luci-app-mt5700m` | `sms-tool_q`<br>`ubus-at-daemon` | `luci-app-mt5700` | QModem feed (`FUjr/QModem`) |
| **`MT5700`** *(方案 B)* | `luci-app-mt5700` | 单包内置 Rust 后端 | `luci-app-mt5700m`<br>`sms-tool_q`<br>`ubus-at-daemon` | packages feed (`immortalwrt/packages`) |
| **`NONE` / 留空** | *(不安装 MT 插件)* | — | 全量 MT 模组应用 | packages feed (`immortalwrt/packages`) |

> [!WARNING]
> **QMI WWAN 驱动同名文件冲突防踩坑机制**：
>
> 两个方案包含相同命名的内核模块：
> - **QModem feed** 提供：`kmod-qmi_wwan_f` / `kmod-qmi_wwan_q` / `kmod-qmi_wwan_s`
> - **官方 packages feed** 提供：`kmod-usb-net-qmi-wwan-fibocom` / `kmod-usb-net-qmi-wwan-quectel`
>
> 双方均会向 rootfs 写入 `qmi_wwan_f.ko` 和 `qmi_wwan_q.ko`。若配置不当导致双方并存，`apk` 会触发文件所有权冲突拦截并中断构建。
> 
> **本项目通过双重校验彻底杜绝冲突**：
> 1. **配置前置注入**：`ApplyMTMode.sh` 在 `MT5700M` 模式下将 packages 侧的互斥包显式置为 `=n`。
> 2. **编译前置拦截**：`VerifyMTMode.sh` 在 `make defconfig` 之后执行严格语义检查，凡发现两类驱动同时选中或均未选中，将立即抛错中止 CI，防止产出脏固件。

---

## 🛠️ 底层系统能力集成

- 🚀 **硬件加解密引擎加速**：内核级编译 `kmod-cryptodev` 与 `kmod-tls`，让 OpenClash、HomeProxy 等代理服务及 VPN 隧道完全跑在内核硬件加速通道上。
- 💾 **轻量级高可用 NAS**：原生集成 NVMe 驱动（`kmod-nvme`）、BTRFS 现代文件系统与 Samba4 服务，让高速固态硬盘满速共享。
- 🌐 **零配置组网体系**：预置 Tailscale 与 EasyTier，方便在无公网 IP 环境下轻松穿透打通远程内网。

---

## 🚀 自动化云编译使用指南

所有编译任务均由 GitHub Actions 驱动，无需在本地配置交叉编译工具链。

### 1. 工作流矩阵

| 工作流名称 | 触发机制 | 核心职责 |
| :--- | :--- | :--- |
| **`WRT-BUILD`** | 手动 `workflow_dispatch` | 自定义按需编译。可自选机型、上游源码、MT 模式；默认 `TEST=true`（仅跑语法检查与配置验证） |
| **`H5000M-MT-AUTO`** | 每日定时 (随 Auto-Clean) / 手动 | 并行编译 H5000M 的 **MT5700 + MT5700M** 双配置并自动发版 |
| **`AP3000M-MT-AUTO`** | 每日定时 (随 Auto-Clean) / 手动 | 并行编译 AP3000M 的 **MT5700 + MT5700M** 双配置并自动发版 |
| **`X86-MT-AUTO`** | 每日定时 (随 Auto-Clean) / 手动 | 并行编译 X86 的 **MT5700 + MT5700M** 双配置并自动发版 |
| **`Auto-Clean`** | 每日定时调度 / 手动 | 保持仓库整洁：保留最近 1 个 Release 及 30 天以内的构建日志 |
| **`Cache-Clean`** | 手动触发 | 主动清理 actions/cache 编译缓存（不设定时清空，避免缓存频繁冷启动） |

### 2. 手动编译快速指引

1. 进入仓库页面，点击 **`Actions`** 选项卡。
2. 在左侧列表选择 **`WRT-BUILD`**，点击右侧 **`Run workflow`**。
3. 按需选择：
   - **Target Device**：`H5000M-WIFI-YES` / `AP3000M` / `X86`
   - **MT Mode**：`MT5700M` / `MT5700` / `NONE`
   - **TEST**：若要正式输出固件，**务必将 `TEST` 改为 `false`**（设为 `true` 仅导出校验用 `.config`）。

### 3. 产物命名与 Release 规范

自动工作流会将模式标签与生成日期直接融入产物名与 Release Tag，便于区分：

```text
# 固件文件名规范示例
immortalwrt-mediatek-filogic-hiveton_h5000m-MT5700-wifi-yes-26.09.13-sysupgrade.bin
immortalwrt-mediatek-filogic-hiveton_h5000m-MT5700M-wifi-yes-26.09.13-sysupgrade.bin

# Release Tag 规范
H5000M-WIFI-YES-MT5700-2026.09.13
H5000M-WIFI-YES-MT5700M-2026.09.13

```

---

## 📂 项目结构全景

```text
OpenWRT-CI/
├── .github/workflows/        # CI/CD 云编译自动化编排
│   ├── WRT-CORE.yml          # 公共编译底层流水线模板（被各任务调用）
│   ├── WRT-BUILD.yml         # 手动编译入口（支持机型与 MT 模式矩阵选择）
│   ├── H5000M-MT-AUTO.yml    # H5000M 双配置定时自动化发布
│   ├── AP3000M-MT-AUTO.yml   # AP3000M 双配置定时自动化发布
│   ├── X86-MT-AUTO.yml       # X86 双配置定时自动化发布
│   ├── Auto-Clean.yml        # 自动化历史制品与任务日志清理
│   └── Cache-Clean.yml       # 手动编译缓存回收
├── Config/                   # 模块化编译配置文件层
│   ├── GENERAL.txt           # 全设备通用内核参数与功能插件（不含 MT 驱动）
│   ├── MT5700.txt            # MT5700 方案独立包配置（方案 B）
│   ├── MT5700M.txt           # MT5700M 方案独立包配置（方案 A）
│   ├── H5000M-WIFI-YES.txt   # Hiveton H5000M 专属硬件板级定义
│   ├── AP3000M.txt           # AirPi AP3000M 专属硬件板级定义
│   └── X86.txt               # X86_64 架构板级定义
├── AP3000M-EEPROM/           # AP3000M 自动化射频恢复套件
│   ├── mt7981_eeprom_mt7976_dbdc.bin # 提取自闭源固件的标准校准 EEPROM
│   └── 99-ap3000m-eeprom     # 首次启动写入 factory 分区的初始化脚本
├── Scripts/                  # 编译流水线钩子脚本
│   ├── Packages.sh           # 第三方 Feed 拉取与版本锁定
│   ├── ApplyMTMode.sh        # 根据选定模式组装配置层并注入互斥开关
│   ├── VerifyMTMode.sh       # defconfig 后期校验，严查同名 .ko 驱动冲突
│   ├── Handles.sh            # 静态资源预置、主题适配与组件补丁
│   └── Settings.sh           # 默认 IP、主机名、Wi-Fi 射频参数编译期写入
├── LICENSE
└── README.md

```

---

## 💖 致敬与鸣谢

固件的稳定性与特定模组的良好体验离不开开源社区开发者的贡献，特别鸣谢以下项目与维护者：

* 🐧 **底包源码提供**：
* [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt/?utm_source=gemini)（X86 主线源码基石）
* [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt?utm_source=gemini)（为 H5000M / AP3000M 提供出色的板级适配与优化）


* 👤 **编译框架与底包优化**：
* [VIKINGYFY / OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI?utm_source=gemini)（稳定强大的云编译框架与大量实用插件优化）


* 👤 **5G CPE 核心插件支持**：
* [FAN789](https://github.com/FAN789?utm_source=gemini)（为 H5000M 与 MT5700 系列模组赋予了完善的控制能力）
* [luci-app-mt5700m](https://github.com/LianXia233/luci-app-mt5700m?utm_source=gemini)（5G 蜂窝监控与管理）
* [luci-app-h5000m-fancontrol](https://github.com/FAN789/luci-app-h5000m-fancontrol?utm_source=gemini)（硬件级智能风扇温控）
* [luci-app-h5000m-netmode](https://github.com/LianXia233/luci-app-h5000m-netmode?utm_source=gemini)（智能网络模式无缝调度）

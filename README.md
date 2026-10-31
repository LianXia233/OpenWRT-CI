<div align="center">

# 🚀 H5000M / AP3000M / X86_64 定制固件自动化云编译

**基于 ImmortalWrt 深度定制 · 专为 5G CPE、Wi-Fi 路由器与软路由量身打造的自动化云编译生态**

[![ImmortalWrt](https://img.shields.io/badge/Source-VIKINGYFY%2Fimmortalwrt-00A0D0?logo=openwrt&logoColor=white&style=flat-square)](https://github.com/VIKINGYFY/immortalwrt)
[![ImmortalWrt Master](https://img.shields.io/badge/Source-immortalwrt%2Fmaster-brightgreen?logo=openwrt&logoColor=white&style=flat-square)](https://github.com/immortalwrt/immortalwrt)
[![Platform Filogic](https://img.shields.io/badge/Platform-MediaTek%20Filogic-FF6B35?style=flat-square)](#-平台与机型支持)
[![Platform x86_64](https://img.shields.io/badge/Platform-x86__64-informational?style=flat-square)](#-平台与机型支持)
[![CI Build](https://img.shields.io/github/actions/workflow/status/LianXia233/OpenWRT-CI/WRT-BUILD.yml?branch=main&label=CI%20Build&style=flat-square&logo=githubactions&logoColor=white)](https://github.com/LianXia233/OpenWRT-CI/actions)
[![GitHub Pages](https://img.shields.io/badge/Portal-GitHub%20Pages-0ea5e9?style=flat-square&logo=googlechrome&logoColor=white)](https://lianxia233.github.io/OpenWRT-CI/)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue?style=flat-square&logo=gnu&logoColor=white)](LICENSE)

<p align="center">
  <b>全面适配 Hiveton H5000M 5G CPE（MT7987A + MT5700M）、AirPi AP3000M（MT7981B）与通用 X86_64 架构设备</b><br>
  🌐 <b>在线固件下载工坊 / 落地页官网</b>：<a href="https://lianxia233.github.io/OpenWRT-CI/">https://lianxia233.github.io/OpenWRT-CI/</a>
</p>

</div>

---

## 🌟 核心特性亮点

- ⚡ **多源码与架构深度融合**：H5000M / AP3000M 基于稳定验证的 `VIKINGYFY/immortalwrt` (`owrt`) 源码构建，X86_64 直接对接 `immortalwrt/immortalwrt` 官方 `master` 主线分支，兼顾硬件专有驱动与前沿特性。
- 📶 **双模组生态可选**：支持 **鼎桥 MT5700M 5G 模组**（方案 A `MT5700M` 完整版 / 方案 B `MT5700` Rust 单包版）与 **广和通 Fibocom FM350-GL 模组**，互斥隔离、防止底层驱动冲突。
- 🧭 **NetWiz 向导式配网**：集成 NetWiz 现代配置向导家族，零门槛三步完成 5G / 有线网络接入，配备故障自愈守护与看门狗。
- 🛠️ **AP3000M 射频自动恢复**：集成出厂校准 EEPROM 自动灌装套件，首次开机自动提取网卡 MAC 并修正 5GHz 频宽，彻底解决 factory 分区缺失 Wi-Fi 不工作的通病。
- ❄️ **硬件级风扇温控与网络双链路切换**：CPU + 模组双温区轮询，支持 PWM 阶梯温控调速；多网络模式毫秒级故障倒换。
- 🚀 **全面预置加速与轻 NAS 能力**：内核层集成 `kmod-cryptodev` 与 `kmod-tls` 硬件加速，原生支持 NVMe 固态硬盘挂载、BTRFS 与 Samba4 高速共享，内置 Tailscale 与 EasyTier 异地组网。

---

## 📦 固件变体全景总览

本项目提供清晰的产品分流结构，各机型除**基础母配置**外，提供 **FM350 变体** 与 **NetWiz 向导家族**：

| 变体系列 | 适用机型 | 核心特色组件 | 模组方案 (MT Mode) | 典型应用场景 |
| :--- | :--- | :--- | :---: | :--- |
| **基础母配置** | | | | |
| `H5000M-WIFI-YES` | H5000M | 5G 模组控制（可选）+ 风扇温控 + 多网切换 | 按需选择* | 标准 5G CPE 用户、高性能蜂窝路由 |
| `AP3000M` | AP3000M | 5G 模组控制（可选）+ 风扇控制 + 多网切换 | 按需选择* | 双频 Wi-Fi 6 无线路由、移动热点 |
| `X86` | X86_64 | Docker 容器生态 + 多网切换 | 按需选择* | 工控机 / 软路由 / 虚拟机 / All-in-One |
| **FM350 变体** | | | | |
| `*-FM350` | H5000M / AP3000M / X86 | 母配置 **+ `luci-app-fm350`**（FM350-GL 模组管理） | 无 (留空) | 加装广和通 FM350-GL 模组的设备 |
| **NetWiz 向导家族** | | | | |
| `*-NETWIZ-MT5700` | H5000M / AP3000M / X86 | 母配置 **+ `luci-app-netwiz`** + MT5700 方案 | `MT5700` | 初学新手、向导式配网 + 5G（Rust 方案 B） |
| `*-NETWIZ-MT5700M` | H5000M / AP3000M / X86 | 母配置 **+ `luci-app-netwiz`** + MT5700M 方案 | `MT5700M` | 初学新手、向导式配网 + 5G（经典方案 A） |
| `*-NETWIZ-FM350` | H5000M / AP3000M / X86 | 母配置 **+ `luci-app-netwiz`** + FM350 方案 | 无 (留空) | 初学新手、向导式配网 + FM350 模组 |
| **自用配置** | | | | |
| `H5000M-WIFI-YES-NETMONITOR` | H5000M | 母配置 + 网络监控 `netmonitor` + 每日签到 `taygedo` | `MT5700`（固定） | 作者个人测试使用，独立归组 |

> \* 注：基础母配置本身不捆绑特定模组插件，编译时通过 **MT Mode** 下拉选项（`MT5700M` / `MT5700` / `NONE`）按需动态叠加。

### 插件与变体对照矩阵

| 集成插件组件 | 基础母配置 | FM350 变体 | NetWiz-MT5700 | NetWiz-MT5700M | NetWiz-FM350 | 自用配置 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| 多网智能切换 `h5000m-netmode` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 5G 模组管理 `mt5700`（方案 B · Rust） | 🟡 可选 | — | ✅ | — | — | ✅ |
| 5G 模组管理 `mt5700m`（方案 A · 经典） | 🟡 可选 | — | — | ✅ | — | — |
| FM350 模组管理 `fm350` | — | ✅ | — | — | ✅ | — |
| NetWiz 配网向导 `netwiz` | — | — | ✅ | ✅ | ✅ | — |
| 网络监控 `netmonitor` / 签到 `taygedo` | — | — | — | — | — | ✅ |
| 硬件风扇温控 `h5000m/airpi-fancontrol` | H5000M / AP3000M | 包含 | 包含 | 包含 | 包含 | 包含 |

> `✅` 固件默认内置　`🟡` 由编译参数动态决定　`—` 不包含

---

## 🛠️ 平台与机型支持

| 目标配置 | 处理器平台 / SoC | 适配机型 | 底层源码分支 | Wi-Fi 支持 | 输出镜像格式 |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `H5000M-WIFI-YES` | MediaTek Filogic (MT7987A + MT7996E) | Hiveton H5000M 5G CPE | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ Wi-Fi 7 (BE) | Sysupgrade / Factory |
| `AP3000M` | MediaTek Filogic (MT7981B + MT7976C) | AirPi AP3000M 无线路由 | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ Wi-Fi 6 (AX) | Sysupgrade / Factory |
| `X86` | 标准 x86_64 处理器 | PC / 软路由 / 工控机 / 虚拟机 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) (`master`) | — | ISO / EFI / GRUB / VMDK |

> [!IMPORTANT]
> **AP3000M 射频校准全自动注入**：
> 设备出厂时 eMMC 的 `factory` 分区为空，开源 `mt76` 驱动因缺乏射频校准数据无法激活无线。本固件内置高功率版 EEPROM（28~29 dBm），首次开机自启脚本自动绑定真实物理 MAC 并写入射频分区，无需人工拆机刷入。

---

## ⚙️ 固件默认出厂参数

固件首次刷入后的基础网络通信参数如下。所有默认值统一由 [`Config/Defaults.txt`](Config/Defaults.txt) 声明管理：

| 参数项 | 出厂默认值 | 说明 |
| :--- | :--- | :--- |
| **后台管理地址** | `192.168.10.1` | Web 管理页面 IPv4 访问入口 |
| **后台登录账号/密码** | `root` / **空（无密码）** | 首次进入后建议立即设置强密码 |
| **系统主机名** | `OWRT` | 局域网标识符 |
| **默认 Wi-Fi SSID** | `OWRT` | 2.4G 与 5G 双频合一名称 |
| **默认 Wi-Fi 密码** | `12345678` | WPA/WPA2 混合加密 |
| **无线频宽（WiFi 6 · AP3000M）** | 2.4G `40MHz` · 5G `160MHz` | 802.11ax（HE），跑满百兆/千兆无线吞吐 |
| **无线频宽（WiFi 7 · H5000M）** | 2.4G `40MHz` · 5G `160MHz` | 802.11be（EHT），双频设备 5G 上限 160MHz |
| **系统国家码 / 时区** | `CN` / `Asia/Shanghai` | 确保合规射频功率与精准 NTP 时钟校准 |

---

## 🧩 核心模组生态方案详解

### 1. 鼎桥 MT5700M 5G 模组（两套方案对比）

| 方案分类 | 插件名 | 架构特征 | 依赖组件 | 驱动形态 |
| :--- | :--- | :--- | :--- | :--- |
| **方案 A** `MT5700M` | `luci-app-mt5700m` | 经典成熟：状态大屏、AT 交互、短信转发 | `sms-tool_q` + `ubus-at-daemon` | QModem feed 驱动栈 |
| **方案 B** `MT5700` | `luci-app-mt5700` | 现代化单包：内置 Rust/Tokio 异步后端，12 个独立控制台 | 静态二进制内置，零外部依赖 | 官方 packages feed |

> [!WARNING]
> **方案互斥保障**：两套方案底层存在驱动层 `.ko` 冲突。本仓库流水线在编译前注入了互斥校验门禁，若在配置中误将两套同时选中，CI 将在早期直接拦截，确保输出固件的绝对纯净。

### 2. 广和通 Fibocom FM350-GL 模组管理 (`luci-app-fm350`)

- **RNDIS 免驱拨号**：原生走高速 RNDIS 数据通路，与 QMI 驱动栈无任何冲突；
- **Rust 独立守护**：内置 `fm350d` 静态 musl 二进制，独占 AT 端口执行频段锁死、状态查询与短信收发。

### 3. NetWiz 向导式网络管家 (`luci-app-netwiz`)

- **一步一景向导**：提供图形化配置网络流程，降低家庭/企业初次入网难度；
- **三层容灾自愈**：内置 `netwiz-monitor` 巡检、`netwiz-recovery` 自愈与 `netwiz-watchdog` 状态看门狗。

---

## 🚀 自动化云端编译与构建发布

无需本地准备繁琐的交叉编译工具链，依托 GitHub Actions 全自动化编排：

### 工作流矩阵职责

| 工作流文件 | 触发机制 | 职责与产物说明 |
| :--- | :--- | :--- |
| **`WRT-BUILD.yml`** | 手动 `workflow_dispatch` | 自定义按需编译：自选目标机型、源码上游与 MT 模组方案；支持 `TEST=true` 语法预演验证 |
| **`*-MT-AUTO.yml`** | 每日定时 / 手动 | H5000M / AP3000M / X86 基础配置自动化定时编译与 Release 发布 |
| **`FM350-AUTO.yml`** | 每日定时 / 手动 | 全系机型 FM350 变体固件统一编译发版 |
| **`NetWiz-AUTO.yml`** | 每日定时 / 手动 | NetWiz 家族全组合变体自动化编译发版 |
| **`H5000M-NETMONITOR-AUTO.yml`** | 每日定时 / 手动 | 作者个人自用配置自动定时编译 |
| **`Auto-Clean.yml`** | 每日定时 | 轮换保留最新构建 Release，自动清理历史废旧 Tag 与过期运行日志 |
| **`Cache-Clean.yml`** | 每周定时 / 手动 | 回收 Actions 编译缓存，防止依赖冲突 |

### Release 归组与文件命名规范

产物 Tag 统一遵循 `<产品分类>-<YY.MM.DD>` 格式，同一天内的同类固件汇聚至统一 Release：

| 归组 Tag 示例 | 包含的固件产物 |
| :--- | :--- |
| `NetWiz-26.11.01` | NetWiz 家族全部组合变体（`NetWiz-MT5700` / `NetWiz-MT5700M` / `NetWiz-FM350`） |
| `MT5700-26.11.01` | 基础母配置 + MT5700 模式固件 |
| `MT5700M-26.11.01` | 基础母配置 + MT5700M 模式固件 |
| `FM350-26.11.01` | 基础母配置 + FM350 模组固件 |
| `自用-26.11.01` | H5000M 个人专属配置固件 |

固件文件名格式：`<设备>-<产品/方案>-<固件类型>.<扩展名>`（如 `H5000M-MT5700-sysupgrade.bin`、`AP3000M-FM350-factory.bin`）。

---

## 📂 仓库项目结构

```text
OpenWRT-CI/
├── .github/workflows/        # GitHub Actions CI/CD 流水线编排
│   ├── WRT-CORE.yml          # 底层通用编译引擎
│   ├── WRT-BUILD.yml         # 手动触发定制编译入口
│   ├── *-MT-AUTO.yml         # MT 方案定时构建发版
│   ├── FM350-AUTO.yml        # FM350 变体定时构建
│   ├── NetWiz-AUTO.yml       # NetWiz 家族定时构建
│   ├── Auto-Clean.yml        # 历史制品轮换与清理
│   └── Cache-Clean.yml       # Actions 缓存回收
├── Config/                   # 模块化 Kconfig 配置文件片段
│   ├── Defaults.txt          # 出厂网络/无线默认值集中定义
│   ├── GENERAL.txt           # 通用内核优化参数与基础插件
│   ├── MT5700.txt / MT5700M.txt       # 模组管理方案 A/B 独立包定义
│   ├── H5000M-WIFI-YES.txt / AP3000M.txt / X86.txt # 硬件机型基础母配置
│   ├── *-FM350.txt           # 各机型 FM350 变体配置
│   └── *-NETWIZ-*.txt        # NetWiz 组合变体配置
├── AP3000M-EEPROM/           # AP3000M 射频恢复与校准脚本套件
├── Scripts/                  # 编译生命周期钩子脚本
│   ├── Packages.sh           # 第三方源码 Feed 拉取与版本锁定
│   ├── ApplyMTMode.sh        # MT 模组方案注入与配置组装
│   ├── VerifyMTMode.sh       # 编译前驱动冲突语义安全拦截
│   ├── Handles.sh            # 静态补丁应用与组件冲突修复
│   └── Settings.sh           # 出厂默认 IP / Wi-Fi 编译期注入
├── docs/                     # GitHub Pages 静态落地页源码
└── README.md                 # 固件说明文档
```

---

## 💖 致敬与鸣谢

* 🐧 **底包源码**：[immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)（X86 官方主线）· [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)（Filogic 硬件板级适配）
* 👤 **编译框架**：[VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI)（优秀的开源自动化编译框架）
* 👤 **模组与生态插件**：[FAN789](https://github.com/FAN789) · [luci-app-mt5700](https://github.com/LianXia233/luci-app-mt5700) · [luci-app-mt5700m](https://github.com/LianXia233/luci-app-mt5700m) · [luci-app-fm350](https://github.com/LianXia233/luci-app-fm350) · [luci-app-netwiz](https://github.com/huchd0/luci-app-netwiz) · [luci-app-h5000m-fancontrol](https://github.com/LianXia233/luci-app-h5000m-fancontrol) · [luci-app-h5000m-netmode](https://github.com/LianXia233/luci-app-h5000m-netmode)

---

> 📜 **开源许可**：本项目基于 [GNU General Public License v3.0 (GPL-3.0)](LICENSE) 协议发布。

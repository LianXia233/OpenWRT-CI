<div align="center">

# 🚀 H5000M / AP3000M / X86_64 定制固件

**基于 ImmortalWrt 深度定制 · 专为 5G CPE、Wi-Fi 路由器与软路由打造**

[![Source: VIKINGYFY](https://img.shields.io/badge/Source-VIKINGYFY%2Fimmortalwrt-blue?logo=openwrt&logoColor=white)](#)
[![Source: Master](https://img.shields.io/badge/Source-immortalwrt%2Fmaster-brightgreen?logo=openwrt&logoColor=white)](#)
[![Platform: Filogic](https://img.shields.io/badge/Platform-MediaTek%20Filogic-orange)](#)
[![Platform: x86_64](https://img.shields.io/badge/Platform-x86__64-informational)](#)
[![Build: GitHub Actions](https://img.shields.io/badge/Build-GitHub%20Actions-success?logo=githubactions&logoColor=white)](#)

*适配 Hiveton H5000M 5G CPE（MT7986 + MT5700M）、AirPi AP3000M（MT7981B）与通用 X86_64 架构设备，全系固件由 GitHub Actions 云端编译、自动发布*

</div>

---

## 📦 变体总览

每种机型（`H5000M` / `AP3000M` / `X86`）除**母配置**外，另有 **FM350 变体**、**NetWiz 家族**与 **H5000M 自用配置**，按「产品/配置本身」分类，互不交叉：

| 变体 | 机型 | 核心插件 | MT 模式 | 适用场景 |
| :--- | :--- | :--- | :---: | :--- |
| **基础母配置** |||||
| `H5000M-WIFI-YES` | H5000M | 5G 模组控制（可选）+ 风扇温控 + 多网切换 | 按需* | 标准 5G CPE 用户 |
| `AP3000M` | AP3000M | 5G 模组控制（可选）+ 风扇控制 + 多网切换 | 按需* | 双频 Wi-Fi 路由器 |
| `X86` | X86_64 | Docker + 多网切换 | 按需* | 软路由 / 工控机 |
| **FM350 变体**（`*` = 三种机型各一份） |||||
| `*-FM350` | H5000M / AP3000M / X86 | 母配置 **+ `luci-app-fm350`**（FM350-GL 模组管理） | 无 | 使用 Fibocom FM350-GL 模组的设备 |
| **NetWiz 家族**（`*` = 三种机型各一份） |||||
| `*-NETWIZ-MT5700` | H5000M / AP3000M / X86 | 母配置 **+ `luci-app-netwiz`** + MT5700 方案 | `MT5700` | 向导式配网 + 5G（方案 B） |
| `*-NETWIZ-MT5700M` | H5000M / AP3000M / X86 | 母配置 **+ `luci-app-netwiz`** + MT5700M 方案 | `MT5700M` | 向导式配网 + 5G（方案 A） |
| `*-NETWIZ-FM350` | H5000M / AP3000M / X86 | 母配置 **+ `luci-app-netwiz`** + FM350 | 无 | 向导式配网 + FM350 模组 |
| **个人自用** |||||
| `H5000M-WIFI-YES-NETMONITOR` | H5000M | 母配置 + 网络监控 `netmonitor` + 每日签到 `taygedo` | `MT5700`（固定） | 作者自用，不对外维护 |

> *按需：母配置本身不含 5G 模组插件，编译时通过 **MT Mode** 下拉（`MT5700M` / `MT5700` / `NONE`）叠加，详见下文「模组方案」。

### 插件 × 变体对照矩阵

| 插件 | 母配置 | FM350 | NetWiz-MT5700 | NetWiz-MT5700M | NetWiz-FM350 | 自用 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| 多网智能切换 `h5000m-netmode` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 5G 模组控制 `mt5700`（方案 B） | 🟡 | — | ✅ | — | — | ✅ |
| 5G 模组控制 `mt5700m`（方案 A） | 🟡 | — | — | ✅ | — | — |
| FM350 模组管理 `fm350` | — | ✅ | — | — | ✅ | — |
| NetWiz 网络向导 `netwiz` | — | — | ✅ | ✅ | ✅ | — |
| 网络监控 `netmonitor` | — | — | — | — | — | ✅ |
| 每日签到 `taygedo` | — | — | — | — | — | ✅ |
| 风扇温控 `h5000m/airpi-fancontrol` | H5000M / AP3000M | 同左 | 同左 | 同左 | 同左 | H5000M |

> `✅` 内置　`🟡` 可选（由 MT Mode 决定）　`—` 不包含

> [!IMPORTANT]
> **NetWiz 是独立产品分类**：NetWiz 家族（含 MT / FM350 组合）产物在 Releases 中统一归组「NetWiz」，绝不进入 MT5700 / MT5700M / FM350 等插件分类；组合差异体现在固件文件名后缀（如 `H5000M-NetWiz-MT5700-sysupgrade.bin`）。

> [!NOTE]
> **自用配置**为作者个人私有：产物单独归组「自用」，不进入任何公开分类，仅供作者自有设备使用。

---

## 🛠️ 平台与机型

| 目标配置 | 硬件平台 / SoC | 适配机型 | 源码 | Wi-Fi | 镜像格式 |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `H5000M-WIFI-YES` | MediaTek Filogic (MT7986) | Hiveton H5000M 5G CPE | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ | Sysupgrade / Factory |
| `AP3000M` | MediaTek Filogic (MT7981B) | AirPi AP3000M | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ | Sysupgrade / Factory |
| `X86` | 标准 x86_64 处理器 | 通用 PC / 工控机 / 软路由 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) (`master`) | — | ISO / EFI / GRUB / VMDK |

> [!IMPORTANT]
> **AP3000M Wi-Fi 校准**：设备 eMMC 出厂时 factory 分区为空，Wi-Fi 驱动无法加载校准参数。本固件内置校准版 EEPROM（发射功率 28~29 dBm），**首次启动自动**写入真实 MAC 并修正 5GHz 频段，全程无需手动干预。

---

## 🧩 模组方案与核心插件

### 5G 模组控制（`luci-app-mt5700m` / `luci-app-mt5700`）

| 方案 | 插件 | 特点 | 依赖 | 驱动来源 |
| :--- | :--- | :--- | :--- | :--- |
| **方案 A** `MT5700M` | `luci-app-mt5700m` | 功能完整：状态大屏 + 在线 AT + 短信收发 | `sms-tool_q` + `ubus-at-daemon` | QModem feed |
| **方案 B** `MT5700` | `luci-app-mt5700` | 轻量单包：内置 Rust 后端 | 单包自带 | packages feed |

- 📊 **状态大屏**：实时呈现 5G 信号（RSRP / RSRQ / SINR）、SA/NSA 制式、驻留频段、运营商与 IMEI/IMSI
- 🔌 **全协议拨号**：QMI / NCM 等高速拨号通道
- ⚙️ **在线 AT 交互**：后台 `ubus-at-daemon` 免串口下发 AT 指令，锁频、锁小区
- ✉️ **短信收发**：网页端直接查收流量卡余额、套餐提醒与验证码

> [!WARNING]
> **两方案互斥**：MT5700M（QModem）与 MT5700（官方 packages）存在同名 QMI 驱动 `.ko` 文件冲突。构建流程通过前置注入互斥开关 + 编译前语义校验**双重防护**，MT 模式选错会在编译早期直接拦截，不会产出脏固件。

### Fibocom FM350-GL 模组管理（`luci-app-fm350`）

- 📡 **状态与拨号**：驻留频段、信号质量、APN 配置与拨号管理
- 🔧 **在线 AT 与锁频**：Rust 守护进程 `fm350d` 独占 AT 端口
- 📨 **短信收发**：网页端查收 / 发送短信
- ⚡ **Rust 后端**：cargo 交叉编译为 musl 静态二进制，不走 OpenWrt `rust/host` 源码构建

> [!NOTE]
> FM350 走 **RNDIS** 数据通道，与 MT 方案的 QMI 驱动无 `.ko` 冲突；FM350 变体的 MT 模式一律留空。

### NetWiz 网络配置向导（`luci-app-netwiz`）

- 🧭 **向导式配网**：「上网方式选择 → 参数填写 → 生效验证」一键引导，降低初次配置门槛
- 🛡️ **非破坏性改动**：只追加自身所需配置项，不改动既有网络结构
- 🔁 **三层守护**：`netwiz-monitor`（巡检）+ `netwiz-recovery`（自愈）+ `netwiz-watchdog`（看门狗），另有 DHCP 守卫插件
- 💾 **离线保险箱**：支持预置离线安装包补齐依赖，自愈流程自动保护 `firewall-*` / `dnsmasq-*` 等基础组件

### 风扇温控（`luci-app-h5000m-fancontrol` / `luci-app-airpi-fancontrol`）

- 🌡️ **双温区采集**：CPU + 模组温感数据（H5000M）
- 🌀 **PWM 阶梯变速**：按温度阈值动态调速，兼顾静音与散热

### 多网络智能切换（`luci-app-h5000m-netmode`，全机型）

- 🔄 **接入模式切换**：「仅 5G 蜂窝」「仅 WAN 有线」「双链路负载均衡 / 主备切换」一键调度
- ⚡ **毫秒级容灾**：联动 `mwan3` 探针，主链路中断瞬间切流

### 系统级能力集成

- 🚀 **硬件加解密加速**：内核级 `kmod-cryptodev` + `kmod-tls`，代理 / VPN 隧道跑在硬件加速通道
- 💾 **轻量 NAS**：NVMe + BTRFS + Samba4，高速固态满速共享
- 🌐 **零配置组网**：预置 Tailscale 与 EasyTier，无公网 IP 也能穿透组网
- 🐳 **Docker 支持**（X86）：`luci-app-dockerman` 容器管理

---

## ⚙️ 固件默认参数

| 配置项 | 默认出厂值 | 说明 |
| :--- | :--- | :--- |
| **后台管理地址** | `192.168.10.1` | Web 管理界面默认 IP |
| **后台密码** | 无 | 首次开机无密码 |
| **主机名** | `OWRT` | 系统网络标识 |
| **Wi-Fi** | SSID `OWRT` / 密码 `12345678` | 2.4G 与 5G 共用，WPA 混合加密 |
| **无线（WiFi6 · AP3000M）** | 2.4G `AX 40MHz` · 5G `AX 160MHz` | 2.4G/5G 同步 802.11ax（WiFi6），跑满无线吞吐 |
| **无线（WiFi7 · H5000M）** | 2.4G `BE 40MHz` · 5G `BE 160MHz` | 2.4G/5G 同步 802.11be（WiFi7），5G 上限同为 160MHz（320MHz 仅限 6GHz 频段） |
| **国家码 / 时区** | `CN` / `Asia/Shanghai` | 避免时钟同步异常 |

*以上局域网 / 无线默认值统一存放在 [`Config/Defaults.txt`](Config/Defaults.txt)，编译期由 `Scripts/Settings.sh` 读取并写入固件；修改该文件即可全局生效，无需改动工作流。工作流显式传入的 `WRT_*` 输入优先级更高，可用于按需覆盖。*

---

## 🚀 自动化构建与发布

所有编译任务均由 GitHub Actions 驱动，无需本地交叉编译工具链。

### 工作流矩阵

| 工作流 | 触发 | 职责 |
| :--- | :--- | :--- |
| **`WRT-BUILD`** | 手动 | 自定义按需编译：自选机型 / 源码 / MT 模式；默认 `TEST=true` 仅验证配置 |
| **`H5000M/AP3000M/X86-MT-AUTO`** | 每日定时 · 手动 | 各机型 MT5700 + MT5700M 双配置并行编译并自动发版 |
| **`FM350-AUTO`** | 每日定时 · 手动 | 全部机型 FM350 变体统一编译发版 |
| **`NetWiz-AUTO`** | 每日定时 · 手动 | NetWiz 家族 9 个组合变体统一编译发版 |
| **`H5000M-NETMONITOR-AUTO`** | 每日定时 · 手动 | 自用配置（固定 MT5700）编译发版，归组「自用」 |
| **`Auto-Clean`** | 每日定时 | 保留最近 1 个 Release 与 30 天构建日志 |
| **`Cache-Clean`** | 手动 | 清理 actions/cache 编译缓存 |

### 手动编译快速指引

1. 进入 **`Actions`** → 选择 **`WRT-BUILD`** → **`Run workflow`**
2. **Target Device**：母配置 3 项 / FM350 变体 3 项 / NetWiz 家族 9 项 / 自用 1 项，共 16 项
3. **MT Mode**：`MT5700M` / `MT5700` / `NONE`（选 `*-NETWIZ-MT5700` / `*-NETWIZ-MT5700M` / 自用配置时**必须**同步选对应 MT 模式，否则校验拦截）
4. **TEST**：正式输出固件时**务必设为 `false`**

### Release 归组与固件命名

**Releases 按「产品/配置本身」分类**，Tag 格式 `<组名>-<YY.MM.DD>`，同组同日全部机型产物汇聚到同一个 Release：

| 归组（Tag 示例） | 包含内容 |
| :--- | :--- |
| `NetWiz-26.09.26` | NetWiz 家族全部组合变体（`NetWiz-MT5700` / `NetWiz-MT5700M` / `NetWiz-FM350`） |
| `MT5700-26.09.26` | 非 NetWiz 产品的 MT5700 模式固件 |
| `MT5700M-26.09.26` | 非 NetWiz 产品的 MT5700M 模式固件 |
| `FM350-26.09.26` | 非 NetWiz 产品的 FM350 变体固件 |
| `自用-26.09.26` | H5000M 自用固件（作者私有） |
| `BASE-26.09.26` | 手动编译的无变体基础固件 |

**固件文件名**统一为 `<设备>-<产品/方案>-<固件类型>.<扩展名>`，去除冗余的源码 / 分支 / 时间戳：

```text
H5000M-MT5700-sysupgrade.bin        # 母配置 + MT5700
H5000M-MT5700M-sysupgrade.bin       # 母配置 + MT5700M
AP3000M-FM350-factory.bin           # FM350 变体
H5000M-NetWiz-MT5700-sysupgrade.bin # NetWiz + MT5700 组合
H5000M-NetWiz-MT5700M-sysupgrade.bin
X86-NetWiz-FM350-efi.img
H5000M-自用-sysupgrade.bin          # 作者自用
```

> [!TIP]
> 设备段（`H5000M` / `AP3000M` / `X86`）用于区分同一 Release 内的多机型产物；产品/方案段按产品身份推导（NetWiz 家族统一以 `NetWiz-` 开头）；固件类型段（`sysupgrade` / `factory` / `efi` / `combined` 等）保留刷机判断所需信息。

---

## 📂 项目结构

```text
OpenWRT-CI/
├── .github/workflows/        # CI/CD 云编译编排
│   ├── WRT-CORE.yml          # 公共编译底层流水线（被各任务调用）
│   ├── WRT-BUILD.yml         # 手动编译入口
│   ├── H5000M/AP3000M/X86-MT-AUTO.yml  # 各机型 MT 双配置定时发布
│   ├── FM350-AUTO.yml        # FM350 变体统一入口
│   ├── NetWiz-AUTO.yml       # NetWiz 家族统一入口
│   ├── H5000M-NETMONITOR-AUTO.yml       # 自用配置定时发布
│   ├── Auto-Clean.yml        # 历史制品与日志清理
│   └── Cache-Clean.yml       # 编译缓存回收
├── Config/                   # 模块化编译配置层
│   ├── GENERAL.txt           # 全设备通用内核参数与插件
│   ├── MT5700.txt / MT5700M.txt         # MT 方案独立包配置
│   ├── H5000M-WIFI-YES.txt / AP3000M.txt / X86.txt   # 机型板级定义
│   ├── *-FM350.txt           # 各机型板级 + luci-app-fm350
│   ├── *-NETWIZ-MT5700 / -MT5700M / -FM350.txt       # NetWiz 组合变体
│   └── H5000M-WIFI-YES-NETMONITOR.txt  # 自用配置
├── AP3000M-EEPROM/           # AP3000M 射频恢复套件
├── Scripts/                  # 编译流水线钩子
│   ├── Packages.sh           # 第三方 Feed 拉取与版本锁定
│   ├── Packages-FM350.sh / Packages-NetWiz.sh / Packages-NetMonitor.sh
│   ├── ApplyMTMode.sh        # MT 方案配置层组装与互斥注入
│   ├── VerifyMTMode.sh       # 编译前 MT 驱动冲突语义校验
│   ├── Handles.sh            # 静态资源预置与组件补丁
│   └── Settings.sh           # 默认 IP / Wi-Fi 参数编译期写入
└── README.md
```

---

## 💖 致敬与鸣谢

* 🐧 **底包源码**：[immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)（X86 主线）· [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)（H5000M / AP3000M 板级适配）
* 👤 **编译框架**：[VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI)（云编译框架与插件优化）
* 👤 **模组与插件**：[FAN789](https://github.com/FAN789) · [luci-app-mt5700m](https://github.com/LianXia233/luci-app-mt5700m) · [luci-app-fm350](https://github.com/LianXia233/luci-app-fm350) · [luci-app-netwiz](https://github.com/huchd0/luci-app-netwiz) · [luci-app-h5000m-fancontrol](https://github.com/FAN789/luci-app-h5000m-fancontrol) · [luci-app-h5000m-netmode](https://github.com/LianXia233/luci-app-h5000m-netmode)

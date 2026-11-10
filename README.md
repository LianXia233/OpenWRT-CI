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
| 网络监控 `netmonitor` | — | — | — | — | — | ✅ |
| 每日签到 `taygedo` | 🟡 可选 | 🟡 可选 | 🟡 可选 | 🟡 可选 | 🟡 可选 | ✅ |
| 在线升级 `online-upgrade` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 硬件风扇温控 `h5000m/airpi-fancontrol` | H5000M / AP3000M | 包含 | 包含 | 包含 | 包含 | 包含 |

> `✅` 固件默认内置　`🟡` 由编译参数动态决定　`—` 不包含

> **关于 `taygedo`**：该包自 2026-11 起改为**配置驱动**——任何 `Config/*.txt`
> 只要写一行 `CONFIG_PACKAGE_luci-app-taygedo=y`，`Scripts/Packages-Taygedo.sh`
> 就会在 `defconfig` 之前把包与 Rust 源码放进 `package/luci-app-taygedo/`，
> 无需改动工作流，也不再与 `H5000M-WIFI-YES-NETMONITOR` 变体绑定。
>
> 二进制**从源码交叉编译**：`defconfig` 之后由 `Scripts/Build-Taygedo.sh`
> 用宿主机 rustup + OpenWrt `staging_dir` 里的 `<arch>-openwrt-linux-musl-gcc`
> 编出 `--no-default-features --features openwrt` 形态的静态 musl 可执行文件，
> 落到 `package/luci-app-taygedo/local/taygedo-rs`，包 Makefile 见到即跳过
> 网络下载。与「预编译 AirPi Rust 后端」共用同一套工具链思路；编译失败时
> 自动回退 `cross`（Docker），仍失败可设 `TAYGEDO_PREBUILT=1` 退回 Release
> 预编译资产。

### 3. 在线升级 `luci-app-online-upgrade`（全机型内置）

[`LianXia233/luci-app-online-upgrade`](https://github.com/LianXia233/luci-app-online-upgrade) 是一条「检查 → 下载 → 调 `sysupgrade`」的在线升级链路：LuCI 前端 + `rpcd` ucode 后端 + Rust 静态二进制 `/usr/bin/online-upgrade`（分片并发下载、断点续传、Release 资产正则匹配）。

**接入方式**

- 上游仓库是「包即仓库根」形态（`Makefile` / `root/` / `rust/` 都在根目录），不是 feeds 布局，因此不挂 `src-git` feed；由 [`Scripts/Packages-OnlineUpgrade.sh`](Scripts/Packages-OnlineUpgrade.sh) 在 `defconfig` 之前 clone 进 `package/luci-app-online-upgrade/`。
- 上游 `Build/Prepare` 与 `Build/Compile` 均为空，安装段直接取 `./root/usr/bin/online-upgrade`，即二进制必须外部预置。本仓库在 [`WRT-CORE.yml`](.github/workflows/WRT-CORE.yml)「预编译 Rust 后端」第 ④ 段用官方 Rust SDK + OpenWrt musl 交叉链接器编译，产物落到包内该路径（`RUST_NO_INJECT=1`，不改上游 Makefile）。
- [`Scripts/Settings.sh`](Scripts/Settings.sh) 对**全部** `Config/*.txt` 统一打开 `CONFIG_PACKAGE_luci-app-online-upgrade=y`，新增机型无需再逐份改配置。运行期依赖 `rpcd-mod-ucode`、`ucode-mod-fs`、`ucode-mod-uci` 由包 `DEPENDS` 自动拉取。

**各机型预设配置**

预设由 [`Scripts/OnlineUpgradePreset.sh`](Scripts/OnlineUpgradePreset.sh) 在构建期按 `WRT_DEVICE` / `WRT_FLAVOR` / `WRT_ARCH` / `WRT_TAG_GROUP` 生成，落在 `files/etc/config/online-upgrade`（`$(TOPDIR)/files` 会被并入 rootfs），覆盖包自带同名 conffile，首次开机即指向本机型自己的产物：

| 机型 | `firmware_pattern`（正则） | 匹配的实际资产 |
| :--- | :--- | :--- |
| H5000M | `^H5000M-[A-Za-z0-9-]+-aarch64-[0-9]{2}\.[0-9]{2}\.[0-9]{2}-sysupgrade\.bin$` | `H5000M-NetWiz-MT5700-aarch64-26.11.09-sysupgrade.bin`、`H5000M-FM350-aarch64-26.11.09-sysupgrade.bin`、自用版 `H5000M-SelfUse-aarch64-26.11.09-sysupgrade.bin` |
| AP3000M | `^AP3000M-[A-Za-z0-9-]+-aarch64-[0-9]{2}\.[0-9]{2}\.[0-9]{2}-sysupgrade\.bin$` | `AP3000M-NetWiz-MT5700-aarch64-26.11.09-sysupgrade.bin` 等 |
| X86 | `^X86-[A-Za-z0-9-]+-x86-64-[0-9]{2}\.[0-9]{2}\.[0-9]{2}-efi\.img\.gz$` | `X86-NetWiz-MT5700-x86-64-26.11.09-efi.img.gz` 等（UEFI 引导） |

- **架构段是自动升级的前提**：资产名必须带 `aarch64`（H5000M / AP3000M，mediatek filogic）或 `x86-64`（X86），上游 `compat::asset_arch()` 靠它判定架构。少了它，即使机型命中也会被判成「资产未声明架构」（`arch_check=undeclared`）→ `can_upgrade=false`，只能在「固件列表」里人工确认。架构段放在日期之前，因此旧的宽松正则 `[A-Za-z0-9-]+-[0-9]{2}\.[0-9]{2}\.[0-9]{2}-` 仍能命中：升级前已刷老固件的设备不必先手动重刷，就能拿到新命名产物。
- **表里的 `[A-Za-z0-9-]+` 在实际预设中是精确值**：构建期把它换成该次构建的 `WRT_FLAVOR`（如 `NetWiz-MT5700`）。同一归组里同时存在 `H5000M-NetWiz-FM350` 与 `H5000M-NetWiz-MT5700`，只有精确到模组段才不会取错变体。

- `tag` 统一为 `latest@^<归组>-`，归组取 `BASE` / `MT5700` / `MT5700M` / `FM350` / `NetWiz` / `自用`，与 Release 的 Tag 前缀一致（如 `latest@^MT5700-` 只在 `MT5700-26.11.09` 这类 Tag 里找最新）。同一归组下三个机型共用 Release，靠 `firmware_pattern` 的设备前缀区分，不会互相取错。
- **日期段是识别关键**：上游 `version::pick()` 从资产名取「最后一个点分数字」当版本号，`is_date_tag()` 只把 `YY.MM.DD` / `YYYY.MM.DD` 认作日期型版本。固件名带编译日期后，自用 SNAPSHOT 固件的本地构建日期才能与目标版本正确比较新/旧；不带日期（或写成 `20261109`）只能退化成按 Release 发布时间判断。正则里的 `[0-9]{2}\.[0-9]{2}\.[0-9]{2}` 明确锚定日期段，也不会误匹配轮换前遗留的旧格式资产。
- 模组插件段全 ASCII：自用变体文件名用 `SelfUse`（`Release` 标题与 `Tag` 仍是中文「自用」）。此前用中文导致 GitHub 资产名被字节化成 `H5000M-.-sysupgrade.bin`，既不可读也无法稳定匹配，现已修复。
- **X86 引导方式需人工确认**：预设按 UEFI 取 `efi.img.gz`。BIOS/Legacy 引导的机器必须把 `firmware_pattern` 里的 `efi` 改成 `combined` —— 两者分区表不同，混用会导致升级后无法引导。
- 尚未发布过的归组（例如当前没有 `BASE-*` Release）不会报错，只是检查更新时返回「无新版本」，等对应构建出包后自动生效。
- **v2 二进制路径三方对齐（构建期断言）**：上游 `root/etc/uci-defaults/90-online-upgrade-auto` 曾判定 v1 的 `/usr/bin/online-upgrade.sh`，已于上游 `98a966a` 修复为 `[ -x /usr/bin/online-upgrade ]`。[`Scripts/Packages-OnlineUpgrade.sh`](Scripts/Packages-OnlineUpgrade.sh) 现在**按内容判定、幂等**：只在检测到 v1 路径时才改写，上游已修复则一行不动；随后断言文件内没有 `online-upgrade.sh`、守卫判定的就是 `/usr/bin/online-upgrade` —— 与 `Makefile` 安装项、WRT-CORE 预编译落点三者一致，任一处漂移即构建失败。

**预设的配置项（键名取自上游代码，非推测）**

| 配置项 | 预设值 | 含义 |
| :--- | :--- | :--- |
| `repo` | `LianXia233/OpenWRT-CI` | 升级源仓库（GitHub `owner/repo`） |
| `tag` | `latest@^<归组>-` | `latest` 取最新 Release；`latest@<正则>` 限定 Tag 范围 |
| `firmware_pattern` | 见上表 | 对 Release 资产名做**正则**匹配，决定下载哪个文件 |
| `min_size_mb` | `15` | 下载完整性下限（MB），低于即判为截断 |
| `proxy` | `https://gh.acg2.mom/` | 下载加速前缀，直连 GitHub 不稳时使用 |
| `expected_sha256` | 留空 | 留空则自动读取 Release 里的 `sha256sums` 总表或 `<固件名>.sha256`（按固件名匹配哈希）；填值则强制校验该哈希 |
| `dl_workers` | `6` | 分片并发数 |
| `dl_chunk_mb` | `4` | 单分片大小（MB） |
| `dl_stall_sec` | `30` | 无进展判定超时（秒），超时后重试该分片 |
| `dl_retries` | `3` | 分片重试次数 |

> 上游默认配置里还有 `enabled`、`keep_config` 两项，本版本 Rust 与 `rpcd` 代码均未读取，因此预设不写入，避免出现「配了却不起作用」的假象。升级成功后配置由包内 `/lib/upgrade/keep.d/online-upgrade` 保留。

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

**Releases 只收录可直接刷写的完整固件镜像 + 配套的 SHA256 校验文件**：不再附带 `Config-*.txt`、`.manifest`、`kernel.bin`、`rootfs` 分片等辅助文件；`kernel` / `rootfs` 在打包阶段就被排除，X86 保留 `efi` / `combined` / `iso` / `vmdk` 等完整镜像。

每个 Release 附带两类校验资产，均由打包阶段**按重命名后的固件名重新生成**（OpenWrt 原生的 `sha256sums` 记录的是编译原始文件名，重命名后会失效，故不直接沿用）：

| 校验资产 | 用途 |
| :--- | :--- |
| `sha256sums` | 标准聚合表，下载后 `sha256sum -c sha256sums` 可人工核对全部固件；也是 `luci-app-online-upgrade` 的 `checksum_asset` 来源 |
| `<固件名>.sha256` | 每个固件一份单哈希文件，插件按 `{固件名}.sha256` 精确匹配；同组多机型 job 追加进同一 Release 时文件名唯一，不会被 `--clobber` 互相覆盖 |

> 同组同日多机型 job 共享同一个 Tag，标准 `sha256sums` 总表采用「下载已有表 → 按文件名去重合并 → 再上传」的方式尽量保留其它机型的条目；插件的自动校验以不会冲突的 `<固件名>.sha256` 为主路径，总表即使被覆盖也不影响在线升级。`firmware_pattern` 不匹配校验资产，插件不会把校验文件误当成固件下载。

固件文件名统一为 **`<机型>-<模组插件>-<编译日期>-<固件类型>.<扩展名>`**：

| 段 | 取值 | 说明 |
| :--- | :--- | :--- |
| 机型 | `H5000M` / `AP3000M` / `X86` | 由 `WRT_CONFIG` 首段推导 |
| 模组插件 | `NetWiz-MT5700` / `NetWiz-MT5700M` / `NetWiz-FM350` / `MT5700` / `MT5700M` / `FM350` / `SelfUse` / `BASE` | 全 ASCII；无变体时以 `BASE` 占位，保证所有变体结构一致 |
| 编译日期 | `YY.MM.DD`（`TZ=UTC-8`，如 `26.11.09`） | 与 Tag 的日期段同源（`WRT_DATE_SHORT`）；既是版本标识，也避免跨天同名互相覆盖 |
| 固件类型 | `sysupgrade` / `factory` / `initramfs` / `recovery` / `efi` / `combined` / `efi-iso` / `iso` / `efi-vmdk` / `vmdk` | 保留刷机方式判断所必需的信息 |

示例：`H5000M-MT5700-aarch64-26.11.09-sysupgrade.bin`、`AP3000M-NetWiz-FM350-aarch64-26.11.09-factory.bin`、`X86-NetWiz-MT5700-x86-64-26.11.09-efi.img.gz`、`H5000M-SelfUse-aarch64-26.11.09-sysupgrade.bin`。

`luci-app-online-upgrade` 的 `firmware_pattern` 与 `docs/index.html` 的产物解析均按此规范实现，详见 [`Scripts/OnlineUpgradePreset.sh`](Scripts/OnlineUpgradePreset.sh) 与 [`docs/index.html`](docs/index.html)。

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

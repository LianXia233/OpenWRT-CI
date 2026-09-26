<div align="center">

# 🚀 H5000M / AP3000M / X86_64 定制固件说明书

**基于 ImmortalWrt 深度定制 · 专为 5G CPE、Wi-Fi 路由器与软路由量身打造**

[![Source: VIKINGYFY](https://img.shields.io/badge/Source-VIKINGYFY%2Fimmortalwrt-blue?logo=openwrt&logoColor=white)](#)
[![Source: Master](https://img.shields.io/badge/Source-immortalwrt%2Fmaster-brightgreen?logo=openwrt&logoColor=white)](#)
[![Platform: Filogic](https://img.shields.io/badge/Platform-MediaTek%20Filogic-orange)](#)
[![Platform: x86_64](https://img.shields.io/badge/Platform-x86__64-informational)](#)
[![Workflow: CI](https://img.shields.io/badge/Build-GitHub%20Actions-success?logo=githubactions&logoColor=white)](#)

*适配 Hiveton H5000M 5G CPE（MT7986 + MT5700M）、AirPi AP3000M（MT7981B）与通用 X86_64 架构设备*

*每个机型除母配置外另有多个变体：**FM350 变体**（Fibocom FM350-GL 模组管理 `luci-app-fm350`）、**NetWiz 家族**（网络配置向导 `luci-app-netwiz`，含纯 NetWiz 及与 MT5700 / MT5700M / FM350 的组合变体，共 4 种 × 3 机型）*

---

</div>

## 📌 支持机型与底层架构

| 目标配置 | 硬件平台 / SoC | 适配机型 | 源码分支 | Wi-Fi 支持 | 镜像格式 |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `H5000M-WIFI-YES` | MediaTek Filogic (MT7986) | Hiveton H5000M 5G CPE | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ 开启 | Sysupgrade / Factory |
| `AP3000M` | MediaTek Filogic (MT7981B) | AirPi AP3000M | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ 开启 | Sysupgrade / Factory |
| `X86` | 标准 x86_64 处理器 | 通用 64 位 PC / 工控机 / 软路由 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) (`master`) | — | ISO / EFI / GRUB / VMDK |
| `H5000M-WIFI-YES-FM350` | MediaTek Filogic (MT7986) | Hiveton H5000M + Fibocom FM350-GL | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ 开启 | Sysupgrade / Factory |
| `AP3000M-FM350` | MediaTek Filogic (MT7981B) | AirPi AP3000M + Fibocom FM350-GL | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ 开启 | Sysupgrade / Factory |
| `X86-FM350` | 标准 x86_64 处理器 | 通用 64 位 PC / 工控机 + Fibocom FM350-GL | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) (`master`) | — | ISO / EFI / GRUB / VMDK |
| `H5000M-WIFI-YES-NETWIZ` | MediaTek Filogic (MT7986) | Hiveton H5000M + NetWiz 网络向导 | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ 开启 | Sysupgrade / Factory |
| `AP3000M-NETWIZ` | MediaTek Filogic (MT7981B) | AirPi AP3000M + NetWiz 网络向导 | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) (`owrt`) | ✅ 开启 | Sysupgrade / Factory |
| `X86-NETWIZ` | 标准 x86_64 处理器 | 通用 64 位 PC / 工控机 + NetWiz 网络向导 | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) (`master`) | — | ISO / EFI / GRUB / VMDK |
| `*-NETWIZ-MT5700` | 各机型同上 | NetWiz 向导 + MT5700 方案（MT 层由 `MT_MODE=MT5700` 驱动） | 同上（与各机型母配置一致） | ✅ 开启 | 同上 |
| `*-NETWIZ-MT5700M` | 各机型同上 | NetWiz 向导 + MT5700M 方案（含短信与 AT 守护） | 同上 | ✅ 开启 | 同上 |
| `*-NETWIZ-FM350` | 各机型同上 | NetWiz 向导 + FM350 模组管理 | 同上 | ✅ / — | 同上 |

> [!NOTE]
> **FM350 变体说明**：三份 `<机型>-FM350.txt` 均为**新增文件**，板级部分与母配置逐行一致，仅在末尾追加 `luci-app-fm350` 及其依赖；母配置未做任何改动。配置名保留机型前缀是硬性要求：`WRT-CORE.yml` 中 AP3000M 的 EEPROM 注入与 AirPi Rust 后端预编译两步靠 `contains(env.WRT_CONFIG, 'AP3000M')` 命中，改名会让它们静默失配（factory 分区为空 → mt76 起不来 → Wi-Fi 瘫痪）。

> [!NOTE]
> **NetWiz 变体说明**：NetWiz 家族共 4 种组合 × 3 机型 = 12 份配置，均为**新增文件**，板级部分与母配置逐行一致：
> - `*-NETWIZ`：板级 + `luci-app-netwiz` 及其依赖；`MT_MODE` 留空，产物归组 `NetWiz`。
> - `*-NETWIZ-MT5700` / `*-NETWIZ-MT5700M`：板级 + NetWiz 段，**MT 插件层刻意不写在配置里** —— `ApplyMTMode.sh` 在空模式时会显式禁用全部 MT 包，`Packages.sh` 的 `FOLD_MT5700M`（MT5700M 的 Rust 后端折叠）也必须由 `MT_MODE=MT5700M` 驱动，因此 MT 选择必须走独立配置层：定时工作流矩阵已绑定对应 `MT_MODE`，手动触发时须把 MT Mode 下拉同步选对（错配会被校验步骤拦截），归组 `NetWiz-MT5700` / `NetWiz-MT5700M`。
> - `*-NETWIZ-FM350`：板级 + NetWiz 段 + FM350 段；WRT-CORE 的导入/校验步骤按 `contains` 子串命中，NETWIZ 与 FM350 两个分支同时生效，`MT_MODE` 留空，归组 `NetWiz-FM350`。
>
> 母配置、FM350 变体均未做任何改动。配置名保留机型前缀（`AP3000M` 的 EEPROM 注入等按 `contains` 命中）。

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

### 4. Fibocom FM350-GL 模组管理 (`luci-app-fm350`)
*（仅编入 `<机型>-FM350` 变体）*

- 📡 **状态与拨号**：LuCI 界面呈现驻留频段、信号质量与连接状态，支持 APN 配置、连接与断开、拨号管理。
- 🔧 **在线 AT 与锁频**：后端守护 `fm350d` 独占 AT 端口，可下发 AT 指令，支持锁频段与锁小区。
- 📨 **短信收发**：网页端直接查收与发送短信，便于读取流量卡余额与验证码。
- ⚙️ **Rust 后端**：守护进程为 Rust 编写，编译期由 cargo 交叉编译为 musl 静态二进制（`/usr/sbin/fm350d`），不走 OpenWrt 的 `rust/host` 源码构建，构建耗时可控。

> [!NOTE]
> FM350 走 **RNDIS** 数据通道，与 MT5700M 方案的 QMI vendor 驱动（`kmod-qmi_wwan_f` / `kmod-qmi_wwan_q`）不争抢同名 `.ko`，两者无 rootfs 文件冲突。FM350 变体的 `MT_MODE` 一律留空（不装 MT 插件）。

### 5. NetWiz 网络配置向导 (`luci-app-netwiz`)
*（仅编入 `<机型>-NETWIZ` 变体）*

- 🧭 **向导式网络配置**：把「上网方式选择 → 参数填写 → 生效验证」串成一条引导流程，降低初次配置门槛。
- 🛡️ **非破坏性改动**：向导只按需追加/修改自身所需配置项，不改动既有网络结构，回退成本低。
- 🔁 **三层守护**：内置 `netwiz-monitor`（状态巡检）、`netwiz-recovery`（异常自愈）、`netwiz-watchdog`（独立看门狗）三个 procd 服务，另有 DHCP 热插拔守卫 `99-netwiz-guard` 在上游 DHCP 事件时介入。
- 💾 **离线安装保险箱**：支持预置 `/etc/netwiz/custom_pkgs/*.[ia]pk`，断网环境下也能补齐依赖；自愈流程会主动剔除 `firewall-*` / `dnsmasq-*` / `wpad-*` / `base-files-*` / `libc-*` 等基础组件，避免误伤系统。

> [!IMPORTANT]
> **NetWiz 包的行尾处理**：上游仓库 `huchd0/luci-app-netwiz` 提交的 20 个文件（含 `Makefile`、全部 init.d 服务、rpcd 插件、`menu.d`/`acl.d` JSON）均为 **CRLF**。`Scripts/Packages-NetWiz.sh` 在拉取后强制 `CRLF → LF` 归一化并逐文件复核，原因：`Makefile` 的 `\r` 会让 `include $(TOPDIR)/feeds/luci/luci.mk` 路径带脏字符导致编不过；`init.d` 脚本 shebang 变成 `#!/bin/sh /etc/rc.common\r` 会让 procd 启动失败；JSON 中的 `\r` 属非法空白，表现为「装上了但界面里找不到入口」。
>
> 注意 `WRT-CORE.yml` 中既有的「脚本格式规整（CRLF → LF）」步骤**管不到**这里：它只覆盖 OpenWrt 源码树顶层三级的 `txt/sh`，且执行时机早于取包步骤。故归一化必须在取包脚本内部完成。
>
> 该包 `LUCI_PKGARCH:=all`（纯脚本架构），生成的 ipk/apk 与 CPU 架构无关，三个机型共用同一份包；同时它 `include` LuCI feed 的 `luci.mk`，因此必须晚于 `feeds update -a`、早于 `make defconfig` 就位，位置在 `WRT-CORE.yml` 中已固定并加了 `luci.mk` 可用性预检。

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
> 3. **驱动归属显式化**：`Config/MT5700M.txt` 直接写出 QModem 侧 `kmod-qmi_wwan_f` / `kmod-qmi_wwan_q` 的 `=y`，不再依赖「上游 qmodem 主包的隐式默认值会顺带把它们拉进来」。上游 2026-09-19 调整 luci 打包后该隐式路径失效，MT5700M 变体因此在 `Verify MT Mode` 阶段全灭（见 CHANGELOG 2026-09-20）。显式选中后，上游再改打包也不会让 MT5700M 停摆。

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
| **`FM350-AUTO`** | 每日定时 (随 Auto-Clean) / 手动 | 一份 workflow 覆盖全部机型的 **FM350 变体**（H5000M / AP3000M / X86）并自动发版 |
| **`NetWiz-AUTO`** | 每日定时 (随 Auto-Clean) / 手动 | 一份 workflow 覆盖全部机型的 **NetWiz 变体**（H5000M / AP3000M / X86）并自动发版 |
| **`Auto-Clean`** | 每日定时调度 / 手动 | 保持仓库整洁：保留最近 1 个 Release 及 30 天以内的构建日志 |
| **`Cache-Clean`** | 手动触发 | 主动清理 actions/cache 编译缓存（不设定时清空，避免缓存频繁冷启动） |

### 2. 手动编译快速指引

1. 进入仓库页面，点击 **`Actions`** 选项卡。
2. 在左侧列表选择 **`WRT-BUILD`**，点击右侧 **`Run workflow`**。
3. 按需选择：
   - **Target Device**：母配置 3 项 / FM350 变体 3 项 / NetWiz 家族 12 项（`*-NETWIZ` 及 `-NETWIZ-MT5700` / `-NETWIZ-MT5700M` / `-NETWIZ-FM350` 组合），共 18 项
   - **MT Mode**：`MT5700M` / `MT5700` / `NONE`（选 `*-NETWIZ-MT5700` / `*-NETWIZ-MT5700M` 配置时**必须**同步选对应 MT 模式，否则校验拦截；其余配置保持 `NONE`）
   - **TEST**：若要正式输出固件，**务必将 `TEST` 改为 `false`**（设为 `true` 仅导出校验用 `.config`）。

### 3. 产物命名与 Release 规范

**Release 按变体归组**：Tag 格式为 `<组名>-<YY.MM.DD>`（天级），同组同一天内全部机型的产物汇聚到**同一个 Release**，Releases 页面天然按类别归类：

| Release（Tag 示例） | 包含内容 |
| :--- | :--- |
| `MT5700-26.09.26` | 当天全部机型的 MT5700 模式固件 |
| `MT5700M-26.09.26` | 当天全部机型的 MT5700M 模式固件 |
| `FM350-26.09.26` | 当天全部机型的 FM350 变体固件 |
| `NetWiz-26.09.26` | 当天全部机型的纯 NetWiz 固件 |
| `NetWiz-MT5700-26.09.26` | 当天全部机型的 NetWiz + MT5700 组合固件 |
| `NetWiz-MT5700M-26.09.26` | 当天全部机型的 NetWiz + MT5700M 组合固件 |
| `NetWiz-FM350-26.09.26` | 当天全部机型的 NetWiz + FM350 组合固件 |
| `BASE-26.09.26` | 当天手动编译的无变体、无 MT 模式固件 |

> [!NOTE]
> **归组机制**：`WRT-CORE.yml` 在「初始化构建变量」时按 `WRT_VARIANT`（FM350 / NetWiz）优先、其次 `MT_MODE`（MT5700 / MT5700M）、兜底 `BASE` 推导组名，Tag 只含天级日期 —— 三个机型的定时 job 由同一次 Auto-Clean 触发、同一天内执行，天级时间戳必然一致，因此跨 workflow 也能共享同一 Tag；`action-gh-release` 对已存在的 Tag 会把产物追加进既有 Release 而非另开新页。
>
> **Auto-Clean 兼容**：`keep_latest_per_device` 的归组键解析同时兼容旧格式 `<配置>-<MT模式>-<源码>-<分支>-<日期时间>`（按机型保留）与新格式 `<组名>-<日期>`（按变体保留），历史 Release 不会被误删。

**固件文件名**（含秒级时间戳，同组内可区分不同批次的构建）：

```text
# 固件文件名规范示例（变体标签追加在日期之后）
immortalwrt-mediatek-filogic-hiveton_h5000m-MT5700-wifi-yes-26.09.13-sysupgrade.bin
immortalwrt-mediatek-filogic-hiveton_h5000m-MT5700M-wifi-yes-26.09.13-sysupgrade.bin
...-hiveton_h5000m-NONE-wifi-yes-26.09.23-FM350-sysupgrade.bin
...-hiveton_h5000m-NONE-wifi-yes-26.09.26-NetWiz-sysupgrade.bin
```

> [!TIP]
> **为什么要加变体后缀**：固件文件名由镜像原名拼出，**不含机型配置名**，普通版、FM350 版与 NetWiz 版的文件名会完全一样，下载到本地后无法区分。因此在 `WRT-CORE.yml` 增加可选入参 `WRT_VARIANT`：FM350 变体传 `FM350`，NetWiz 变体传 `NetWiz`，追加到文件名末尾；现有机型不传该参数，产物名逐字节不变。
>
> **为什么产物标签大小写不同**：配置名（`Config/*.txt` 与下拉项）统一用全大写 `NETWIZ`，与既有 `FM350` 风格一致；而产物标签用驼峰 `NetWiz`，因为它会直接出现在用户下载到的固件文件名里，可读性更好。两者在 `WRT-BUILD.yml` 中通过独立的 `endsWith` 三元链各自映射，互不干扰。

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
│   ├── FM350-AUTO.yml        # FM350 变体统一入口（覆盖全部机型）
│   ├── NetWiz-AUTO.yml       # NetWiz 变体统一入口（覆盖全部机型）
│   ├── Auto-Clean.yml        # 自动化历史制品与任务日志清理
│   └── Cache-Clean.yml       # 手动编译缓存回收
├── Config/                   # 模块化编译配置文件层
│   ├── GENERAL.txt           # 全设备通用内核参数与功能插件（不含 MT 驱动）
│   ├── MT5700.txt            # MT5700 方案独立包配置（方案 B）
│   ├── MT5700M.txt           # MT5700M 方案独立包配置（方案 A）
│   ├── H5000M-WIFI-YES.txt   # Hiveton H5000M 专属硬件板级定义
│   ├── AP3000M.txt           # AirPi AP3000M 专属硬件板级定义
│   ├── X86.txt               # X86_64 架构板级定义
│   ├── H5000M-WIFI-YES-FM350.txt # H5000M 板级定义 + luci-app-fm350
│   ├── AP3000M-FM350.txt     # AP3000M 板级定义 + luci-app-fm350
│   ├── X86-FM350.txt         # X86_64 板级定义 + luci-app-fm350
│   ├── H5000M-WIFI-YES-NETWIZ.txt # H5000M 板级定义 + luci-app-netwiz
│   ├── AP3000M-NETWIZ.txt    # AP3000M 板级定义 + luci-app-netwiz
│   ├── X86-NETWIZ.txt        # X86_64 板级定义 + luci-app-netwiz
│   ├── *-NETWIZ-MT5700.txt   # 各机型板级 + netwiz（MT 层由 MT_MODE=MT5700 驱动）
│   ├── *-NETWIZ-MT5700M.txt  # 各机型板级 + netwiz（MT 层由 MT_MODE=MT5700M 驱动）
│   └── *-NETWIZ-FM350.txt    # 各机型板级 + netwiz + fm350
├── AP3000M-EEPROM/           # AP3000M 自动化射频恢复套件
│   ├── mt7981_eeprom_mt7976_dbdc.bin # 提取自闭源固件的标准校准 EEPROM
│   └── 99-ap3000m-eeprom     # 首次启动写入 factory 分区的初始化脚本
├── Scripts/                  # 编译流水线钩子脚本
│   ├── Packages.sh           # 第三方 Feed 拉取与版本锁定
│   ├── Packages-FM350.sh     # FM350 变体专用：拉取 luci-app-fm350 源码
│   ├── Packages-NetWiz.sh    # NetWiz 变体专用：拉取 luci-app-netwiz 源码 + CRLF 归一化
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
* [luci-app-fm350](https://github.com/LianXia233/luci-app-fm350)（Fibocom FM350-GL 模组管理，LuCI 界面 + Rust 后端）
* [luci-app-netwiz](https://github.com/huchd0/luci-app-netwiz)（NetWiz 网络配置向导，向导式上网配置 + 三层自愈守护）

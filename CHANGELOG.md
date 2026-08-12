# 更新日志

本仓库的所有重要变更都会记录在此文件中。

## [2026-08-12]

### 修复

- **修复默认无线密码和时区不生效问题**（`Scripts/Settings.sh`）：默认无线加密设为 WPA-PSK/WPA2-PSK Mixed Mode、地区 CN、2.4G 频宽 40MHz、5G 频宽 160MHz，并在 `config_generate` 中强制写入 `timezone='CST-8'` + `zonename='Asia/Shanghai'` 确保时区生效。同时兼容旧式 `set-wireless.sh` 和新型 `mac80211.uc` 两套无线默认配置路径。
- **HomeProxy ucode 兼容性修复**：ImmortalWrt master 已移除 `luci.sys.init_action` 且 ucode 不含 `math` 模块，导致订阅更新与客户端配置生成失败（sing-box 无法启动，页面报 "URLTest: 无效节点"）。在 `Scripts/Handles.sh` 中加入自动覆盖修复，CI 构建时替换上游的两个脚本：
  - `update_subscriptions.uc`：移除 `import { init_action } from 'luci.sys'`，将 `init_action('homeproxy', 'restart')` 替换为 `system('/etc/init.d/homeproxy restart >/dev/null 2>&1')`，修复订阅拉取后无法更新节点列表的问题。
  - `generate_client.uc`：移除 `import { isnan } from 'math'`，将 `isnan(int(i))` 替换为 `type(int(i)) === 'double'`（ucode 中 `int("abc")` 返回 double 类型 `NaN`），修复 sing-box 客户端配置生成失败导致服务无法启动的问题。
  - 修复脚本存放于 `Scripts/homeproxy/`，不包含节点信息。
- **修复 OWRT-ALL / X86 编译失败（Run #31556891052）**：`Compile Firmware` 步骤报错 `exit code 2`。根因为 `kmod-nft-fullcone`（fullconenat，`llccd/netfilter-full-cone-nat`）为树外内核模块、直接补丁 nftables 核心，其源码停留在 `PKG_SOURCE_DATE=2023-01-01`，未适配 immortalwrt master 内核 **6.18.41**，导致内核模块编译失败（`make download` 已成功，故为编译期而非下载期错误）。在 `Config/GENERAL.txt` 中暂时禁用 `CONFIG_PACKAGE_kmod-nft-fullcone`（全机型通用配置），待上游提供 6.18 兼容版本后取消注释即可恢复 Fullcone NAT 支持。

### 变更（临时禁用）

- **暂时禁用 Honk 插件**：按需求临时关闭，未删除任何逻辑，可一键恢复。
  - `Scripts/Packages.sh`：将 `INSTALL_HONK_PREBUILT` 调用注释（函数体保留）。
  - `Config/GENERAL.txt`：将 Honk 运行时依赖（`ca-bundle`/`jq`/`nsenter`/`tc-full`/`v2ray-geoip`/`v2ray-geosite`/`kmod-sched-core`/`kmod-sched-bpf`）与 `CONFIG_KERNEL_DEBUG_INFO_BTF=y` 全部注释。
  - 恢复方法：取消 `Packages.sh` 中 `INSTALL_HONK_PREBUILT` 的注释，并取消 `GENERAL.txt` 中上述 `CONFIG_*` 行的注释即可。

## [2026-08-11]

### 新增

- **全机型集成 Honk eBPF 透明代理插件**（[breeze303/openwrt-honk](https://github.com/breeze303/openwrt-honk)，`main` 分支），默认启用，覆盖全部编译机型（X86 / AP3000M / H5000M-WIFI-YES，均为 x86_64 / aarch64，满足插件平台要求）：
  - `Scripts/Packages.sh`：新增 `UPDATE_PACKAGE "honk"`，以 `pkg` 模式从上游仓库提取 `honk`、`luci-app-honk`、`luci-app-honk-legacy` 三个软件包（自动跳过 docs/locks/tests 等非包目录）。
  - `Config/GENERAL.txt`：默认启用 `CONFIG_PACKAGE_honk=y` 与 `CONFIG_PACKAGE_luci-app-honk=y`（新版 LuCI 管理界面；旧版 `luci-app-honk-legacy` 作为回滚备用，默认不编译进固件）。

### 依赖处理

- **运行时依赖**（`Config/GENERAL.txt` 显式启用）：`ca-bundle`、`jq`、`nsenter`、`tc-full`、`v2ray-geoip`、`v2ray-geosite`、`kmod-sched-core`、`kmod-sched-bpf`；`ip-full`、`kmod-veth`、`curl`、`luci-base`、`luci-compat` 此前已在通用配置中启用。`libstdcpp` 等由软件包 `DEPENDS` 自动解析。
- **内核依赖**：显式启用 `CONFIG_KERNEL_DEBUG_INFO_BTF=y`，满足 eBPF 程序的 BTF 需求（BPF/BPF_JIT/CGROUP_BPF/NET_CLS_BPF 等由 `kmod-sched-bpf` 等内核模块依赖自动带出）。
- **主机编译依赖**（`Scripts/Packages.sh` 新增 `INSTALL_HONK_DEPS`，在 Custom Packages 阶段自动执行）：
  - 系统组件：`clang`、`llvm`、`libbpf-dev`、`libclang-dev`、`pkg-config`、`cmake`、`zstd`（bindgen 与 eBPF 编译所需）；
  - Rust 工具链：通过 rustup 安装上游锁定的 `nightly-2026-07-20`（含 `rust-src` 组件，用于 `-Zbuild-std=core` 编译 `bpfel-unknown-none` 目标）；
  - eBPF 链接器：安装 `bpf-linker 0.10.4`（下载后执行 SHA-256 校验，校验失败立即中断，避免引入被篡改的工具链），并写入 `GITHUB_PATH` 保证后续编译步骤可用。
### 修复（构建超时）

- **修复 MTK-AUTO 构建被 GitHub 6 小时上限取消的问题（Run #31472548184）**：MTK-AUTO 构建 `08:17` 开始，`14:17`（正好 6 小时）被 GitHub 强制取消，日志中无编译报错（仅 Kconfig `recursive dependency` 警告与已成功的依赖安装步骤），取消时 cargo/rustc 正在编译 honk。根因为 honk 为 Rust/eBPF 架构，从源码编译极重，使总耗时超过 GitHub 标准 runner 的单 job 6 小时硬上限。
- **honk 改为上游预编译 APK 注入**（不再从源码编译）：
  - `Scripts/Packages.sh`：移除 `UPDATE_PACKAGE "honk"` 与 `INSTALL_HONK_DEPS`（主机 Rust/eBPF 工具链），新增 `INSTALL_HONK_PREBUILT()`——按目标架构从上游最新 release 下载 `honk` 与 `luci-app-honk` 的 `openwrt-25.12` APK（与 `immortalwrt/immortalwrt@master` 默认 `USE_APK=y` 匹配），放入固件 `files/etc/honk/`，并写入 `files/etc/uci-defaults/99-honk-install`，在设备**首次开机时离线 `apk add --allow-untrusted`** 安装（依赖由 `GENERAL.txt` 编入镜像，无需联网）：
    - 架构映射（优先用 `WRT_TARGET`，回退 `WRT_CONFIG`）：`x86`→`x86_64`；**`mediatek`→`aarch64_cortex-a53`**（MT798x / MT7622 等 MTK 机型专用，Cortex-A53 架构）；其余→`aarch64_generic`。
  - `Config/GENERAL.txt`：移除 `CONFIG_PACKAGE_honk=y` / `CONFIG_PACKAGE_luci-app-honk=y`（APK 构建中无对应源码符号，会被 defconfig 丢弃），保留全部运行时依赖（`ca-bundle`/`jq`/`nsenter`/`tc-full`/`v2ray-geoip`/`v2ray-geosite`/`kmod-sched-*`）与 `CONFIG_KERNEL_DEBUG_INFO_BTF=y`。

### 修复
- **修复 honk 包编译失败（Run #33）**：AP3000M / H5000M-WIFI-YES 两个机型均在 `Compile Firmware` 阶段报错 `cp: cannot overwrite non-directory '.../root-mediatek/./var' with directory '.../.pkgdir/honk/./var'`。
  - 根因：honk 上游 `Makefile` 的 `Package/honk/install` 中执行 `$(INSTALL_DIR) $(1)/var/share/honk`，在 pkgdir 下创建了 `var/` 目录；而 OpenWrt rootfs 中 `/var` 是指向 `/tmp` 的符号链接，构建系统复制 pkgdir 到 rootfs 时 `cp` 无法用目录覆盖符号链接。
  - 修复（`Scripts/Handles.sh` 新增 honk 修复段）：在 Custom Packages 阶段自动移除 honk `Makefile` 中 `/var/share/honk` 的创建与 `chmod 0700`；运行时数据目录由 `honk.init` 的 `prepare_subscription_store()` 在启动时通过 `mkdir -p` 自动创建，不影响功能。

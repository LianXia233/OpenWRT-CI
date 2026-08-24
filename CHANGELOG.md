# 更新日志

本仓库的所有重要变更都会记录在此文件中。

## [2026-08-24]

### 新增

- **MT7987 WED V3.1 硬件路径支持（内核 6.18）**（commit `d1d718d`）：将 MT7987 WED（Wireless Ethernet Dispatch）V3.1 硬件路径支持补丁移植到 6.18 内核 API 并注入 CI 构建流程，解决 MT7987 平台因设备树（DTS）缺少 `wo-ccif` 节点导致内核报 `failed to attach wed device`、无线硬件加速不可用的问题。
  - `999-mtk7987-wed-v31.patch`：内核侧补丁（6329 行），将 WED V3.1 硬件路径支持适配至 6.18 内核 API。
  - `998-mt76-wed-hwrro-enum.patch`：mt76 驱动侧 `WED_HWRRO` 枚举修正，与内核补丁配套。
  - `Scripts/Handles.sh`：新增注入段，将上述补丁在构建时自动拷入对应源码目录并应用。

### 修复

- **修复 MTK-AUTO 编译失败（Run #32730137693）**：首次推送的 `999-mtk7987-wed-v31.patch` 基于无提交记录的本地基线生成，被 git 当作 **new-file 格式**（整个文件为新增行），而 OpenWrt 构建时目标文件已存在，导致补丁应用全部 hunk 失败，`Compile Firmware` 阶段中断。
  - 根因：补丁基线（`wed618` 临时目录）从未建立 git 基线提交，`git diff` 输出为全新增文件；且 Windows 侧 CRLF 污染曾使 diff 整文件漂移。
  - 修复（commit `313909a` 后追加提交）：重新以 **6.18.44 官方内核源文件 + immortalwrt patches-6.18（940/942/943/944）** 建立真实基线（`wedreal`），基于该基线重新生成补丁（1825 行，778 增 / 259 删，与原厂补丁规模一致），在本地 `git apply --check` 验证通过；同时修正 `998-mt76-wed-hwrro-enum.patch` 的 hunk 行数错误并对照 CI 实际使用的 mt76 commit（`5967691`）验证可应用。补丁统一为 LF、标准 `diff --git` 格式。

- **修复 MTK-AUTO 编译失败（Run #32737139044）：** 修复提交 `9069348` 后 `999-mtk7987-wed-v31.patch` 在 `Compile Firmware` 阶段 `mtk_wed.c` 编译失败，报错 `struct <anonymous> has no member named 'wed_rev_id'` 及 `MTK_WED_REV_ID_MAJOR/MINOR undeclared`。
  - 根因：移植 6.18 的补丁只合并了联发科 `999-wed-10-add-mt7987-hwpath-support.patch` 的核心逻辑，但漏掉同系列 `999-wed-08-extended-wed-debugfs.patch` 中配套的定义：`struct mtk_wed_soc_data` regmap 缺 `u32 wed_rev_id;` 成员、`mtk_wed_regs.h` 缺 `MTK_WED_REV_ID_MAJOR (GENMASK(31,28))` / `MTK_WED_REV_ID_MINOR (GENMASK(27,16))` 宏。
  - 修复：在 6.18.44 基线（wedreal）上补齐上述定义，并为 mt7622/mt7986/mt7988 的 `soc_data.regmap` 补上 `.wed_rev_id` 初始化（与联发科 6.12 一致：0 / 0x4 / 0x4）；重新生成补丁（1855 行，784 增 / 259 删），本地 `git apply --check` 验证通过。

## [2026-08-18]

### 修复

- **修复 OWRT-ALL / X86 编译失败（Run #32071207860）**：`Compile Firmware` 阶段报错 `bash: line 1: ./hack/make.sh: No such file or directory`，`make[3]: *** [Makefile:168: .../dockerd-29.6.1/.built] Error 127`，`ERROR: package/feeds/packages/dockerd failed to build.`。
  - 根因：`Scripts/Handles.sh` 中 Python 注入 `fix-binary-daemon.sh` 调用时，替换出的行**未保留 Makefile 的 `\` 续行符**，把原本连续的 recipe 拆成两条独立 shell 命令——`cd $(PKG_BUILD_DIR); ... . fix-binary-daemon.sh ...` 在源码目录执行并成功打补丁，但 `./hack/make.sh binary` 退化为独立 recipe 行，在**包目录**（`feeds/packages/utils/dockerd`）执行，该目录下不存在 `hack/make.sh`，故报 Error 127。
  - 修复（`Scripts/Handles.sh`）：注入行改为 `cd $(PKG_BUILD_DIR) && . "$(CURDIR)/fix-binary-daemon.sh" "$(PKG_BUILD_DIR)" && \` 以 `&& \` 续行符结尾，确保 `cd`、补丁脚本、`./hack/make.sh binary` 在同一条 make recipe（同一 shell、同一工作目录）中顺序执行。已用上游 `openwrt/packages` 的 dockerd Makefile 本地模拟验证注入结果正确。

### 变更

- **默认 Wi-Fi SSID 回退为 `OWRT`**：`OWRT-ALL.yml` / `MTK-AUTO.yml` / `WRT-BUILD.yml` 三个工作流的 `WRT_SSID` 环境变量由 `OWRT_2.4G` 回退为默认值 `OWRT`（2.4G 与 5G 频段默认 SSID 一致，由 `Scripts/Settings.sh` 在编译时写入）。默认密码仍为 `12345678`，加密方式 WPA-PSK/WPA2-PSK Mixed Mode、国家码 `CN` 等保持不变。同步更新 `README.md`「默认配置」小节中的 SSID 记录。

## [2026-08-15]

### 修复

- **修复 OWRT-ALL / X86 编译失败（Run #31842487773）**：`Compile Firmware` 阶段报错 `make[3]: *** [Makefile:166: .../dockerd-29.6.1/.built] Error 1`（失败 job：94902144731，SOURCE=immortalwrt/immortalwrt）。根因为 `dockerd 29.6.1` 的 moby 构建脚本 `hack/make/binary-daemon` 中 `copy_binaries()`：当 CI runner 预装 Docker（存在 `/usr/local/bin/runc`）且目标架构与宿主一致（linux/amd64）时，会尝试从宿主 PATH 拷贝 `containerd`/`runc`/`rootlesskit`/`dockerd-rootless.sh` 等“嵌套可执行文件”；但 GitHub Actions runner 上这些并不在 PATH，`command -v` 返回空串导致 `cp -f ""` 报错，配合脚本 `set -e` 直接中断编译。这些二进制本就由独立的 OpenWrt 包在运行时提供，无需打入 dockerd bundle。
  - 为何原有补丁未生效：仓库既有 `Scripts/patches/dockerd/999-fix-nested-binaries.patch` 内容正确（同样将拷贝改为条件拷贝），但本次构建日志中**没有出现任何 `patching file hack/make/binary-daemon` 输出**，说明 OpenWrt 未触发对该文件应用补丁，故仅依赖补丁机制不可靠。
  - 修复（双保险，绕过补丁机制）：
    - 保留 `999-fix-nested-binaries.patch` 拷入 `feeds/.../dockerd/patches/`（OpenWrt 标准机制，能用时生效）；
    - 新增 `Scripts/patches/dockerd/fix-binary-daemon.sh`：在 dockerd 源码解包后、编译前对 `hack/make/binary-daemon` 做就地 sed 修正，将 `cp -f "$(command -v "$file")" "$dir/"` 改为「仅当该文件存在于 PATH 时才拷贝，缺失则跳过」（`bin="$(command -v "$file" 2>/dev/null || true)"; [ -n "$bin" ] && cp -f "$bin" "$dir/"`）。
    - 修改 `Scripts/Handles.sh` dockerd 段（约 300–368 行）：把补丁与修正脚本一同拷入 dockerd 包目录并 `chmod +x`，再用 Python 在 dockerd `Makefile` 的 `Build/Compile` 中、`./hack/make.sh binary` 之前注入 `bash "$(CURDIR)/fix-binary-daemon.sh" "$(PKG_BUILD_DIR)"; \`（幂等，已注入则跳过）；`find` 同时覆盖拷贝安装与软链安装两种 feeds 路径。

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

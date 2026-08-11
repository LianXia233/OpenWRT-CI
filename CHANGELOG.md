# 更新日志

本仓库的所有重要变更都会记录在此文件中。

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
### 修复
- **修复 honk 包编译失败（Run #33）**：AP3000M / H5000M-WIFI-YES 两个机型均在 `Compile Firmware` 阶段报错 `cp: cannot overwrite non-directory '.../root-mediatek/./var' with directory '.../.pkgdir/honk/./var'`。
  - 根因：honk 上游 `Makefile` 的 `Package/honk/install` 中执行 `$(INSTALL_DIR) $(1)/var/share/honk`，在 pkgdir 下创建了 `var/` 目录；而 OpenWrt rootfs 中 `/var` 是指向 `/tmp` 的符号链接，构建系统复制 pkgdir 到 rootfs 时 `cp` 无法用目录覆盖符号链接。
  - 修复（`Scripts/Handles.sh` 新增 honk 修复段）：在 Custom Packages 阶段自动移除 honk `Makefile` 中 `/var/share/honk` 的创建与 `chmod 0700`；运行时数据目录由 `honk.init` 的 `prepare_subscription_store()` 在启动时通过 `mkdir -p` 自动创建，不影响功能。

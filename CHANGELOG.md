# 更新日志
## [2026-08-31] 编译提速：缓存重构、并行重试与 Rust 预编译（PR #5）

### 优化（编译提速）

- **基线实测：上一次 `H5000M-AUTO`（Run #33341410294）总耗时 225.9 分钟，其中 `Compile Firmware` 独占 211.8 分钟，四个缓存检查步骤（`Toolchain` / `Ccache` / `Feeds` / `Download`）耗时全部为 0.0 分钟——即一次零缓存冷编译。** 这说明 08-28 / 08-29 两轮引入的缓存体系当时并未生效，本次针对其失效原因逐项修整。
- **① 停止每周定时清空缓存（本次最大收益项）**：`Cache-Clean.yml` 原 `schedule: 0 20 * * 0` 每周一 04:00（CST）执行 `gh cache delete --all`，之后第一次构建必然全量重编。证据：当时仓库 8 条缓存全部创建于 08-31（即清理动作之后），而 211.8 分钟的那次构建正好在清理之后启动。现改为**仅保留 `workflow_dispatch` 手动触发**——GitHub 会按 LRU 自动回收超配额缓存，定时全量清空只会人为制造每周一次的冷启动。
- **② 工具链与 ccache 合并为一份缓存，并加 `save-always: true`**：原 4 个缓存步骤均无 `save-always`，编译失败 / 超时 / 被取消时 post 保存会被整段跳过，陷入「超时 → 无缓存 → 再超时」死循环（08-29 有两次 `WRT-BUILD` 失败、一次 345 分钟被取消）。工具链（含最耗时的 host tools）在头 1~2 小时就已编好，现在即使后续失败也会保存，下次可直接续用。
- **③ 缓存键由 `WRT_CONFIG` 改为 `WRT_TARGET`，path 收窄为 `host*` / `tool*`**：
  - 键改为按目标平台共享后，`H5000M` 与 `AP3000M` 同为 `mediatek/filogic`，可共用同一份工具链，不再每天各白编一次。
  - path 由整个 `staging_dir/` 收窄为 `staging_dir/host*` + `staging_dir/tool*`（含 `.ccache`）。这是**对 08-28 改动的回退**：`make clean` 对应 Makefile 中的 `_clean: FORCE` → `rm -rf $(BUILD_DIR) $(STAGING_DIR) $(BIN_DIR) ...`，而 `rules.mk` 里 `STAGING_DIR:=$(TOPDIR)/staging_dir/$(TARGET_DIR_NAME)`，即 `staging_dir/target-*` 在缓存上传前就注定被删——打包它纯属浪费带宽，且内容随配置漂移，会污染共享给另一机型的缓存。
- **④ `dl` 缓存键去掉机型维度，按「源码 + 分支」共享**：下载的源码包与机型无关，原 key 带 `WRT_CONFIG` 导致 `H5000M` / `X86` 各存一份 2.1GB；`AP3000M` 一旦日常启用就是 3 × 2.1GB ≈ 6.3GB，叠加每机型一份工具链与 ccache 后必然突破 GitHub 约 10GB 上限，触发 LRU **连锁淘汰**——这比定时清空更隐蔽，会让所有缓存一起失效。
- **⑤ 删除 `feeds` 缓存（对 08-29 改动的回退）**：实测 `feeds update -a` 仅需约 1.0 分钟，而缓存体积 51.9MB 且 key 绑定 `WRT_HASH` 几乎必然 miss。为其付出的两次上传 / 下载开销大于收益，属净亏损，故移除。
- **⑥ 编译失败重试保持并行**：原 `make -j$(nproc) || make -j1 V=s` 一旦偶发失败就把几小时的编译从 4 线程降到 1 线程，几乎必然拖过 6 小时上限被取消。现改为重试仍用 `-j$(nproc) V=s`，输出写入 `build.log`，失败时提取首个出错包并以 `::error::` 注解上报（可经 check-runs API 直接读取，无需下载原始日志）。
- **⑦ 新增 AP3000M 的 `airpi-fanctl` Rust 预编译步骤**：`Config/AP3000M.txt` 中的 `luci-app-airpi-fancontrol` 带 `PKG_BUILD_DEPENDS:=rust/host`，OpenWrt 会从源码构建整套 rustc + cargo + LLVM，约 1.5~3 小时。现用 runner 自带的 rustup 配合已构建好的 aarch64 musl 交叉链接器直接 `cargo build`，再通过 `AIRPI_PREBUILT=1` / `AIRPI_PREBUILT_BIN` 交给包 Makefile（新增 `Scripts/inject_airpi_prebuilt.py` 负责注入）。上游 `LianXia233/luci-app-airpi3000m-fancontrol` 的 Makefile 已原生支持该分支；预编译失败会自动回退到源码构建，不影响出包。
- **⑧ 其他**：job 增加 `timeout-minutes: 345`，避免撞上平台 6 小时硬上限被强杀（强杀时 runner 直接终止，缓存 post 保存同样会被跳过）；`apt` 初始化去掉 `full-upgrade` 与 `autoremove --purge`（托管 runner 每次全量升级要数分钟，对编译零收益）；移除 runner 预置的 google-chrome apt 源（其镜像偶发哈希不一致会让 `apt update` 返回非零并中断初始化）；`make download -j$(nproc)` 仅在失败时才做串行兜底，不再每轮跑两遍全量校验；显式 `echo "CONFIG_CCACHE=y" >> .config` 并在编译步骤 export `CCACHE_DIR` / `CCACHE_MAXSIZE=5G` / `CCACHE_COMPRESS=true`（上限由 08-29 设定的 2G 放宽到 5G，在 10GB 总配额内换取更高命中率）。

### 预期效果

参照 `LianXia233/H5000M-CI-Qmodem` 在同源码（`immortalwrt master db5c5de`）、同 4 vCPU 标准 runner 下的实测：`MTK-AUTO` 99.4 / 102.0 分钟，`OWRT-ALL` 44.3 / 45.6 分钟。

- `H5000M` 稳态（缓存命中）：约 212 分钟 → **25~45 分钟**
- `AP3000M` 稳态：约 230 分钟 → **40~70 分钟**（Rust 预编译单独省 90~180 分钟）
- `X86` 稳态：约 150 分钟 → **20~35 分钟**
- 冷启动（首次 / 上游大版本）：仍是约 212 分钟，不可避免
- 每周冷启动次数：≥1 次 → **0 次**

整体降幅约 **70%~85%**。

### 注意

- **缓存键前缀变更**：`toolchain-` / `dl-` / `ccache-` 改为 `wrt-tc-` / `wrt-dl-`，旧缓存不会被复用，将由 GitHub LRU 自动回收。**合并后的第一次构建仍是冷启动**，收益自第二次起显现。
- **两个天花板**：4 vCPU 是免费标准 runner 的硬上限，`-j4` 冷编整套 ImmortalWrt 就是 2~3 小时，要再往下压只能上付费 larger runner（16 核，约降到 1/3，按分钟计费）或改用自托管；此外缓存命中依赖 `WRT_HASH` 稳定，上游频繁提交时仍会有增量重编。
- 本次仅改动工作流与脚本，不涉及 `Config/` 与固件内容，产物应保持一致。

## ## [2026-08-29] 编译提速：新增 dl / feeds 缓存并限制 ccache 体积

### 优化（编译提速）

- **WRT-CORE 新增两份缓存，补齐「下载源码」与「feeds 更新」阶段的复用（继 08-28 toolchain / ccache `restore-keys` 之后的进一步提速）**：原缓存只覆盖 `staging_dir/`（toolchain）与 `.ccache`（编译产物），而 `make download` 拉取的上游源码包、`feeds update -a` 克隆的软件源索引每轮都从零获取；在 toolchain 已可复用后，这两项成为新的主要耗时来源。
  - 新增 `Check Download Cache`：缓存 `./wrt/dl/`，key `dl-<CONFIG>-<INFO>-<HASH>`，配 `restore-keys: dl-<CONFIG>-<INFO>-` 前缀回退。上游 `WRT_HASH` 一更新精确 key 必然 miss，回退 key 命中同机型上一次的 `dl` 缓存后，`make download` 直接跳过已存在的源码包，不再重复拉取数百 MB～数 GB 的 tarball。
  - 新增 `Check Feeds Cache`：缓存 `./wrt/feeds/` 与 `./wrt/package/feeds/`，key `feeds-<CONFIG>-<INFO>-<HASH>`，同样配 `restore-keys` 回退，避免 `feeds update -a` 每轮完整克隆 / 拉取全部软件源索引。
  - 两个新缓存步骤均带 `if: env.WRT_TEST != 'true'`，与既有 toolchain / ccache 缓存逻辑一致：`TEST=true`（默认，仅生成 `.config` 校验）不受影响，只有真正出包时才读写缓存。
- **限制 ccache 体积**：顶层 `env` 新增 `CCACHE_MAXSIZE: 2G` 与 `CCACHE_COMPRESS: 'true'`。此前 ccache 无上限，缓存持续膨胀会拖慢缓存的恢复与上传；限幅并压缩后缓存更小，命中与回传更快。`Config/GENERAL.txt` 中 `CONFIG_CCACHE=y` 已启用，无需改动编译配置。
- 说明：`dl` / `feeds` 缓存首次运行仍为冷启动，需先各写入一次，自第二轮起才开始显著省时间；仓库缓存总额受 GitHub 约 10GB 上限约束，多份缓存按 LRU 自动淘汰，若出现挤占可调小 `CCACHE_MAXSIZE` 或让 `Cache-Clean.yml` 清理更激进。

## [2026-08-29] 源码切换：H5000M / AP3000M 改用 ImmortalWrt 主线
### Changed
- H5000M-AUTO / AP3000M-AUTO 工作流的 `SOURCE` 由 `VIKINGYFY/immortalwrt` 切换为 `immortalwrt/immortalwrt`，`BRANCH` 由 `owrt` 调整为 `master`；X86（OWRT-ALL）保持 `immortalwrt/immortalwrt` + `master` 不变。
- WRT-BUILD 手动编译默认源码/分支同步调整为 `immortalwrt/immortalwrt` + `master`。
- README 鸣谢保留 VIKINGYFY（OpenWRT-CI 编译框架），设备源码说明统一为 ImmortalWrt 主线。



本仓库的所有重要变更都会记录在此文件中。

## [2026-08-28]

### 优化（编译提速）

- **重构 WRT-CORE 缓存策略，消除 toolchain 全量重建（Run #33119462534 分析）**：原 `Check Caches` 的精确 key 含上游 commit（`WRT_HASH`），上游一推送精确 key 必然 miss，而 miss 时「Update Caches」还会**先删光旧缓存再重建**——失败 run 的完整时间线显示 toolchain（gcc initial+final 两轮）+ 宿主 tools 全量重建占去约 1.9 小时（21:56 → 00:11 才开始编内核），是编译耗时的最大单一来源。
  - `Check Caches` 拆为两份独立缓存并各配 `restore-keys` 前缀回退：
    - `toolchain-<CONFIG>-<INFO>-<HASH>`：整份 `staging_dir/`（原 `host*`/`tool*` 通配改为整目录，含 `staging_dir/target` 的内核头/mac80211 存根，避免遗漏）；
    - `ccache-<CONFIG>-<INFO>-<HASH>`：`wrt/.ccache`（`CONFIG_CCACHE=y` 已启用，单份持久化后对上游 mt76/mac80211 这类频繁变动的树外包命中率显著提升）。
    - 上游更新时 `restore-keys` 命中同机型最近一次缓存，OpenWrt 依据自身 stamp 只增量重编变化的组件，不再从零编译 gcc。
  - 移除「Update Caches」中按 miss 删除旧缓存的逻辑（`gh cache list/delete` 段）：restore-keys 命中的旧缓存正是本次构建的复用基础，删除它会导致下次构建退回全量重建；容量由 GitHub 10GB 上限自动按 LRU 淘汰。
  - `Download Packages` 追加 `make download -j1` 串行兜底：补齐并行下载偶发失败的源码，避免 `Compile Firmware` 中途因下载失败中断重来（该阶段重启的代价远大于多跑一次已全部命中的 download）。

## [2026-08-28]

- **永久移除 `999-mtk7987-wed-v31.patch`（Run #33119462534）**：`Compile Firmware` 阶段 `package/kernel/mt76` 编译失败，`mt7996/mmio.c:517` 与 `mt7996/mmio.c:543` 报错 `error: assignment to expression with array type`，随后 `ERROR: package/kernel/mt76 failed to build.`。
  - 根因：内核侧 `999-mtk7987-wed-v31.patch` 将 `include/linux/soc/mediatek/mtk_wed.h` 中 `wlan.wpdma_tx` 由标量 `u32` 改为数组 `u32 wpdma_tx[MTK_WED_TX_QUEUES]`、`wlan.hw_rro` 由 `bool` 改为枚举 `enum mtk_wed_hwrro_mode`，并新增 `rro_3_1_rx_ring_setup` 等接口；但上游 mt76（`2026.08.08~503c643b`）仍按旧标量 API 赋值 `wed->wlan.wpdma_tx`，且此前配套的 mt76 侧补丁（`998-mt76-wed-hwrro-enum.patch`）已因 mt76 上游更新而移除，内核补丁与 mt76 源码的 API 断裂无法在 CI 侧低风险弥合。
  - 处理：删除 `Scripts/patches/wed/999-mtk7987-wed-v31.patch` 与 `Scripts/patches/wed/` 目录；`Scripts/Handles.sh` 中彻底移除内核侧 WED 补丁注入段（`WED_PATCHES_SRC` / `WED_APPLIED` 逻辑及注释）。VIKINGYFY/immortalwrt `owrt` 分支回到上游原生 WED 代码路径，mt76 按上游默认行为编译，编译恢复。
  - 影响：H5000M（MT7987）机型的 WED 硬件加速回落到上游默认支持状态（如上游未启用则 `mtk_wed_device_attach` 不挂载、走普通收发路径，功能不受影响，仅硬件路径加速不可用）；后续如需重新启用，需基于当时的内核与 mt76 commit 同步重做内核侧与 mt76 侧两套补丁并经 `git apply --check` 双向验证。

## [2026-08-28]

### 变更

- **H5000M / AP3000M 源码切换**：`MTK-AUTO.yml` 编译矩阵的 `SOURCE` 由 `immortalwrt/immortalwrt` 切换为 [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)，`BRANCH` 由 `master` 调整为 `main`（VIKINGYFY 仓库仅有 main/owrt/test 三个分支，无 master）。仅影响 5000M 与 3000M 两个机型的自动编译；OWRT-ALL（X86）、手动编译入口 WRT-BUILD 及 Config/Scripts 均保持不变。
- 风险提示：现有 WED V3.1 补丁（`999-mtk7987-wed-v31.patch` / `998-mt76-wed-hwrro-enum.patch`，仅注入 H5000M-WIFI-YES）此前基于 immortalwrt/immortalwrt master（内核 6.18.x）验证；VIKINGYFY/immortalwrt 的内核与 mt76 版本若与其不同，首次构建可能需要重新校准补丁。
- **分支再次调整**：按最新要求，`MTK-AUTO.yml` 编译矩阵的 `BRANCH` 由 `main` 调整为 `owrt`（使用 VIKINGYFY/immortalwrt 的 owrt 分支）。其余配置不变。

### 变更（永久移除）

- **永久移除 mt76 侧 WED hw_rro 枚举补丁（Run #33100607008）**：`Compile Firmware` 阶段 `package/kernel/mt76` 编译失败，根因为 `Scripts/patches/wed/998-mt76-wed-hwrro-enum.patch` 应用失败——上游 mt76 已更新至 `2026.08.08~503c643b`，`mt7996/mmio.c` 第 488 / 518 行附近上下文与补丁基线不一致，2 个 hunk 全部 FAILED（生成 `.rej`），mt76 包构建中断（`ERROR: package/kernel/mt76 failed to build`）。
  - 处理：删除 `Scripts/patches/wed/998-mt76-wed-hwrro-enum.patch`；`Scripts/Handles.sh` 中彻底移除 mt76 侧注入逻辑（`MT76_PATCH_DIRS` 段）并同步清理相关注释，保留内核侧 `999-mtk7987-wed-v31.patch` 注入不变。
  - 影响：H5000M（MT7987）机型不再注入 mt76 侧 hwrro 枚举映射修正，WED 维持上游默认行为；不影响编译。该补丁已确认不再需要，永久移除、不再恢复。

### 变更

- **MTK-AUTO 重命名为 H5000M-AUTO**：`.github/workflows/MTK-AUTO.yml` 更名为 `H5000M-AUTO.yml`，工作流 `name` 同步改为 `H5000M-AUTO`（原 MTK-AUTO 仅编译 H5000M-WIFI-YES，为与机型命名保持一致而重命名）。同步更新：`WRT-CORE.yml` / `AP3000M-AUTO.yml` 顶部注释、`README.md` 工作流表格与项目结构（补充 AP3000M-AUTO 条目）。编译矩阵、触发方式与参数均不变。
- **拆分 AP3000M 与 H5000M 自动编译**：`MTK-AUTO.yml` 编译矩阵由 `[H5000M-WIFI-YES, AP3000M]` 收敛为仅 `[H5000M-WIFI-YES]`；新增独立工作流 `AP3000M-AUTO.yml`（同样监听 `Auto-Clean` 完成后触发 + 支持手动 `workflow_dispatch`，参数与 MTK-AUTO 保持一致），两个机型从此分开编译、互不影响，Release 与构建日志按机型独立呈现。

## [2026-08-25]

### 新增

- **TTYD Web 终端**：全机型默认集成 [ttyd](https://github.com/tsl0922/ttyd) 网页命令行终端，LuCI「系统 → TTYD 终端」页面可在浏览器直接操作设备 Shell。`Config/GENERAL.txt` 新增并默认启用 `ttyd`、`luci-app-ttyd`、`luci-i18n-ttyd-zh-cn` 三个软件包。

### 修复

- **修复 MTK-AUTO H5000M-WIFI-YES 编译失败（Run #32827814718）**：`Compile Firmware` 阶段 `mt7996/mmio.c` 编译报错 `assignment to expression with array type`（491 / 527 行），`ERROR: package/kernel/mt76 failed to build.`。
  - 根因：内核侧 `999-mtk7987-wed-v31.patch` 将 `include/linux/soc/mediatek/mtk_wed.h` 中 `wlan.wpdma_tx` 由标量改为数组 `u32 wpdma_tx[MTK_WED_TX_QUEUES]`、`wlan.hw_rro` 由 `bool` 改为枚举 `enum mtk_wed_hwrro_mode`，但 mt76 侧补丁未同步适配 `mt7996/mmio.c` 中两处按标量赋值的语句（对照联发科官方 `mtk-openwrt-feeds` 的 `0049-mtk-mt76-mt7990-add-mt7987-wed-hw-path-support.patch` 确认了正确写法）。
  - 修复：重写 `Scripts/patches/wed/998-mt76-wed-hwrro-enum.patch`——`wpdma_tx` 两处赋值改为 `wpdma_tx[0]`（hif2 分支与主分支），主分支补齐 V3.1 所需的 `wpdma_tx[1]`（`MT_TXQ_RING_BASE(1) + MT7996_TXQ_BAND1 * MT_RING_SIZE`），`hw_rro` 改为 `(enum mtk_wed_hwrro_mode)dev->mt76.hwrro_mode` 直接映射（mt76 与内核枚举数值一一对应）；同时预防性修正 `mt7915/mmio.c` 两处同类赋值。已基于 CI 实际使用的 mt76 commit（`5967691`）通过 `git apply --check` 验证。

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

- **WED 补丁仅对 H5000M 机型注入（commit `f2096b6`）**：此前 `Scripts/Handles.sh` 的 WED 注入段对所有目标机型无条件注入 `999-mtk7987-wed-v31.patch` 与 `998-mt76-wed-hwrro-enum.patch`，导致其他机型编译失败：X86 目标（AP3000M）的 mt76 应用 `998-mt76-wed-hwrro-enum.patch` 时 hunk 不匹配报错，MTK-AUTO 的 AP3000M（MT7981）机型也因 SoC/WiFi 芯片不同而不适用该补丁。
  - 修复：在 `Scripts/Handles.sh` 的 WED 注入段增加 `WRT_CONFIG` 判断，仅当配置为 `H5000M-WIFI-YES`（MT7987）时注入上述两个补丁，其余机型（AP3000M / X86 等）完全跳过，不影响构建。

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


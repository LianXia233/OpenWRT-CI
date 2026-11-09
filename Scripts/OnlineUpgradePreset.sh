#!/bin/bash
# SPDX-License-Identifier: MIT
# 按机型生成 luci-app-online-upgrade 的出厂预设（/etc/config/online-upgrade）
#
# 为什么在构建期生成而不是每机型提交一份静态文件：
#   升级源里「哪个 Release / 哪个资产」取决于运行期变量 —— WRT_TAG_GROUP
#   决定 Release 归组（MT5700 / MT5700M / FM350 / NetWiz / 自用 / BASE），
#   WRT_DEVICE + WRT_FLAVOR + WRT_DATE_SHORT 决定资产名
#   （如 H5000M-MT5700-26.11.09-sysupgrade.bin、
#   X86-NetWiz-FM350-26.11.09-efi.img.gz）。静态文件无法覆盖「同一份 .config 手工
#   传不同 MT_MODE 编译」的组合，构建期生成则与产物一一对应。
#
# 落点遵循仓库既有 overlay 约定：$(TOPDIR)/files 会被原样并入 rootfs，
# Scripts/Settings.sh 也已经用 ./files/etc/uci-defaults 生成主题种子。
# 因此这里写 ./files/etc/config/online-upgrade，覆盖包自带的同名 conffile，
# 首次开机即为对应机型的升级源，用户在 LuCI 里改过后由 keep.d 保留。
#
# 键名全部取自上游代码，不是猜测：
#   rust/src/uci.rs                 const BASE = "online-upgrade.settings"
#   rust/src/github.rs              repo / tag / proxy / firmware_pattern / min_size_mb
#   rust/src/downloader.rs          dl_workers / dl_chunk_mb / dl_stall_sec / dl_retries
#   rust/src/upgrade.rs             expected_sha256（自定义校验值，留空则用 Release 资产的）
# 上游默认配置里的 enabled / keep_config 在本版本 Rust 与 rpcd 代码中均未被读取，
# 故不写入预设，避免产生「配了却不起作用」的假象。
#
# 用法（在 OpenWrt 源码树根目录，defconfig 之前由 Settings.sh 调用）：
#   Scripts/OnlineUpgradePreset.sh

set -euo pipefail

WRT_CONFIG="${WRT_CONFIG:-}"
WRT_DEVICE="${WRT_DEVICE:-${WRT_CONFIG%%-*}}"
WRT_VARIANT="${WRT_VARIANT:-}"
MT_MODE="${MT_MODE:-}"
# 归组优先级与 WRT-CORE「初始化构建变量」完全一致：
#   有变体按变体（NetWiz / FM350 / 自用），否则按 MT 模式，再否则 BASE
WRT_TAG_GROUP="${WRT_TAG_GROUP:-${WRT_VARIANT:-${MT_MODE:-BASE}}}"

TARGET="./files/etc/config/online-upgrade"
UPGRADE_REPO="${ONLINE_UPGRADE_SOURCE_REPO:-LianXia233/OpenWRT-CI}"

# 包未选中时不生成预设：文件会随 files/ 打进固件，但设备上没有对应软件，
# 只会留下一个没人读的配置。Settings.sh 默认总会选中它，这里只是防御。
if [ -f ./.config ] && ! grep -q '^CONFIG_PACKAGE_luci-app-online-upgrade=y' ./.config; then
	echo "==> luci-app-online-upgrade 未选中，跳过升级预设生成"
	exit 0
fi

if [ -z "$WRT_DEVICE" ]; then
	echo "::warning::无法确定 WRT_DEVICE（WRT_CONFIG 为空？），跳过升级预设生成"
	exit 0
fi

# 资产名规则取自 WRT-CORE「整理并打包固件」：
#   <机型>-<模组插件>-<编译日期>-<固件类型>.<扩展名>
#   - H5000M / AP3000M：<机型>-<模组插件>-<YY.MM.DD>-sysupgrade.bin
#   - X86：<机型>-<模组插件>-<YY.MM.DD>-efi.img.gz（无 sysupgrade.bin）
#   - 例：H5000M-MT5700-26.11.09-sysupgrade.bin
#         H5000M-SelfUse-26.11.09-sysupgrade.bin（自用，文件名已 ASCII 化）
#         X86-NetWiz-MT5700-26.11.09-efi.img.gz
# 模组插件段全 ASCII（含 NetWiz-MT5700 这类带连字符的组合），不再出现中文
# 被 GitHub 字节化成 `.` 的资产名；日期段用 [0-9]{2}\.[0-9]{2}\.[0-9]{2}
# 明确锚定，既能被上游 version::pick() 解析成日期型版本号，也不会误匹配
# 轮换前遗留的旧格式资产。flavor 不写死，同归组内新增变体无需改预设。
case "$WRT_DEVICE" in
	X86)
		# x86 默认取 UEFI 镜像（现代小主机/软路由主流引导方式）。
		# BIOS/Legacy 引导的机器需把 firmware_pattern 里的 efi 改成
		# combined —— 两种镜像的分区表不同，不能混用。
		PATTERN="^X86-[A-Za-z0-9-]+-[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}-efi\\.img\\.gz\$"
		;;
	H5000M | AP3000M)
		PATTERN="^${WRT_DEVICE}-[A-Za-z0-9-]+-[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}-sysupgrade\\.bin\$"
		;;
	*)
		echo "::warning::未知机型 ${WRT_DEVICE}，按 sysupgrade.bin 规则生成，请核对资产名"
		PATTERN="^${WRT_DEVICE}-[A-Za-z0-9-]+-[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}-sysupgrade\\.bin\$"
		;;
esac

# tag 语义来自 rust/src/github.rs：latest 取最新 Release，
# latest@<正则> 只在该正则匹配的 Tag 里找最新 —— 这里按归组过滤，
# 保证 H5000M 不会从 FM350 组里取错产物。
TAG="latest@^${WRT_TAG_GROUP}-"

mkdir -p "$(dirname "$TARGET")"
{
	printf '# 出厂预设：构建期由 Scripts/OnlineUpgradePreset.sh 按机型生成，勿手改\n'
	printf 'config online-upgrade %s\n' "'settings'"
	printf "\toption repo '%s'\n" "$UPGRADE_REPO"
	printf "\toption tag '%s'\n" "$TAG"
	printf "\toption firmware_pattern '%s'\n" "$PATTERN"
	printf "\toption min_size_mb '15'\n"
	printf "\toption proxy 'https://gh.acg2.mom/'\n"
	printf "\toption expected_sha256 ''\n"
	printf "\toption dl_workers '6'\n"
	printf "\toption dl_chunk_mb '4'\n"
	printf "\toption dl_stall_sec '30'\n"
	printf "\toption dl_retries '3'\n"
} > "$TARGET"

# 生成后自检：10 个键一个不少，且关键项与推导值一致。
# 任何一项不匹配都说明模板被改坏，直接红掉而不是带着坏预设编译。
EXPECT_KEYS=10
GOT_KEYS=$(grep -c '^[[:space:]]*option ' "$TARGET" || true)
if [ "$GOT_KEYS" -ne "$EXPECT_KEYS" ]; then
	echo "::error::${TARGET} 生成异常：期望 ${EXPECT_KEYS} 个 option，实际 ${GOT_KEYS}"
	exit 1
fi
grep -qF "option tag '${TAG}'" "$TARGET" || {
	echo "::error::${TARGET} 的 tag 与推导值不一致"
	exit 1
}

echo "==> 在线升级预设：机型=${WRT_DEVICE} 归组=${WRT_TAG_GROUP} 资产正则=${PATTERN}"

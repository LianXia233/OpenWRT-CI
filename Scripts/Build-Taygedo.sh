#!/bin/bash
# SPDX-License-Identifier: MIT
# luci-app-taygedo 的 Rust 后端：源码交叉编译。
#
# 用法（在 OpenWrt 源码树根目录）：
#   $GITHUB_WORKSPACE/Scripts/Build-Taygedo.sh ./package/luci-app-taygedo
#
# 前置条件：包目录下已有 src/（由 Scripts/Packages-Taygedo.sh 放置），
#           且 .config 已由 defconfig 生成（用于推导目标架构）。
#
# 环境变量（均可选）：
#   TAYGEDO_ARCH        目标架构 x86_64 / aarch64，留空从 .config 推导
#   TAYGEDO_LINKER      显式指定 C 编译器/链接器，跳过自动探测
#   TAYGEDO_SKIP_TOOLCHAIN=1   不自动执行 make toolchain/install
#   TAYGEDO_NO_CROSS=1         禁止回退到 cross（Docker）
#   TAYGEDO_FORCE=1            忽略已有产物，强制重编
#
# ── 为什么是这个方案（而不是 lang/rust feed，也不是下载预编译资产）─────────
# 1) lang/rust feed 会连 rustc 本体一起编（约 1.5~3 小时），本包只需要一个
#    静态 musl 可执行文件，性价比极低；
# 2) 预编译资产（GitHub Release）依赖跨仓库发版节奏，版本错位 / 404 /
#    nightly 内容漂移都发生在固件编译的中后期，排查成本高；
# 3) 本方案与仓库内已有的 AirPi 风扇插件（WRT-CORE 的「预编译 AirPi Rust
#    后端」步骤）完全一致：宿主机 rustup + OpenWrt staging_dir 里自带的
#    `<arch>-openwrt-linux-musl-gcc` 作链接器。同一套工具链、同一份 musl，
#    产物与固件同源，编译只需分钟级。
#
# 唯一与 AirPi 不同的是兜底：ApPi 失败即回退 lang/rust（数小时），这里失败
# 先回退 cross（Docker，5~15 分钟），再失败才彻底报错 —— 因为 taygedo 的
# TLS 后端是 ring（含 C/汇编），OpenWrt gcc 的 sysroot 若与 rustc 自带 musl
# 冲突，cross 是已经验证过能出包的路径。
set -euo pipefail

PKG_DIR="${1:?用法: Build-Taygedo.sh <包目录，如 ./package/luci-app-taygedo>}"
# 转绝对路径：脚本中途会 cd 到工程目录，后续所有相对路径（镜像备份恢复、
# 产物拷贝）都必须基于固定基准，否则会在错误的 cwd 下静默写错位置。
PKG_DIR="$(cd "$PKG_DIR" 2>/dev/null && pwd)" || { echo "::error::[taygedo] 包目录不存在：$1" >&2; exit 1; }
# 目录名固定 rust/（不是 src/）：Rust 工程自身有 src/，平铺会与 Cargo.toml
# 的 `path = "src/main.rs"` 解析冲突，cargo 会报 couldn't read src/main.rs。
SRC_DIR="${PKG_DIR}/rust"
OUT_DIR="${PKG_DIR}/local"
OUT_BIN="${OUT_DIR}/taygedo-rs"
INFO="${OUT_DIR}/BUILD-INFO"

WRT_ROOT="$(pwd)"

say() { echo "==> [taygedo] $*"; }
warn() { echo "::warning::[taygedo] $*"; }
die() { echo "::error::[taygedo] $*" >&2; exit 1; }

[ -f "${SRC_DIR}/Cargo.toml" ] || die "未找到 ${SRC_DIR}/Cargo.toml：请先执行 Scripts/Packages-Taygedo.sh"

# ===========================================================================
# 0) 目标架构 -> Rust musl triple
# ===========================================================================
# 从 .config 的 CONFIG_TARGET_ARCH_PACKAGES 读（如 aarch64_cortex-a53 /
# x86_64）。不用 $(ARCH)：那是 make 变量，脚本里拿不到，而且 defconfig
# 生成的 .config 是唯一权威来源。
ARCH="${TAYGEDO_ARCH:-}"
if [ -z "$ARCH" ]; then
	ARCH_PKGS="$(sed -n 's/^CONFIG_TARGET_ARCH_PACKAGES="\(.*\)"$/\1/p' ./.config 2>/dev/null | head -n1)"
	case "$ARCH_PKGS" in
		x86_64*) ARCH="x86_64" ;;
		aarch64*) ARCH="aarch64" ;;
		"") die "无法从 ./.config 读取 CONFIG_TARGET_ARCH_PACKAGES，且未设置 TAYGEDO_ARCH" ;;
		*) die "目标架构 '${ARCH_PKGS}' 暂不支持源码交叉编译（仅 x86_64 / aarch64）" ;;
	esac
fi

case "$ARCH" in
	x86_64)  TRIPLE="x86_64-unknown-linux-musl" ;;
	aarch64) TRIPLE="aarch64-unknown-linux-musl" ;;
	*) die "不支持的目标架构 '${ARCH}'（ring 的 C/汇编后端未覆盖该架构）" ;;
esac
TRIPLE_U="$(printf '%s' "$TRIPLE" | tr '-' '_')"
TRIPLE_UC="$(printf '%s' "$TRIPLE_U" | tr '[:lower:]' '[:upper:]')"
say "目标架构 ${ARCH} → ${TRIPLE}"

# ===========================================================================
# 1) 幂等：源码未变且产物完好则直接复用
# ===========================================================================
SRC_REV="$(cat "${SRC_DIR}/.taygedo-src-rev" 2>/dev/null || echo unknown)"
if [ "${TAYGEDO_FORCE:-0}" != "1" ] && [ -s "$OUT_BIN" ] && [ -f "$INFO" ]; then
	if grep -qx "src_rev=${SRC_REV}" "$INFO" && grep -qx "triple=${TRIPLE}" "$INFO"; then
		say "复用已有产物 ${OUT_BIN}（$(du -h "$OUT_BIN" | cut -f1)，src ${SRC_REV}）"
		exit 0
	fi
	say "已有产物与当前源码/triple 不匹配，重新编译"
fi

# ===========================================================================
# 2) Rust 工具链
# ===========================================================================
if ! command -v cargo >/dev/null 2>&1; then
	say "未检测到 cargo，安装 rustup（minimal profile）"
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
		| sh -s -- -y --profile minimal --default-toolchain stable \
		|| die "rustup 安装失败"
	# shellcheck disable=SC1091
	. "$HOME/.cargo/env"
fi
export PATH="$HOME/.cargo/bin:$PATH"
say "cargo $(cargo --version 2>/dev/null | awk '{print $2}')"

rustup target add "$TRIPLE" >/dev/null 2>&1 || true
rustup target list --installed | grep -qx "$TRIPLE" \
	|| die "rustup 未能安装 target ${TRIPLE}"

# ===========================================================================
# 3) 定位 C 链接器
# ===========================================================================
# 优先 OpenWrt 自己编出来的交叉 gcc：同一份 musl、同一套 ABI，产物与固件
# 完全同源。名字形如 aarch64-openwrt-linux-musl-gcc / x86_64-openwrt-linux-musl-gcc。
find_linker() {
	find "${WRT_ROOT}/staging_dir" -type f -perm -111 \
		-name "${ARCH}-openwrt-linux-musl-gcc" 2>/dev/null | head -n1
}

LINKER="${TAYGEDO_LINKER:-}"
[ -n "$LINKER" ] && say "使用显式指定的链接器：${LINKER}"

if [ -z "$LINKER" ]; then
	LINKER="$(find_linker)"
fi

if [ -z "$LINKER" ] && [ "${TAYGEDO_SKIP_TOOLCHAIN:-0}" != "1" ]; then
	# staging_dir 里还没有交叉 gcc：先构建工具链。固件编译本来也要这一步，
	# 这里只是把顺序提前，命中缓存时几秒完成。
	# 日志落盘而不是 /dev/null：工具链构建失败时，只看一句 "返回非零" 无法
	# 定位（缺依赖 / 磁盘满 / 上游补丁冲突），必须把尾部输出带出来。
	TC_LOG="$(mktemp -t taygedo-toolchain.XXXXXX.log)"
	say "staging_dir 未找到 ${ARCH} musl 交叉 gcc，先执行 make toolchain/install（日志 ${TC_LOG}）"
	if ! make toolchain/install -j"$(nproc)" > "$TC_LOG" 2>&1; then
		warn "make toolchain/install 返回非零，尾部输出："
		tail -n 25 "$TC_LOG" || true
	fi
	LINKER="$(find_linker)"
fi

if [ -n "$LINKER" ]; then
	LINKER="$(readlink -f "$LINKER")"
	say "交叉链接器：${LINKER}"
else
	warn "未找到 ${ARCH}-openwrt-linux-musl-gcc，将尝试 PATH 中的 musl gcc"
	LINKER="$(command -v "${ARCH}-linux-musl-gcc" 2>/dev/null || true)"
	[ -n "$LINKER" ] && say "使用系统 musl gcc：${LINKER}"
fi

# ===========================================================================
# 4) 编译
# ===========================================================================
# ring（rustls 的加密后端）在 musl 交叉编译时需要显式告知 C 编译器与归档器，
# 否则 cc crate 会退化成 `${triple}-gcc`（不存在）并报 "failed to find tool"。
# 这里同时设置三套命名（cc crate 的 CC_<triple>、cargo 的链接器、以及
# 通用 CC/AR），覆盖不同版本 crate 的读取习惯。
build_with_host() {
	local cc="$1" ar=""
	ar="$(dirname "$cc")/$(basename "$cc" | sed 's/gcc$/ar/')"
	[ -x "$ar" ] || ar="$(command -v "${ARCH}-openwrt-linux-musl-ar" 2>/dev/null || echo ar)"

	export CC="${cc}" AR="${ar}"
	export "CC_${TRIPLE_U}=${cc}"
	export "AR_${TRIPLE_U}=${ar}"
	export "CARGO_TARGET_${TRIPLE_UC}_LINKER=${cc}"
	# 交叉 gcc 的 sysroot 指向 OpenWrt staging_dir，显式声明目标，避免
	# configure 类探测（cmake/cc）把宿主 x86_64 当成目标。
	export "CFLAGS_${TRIPLE_U}=-O2"

	say "编译参数：CC=${cc} AR=${ar}"
	[ -d "$SRC_DIR" ] || die "工程目录不存在：${SRC_DIR}"
	cd "$SRC_DIR"
	cargo build --release --locked --target "$TRIPLE" \
		--no-default-features --features openwrt
}

build_with_cross() {
	[ "${TAYGEDO_NO_CROSS:-0}" = "1" ] && return 1
	command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 || {
		warn "Docker 不可用，无法回退 cross"
		return 1
	}
	if ! command -v cross >/dev/null 2>&1; then
		say "安装 cross（cargo install，约 1~2 分钟）"
		cargo install cross --locked >/dev/null 2>&1 || {
			warn "cross 安装失败"
			return 1
		}
	fi
	say "回退 cross（Docker 容器内交叉编译）"
	# 清掉宿主机路径设置的一整套 CC/AR/LINKER：cross 走自己的镜像工具链，
	# 宿主机的 OpenWrt gcc 路径在容器里不存在，留着只会让 cc crate 直接报
	# "failed to find tool"。
	unset CC AR "CC_${TRIPLE_U}" "AR_${TRIPLE_U}" "CARGO_TARGET_${TRIPLE_UC}_LINKER" "CFLAGS_${TRIPLE_U}"
	[ -d "$SRC_DIR" ] || die "工程目录不存在：${SRC_DIR}"
	cd "$SRC_DIR"
	cross build --release --locked --target "$TRIPLE" \
		--no-default-features --features openwrt
}

# CI 上用官方 crates.io：.cargo/config.mirror.toml 里的 rsproxy 镜像在
# GitHub runner（境外）反而拖慢下载。与 taygedo-CI 的 build.yml 保持一致。
MIRROR="${SRC_DIR}/.cargo/config.mirror.toml"
MIRROR_BAK=""
if [ "${TAYGEDO_KEEP_MIRROR:-0}" != "1" ] && [ -f "$MIRROR" ] && grep -q 'rsproxy' "$MIRROR" 2>/dev/null; then
	MIRROR_BAK="$(mktemp)"
	cp -f "$MIRROR" "$MIRROR_BAK"
	printf '' > "$MIRROR"
	say "已临时清空 crates 镜像配置（切回官方源）"
fi
restore_mirror() {
	if [ -n "$MIRROR_BAK" ] && [ -f "$MIRROR_BAK" ]; then
		cp -f "$MIRROR_BAK" "$MIRROR"
		rm -f "$MIRROR_BAK"
	fi
}
trap restore_mirror EXIT

# cargo 自带 strip：走 -C strip=symbols，不依赖目标平台的 strip 是否在 PATH
export CARGO_PROFILE_RELEASE_STRIP="${CARGO_PROFILE_RELEASE_STRIP:-symbols}"

BUILD_MODE="host"
if [ -n "$LINKER" ]; then
	if ! build_with_host "$LINKER"; then
		warn "宿主机交叉编译失败（详见上方 cargo 输出）"
		BUILD_MODE="cross"
	fi
else
	warn "没有可用的 ${ARCH} musl C 编译器"
	BUILD_MODE="cross"
fi

if [ "$BUILD_MODE" = "cross" ]; then
	build_with_cross || die "源码交叉编译失败，且 cross 回退不可用。
  排查方向：
    1) 确认 OpenWrt 工具链已构建（staging_dir/toolchain-*/bin/${ARCH}-openwrt-linux-musl-gcc）；
    2) 确认 ring 的 C 后端能编：需要目标 musl gcc + ar；
    3) 或在 taygedo-CI 打 tag 出预编译资产，改回下载模式（TAYGEDO_PREBUILT=1）。"
fi

# ===========================================================================
# 5) 产物校验
# ===========================================================================
BIN="${SRC_DIR}/target/${TRIPLE}/release/taygedo-rs"
[ -f "$BIN" ] || die "cargo 返回成功但未产出 ${BIN}"

SIZE="$(stat -c%s "$BIN")"
[ "$SIZE" -gt 1048576 ] || die "产物仅 ${SIZE} 字节，明显异常（预期 >1MB）"

# 静态性：openwrt 形态必须是静态 musl，绝不能依赖目标机 libc 版本。
if command -v readelf >/dev/null 2>&1; then
	if readelf -l "$BIN" 2>/dev/null | grep -q 'INTERP'; then
		die "产物含动态解释器（INTERP），不是静态链接：装到路由器会因缺 libc 起不来"
	fi
fi

# 架构核验：防止 linker 与 triple 不匹配时「编出来却是错的架构」
if command -v file >/dev/null 2>&1; then
	FILE_OUT="$(file -b "$BIN")"
	case "$ARCH" in
		aarch64) printf '%s' "$FILE_OUT" | grep -qi 'aarch64\|ARM' \
			|| die "产物架构不符（期望 aarch64）：${FILE_OUT}" ;;
		x86_64)  printf '%s' "$FILE_OUT" | grep -qi 'x86-64' \
			|| die "产物架构不符（期望 x86_64）：${FILE_OUT}" ;;
	esac
	say "产物：${FILE_OUT}"
fi

mkdir -p "$OUT_DIR"
install -m 0755 "$BIN" "$OUT_BIN"

{
	echo "src_rev=${SRC_REV}"
	echo "triple=${TRIPLE}"
	echo "features=openwrt"
	echo "mode=${BUILD_MODE}"
	echo "size=${SIZE}"
	echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$INFO"

say "完成：${OUT_BIN}（$(du -h "$OUT_BIN" | cut -f1)，方式 ${BUILD_MODE}，src ${SRC_REV}）"

#!/bin/bash
# SPDX-License-Identifier: MIT
# =============================================================================
# Build-Rust-Prebuilt.sh — 统一 Rust 后端预编译（官方 Rust SDK 交叉编译）
#
# 覆盖过去在 OpenWrt buildroot（build_dir）内调 cargo 的三个 Rust 插件：
#   luci-app-mt5700（at-webserver）/ luci-app-h5000m-fancontrol / luci-app-fm350（fm350d）。
# 与仓库内已有的 taygedo / airpi 预编译路径同一思路：宿主机 rustup 官方工具链
# 交叉编译，OpenWrt 侧只做二进制打包 —— rustc/cargo 始终来自 Rust 官方 SDK，
# 绝不触发 OpenWrt 的 rust/host 源码构建（那套要 1.5~3 小时）。
#
# 相比 buildroot 内编译的收益：
#   1. 编译期从固件编译中段前移到独立步骤，cargo 目标目录固定在
#      ./.rust-build/<包名>/target，可被 CI 缓存整体复用（命中后增量秒级）；
#   2. 不再依赖 buildroot 环境对 CARGO_HOME/PATH 的透传（2026-11-06 曾因
#      链接器回退 cc 导致五个工作流全红的正是这条脆弱链路）；
#   3. 产物在进入 buildroot 前先完成架构/静态链接自检，坏产物在 1 分钟内
#      红掉，而不是拖到固件编译中后期。
#
# 用法（在 OpenWrt 源码树根目录）：
#   Build-Rust-Prebuilt.sh <包目录> <rust 工程相对包目录> <二进制名> [额外 cargo 参数...]
#   例：Build-Rust-Prebuilt.sh ./package/luci-app-fm350 rust fm350d
#   调试：Build-Rust-Prebuilt.sh --inject-only <包目录> <rust 目录> <二进制名>
#         （跳过编译，只重放 Makefile 注入，便于验证上游包结构变化）
#
# 环境变量（均可选）：
#   RUST_OUT_BIN          产物落点（默认跟随注入目标：luci.mk 型包为
#                         <包>/src/prebuilt/<bin>，自包含型包为 <包>/prebuilt/<bin>）
#   RUST_NO_INJECT=1      只编译不注入（airpi/taygedo 等自带注入机制的包用）
#   RUST_SKIP_TOOLCHAIN=1 staging_dir 无交叉 gcc 时不自动 make toolchain/install
#   RUST_FORCE=1          忽略幂等复用，强制重编
#
# 注入行为（RUST_NO_INJECT 未设置时）：
#   在包 Makefile 末尾（fm350 为 $(eval 之前）追加 CI-RUST-PREBUILT 守卫块：
#   build_dir 里存在 <包>/prebuilt/<二进制名> 时直接取用并跳过 buildroot 内
#   cargo；产物缺失时守卫自动失效，回退原始 cargo 路径（配合 Packages.sh 写
#   入的 .cargo/config.toml 链接器兜底，行为与迁移前一致）。
#
# 退出码：0 成功；非 0 失败（调用方应让步骤红掉，不做静默回退）。
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# 0) 参数
# ---------------------------------------------------------------------------
usage() {
	echo "用法: $0 [--inject-only] <包目录> <rust 工程相对包目录> <二进制名> [额外 cargo 参数...]" >&2
	exit 2
}

INJECT_ONLY=0
if [ "${1:-}" = "--inject-only" ]; then
	INJECT_ONLY=1
	shift
fi

PKG_DIR="${1:-}"
RUST_DIR_REL="${2:-}"
BIN_NAME="${3:-}"
if [ $# -ge 3 ]; then
	shift 3
	EXTRA_CARGO_ARGS=("$@")
else
	EXTRA_CARGO_ARGS=()
fi

[ -n "$PKG_DIR" ] && [ -n "$RUST_DIR_REL" ] && [ -n "$BIN_NAME" ] || usage

PKG_DIR="$(cd "$PKG_DIR" 2>/dev/null && pwd)" \
	|| { echo "::error::[rust-prebuilt] 包目录不存在：$PKG_DIR" >&2; exit 1; }
PKG_NAME="$(basename "$PKG_DIR")"
TAG="${PKG_NAME#luci-app-}"
TAG_UPPER="$(printf '%s' "$TAG" | tr '[:lower:]-' '[:upper:]_')"
SRC_DIR="${PKG_DIR}/${RUST_DIR_REL}"
# 注入目标 Makefile 决定产物落点：
#   luci.mk 型（src/Makefile）的守卫查 $(CURDIR)/prebuilt，且只有 src/ 下
#   的内容会被 luci.mk 复制进 build_dir —— 产物必须放 src/prebuilt/；
#   自包含型（fm350）就地构建（CURDIR=包根），产物放 <包>/prebuilt/。
if [ -f "${PKG_DIR}/src/Makefile" ]; then
	PKG_MAKEFILE="${PKG_DIR}/src/Makefile"
	DEFAULT_OUT_DIR="${PKG_DIR}/src/prebuilt"
else
	PKG_MAKEFILE="${PKG_DIR}/Makefile"
	DEFAULT_OUT_DIR="${PKG_DIR}/prebuilt"
fi
OUT_BIN="${RUST_OUT_BIN:-${DEFAULT_OUT_DIR}/${BIN_NAME}}"
OUT_DIR="$(dirname "$OUT_BIN")"
RUST_BUILD_ROOT="${WRT_RUST_BUILD_ROOT:-$(pwd)/.rust-build}"
CARGO_TARGET_DIR="${RUST_BUILD_ROOT}/${PKG_NAME}/target"
INFO_DIR="${RUST_BUILD_ROOT}/${PKG_NAME}"

WRT_ROOT="$(pwd)"

say() { echo "==> [${TAG}] $*"; }
warn() { echo "::warning::[${TAG}] $*"; }
die() { echo "::error::[${TAG}] $*" >&2; exit 1; }

[ -f "${SRC_DIR}/Cargo.toml" ] || die "未找到 ${SRC_DIR}/Cargo.toml（rust 目录是否为 ${RUST_DIR_REL}？）"

# ---------------------------------------------------------------------------
# A) 注入 Makefile 守卫块：build_dir 内见产物即取用，跳过 cargo
# （提前定义：幂等复用与 --inject-only 分支都会调用）
# ---------------------------------------------------------------------------
inject_prebuilt() {
	local mf style outvar block_file splice_line

	if [ "${RUST_NO_INJECT:-0}" = "1" ]; then
		say "RUST_NO_INJECT=1，跳过 Makefile 注入"
		return 0
	fi

	mf="$PKG_MAKEFILE"
	[ -f "$mf" ] || { warn "未找到 Makefile，跳过注入（仍保留产物）"; return 0; }

	if grep -q "### CI-RUST-PREBUILT(${TAG})" "$mf"; then
		say "Makefile 已含注入守卫，跳过（${mf}）"
		return 0
	fi

	block_file="$(mktemp)"

	if grep -q '^RUST_OUT[[:space:]]*[:+]*=' "$mf" && grep -q 'define Build/Compile' "$mf"; then
		# fm350 型：自包含包。重指 RUST_OUT 到预编译产物，并把 Build/Compile
		# 换成存在性校验 —— 宏后定义覆盖先定义，且插在 $(eval 之前才生效。
		style="fm350"
		{
			printf '\n'
			printf '### CI-RUST-PREBUILT(%s) BEGIN：runner 侧官方 Rust SDK 交叉编译产物优先 ###\n' "$TAG"
			printf '%s_PREBUILT := $(CURDIR)/prebuilt/%s\n' "$TAG_UPPER" "$BIN_NAME"
			printf 'ifneq ($(wildcard $(%s_PREBUILT)),)\n' "$TAG_UPPER"
			printf 'RUST_OUT := $(%s_PREBUILT)\n' "$TAG_UPPER"
			printf 'endif\n'
			printf '\n'
			printf 'define Build/Compile\n'
			printf '\t@echo "==> [%s] 使用 CI 预编译二进制（官方 Rust SDK 交叉编译）"\n' "$TAG"
			printf '\ttest -f "$(RUST_OUT)" || { echo "ERROR: 预编译产物缺失: $(RUST_OUT)"; exit 1; }\n'
			printf 'endef\n'
			printf '### CI-RUST-PREBUILT(%s) END ###\n' "$TAG"
		} > "$block_file"

		splice_line="$(grep -n -m1 '^\$(' "$mf" | cut -d: -f1 || true)"
		if [ -n "${splice_line:-}" ]; then
			{ head -n $((splice_line - 1)) "$mf"; cat "$block_file"; tail -n "+${splice_line}" "$mf"; } > "${mf}.tmp" \
				&& mv "${mf}.tmp" "$mf"
		else
			cat "$block_file" >> "$mf"
		fi
	elif grep -Eq '^(BIN|BINARY)[[:space:]]*[:+]=.*release' "$mf"; then
		# luci.mk 型：src/Makefile 的 compile 目标产出 $(BIN)/$(BINARY)。
		# 后定义的 compile 目标覆盖原始配方（GNU make 覆盖警告属预期）。
		style="compile-var"
		if grep -q '^BIN[[:space:]]*[:+]=.*release' "$mf"; then
			outvar="BIN"
		else
			outvar="BINARY"
		fi
		{
			printf '\n'
			printf '### CI-RUST-PREBUILT(%s) BEGIN：runner 侧官方 Rust SDK 交叉编译产物优先 ###\n' "$TAG"
			printf '# 产物缺失时下方 wildcard 守卫自动失效，回退原始 cargo 编译路径。\n'
			printf 'ifneq ($(wildcard $(CURDIR)/prebuilt/%s),)\n' "$BIN_NAME"
			printf 'compile:\n'
			printf '\t@echo "==> [%s] 使用 CI 预编译二进制（官方 Rust SDK 交叉编译）"\n' "$TAG"
			printf '\tmkdir -p $(dir $(%s))\n' "$outvar"
			printf '\tcp -f "$(CURDIR)/prebuilt/%s" "$(%s)"\n' "$BIN_NAME" "$outvar"
			printf '\tchmod 0755 "$(%s)"\n' "$outvar"
			printf 'endif\n'
			printf '### CI-RUST-PREBUILT(%s) END ###\n' "$TAG"
		} > "$block_file"
		cat "$block_file" >> "$mf"
	else
		warn "无法识别 ${mf} 的编译结构（既无 RUST_OUT+Build/Compile，也无 BIN/BINARY），跳过注入 —— 将回退 buildroot 内 cargo"
		rm -f "$block_file"
		return 0
	fi

	rm -f "$block_file"
	say "已注入守卫块（${style}）→ ${mf}"
	return 0
}

# ---------------------------------------------------------------------------
# 1) 目标架构 -> Rust musl triple（权威来源是 defconfig 后的 .config）
# ---------------------------------------------------------------------------
ARCH_PKGS="$(sed -n 's/^CONFIG_TARGET_ARCH_PACKAGES="\(.*\)"$/\1/p' ./.config 2>/dev/null | head -n1)"
case "$ARCH_PKGS" in
	x86_64*)  ARCH="x86_64" ;;
	aarch64*) ARCH="aarch64" ;;
	"")      die "无法从 ./.config 读取 CONFIG_TARGET_ARCH_PACKAGES（是否在 defconfig 之后调用？）" ;;
	*)       die "目标架构 '${ARCH_PKGS}' 暂不支持（仅 x86_64 / aarch64）" ;;
esac

case "$ARCH" in
	x86_64)  TRIPLE="x86_64-unknown-linux-musl" ;;
	aarch64) TRIPLE="aarch64-unknown-linux-musl" ;;
esac
TRIPLE_U="$(printf '%s' "$TRIPLE" | tr '-' '_')"
TRIPLE_UC="$(printf '%s' "$TRIPLE_U" | tr '[:lower:]' '[:upper:]')"
say "目标架构 ${ARCH_PKGS} → ${TRIPLE}"

# ---------------------------------------------------------------------------
# 2) 幂等复用：同源码 + 同 triple 的完好产物直接跳过编译
# ---------------------------------------------------------------------------
SRC_REV="$(git -C "$SRC_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ "${RUST_FORCE:-0}" != "1" ] && [ -s "$OUT_BIN" ] && [ -f "${INFO_DIR}/BUILD-INFO" ]; then
	if grep -qx "src_rev=${SRC_REV}" "${INFO_DIR}/BUILD-INFO" \
		&& grep -qx "triple=${TRIPLE}" "${INFO_DIR}/BUILD-INFO"; then
		say "复用已有产物 ${OUT_BIN}（$(du -h "$OUT_BIN" | cut -f1)，src ${SRC_REV}）"
		inject_prebuilt
		exit 0
	fi
	say "已有产物与当前源码/triple 不匹配，重新编译"
fi

if [ "$INJECT_ONLY" = "1" ]; then
	inject_prebuilt
	exit 0
fi

# ---------------------------------------------------------------------------
# 3) Rust 官方工具链（rustup）
# ---------------------------------------------------------------------------
if ! command -v cargo >/dev/null 2>&1; then
	say "未检测到 cargo，安装 rustup（minimal profile）"
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
		| sh -s -- -y --profile minimal --default-toolchain stable \
		|| die "rustup 安装失败"
	# shellcheck disable=SC1091
	. "$HOME/.cargo/env"
fi
export PATH="$HOME/.cargo/bin:$PATH"
say "rustc $(rustc --version 2>/dev/null | awk '{print $2}') / cargo $(cargo --version 2>/dev/null | awk '{print $2}')"

if ! rustup target add "$TRIPLE" >/dev/null 2>&1; then
	# 环境若配置了镜像（RUSTUP_DIST_SERVER），缺件时回退官方源再试一次；
	# GitHub 托管 runner 默认直连官方，本分支只是兜底。
	say "rustup target add 失败（镜像缺件？），回退官方分发源重试"
	RUSTUP_DIST_SERVER=https://static.rust-lang.org \
		RUSTUP_UPDATE_ROOT=https://static.rust-lang.org/rustup \
		rustup target add "$TRIPLE" >/dev/null 2>&1 || true
fi
rustup target list --installed 2>/dev/null | grep -qx "$TRIPLE" \
	|| die "rustup 未能安装 target ${TRIPLE}"

# ---------------------------------------------------------------------------
# 4) 定位交叉链接器（OpenWrt staging_dir 的 musl gcc，与固件工具链同源）
# ---------------------------------------------------------------------------
find_linker() {
	find "${WRT_ROOT}/staging_dir" -type f -perm -111 \
		-name "${ARCH}-openwrt-linux-musl-gcc" 2>/dev/null | head -n1
}

LINKER="$(find_linker || true)"
if [ -z "$LINKER" ] && [ "${RUST_SKIP_TOOLCHAIN:-0}" != "1" ]; then
	# 命中工具链缓存时秒过，冷缓存才会真正构建 —— 固件编译本来也需要这一步，
	# 这里只是把顺序提前，不增加总时长。日志落盘便于失败定位。
	TC_LOG="$(mktemp -t rust-prebuilt-toolchain.XXXXXX.log)"
	say "staging_dir 未找到 ${ARCH} musl 交叉 gcc，先执行 make toolchain/install（日志 ${TC_LOG}）"
	if ! make -C "$WRT_ROOT" toolchain/install -j"$(nproc)" > "$TC_LOG" 2>&1; then
		warn "make toolchain/install 返回非零，尾部输出："
		tail -n 25 "$TC_LOG" || true
	fi
	LINKER="$(find_linker || true)"
fi

if [ -n "$LINKER" ]; then
	LINKER="$(readlink -f "$LINKER")"
	say "交叉链接器：${LINKER}"
else
	# 兜底：零依赖 crate（如 h5000m-fancontrol）走 rustc 自带 rust-lld 的
	# self-contained musl 链接也能出静态产物；含 ring 的包（mt5700/fm350）
	# 缺交叉 gcc 会在编译期显式失败，不会静默产出坏二进制。
	warn "未找到 ${ARCH}-openwrt-linux-musl-gcc，回退 rustc 自带 self-contained musl 链接"
fi

# ---------------------------------------------------------------------------
# 5) cargo 环境与镜像收敛
# ---------------------------------------------------------------------------
if [ -n "$LINKER" ]; then
	AR_BIN="$(dirname "$LINKER")/$(basename "$LINKER" | sed 's/gcc$/ar/')"
	[ -x "$AR_BIN" ] || AR_BIN="$(command -v "${ARCH}-openwrt-linux-musl-ar" 2>/dev/null || echo ar)"
	# 三套命名并设：cc crate（CC_<triple>）、cargo 链接器、通用 CC/AR，
	# 覆盖 ring 等 build.rs 依赖的不同读取习惯。
	export CC="$LINKER" AR="$AR_BIN"
	export "CC_${TRIPLE_U}=$LINKER"
	export "AR_${TRIPLE_U}=$AR_BIN"
	export "CARGO_TARGET_${TRIPLE_UC}_LINKER=$LINKER"
	export "CFLAGS_${TRIPLE_U}=-O2"
fi

# GitHub runner 在境外：包内如带 rsproxy 镜像配置，临时清空切回官方 crates.io
MIRROR="${SRC_DIR}/.cargo/config.mirror.toml"
MIRROR_BAK=""
if [ -f "$MIRROR" ] && grep -q 'rsproxy' "$MIRROR" 2>/dev/null; then
	MIRROR_BAK="$(mktemp)"
	cp -f "$MIRROR" "$MIRROR_BAK"
	printf '' > "$MIRROR"
	say "已临时清空 crates 镜像配置（runner 上直连官方源更快）"
fi
restore_mirror() {
	if [ -n "$MIRROR_BAK" ] && [ -f "$MIRROR_BAK" ] && [ -f "$MIRROR" ]; then
		cp -f "$MIRROR_BAK" "$MIRROR"
		rm -f "$MIRROR_BAK"
	fi
}
trap restore_mirror EXIT

# cargo 自带 strip：不依赖目标平台 strip 是否在 PATH
export CARGO_PROFILE_RELEASE_STRIP="${CARGO_PROFILE_RELEASE_STRIP:-symbols}"

# 目标目录固定到 .rust-build/<包名>/target：CI 缓存按该前缀整体复用，
# 命中后只重编业务 crate（增量秒级），依赖树不再每次从零构建。
export CARGO_TARGET_DIR
mkdir -p "$CARGO_TARGET_DIR" "$OUT_DIR" "$INFO_DIR"
say "cargo 目标目录：${CARGO_TARGET_DIR}"

# ---------------------------------------------------------------------------
# 6) 编译
# ---------------------------------------------------------------------------
LOCK_FLAG="--locked"
[ -f "${SRC_DIR}/Cargo.lock" ] || LOCK_FLAG=""

cd "$SRC_DIR"
say "cargo build ${LOCK_FLAG:-(无锁)} --release --target ${TRIPLE} ${EXTRA_CARGO_ARGS[*]:-}"
if [ -n "$LOCK_FLAG" ]; then
	cargo build --locked --release --target "$TRIPLE" ${EXTRA_CARGO_ARGS[@]+"${EXTRA_CARGO_ARGS[@]}"}
else
	cargo build --release --target "$TRIPLE" ${EXTRA_CARGO_ARGS[@]+"${EXTRA_CARGO_ARGS[@]}"}
fi

BIN_PATH="${CARGO_TARGET_DIR}/${TRIPLE}/release/${BIN_NAME}"
[ -f "$BIN_PATH" ] || die "cargo 返回成功但未产出 ${BIN_PATH}"

# ---------------------------------------------------------------------------
# 7) 产物自检：尺寸 / 静态性 / 架构，坏产物不进 buildroot
# ---------------------------------------------------------------------------
SIZE="$(stat -c%s "$BIN_PATH")"
[ "$SIZE" -gt 65536 ] || die "产物仅 ${SIZE} 字节，明显异常"
if command -v readelf >/dev/null 2>&1; then
	if readelf -l "$BIN_PATH" 2>/dev/null | grep -q 'INTERP'; then
		die "产物含动态解释器（INTERP），不是静态 musl：装到设备会因缺 libc 起不来"
	fi
fi
if command -v file >/dev/null 2>&1; then
	FILE_OUT="$(file -b "$BIN_PATH")"
	case "$ARCH" in
		aarch64) printf '%s' "$FILE_OUT" | grep -qi 'aarch64' \
			|| die "架构核验失败：期望 aarch64，实际 ${FILE_OUT}" ;;
		x86_64)  printf '%s' "$FILE_OUT" | grep -qi 'x86-64' \
			|| die "架构核验失败：期望 x86-64，实际 ${FILE_OUT}" ;;
	esac
	say "产物自检通过：${FILE_OUT%%,*}（$(du -h "$BIN_PATH" | cut -f1)）"
fi

install -m 0755 "$BIN_PATH" "$OUT_BIN"

# BUILD-INFO 记录编译要素（幂等复用与排障都靠它）；BUILD-INDEX 汇总本轮清单。
RUSTC_VER="$(rustc --version 2>/dev/null | awk '{print $2}')"
LINKER_NOTE="${LINKER:-rust-lld(self-contained)}"
{
	echo "pkg=${PKG_NAME}"
	echo "bin=${BIN_NAME}"
	echo "triple=${TRIPLE}"
	echo "rustc=${RUSTC_VER}"
	echo "linker=${LINKER_NOTE}"
	echo "src_rev=${SRC_REV}"
	echo "built_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${INFO_DIR}/BUILD-INFO"
echo "${PKG_NAME} ${BIN_NAME} ${TRIPLE} ${SRC_REV}" >> "${RUST_BUILD_ROOT}/BUILD-INDEX"

say "产物已就位：${OUT_BIN}"

# ---------------------------------------------------------------------------
# 8) 注入守卫块并收尾
# ---------------------------------------------------------------------------
inject_prebuilt

say "完成（bin=$(du -h "$OUT_BIN" | cut -f1) triple=${TRIPLE} src=${SRC_REV}）"

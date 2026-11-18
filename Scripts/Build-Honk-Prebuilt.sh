#!/bin/bash
# SPDX-License-Identifier: MIT
# =============================================================================
# Build-Honk-Prebuilt.sh — honk-core 源码交叉编译（官方 Rust SDK，buildroot 外）
#
# 用法（在 OpenWrt 源码树根目录、defconfig 之后执行）：
#   bash Scripts/Build-Honk-Prebuilt.sh
#
# 与仓库内既有的 Rust 后端路径一致（Build-Rust-Prebuilt.sh / Build-Taygedo.sh /
# AirPi 预编译）：runner 侧 rustup 官方工具链交叉编译，OpenWrt 的 Build/Compile
# 只做打包。差别只在 honk 需要 Zig + bpf-linker 生成 eBPF 对象，再用 musl
# 静态链接 honk-core。
#
# 产物：package/honk/files/honk-core.bin + .stamp
#   Build/Compile 里的 build_honk_core.sh --if-needed 看到同 target 的 stamp
#   后直接跳过 —— 不会在 buildroot 里调 cargo，也不会触发 OpenWrt rust/host。
#
# 环境变量（均可选）：
#   HONK_PKG_DIR   默认 ./package/honk
#   HONK_OUT_BIN   默认 $HONK_PKG_DIR/files/honk-core.bin
#   HONK_SRC_DIR   默认 ./.rust-build/honk/src（随 .rust-build 一起缓存）
#   HONK_FORCE=1   忽略 stamp，强制重新源码编译
#   HONK_SKIP_APT=1 调试用：不执行 apt-get install
# =============================================================================
set -euo pipefail

PKG_DIR="${HONK_PKG_DIR:-./package/honk}"
PKG_DIR="$(cd "$PKG_DIR" 2>/dev/null && pwd)" || {
	echo "::error::[honk] 包目录不存在：${HONK_PKG_DIR:-./package/honk}" >&2
	exit 1
}
OUT_BIN="${HONK_OUT_BIN:-${PKG_DIR}/files/honk-core.bin}"
BASE_DIR="$(pwd)/.rust-build/honk"
SRC_DIR="${HONK_SRC_DIR:-${BASE_DIR}/src}"
ZIG_DIR="${BASE_DIR}/zig"
TOOL_BIN="${BASE_DIR}/bin"
INFO="${BASE_DIR}/BUILD-INFO"

say() { echo "==> [honk] $*"; }
warn() { echo "::warning::[honk] $*"; }
die() { echo "::error::[honk] $*" >&2; exit 1; }

# honk 源码编译所需系统依赖（clang/libclang/libbpf；与上游 release.yml 对齐）。
# 必须在 Zig/bpf-linker 下载前调用：bpf-linker 是 .tar.zst（要 zstd），
# Zig 是 .tar.xz（要 xz）。
ensure_apt_deps() {
	local NEED_APT=0 C
	for C in clang cmake pkg-config zstd xz readelf; do
		command -v "$C" >/dev/null 2>&1 || NEED_APT=1
	done
	pkg-config --exists libclang 2>/dev/null || NEED_APT=1
	pkg-config --exists libbpf 2>/dev/null || NEED_APT=1

	if [ "${HONK_SKIP_APT:-0}" != "1" ] && [ "$NEED_APT" = "1" ]; then
		if command -v apt-get >/dev/null 2>&1; then
			if sudo -n true 2>/dev/null; then
				say "安装 honk 源码编译系统依赖（clang/llvm/libbpf-dev/libclang-dev 等）"
				sudo apt-get update -qq || true
				sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
					clang llvm libbpf-dev pkg-config cmake libclang-dev zstd xz-utils binutils \
					|| die "apt-get install 失败"
			else
				die "需要 sudo 安装 clang/llvm/libbpf-dev/libclang-dev；或预装后设置 HONK_SKIP_APT=1"
			fi
		else
			die "缺少 clang/cmake/pkg-config/zstd/xz/readelf，且没有 apt-get"
		fi
	fi

	for C in clang cmake pkg-config zstd xz readelf; do
		command -v "$C" >/dev/null 2>&1 || die "源码编译依赖缺失：$C"
	done
	pkg-config --exists libclang 2>/dev/null || die "源码编译依赖缺失：libclang"
	pkg-config --exists libbpf 2>/dev/null || die "源码编译依赖缺失：libbpf"
}

[ -f "${PKG_DIR}/build_honk_core.sh" ] || die "未找到 ${PKG_DIR}/build_honk_core.sh：请先执行 Scripts/Packages-Honk.sh"
[ -f "${PKG_DIR}/honk_toolchain.sh" ] || die "未找到 ${PKG_DIR}/honk_toolchain.sh：包骨架不完整"

# ===========================================================================
# 0) 目标架构 -> Rust musl triple（与 Build-Rust-Prebuilt.sh 同一口径）
# ===========================================================================
ARCH_PKGS="$(sed -n 's/^CONFIG_TARGET_ARCH_PACKAGES="\(.*\)"$/\1/p' ./.config 2>/dev/null | head -n1)"
case "$ARCH_PKGS" in
	aarch64*) ARCH="aarch64" ;;
	x86_64*)  ARCH="x86_64" ;;
	"")       die "无法从 ./.config 读取 CONFIG_TARGET_ARCH_PACKAGES（是否在 defconfig 之后调用？）" ;;
	*)        die "目标架构 '${ARCH_PKGS}' 暂不支持（仅 x86_64 / aarch64）" ;;
esac
case "$ARCH" in
	aarch64) TRIPLE="aarch64-unknown-linux-musl" ;;
	x86_64)  TRIPLE="x86_64-unknown-linux-musl" ;;
esac
say "目标架构 ${ARCH_PKGS} → ${TRIPLE}"

# ===========================================================================
# 1) 上游 pins（Zig / bpf-linker / honk 源码 commit）
# ===========================================================================
eval "$("${PKG_DIR}/honk_toolchain.sh" "${PKG_DIR}/Makefile")"
[ -n "${ZIG_VERSION:-}" ] || die "honk_toolchain.sh 未解析出 ZIG_VERSION"
[ -n "${BPF_LINKER_VERSION:-}" ] || die "honk_toolchain.sh 未解析出 BPF_LINKER_VERSION"
[ -n "${BPF_LINKER_SHA256:-}" ] || die "honk_toolchain.sh 未解析出 BPF_LINKER_SHA256"
say "pin：Zig ${ZIG_VERSION} / bpf-linker ${BPF_LINKER_VERSION} / honk ${HONK_SRC_VERSION:-unknown}"

# 与 Build-Rust-Prebuilt.sh 一样，源码目录放 .rust-build 下，随缓存复用。
# build_honk_core.sh 在传入 SRC_DIR 时不会自己 clone，必须先确保 checkout
# 到钉死的 commit，否则 honk_toolchain.sh --src 会因缺 .github 元数据失败。
ensure_honk_src() {
	local rev
	rev="$(git -C "$SRC_DIR" rev-parse HEAD 2>/dev/null || true)"
	if [ -d "$SRC_DIR/.git" ] && [ "$rev" = "$HONK_SRC_VERSION" ] \
		&& [ -f "$SRC_DIR/crates/honk-core/Cargo.toml" ]; then
		say "复用源码 ${SRC_DIR} @ ${HONK_SRC_VERSION}"
		return 0
	fi
	say "拉取 honk 源码 ${HONK_SRC_URL} @ ${HONK_SRC_VERSION}"
	rm -rf "$SRC_DIR"
	mkdir -p "$(dirname "$SRC_DIR")"
	git init -q "$SRC_DIR"
	git -C "$SRC_DIR" remote add origin "$HONK_SRC_URL"
	git -C "$SRC_DIR" fetch --depth 1 origin "$HONK_SRC_VERSION"
	git -C "$SRC_DIR" checkout -q --detach FETCH_HEAD
}

mkdir -p "$BASE_DIR" "$TOOL_BIN" "$(dirname "$OUT_BIN")" "$(dirname "$SRC_DIR")"

# 幂等：同 commit + 同 triple 的产物直接复用（缓存命中时秒级）
SRC_REV="$(git -C "$SRC_DIR" rev-parse HEAD 2>/dev/null || true)"
if [ "${HONK_FORCE:-0}" != "1" ] && [ -s "$OUT_BIN" ] && [ -f "$OUT_BIN.stamp" ] && [ -f "$INFO" ]; then
	if [ "$(cat "$OUT_BIN.stamp")" = "$TRIPLE" ] \
		&& grep -qx "src_rev=${HONK_SRC_VERSION}" "$INFO" \
		&& grep -qx "triple=${TRIPLE}" "$INFO"; then
		say "复用已有产物 ${OUT_BIN}（$(du -h "$OUT_BIN" | cut -f1)，src ${HONK_SRC_VERSION}）"
		exit 0
	fi
	say "已有产物与当前源码/triple 不匹配，重新编译"
fi

if [ "${HONK_FORCE:-0}" = "1" ]; then
	rm -f "$OUT_BIN" "$OUT_BIN.stamp"
fi

# ===========================================================================
# 2) Rust 官方工具链（rustup；等价于 Build-Rust-Prebuilt.sh 的做法）
# ===========================================================================
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export PATH="$CARGO_HOME/bin:$TOOL_BIN:$ZIG_DIR:$PATH"
if ! command -v cargo >/dev/null 2>&1; then
	say "未检测到 cargo，安装 rustup（minimal profile）"
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
		| sh -s -- -y --profile minimal --default-toolchain stable \
		|| die "rustup 安装失败"
	# shellcheck disable=SC1091
	. "$CARGO_HOME/env"
fi
say "rustc $(rustc --version 2>/dev/null | awk '{print $2}') / cargo $(cargo --version 2>/dev/null | awk '{print $2}')"

rustup target add "$TRIPLE" >/dev/null 2>&1 || true
rustup target list --installed 2>/dev/null | grep -qx "$TRIPLE" \
	|| die "rustup 未能安装 target ${TRIPLE}"

ensure_apt_deps

# ===========================================================================
# 3) Zig（honk 上游 release.yml 的 setup-zig 版本；用于 musl 静态链接）
# ===========================================================================
if [ ! -x "${ZIG_DIR}/zig" ] || [ "$("${ZIG_DIR}/zig" version 2>/dev/null || true)" != "$ZIG_VERSION" ]; then
	say "安装 Zig ${ZIG_VERSION}"
	ZIG_JSON="$(mktemp)"
	curl -fsSL --retry 5 --retry-all-errors --max-time 120 \
		-o "$ZIG_JSON" https://ziglang.org/download/index.json \
		|| die "Zig index.json 下载失败"
	ZIG_URL="$(python3 - "$ZIG_JSON" "$ZIG_VERSION" <<'PY' || true
import json,sys
d=json.load(open(sys.argv[1]))
print(d[sys.argv[2]]["x86_64-linux"]["tarball"])
PY
)"
	ZIG_SHA="$(python3 - "$ZIG_JSON" "$ZIG_VERSION" <<'PY' || true
import json,sys
d=json.load(open(sys.argv[1]))
print(d[sys.argv[2]]["x86_64-linux"].get("shasum",""))
PY
)"
	rm -f "$ZIG_JSON"
	if [ -z "$ZIG_URL" ]; then
		for U in \
			"https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
			"https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz"; do
			if curl -fsIL --max-time 30 "$U" >/dev/null 2>&1; then
				ZIG_URL="$U"
				break
			fi
		done
	fi
	[ -n "$ZIG_URL" ] || die "找不到 Zig ${ZIG_VERSION} 的 x86_64-linux 下载地址"
	ZIG_TMP="$(mktemp -d)"
	curl -fsSL --retry 5 --retry-all-errors --max-time 300 \
		-o "$ZIG_TMP/zig.tar.xz" "$ZIG_URL" || die "Zig 下载失败"
	if [ -n "$ZIG_SHA" ]; then
		echo "$ZIG_SHA  $ZIG_TMP/zig.tar.xz" | sha256sum -c - || die "Zig sha256 校验失败"
	fi
	rm -rf "$ZIG_DIR"
	mkdir -p "$ZIG_DIR"
	tar -xJf "$ZIG_TMP/zig.tar.xz" -C "$ZIG_DIR" --strip-components=1 \
		|| die "Zig 解包失败"
	rm -rf "$ZIG_TMP"
fi
[ -x "${ZIG_DIR}/zig" ] || die "${ZIG_DIR}/zig 不存在"
# build_honk_core.sh 会把 $HOME/.cargo/bin 放到 PATH 最前；给 zig 建个链接，
# 避免 runner 上同名 zig 抢占版本。
mkdir -p "$CARGO_HOME/bin"
ln -sf "${ZIG_DIR}/zig" "$CARGO_HOME/bin/zig"
say "zig $("${ZIG_DIR}/zig" version)"

# ===========================================================================
# 4) bpf-linker（honk pins.env 的版本 + sha256；产物直接放 $CARGO_HOME/bin）
# ===========================================================================
BPF_URL="https://github.com/aya-rs/bpf-linker/releases/download/v${BPF_LINKER_VERSION}/bpf-linker-x86_64-unknown-linux-musl.tar.zst"
if [ ! -x "$CARGO_HOME/bin/bpf-linker" ]; then
	say "安装 bpf-linker ${BPF_LINKER_VERSION}"
	mkdir -p "$TOOL_BIN"
	curl -fsSL --retry 5 --retry-all-errors --max-time 120 \
		-o "$TOOL_BIN/bpf-linker.tar.zst" "$BPF_URL" || die "bpf-linker 下载失败"
	echo "${BPF_LINKER_SHA256}  $TOOL_BIN/bpf-linker.tar.zst" | sha256sum -c - \
		|| die "bpf-linker sha256 校验失败"
	zstd -dc "$TOOL_BIN/bpf-linker.tar.zst" | tar -xf - -C "$TOOL_BIN" \
		|| die "bpf-linker 解包失败"
	install -m 0755 "$TOOL_BIN/bpf-linker" "$CARGO_HOME/bin/bpf-linker"
	rm -f "$TOOL_BIN/bpf-linker.tar.zst"
fi
[ -x "$CARGO_HOME/bin/bpf-linker" ] || die "bpf-linker 未安装成功"
say "bpf-linker $("$CARGO_HOME/bin/bpf-linker" --version 2>/dev/null | head -n1)"

# ===========================================================================
# 5) 源码编译（源码目录在 .rust-build/honk/src，随缓存复用）
# ===========================================================================
ensure_honk_src
say "源码编译 honk-core（${TRIPLE}）"
HONK_MAKEFILE="${PKG_DIR}/Makefile" \
CARGO_HOME="$CARGO_HOME" \
RUSTUP_HOME="$RUSTUP_HOME" \
PATH="$CARGO_HOME/bin:$TOOL_BIN:$ZIG_DIR:$PATH" \
	bash "${PKG_DIR}/build_honk_core.sh" --if-needed "$ARCH" "$OUT_BIN" "$SRC_DIR"

[ -s "$OUT_BIN" ] || die "编译结束但 ${OUT_BIN} 不存在"
[ -f "$OUT_BIN.stamp" ] || die "编译结束但 ${OUT_BIN}.stamp 不存在"
case "$(file -b "$OUT_BIN")" in
	ELF*) ;;
	*) die "honk-core 不是 ELF：$(file -b "$OUT_BIN")" ;;
esac
if [[ "$TRIPLE" == *-musl ]] && [[ "$(file -b "$OUT_BIN")" != *"statically linked"* ]]; then
	die "honk-core 不是静态链接：$(file -b "$OUT_BIN")"
fi
EXPECT_MACHINE="AArch64"
[ "$ARCH" = "x86_64" ] && EXPECT_MACHINE="X86-64"
readelf -h "$OUT_BIN" | grep -q "Machine:.*${EXPECT_MACHINE}" \
	|| die "honk-core 架构不是 ${EXPECT_MACHINE}：$(readelf -h "$OUT_BIN" | grep Machine || true)"

SRC_REV="$(git -C "$SRC_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
{
	echo "src_rev=${SRC_REV}"
	echo "triple=${TRIPLE}"
	echo "pkg_version=$(sed -n 's/^PKG_VERSION:=//p' "${PKG_DIR}/Makefile" | head -n1)"
	echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$INFO"

say "编译完成：${OUT_BIN}（$(du -h "$OUT_BIN" | cut -f1)，src ${SRC_REV}，${TRIPLE}）"

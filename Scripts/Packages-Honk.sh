#!/bin/bash
# SPDX-License-Identifier: MIT
# luci-app-honk 取包：把 QiuSimons/luci-app-honk 的 honk / luci-app-honk
# 两个包放进 package/，并在 defconfig 前准备 honk-core 的源码编译工具链。
#
# ── 为什么不再用上游预编译 core ──────────────────────────────────────────
# 上游 Release 只发 aarch64_generic 的 ipk/apk；H5000M 实机是 Cortex-A53，
# OpenWrt 给它打的包架构是 aarch64_cortex-a53，apk 会直接拒绝
# aarch64_generic 的包。改为在 honk 的 Build/Compile 里用包内
# build_honk_core.sh 从源码编译，产物架构跟随 target，最终 honk apk 的
# 架构就是 aarch64_cortex-a53，实机可以正常安装。
#
# ── 工具链 ──────────────────────────────────────────────────────────────
# honk-core 是 Rust + eBPF（zig / bpf-linker / nightly）程序，源码编译需要：
#   - rustup / cargo（stable 用于构建，脚本内部再装 nightly + rust-src）
#   - Zig（版本由上游 release.yml 的 setup-zig 钉死）
#   - bpf-linker（版本与 sha256 由上游 .github/ci/pins.env 钉死）
#   - clang / llvm / libbpf-dev / cmake / libclang-dev / zstd / xz
# 本脚本把它们装到 $HOME，并把 $HOME/.cargo/bin 与 Zig 目录写进
# $GITHUB_PATH；后续 make 步骤的 Build/Compile 直接继承 PATH。
#
# 用法（在 OpenWrt 源码树的 package/ 目录下执行）：
#   $GITHUB_WORKSPACE/Scripts/Packages-Honk.sh
#
# 环境变量（均可选）：
#   HONK_REPO 上游仓库，默认 QiuSimons/luci-app-honk
#   HONK_REF  上游分支/tag/commit，默认 honk_2026.11.15_a9925bd-r1
#             （包骨架与 HONK_SRC_VERSION 同源，升级时一起改）
#   WRT_TEST  true 时跳过工具链安装（TEST 模式只出配置、不编译固件）
set -euo pipefail

PKG1="honk"
PKG2="luci-app-honk"
REPO="${HONK_REPO:-QiuSimons/luci-app-honk}"
REF="${HONK_REF:-honk_2026.11.15_a9925bd-r1}"
UPSTREAM=".${PKG1}-upstream"
TOOL_TMP=""

say() { echo "==> $*"; }
die() { echo "::error::$*" >&2; exit 1; }
cleanup() { [ -n "${TOOL_TMP:-}" ] && rm -rf "$TOOL_TMP" || true; }
trap cleanup EXIT INT TERM

# ===========================================================================
# 0) 取上游包骨架（honk + luci-app-honk）
# ===========================================================================
# 用 git init + fetch 而不是 `git clone --branch`：REF 既可能是 tag，也可能
# 是分支或 commit SHA，后者不接受 --branch。--depth=1 只取目标提交。
say "拉取 ${REPO}@${REF}"
rm -rf "./${PKG1}" "./${PKG2}" "./${UPSTREAM}"
git init -q "./${UPSTREAM}"
git -C "./${UPSTREAM}" remote add origin "https://github.com/${REPO}.git"
git -C "./${UPSTREAM}" fetch --depth=1 origin "${REF}"
git -C "./${UPSTREAM}" checkout -q --detach FETCH_HEAD

SRC_REV="$(git -C "./${UPSTREAM}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
say "上游提交 ${SRC_REV}"

# 布局断言：上游若调整仓库结构，显式失败而不是产出缺文件的包
for D in "${PKG1}" "${PKG2}"; do
	[ -d "./${UPSTREAM}/${D}" ] || die "${UPSTREAM}/${D} 不存在：上游仓库布局可能已变更"
done

cp -a "./${UPSTREAM}/${PKG1}" "./${PKG1}"
cp -a "./${UPSTREAM}/${PKG2}" "./${PKG2}"
rm -rf "./${UPSTREAM}" "./${PKG1}/.git" "./${PKG2}/.git"

# 行尾归一化：Makefile 的 include 路径若带 CR，会报
# "No such file or directory"；init.d 的 shebang 带 CR，procd 直接启动失败。
# 只处理构建链路上的文本文件，不动 doona 的 JS 静态资源（浏览器能容忍 CRLF）。
for F in \
	"./${PKG1}/Makefile" \
	"./${PKG1}/build_honk_core.sh" \
	"./${PKG1}/honk_toolchain.sh" \
	"./${PKG1}/files/honk.init" \
	"./${PKG2}/Makefile" \
	"./${PKG2}/root/usr/share/honk/download_dashboard.sh"; do
	[ -f "$F" ] || die "$F 缺失：上游目录结构可能已调整"
	sed -i 's/\r$//' "$F"
done

# 可执行位：clone 会保留上游 mode，但上游若曾以 Windows 提交或经过 archive
# 下载，x 位可能丢失。显式补齐，缺失时直接失败（这四个文件都必须可执行）。
chmod +x \
	"./${PKG1}/build_honk_core.sh" \
	"./${PKG1}/honk_toolchain.sh" \
	"./${PKG1}/files/honk.init" \
	"./${PKG2}/root/usr/share/honk/download_dashboard.sh"

# ===========================================================================
# 1) 包骨架自检（防上游回归）
# ===========================================================================
MK="./${PKG1}/Makefile"
LMK="./${PKG2}/Makefile"
[ -f "$MK" ] || die "${MK} 不存在"
[ -f "$LMK" ] || die "${LMK} 不存在"

grep -q 'HONK_SRC_VERSION' "$MK" || die "${MK} 未声明 HONK_SRC_VERSION：上游包结构可能已变更"
grep -q 'build_honk_core.sh' "$MK" || die "${MK} 不再调用 build_honk_core.sh：源码编译路径失效"
grep -q 'HONK_RUST_ARCH_DEPENDS' "$MK" || die "${MK} 缺少架构约束（上游可能已放弃 aarch64/x86_64 限制）"
grep -q 'luci.mk' "$LMK" || die "${LMK} 未 include feeds/luci/luci.mk"

VER="$(sed -n 's/^PKG_VERSION:=//p' "$MK" | head -n1)"
REL="$(sed -n 's/^PKG_RELEASE:=//p' "$MK" | head -n1)"
[ -n "$VER" ] || die "${MK} 未声明 PKG_VERSION"
[ -n "$REL" ] || die "${MK} 未声明 PKG_RELEASE"
say "包版本 ${VER}-r${REL}"

# 当前方案必须走源码编译：清掉任何预编译 core / stamp，避免 --if-needed
# 误判为「已是最新」而跳过编译（预编译 aarch64_generic 正是要淘汰的路径）。
rm -f "./${PKG1}/files/honk-core.bin" "./${PKG1}/files/honk-core.bin.stamp"

# ===========================================================================
# 2) 源码编译工具链（Rust / Zig / bpf-linker / clang...）
# ===========================================================================
install_honk_toolchain() {
	local MK="./${PKG1}/Makefile"
	local ZIG_DIR="$HOME/.honk-zig"
	local CARGO_BIN_DIR
	local ZIG_JSON ZIG_URL ZIG_SHA
	local BPF_URL

	say "准备 honk-core 源码编译工具链（Rust / Zig / bpf-linker）"

	# 2.1 系统依赖：与上游 release.yml 的 Install dependencies 对齐
	if command -v apt-get >/dev/null 2>&1; then
		if sudo -n true 2>/dev/null; then
			sudo apt-get update -qq || true
			sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
				clang llvm libbpf-dev pkg-config cmake libclang-dev zstd xz-utils binutils \
				|| die "honk: 安装源码编译依赖失败（clang/llvm/libbpf-dev/libclang-dev/zstd 等）"
		else
			say "无 sudo：跳过 apt 安装，假定 runner 已预装 clang/llvm/libbpf-dev 等"
		fi
	fi

	# 2.2 rustup / cargo
	if ! command -v rustup >/dev/null 2>&1 || ! command -v cargo >/dev/null 2>&1; then
		say "安装 rustup（minimal profile）"
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
			| sh -s -- -y --profile minimal --no-modify-path \
			|| die "honk: rustup 安装失败"
	fi
	export PATH="$HOME/.cargo/bin:$PATH"
	command -v cargo >/dev/null 2>&1 || die "honk: cargo 不在 PATH"
	command -v rustup >/dev/null 2>&1 || die "honk: rustup 不在 PATH"
	CARGO_BIN_DIR="$(dirname "$(command -v cargo)")"

	# 2.3 读取上游钉死的 Zig / bpf-linker 版本与校验和
	eval "$("./${PKG1}/honk_toolchain.sh" "$MK")"
	[ -n "${ZIG_VERSION:-}" ] || die "honk: 未解析到 ZIG_VERSION（上游 release.yml 可能已变更）"
	[ -n "${BPF_LINKER_VERSION:-}" ] || die "honk: 未解析到 BPF_LINKER_VERSION"
	[ -n "${BPF_LINKER_SHA256:-}" ] || die "honk: 未解析到 BPF_LINKER_SHA256"

	# 2.4 Zig：优先用官方 index.json 精确 URL + sha256；兼容新旧文件名
	if [ -x "$ZIG_DIR/zig" ] && [ "$("$ZIG_DIR/zig" version 2>/dev/null)" = "$ZIG_VERSION" ]; then
		say "复用 Zig ${ZIG_VERSION}"
	else
		rm -rf "$ZIG_DIR"
		ZIG_JSON="$(curl -fsSL --retry 5 --retry-all-errors --max-time 60 \
			https://ziglang.org/download/index.json)" \
			|| die "honk: 读取 ziglang.org index.json 失败"
		ZIG_URL="$(printf '%s' "$ZIG_JSON" | jq -r --arg v "$ZIG_VERSION" \
			'.[$v]["x86_64-linux"].tarball // empty')"
		ZIG_SHA="$(printf '%s' "$ZIG_JSON" | jq -r --arg v "$ZIG_VERSION" \
			'.[$v]["x86_64-linux"].shasum // empty')"
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
		[ -n "$ZIG_URL" ] || die "honk: 找不到 Zig ${ZIG_VERSION} 的 x86_64-linux 下载地址"
		mkdir -p "$ZIG_DIR"
		say "下载 Zig ${ZIG_VERSION}"
		curl -fsSL --retry 5 --retry-all-errors --max-time 300 \
			-o "$TOOL_TMP/zig.tar.xz" "$ZIG_URL" || die "honk: Zig 下载失败"
		if [ -n "$ZIG_SHA" ]; then
			echo "$ZIG_SHA  $TOOL_TMP/zig.tar.xz" | sha256sum -c - \
				|| die "honk: Zig 压缩包 sha256 校验失败"
		fi
		tar -xJf "$TOOL_TMP/zig.tar.xz" -C "$ZIG_DIR" --strip-components=1 \
			|| die "honk: Zig 解包失败（缺 xz？）"
	fi
	[ -x "$ZIG_DIR/zig" ] || die "honk: $ZIG_DIR/zig 不存在"

	# 2.5 bpf-linker：始终按上游 version + sha256 重新落位，避免 runner
	#     预装的版本与 honk 钉死的 0.11.0 不一致（bpf-linker --version 会误报 0.0.0）
	mkdir -p "$HOME/.cargo/bin"
	BPF_URL="https://github.com/aya-rs/bpf-linker/releases/download/v${BPF_LINKER_VERSION}/bpf-linker-x86_64-unknown-linux-musl.tar.zst"
	say "下载 bpf-linker ${BPF_LINKER_VERSION}"
	curl -fsSL --retry 5 --retry-all-errors --max-time 120 \
		-o "$TOOL_TMP/bpf-linker.tar.zst" "$BPF_URL" \
		|| die "honk: bpf-linker 下载失败"
	echo "$BPF_LINKER_SHA256  $TOOL_TMP/bpf-linker.tar.zst" | sha256sum -c - \
		|| die "honk: bpf-linker sha256 校验失败"
	zstd -dc "$TOOL_TMP/bpf-linker.tar.zst" | tar -xf - -C "$HOME/.cargo/bin" \
		|| die "honk: bpf-linker 解包失败（缺 zstd？）"
	chmod +x "$HOME/.cargo/bin/bpf-linker"

	export PATH="$HOME/.cargo/bin:$ZIG_DIR:$PATH"
	command -v zig >/dev/null 2>&1 || die "honk: zig 不在 PATH"
	command -v bpf-linker >/dev/null 2>&1 || die "honk: bpf-linker 不在 PATH"

	# 2.6 让后续 make 步骤继承 PATH
	if [ -n "${GITHUB_PATH:-}" ]; then
		for P in "$HOME/.cargo/bin" "$ZIG_DIR" "$CARGO_BIN_DIR"; do
			grep -qxF "$P" "$GITHUB_PATH" 2>/dev/null || echo "$P" >> "$GITHUB_PATH"
		done
	else
		say "非 GitHub Actions：请把 $HOME/.cargo/bin 与 $ZIG_DIR 加入 PATH 后再 make"
	fi

	say "工具链就绪：zig $(zig version)，bpf-linker $(bpf-linker --version 2>/dev/null | head -n1)"
}

if [ "${WRT_TEST:-false}" = "true" ]; then
	say "WRT_TEST=true，跳过 honk 源码编译工具链安装（TEST 模式不编译）"
else
	TOOL_TMP="$(mktemp -d)"
	install_honk_toolchain
fi

# ===========================================================================
# 3) 源码编译路径确认
# ===========================================================================
[ -x "./${PKG1}/build_honk_core.sh" ] || die "${PKG1}/build_honk_core.sh 不可执行"
[ ! -e "./${PKG1}/files/honk-core.bin" ] || die "${PKG1}/files/honk-core.bin 仍存在：必须由 Build/Compile 源码生成"

say "${PKG1} 目录：$(cd "./${PKG1}" && ls | tr '\n' ' ')"
say "${PKG2} 目录：$(cd "./${PKG2}" && ls | tr '\n' ' ')"
echo "==> honk-core 将按源码编译（Build/Compile → build_honk_core.sh），不再下载上游预编译 core。"

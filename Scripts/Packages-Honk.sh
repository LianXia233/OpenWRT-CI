#!/bin/bash
# SPDX-License-Identifier: MIT
# luci-app-honk 取包：把 QiuSimons/luci-app-honk 的 honk / luci-app-honk
# 两个包放进 package/，并用上游同版本 Release 里的预编译 honk-core 顶替
# 源码编译（Rust + eBPF 工具链太重，会挤爆 GitHub 6 小时构建上限）。
#
# 用法（在 OpenWrt 源码树的 package/ 目录下执行）：
#   $GITHUB_WORKSPACE/Scripts/Packages-Honk.sh
#
# 环境变量（均可选）：
#   HONK_REPO   上游仓库，默认 QiuSimons/luci-app-honk
#   HONK_REF    上游分支/tag/commit，默认 honk_2026.11.15_a9925bd-r1
#               （与 honk/Makefile 的 PKG_VERSION 严格同源：同一个 tag
#                里的包骨架与 Release 资产一一对应，避免「包版本领先/落后
#                于预编译 core」的半旧半新组合）
#   HONK_TAG    强制指定 Release tag；留空时 REF 是 honk_* 就直接复用，
#               否则按 Makefile 的 PKG_VERSION/PKG_RELEASE 推导
#   HONK_ARCH   目标架构，仅 aarch64_generic / x86_64；留空按 WRT_TARGET 推导
#
# ── 为什么不写进 Scripts/Packages.sh ──────────────────────────────────────
# Packages.sh 是全机型共用入口，任何改动都会连带影响 H5000M / AP3000M / X86
# 的所有变体。honk 目前只服务作者自用的 H5000M-WIFI-YES-NETMONITOR（Release
# 单独归组「自用」），因此独立成脚本，由 WRT-CORE 中
# env.WRT_HONK == 'true' 的步骤调用；其余配置不执行本脚本。
#
# ── 依赖闭环 ─────────────────────────────────────────────────────────────
# 本脚本只负责「把包和二进制放到位」，依赖交给 OpenWrt 正常解析：
#   - honk/Makefile 的 DEPENDS（kmod-sched-core / kmod-sched-bpf / kmod-veth /
#     kmod-nft-queue / v2ray-geoip / v2ray-geosite / ca-bundle）由 defconfig
#     与 apk 打包器在构建期校验，不再走「首启 apk add」那种离线安装；
#   - luci-app-honk/Makefile 的 LUCI_DEPENDS（+honk +luci-base
#     +rpcd-mod-ucode +unzip）同样交给 luci.mk 解析；
#   - eBPF CO-RE 需要的内核 BTF 不在本脚本里造，由配置文件显式打开
#     CONFIG_KERNEL_DEBUG_INFO_BTF=y（见 Config/H5000M-WIFI-YES-NETMONITOR.txt）。
set -euo pipefail

PKG1="honk"
PKG2="luci-app-honk"
REPO="${HONK_REPO:-QiuSimons/luci-app-honk}"
REF="${HONK_REF:-honk_2026.11.15_a9925bd-r1}"
UPSTREAM=".${PKG1}-upstream"

say() { echo "==> $*"; }
die() { echo "::error::$*" >&2; exit 1; }

# ===========================================================================
# 0) 目标架构 → 上游 Release 资产里的架构段
# ===========================================================================
# honk-core 只支持 aarch64 / x86_64（上游 Makefile 用
# HONK_RUST_ARCH_DEPENDS:=@(aarch64||x86_64) 做约束）。这里提前判定，
# 让「架构不支持」在取包阶段带着清晰说明失败，而不是等 defconfig 把包
# 静默丢掉、最后固件里少一个插件。
HONK_ARCH="${HONK_ARCH:-}"
if [ -z "$HONK_ARCH" ]; then
	case "${WRT_TARGET:-}" in
		x86*) HONK_ARCH="x86_64" ;;
		mediatek) HONK_ARCH="aarch64_generic" ;;
		aarch64*) HONK_ARCH="aarch64_generic" ;;
		"") : ;;
		*) die "honk: 不支持的目标平台 '${WRT_TARGET}'（仅支持 mediatek aarch64 与 x86_64）" ;;
	esac
fi
# WRT_TARGET 未导出时（本地手跑）回退读配置文件，避免依赖调用方的环境
if [ -z "$HONK_ARCH" ]; then
	CFG_ROOT="${GITHUB_WORKSPACE:-$(pwd)/../..}/Config"
	if [ -n "${WRT_CONFIG:-}" ] && [ -f "${CFG_ROOT}/${WRT_CONFIG}.txt" ]; then
		if grep -q '^CONFIG_TARGET_x86=y' "${CFG_ROOT}/${WRT_CONFIG}.txt"; then
			HONK_ARCH="x86_64"
		else
			HONK_ARCH="aarch64_generic"
		fi
	fi
fi
[ -n "$HONK_ARCH" ] || die "honk: 无法判定目标架构（HONK_ARCH / WRT_TARGET / WRT_CONFIG 均为空）"

case "$HONK_ARCH" in
	aarch64_generic|x86_64) ;;
	*) die "honk: 不支持的目标架构 '${HONK_ARCH}'（上游仅提供 aarch64_generic / x86_64）" ;;
esac
say "目标架构 ${HONK_ARCH}"

# ===========================================================================
# 1) 取上游包骨架（honk + luci-app-honk）
# ===========================================================================
# 用 git init + fetch 而不是 `git clone --branch`：REF 既可能是 tag，也可能
# 是分支或 commit SHA，后者不接受 --branch。--depth=1 只取目标提交，仓库里
# 的 PIC/README 等发布构建用不到的目录随后统一清掉。
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
# 2) 包骨架自检（防上游回归）
# ===========================================================================
MK="./${PKG1}/Makefile"
LMK="./${PKG2}/Makefile"
[ -f "$MK" ] || die "${MK} 不存在"
[ -f "$LMK" ] || die "${LMK} 不存在"

grep -q 'HONK_SRC_VERSION' "$MK" || die "${MK} 未声明 HONK_SRC_VERSION：上游包结构可能已变更"
grep -q 'build_honk_core.sh' "$MK" || die "${MK} 不再调用 build_honk_core.sh：预编译 core 的落点会失效"
grep -q 'HONK_RUST_ARCH_DEPENDS' "$MK" || die "${MK} 缺少架构约束（上游可能已放弃 aarch64/x86_64 限制）"
grep -q 'luci.mk' "$LMK" || die "${LMK} 未 include feeds/luci/luci.mk"

VER="$(sed -n 's/^PKG_VERSION:=//p' "$MK" | head -n1)"
REL="$(sed -n 's/^PKG_RELEASE:=//p' "$MK" | head -n1)"
[ -n "$VER" ] || die "${MK} 未声明 PKG_VERSION"
[ -n "$REL" ] || die "${MK} 未声明 PKG_RELEASE"
say "包版本 ${VER}-r${REL}"

# ===========================================================================
# 3) Release tag 对齐
# ===========================================================================
# 默认 REF 本身就是发布 tag（honk_<PKG_VERSION 的 ~ 换成 _>-r<REL>），
# 这里默认直接复用；只有把 REF 改成 master / 某个 commit 时才按 Makefile
# 推导。推导出来的 tag 若在上游不存在，会在下一步资产页解析时明确报错，
# 而不是让构建在几十页日志之后才暴露「包版本与资产版本错位」。
TAG="${HONK_TAG:-}"
if [ -z "$TAG" ]; then
	case "$REF" in
		honk_*) TAG="$REF" ;;
		*) TAG="honk_$(printf '%s' "$VER" | tr '~' '_')-r${REL}" ;;
	esac
fi
say "Release tag ${TAG}"

# ===========================================================================
# 4) 按架构下载上游预编译包，抽出静态 honk-core
# ===========================================================================
# 上游 Release 同时发布 24.10 的 ipk 与 25.12 的 apk。这里刻意取 ipk：
#   - honk-core 是静态 musl ELF，与 OpenWrt 发行版的打包格式无关；
#   - ipk 是 ar + data.tar.gz，ar/tar 在 runner 上是标配，解包链路最短；
#   - apk（25.12 起）是 apk v3 二进制容器，需要 apk 工具才能解，平白多一层
#     失败点，而我们要的只是里面的 /usr/bin/honk-core。
say "解析 ${REPO} 的 Release 资产页…"
# 不用 api.github.com：Actions 里的 GITHUB_TOKEN 只对当前仓库有效，拿去调
# QiuSimons 的 API 会 403；匿名调用又会被 runner 共享 IP 的 60 次/小时限流
# 打回（本地演练已实测 403）。GitHub 的 releases/expanded_assets 页面是
# 公开 HTML，不受 API 限流影响，上游自己的 download_dashboard.sh 也用它。
ASSETS_HTML="$(curl -fsSL --retry 5 --retry-all-errors --max-time 60 \
	-A "OpenWRT-CI honk fetch" \
	"https://github.com/${REPO}/releases/expanded_assets/${TAG}")" \
	|| die "honk: 无法读取 ${REPO} 的 Release '${TAG}' 资产页（网络或 tag 不存在）"

URL_PATH="$(printf '%s' "$ASSETS_HTML" \
	| grep -o "/${REPO}/releases/download/${TAG}/[^\"']*" \
	| grep -E "honk[-_].*[-_]${HONK_ARCH}-openwrt-24\\.10.*\\.ipk$" \
	| head -n1 || true)"
if [ -z "$URL_PATH" ] && [ -n "${HONK_TOKEN:-}" ]; then
	say "资产页未匹配到 ipk，改用 API（HONK_TOKEN 已配置）"
	REL_JSON="$(curl -fsSL --retry 5 --retry-all-errors --max-time 60 \
		-H "Authorization: Bearer ${HONK_TOKEN}" \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/${REPO}/releases/tags/${TAG}")" \
		|| die "honk: API 也读不到 Release '${TAG}'"
	URL="$(printf '%s' "$REL_JSON" | jq -r --arg arch "$HONK_ARCH" \
		'.assets[]? | select(.name | test("^honk[-_].*[-_]" + $arch + "-openwrt-24\\.[0-9.]+.*\\.ipk$")) | .browser_download_url' \
		| head -n1 || true)"
else
	[ -n "$URL_PATH" ] || die "honk: Release '${TAG}' 没有 ${HONK_ARCH} 的 24.10 ipk 资产（上游资产命名可能已变更）"
	URL="https://github.com${URL_PATH}"
fi
[ -n "${URL:-}" ] || die "honk: Release '${TAG}' 没有 ${HONK_ARCH} 的 24.10 ipk 资产（上游资产命名可能已变更）"
say "下载 $(basename "$URL")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
curl -fsSL --retry 5 --retry-all-errors --max-time 300 \
	-o "$TMP/honk.ipk" "$URL" || die "honk: 预编译包下载失败"

mkdir -p "$TMP/unpack"
( cd "$TMP" && ar x honk.ipk ) 2>/dev/null || \
	( cd "$TMP" && tar xf honk.ipk ) || die "honk: 无法解开 ipk（缺 ar/tar？）"
[ -f "$TMP/data.tar.gz" ] || die "honk: ipk 内没有 data.tar.gz，格式可能已变更"

tar xzf "$TMP/data.tar.gz" -C "$TMP/unpack" ./usr/bin/honk-core 2>/dev/null \
	|| tar xzf "$TMP/data.tar.gz" -C "$TMP/unpack" usr/bin/honk-core 2>/dev/null \
	|| die "honk: data.tar.gz 内没有 honk-core（路径可能已变更）"
[ -s "$TMP/unpack/usr/bin/honk-core" ] || die "honk: 抽出的 honk-core 为空"

# 架构与静态链接核验：宁可现在失败，也不要把「宿主架构的 core」打进固件
#（这种错误要到设备上 `honk-core: not found` / exec format error 才暴露）。
command -v file >/dev/null 2>&1 || die "honk: runner 缺 file 命令，无法校验 honk-core 架构"
FILE_DESC="$(file -b "$TMP/unpack/usr/bin/honk-core")"
case "$HONK_ARCH" in
	aarch64_generic) EXPECT_MACH="ARM aarch64" ;;
	x86_64)          EXPECT_MACH="x86-64" ;;
esac
case "$FILE_DESC" in
	*ELF\ 64-bit*"$EXPECT_MACH"*) ;;
	*) die "honk: honk-core 不是 ${EXPECT_MACH} 的 ELF：${FILE_DESC}" ;;
esac
case "$FILE_DESC" in
	*"statically linked"*) ;;
	*) die "honk: honk-core 不是静态链接：${FILE_DESC}" ;;
esac
say "core 架构核验通过：${FILE_DESC}"

# 落位到包目录：build_honk_core.sh --if-needed 看到「有 bin、无 .stamp」时
# 直接判定为预编译产物并跳过全部 Rust/Zig/bpf-linker 工具链。
# 必须显式删 .stamp：上游若在包里留下 stamp，脚本会按架构戳重编译。
install -m 0755 "$TMP/unpack/usr/bin/honk-core" "./${PKG1}/files/honk-core.bin"
rm -f "./${PKG1}/files/honk-core.bin.stamp"

say "honk-core 就位：$(du -h "./${PKG1}/files/honk-core.bin" | cut -f1)"
say "${PKG1} 目录：$(cd "./${PKG1}" && ls | tr '\n' ' ')"
say "${PKG2} 目录：$(cd "./${PKG2}" && ls | tr '\n' ' ')"
echo "==> 预编译 honk-core 已就位；依赖将由 defconfig / apk 在构建期解析，不做首启安装。"

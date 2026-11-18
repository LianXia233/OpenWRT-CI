#!/bin/bash
# SPDX-License-Identifier: MIT
# =============================================================================
# Packages-Honk.sh — 把 QiuSimons/luci-app-honk 的包骨架放进 package/
#
# 与仓库其他 Rust 后端的边界保持一致：
#   - 本脚本只负责「取包 + 清理上游预编译 core」，不安装 Rust/Zig 工具链；
#   - honk-core 由 Scripts/Build-Honk-Prebuilt.sh 在 runner 侧用 rustup
#     官方 Rust SDK + Zig + bpf-linker 源码交叉编译（buildroot 外）；
#   - OpenWrt 的 Build/Compile 只做打包：包内 files/honk-core.bin 与
#     .stamp 存在且 target 匹配时，build_honk_core.sh --if-needed 直接跳过，
#     不会触发 buildroot 内 cargo，也不会触发 OpenWrt 的 rust/host SDK。
#
# 为什么必须源码编译：上游 Release 只发 aarch64_generic 的 ipk/apk，而
# H5000M 实机是 Cortex-A53，OpenWrt 包架构为 aarch64_cortex-a53，apk 会
# 直接拒绝 aarch64_generic。源码编译后 honk apk 的 PKGARCH 跟随 target。
#
# 用法（工作目录必须是 OpenWrt 源码树的 package/）：
#   $GITHUB_WORKSPACE/Scripts/Packages-Honk.sh
#
# 环境变量（均可选）：
#   HONK_REPO   默认 https://github.com/QiuSimons/luci-app-honk
#   HONK_REF    默认 honk_2026.11.15_a9925bd-r1（须与 honk/Makefile 的
#               PKG_VERSION 同源；升级时改这里）
#   HONK_WORK   临时 clone 目录，默认 mktemp
# =============================================================================
set -euo pipefail

REPO="${HONK_REPO:-https://github.com/QiuSimons/luci-app-honk}"
REF="${HONK_REF:-honk_2026.11.15_a9925bd-r1}"
WORK="${HONK_WORK:-}"

say() { echo "==> $*"; }
die() { echo "::error::$*" >&2; exit 1; }
[ "$(basename "$PWD")" = "package" ] || die "请在 OpenWrt 源码树的 package/ 目录下执行"

if [ -z "$WORK" ]; then
	WORK="$(mktemp -d)"
fi
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK"

say "拉取 ${REPO}@${REF}"
git -C "$WORK" init -q
git -C "$WORK" remote add origin "$REPO"
git -C "$WORK" fetch --depth=1 origin "$REF"
git -C "$WORK" checkout -q --detach FETCH_HEAD

REV="$(git -C "$WORK" rev-parse --short HEAD)"
VERSION="$(sed -n 's/^PKG_VERSION:=//p' "$WORK/honk/Makefile" | head -n1)"
say "上游提交 ${REV}，包版本 ${VERSION:-unknown}"

rm -rf "$PWD/honk" "$PWD/luci-app-honk"
cp -a "$WORK/honk" "$PWD/honk"
cp -a "$WORK/luci-app-honk" "$PWD/luci-app-honk"

# 上游 Release 的预编译 core 绝不能进 buildroot：--if-needed 会把它当成
# 「无 stamp 的预编译产物」直接跳过，最终 apk 里的 core 仍是 aarch64_generic。
rm -f "$PWD/honk/files/honk-core.bin" "$PWD/honk/files/honk-core.bin.stamp"

chmod +x "$PWD/honk/build_honk_core.sh" "$PWD/honk/honk_toolchain.sh" 2>/dev/null || true

[ -f "$PWD/honk/Makefile" ] || die "honk/Makefile 不存在"
[ -f "$PWD/honk/build_honk_core.sh" ] || die "honk/build_honk_core.sh 不存在"
[ -x "$PWD/honk/build_honk_core.sh" ] || die "honk/build_honk_core.sh 不可执行"
[ -f "$PWD/honk/honk_toolchain.sh" ] || die "honk/honk_toolchain.sh 不存在"
if [ -e "$PWD/honk/files/honk-core.bin" ]; then
	die "honk/files/honk-core.bin 不应存在：必须由 Build-Honk-Prebuilt.sh 源码编译"
fi
if [ -e "$PWD/honk/files/honk-core.bin.stamp" ]; then
	die "honk-core.bin.stamp 不应存在：必须由 Build-Honk-Prebuilt.sh 重新生成"
fi

say "honk 目录：$(cd "$PWD/honk" && ls | tr '\n' ' ')"
say "luci-app-honk 目录：$(cd "$PWD/luci-app-honk" && ls | tr '\n' ' ')"
say "已导入包骨架；honk-core 交由 Scripts/Build-Honk-Prebuilt.sh 在 runner 侧源码编译"
say "Rust 侧使用 rustup 官方 Rust SDK，不触发 OpenWrt 的 rust/host SDK"

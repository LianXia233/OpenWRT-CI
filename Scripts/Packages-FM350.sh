#!/bin/bash
# SPDX-License-Identifier: MIT
# FM350 变体专用：把 luci-app-fm350 源码放进 package/
#
# 为什么不写进 Scripts/Packages.sh：那是全机型共用入口，改动它会影响
# H5000M / AP3000M / X86 三套既有构建。FM350 变体才需要这个包，因此独立
# 成脚本，由 WRT-CORE 中带 contains(env.WRT_CONFIG,'FM350') 条件的步骤调用，
# 现有机型构建路径完全不执行本脚本。
#
# 用法（在 OpenWrt 源码树的 package/ 目录下执行）：
#   $GITHUB_WORKSPACE/Scripts/Packages-FM350.sh

set -euo pipefail

PKG_NAME=luci-app-fm350
PKG_REPO=LianXia233/luci-app-fm350
PKG_BRANCH="${FM350_BRANCH:-main}"

echo "==> 拉取 ${PKG_NAME}（${PKG_REPO}@${PKG_BRANCH}）"

# 幂等：重复执行先清干净，避免残留旧版本目录造成包内容混杂
rm -rf "./${PKG_NAME}"

git clone --depth=1 --single-branch --branch "${PKG_BRANCH}" \
	"https://github.com/${PKG_REPO}.git" "./${PKG_NAME}"

# 发布构建用不到的目录：.git 体积大，.github 是上游 CI，rust/target 是宿主产物
rm -rf "./${PKG_NAME}/.git" "./${PKG_NAME}/.github" "./${PKG_NAME}/rust/target"

# Makefile 必须 LF：CRLF 会让 include 路径带上 \r，报错几乎无法定位
if grep -qU $'\r' "./${PKG_NAME}/Makefile"; then
	echo "::error::${PKG_NAME}/Makefile 含 CR（行尾被转换）"
	exit 1
fi

echo "==> ${PKG_NAME} 就位：$(cd "./${PKG_NAME}" && ls | tr '\n' ' ')"

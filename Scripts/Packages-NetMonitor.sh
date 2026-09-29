#!/bin/bash
# SPDX-License-Identifier: MIT
# H5000M 自用（NETMONITOR）变体专用：把 luci-app-netmonitor 与 luci-app-taygedo 放进 package/
#
# 为什么不写进 Scripts/Packages.sh：那是全机型共用入口，改动它会影响
# H5000M / AP3000M / X86 三套既有构建。这两个插件只服务作者自用的
# H5000M-WIFI-YES-NETMONITOR 配置（Release 归组「自用」），因此独立成脚本，
# 由 WRT-CORE 中带 contains(env.WRT_CONFIG,'NETMONITOR') 条件的步骤调用，
# 现有机型构建路径完全不执行本脚本。
#
# 用法（在 OpenWrt 源码树的 package/ 目录下执行）：
#   $GITHUB_WORKSPACE/Scripts/Packages-NetMonitor.sh

set -euo pipefail

# ============================================================
# 1) luci-app-netmonitor：仓库根即 OpenWrt 包（Makefile 在根）
# ============================================================
# 上游仓库（LianXia233/luci-app-netmonitor，分支 main）根目录直接就是包：
#   Makefile / htdocs/ / po/ / root/ 平铺在根下，clone 到 package/luci-app-netmonitor
#   即为标准包目录，无需搬移。
#
# 重要：其 Makefile 刻意不设置 PKG_NAME，包名由 luci.mk 按目录名推导
# （LUCI_NAME=$(notdir ${CURDIR})）。因此目录名必须精确等于 luci-app-netmonitor，
# 且构建环境不得导出同名 PKG_NAME 环境变量（一旦导出，所有 luci 包的包名都会
# 被钉成同一个值，packageinfo/.config 错乱，compile 目标消失）。本仓库的
# WRT-CORE.yml / Packages.sh 均未设置该环境变量，安全。
PKG1=luci-app-netmonitor
REPO1=LianXia233/luci-app-netmonitor
BRANCH1="${NETMONITOR_BRANCH:-main}"

echo "==> 拉取 ${PKG1}（${REPO1}@${BRANCH1}）"
# 幂等：重复执行先清干净，避免残留旧版本目录造成包内容混杂
rm -rf "./${PKG1}"
git clone --depth=1 --single-branch --branch "${BRANCH1}" \
	"https://github.com/${REPO1}.git" "./${PKG1}"
# 发布构建用不到的目录：.git 体积大，.github 是上游 CI
rm -rf "./${PKG1}/.git" "./${PKG1}/.github"

# ============================================================
# 2) luci-app-taygedo：monorepo，包本体在 openwrt/luci-app-taygedo/
# ============================================================
# 上游仓库（LianXia233/taygedo-CI，分支 main）根目录是 Rust 工程
# （Cargo.toml / src/ / docs/ ...），OpenWrt 包在 openwrt/luci-app-taygedo/
# 一级子目录。OpenWrt 只认「package/<包名>/Makefile」这一层，因此必须把
# 子目录整体搬到 package/luci-app-taygedo/，不能直接 clone 到 package/ 根下。
#
# 该包走标准 include $(INCLUDE_DIR)/package.mk（非 luci.mk），PKG_NAME 显式
# 声明。Build/Prepare 从 GitHub Release（v$(PKG_VERSION)）下载预编译 musl
# 二进制 taygedo-rs-<triple>.tar.gz，不经 OpenWrt rust/host 源码构建；
# H5000M 为 aarch64（CONFIG_ARCH=aarch64）→ aarch64-unknown-linux-musl，
# 上游 v0.5.0 Release 已含该资产（taygedo-rs-aarch64-unknown-linux-musl.tar.gz）。
PKG2=luci-app-taygedo
REPO2=LianXia233/taygedo-CI
BRANCH2="${TAYGEDO_BRANCH:-main}"
REPO_DIR2=".taygedo-upstream"

echo "==> 拉取 ${PKG2}（${REPO2}@${BRANCH2}）"
rm -rf "./${PKG2}" "./${REPO_DIR2}"
git clone --depth=1 --single-branch --branch "${BRANCH2}" \
	"https://github.com/${REPO2}.git" "./${REPO_DIR2}"

# 布局断言：上游若调整 monorepo 结构，直接显式失败而不是产出缺文件的包
if [ ! -d "./${REPO_DIR2}/openwrt/${PKG2}" ]; then
	echo "::error::${REPO_DIR2}/openwrt/${PKG2} 不存在：上游仓库布局可能已变更"
	echo "openwrt/ 目录内容：$(ls -A "./${REPO_DIR2}/openwrt" 2>/dev/null | tr '\n' ' ')"
	rm -rf "./${REPO_DIR2}"
	exit 1
fi
mv "./${REPO_DIR2}/openwrt/${PKG2}" "./${PKG2}"
rm -rf "./${REPO_DIR2}"

# ===== 行尾归一化：CRLF → LF（本脚本的核心必要步骤）=====
#
# 两仓库的 .gitattributes 均为 `* text=auto eol=lf`（强制 LF），正常 clone
# 出来的文件就是 LF；此处仍做一次幂等归一化 + 逐文件复核，防止 runner 环境
# 漂移或上游改动 .gitattributes 时 CR 残留：
#   - Makefile：include 路径若带 \r，报 "No such file or directory"，包编不过；
#   - init.d / 脚本 shebang：变成 "#!/bin/sh /etc/rc.common\r"，procd 启动失败；
#   - menu.d / acl.d JSON：\r 是字符串外的非法空白，LuCI 解析失败。
#
# 为什么不能依赖 WRT-CORE.yml 里既有的「脚本格式规整（CRLF → LF）」步骤：
# 那一步只覆盖 OpenWrt 源码树顶层三级的 txt/sh，且执行时机在取包之前 ——
# 本脚本落盘的文件它完全看不到，顺序上已错过。因此必须在包就位后就地转换。
#
# 用 sed 一次性扫过全部文件：不含 CR 的文件是无副作用的空操作，
# 因此不需要先逐个 grep 判断。
mapfile -t PKG_FILES < <(find "./${PKG1}" "./${PKG2}" -type f)
sed -i 's/\r$//' "${PKG_FILES[@]}"

# 转换后复核：逐文件按字节判定是否仍含 CR。
# 不用 `grep -qU $'\r'`：该写法在 Git Bash / MSYS 下对 CR 的匹配语义不可靠，
# 改用 POSIX 参数展开 `$(cat "$F" | tr -d '\r')` 前后长度比较，
# 只依赖 tr 与 ${#var}，跨平台行为一致。
CR_LEFT_FILES=()
for F in "${PKG_FILES[@]}"; do
	ORIG_LEN=$(wc -c < "$F")
	STRIPPED_LEN=$(tr -d '\r' < "$F" | wc -c)
	if [ "$ORIG_LEN" != "$STRIPPED_LEN" ]; then
		CR_LEFT_FILES+=("$F")
	fi
done

if [ "${#CR_LEFT_FILES[@]}" -ne 0 ]; then
	echo "::error::${PKG1} / ${PKG2} 仍存在含 CR 的文件，行尾归一化未完成"
	for F in "${CR_LEFT_FILES[@]}"; do
		echo "  含 CR: $F"
	done
	exit 1
fi
echo "==> 行尾复核通过：${#PKG_FILES[@]} 个文件均为 LF"

# 可执行位补齐：git clone 会保留上游 mode，但上游若曾以 Windows 提交或经过
# archive 下载，x 位可能丢失，导致 procd 启动 init.d 时 Permission denied。
# 路径与上游仓库实测目录结构一致；缺失时仅告警不中断（防御性）。
for FILE in \
	"./${PKG1}/root/etc/init.d/netmonitor" \
	"./${PKG1}/root/usr/libexec/netmonitor/netmon-daemon.sh" \
	"./${PKG2}/root/etc/init.d/taygedo"; do
	if [ -f "$FILE" ]; then
		chmod +x "$FILE"
	else
		echo "::warning::${FILE} 缺失：上游目录结构可能已调整"
	fi
done

echo "==> ${PKG1} / ${PKG2} 就位：$(cd "./${PKG1}" && ls | tr '\n' ' ')"
echo "==> ${PKG2} 就位：$(cd "./${PKG2}" && ls | tr '\n' ' ')"

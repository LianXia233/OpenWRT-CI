#!/bin/bash
# SPDX-License-Identifier: MIT
# H5000M 自用（NETMONITOR）变体专用：把 luci-app-netmonitor 放进 package/
#
# 为什么不写进 Scripts/Packages.sh：那是全机型共用入口，改动它会影响
# H5000M / AP3000M / X86 三套既有构建。本插件只服务作者自用的
# H5000M-WIFI-YES-NETMONITOR 配置（Release 归组「自用」），因此独立成脚本，
# 由 WRT-CORE 中带 contains(env.WRT_CONFIG,'NETMONITOR') 条件的步骤调用，
# 现有机型构建路径完全不执行本脚本。
#
# 历史：本脚本原先同时负责 luci-app-taygedo（塔吉多签到）。2026-11 起该包
# 已改为**配置驱动**，由 Scripts/Packages-Taygedo.sh 独立导入 —— 任何机型
# 只要在 Config/*.txt 写了 CONFIG_PACKAGE_luci-app-taygedo=y 就会生效，
# 不再与 NETMONITOR 变体绑定。两个包的取包逻辑差异较大（taygedo 需要做
# Release 资产名解析与版本对齐），合在一起只会让分支互相牵连，故拆分。
#
# 用法（在 OpenWrt 源码树的 package/ 目录下执行）：
#   $GITHUB_WORKSPACE/Scripts/Packages-NetMonitor.sh

set -euo pipefail

# ============================================================
# luci-app-netmonitor：仓库根即 OpenWrt 包（Makefile 在根）
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

# ===== 行尾归一化：CRLF → LF（本脚本的核心必要步骤）=====
#
# 上游仓库的 .gitattributes 为 `* text=auto eol=lf`（强制 LF），正常 clone
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
mapfile -t PKG_FILES < <(find "./${PKG1}" -type f)

# 文本 / 二进制判定：含 NUL 字节的文件视为二进制（PNG / ZIP / 可执行文件等）。
# 二进制文件的字节流天然含 0x0D（图片数据块、压缩头等），逐字节判 CR 必然误报
# （曾因此把 tests/preview/*.png 与 *.zip 误判为「含 CR 未归一化」导致取包步骤
# 失败），且 sed 行替换也不该作用于二进制（有损坏风险）。故只对文本文件做
# 归一化与复核。判定只依赖 tr / wc（与下方 CR 复核同构，Git Bash / MSYS 下
# 行为一致），不引入 file / grep -I 等对二进制语义各平台不一致的工具。
TXT_FILES=()
for F in "${PKG_FILES[@]}"; do
	ORIG_LEN=$(wc -c < "$F")
	BIN_FREE_LEN=$(tr -d '\0' < "$F" | wc -c)
	[ "$ORIG_LEN" -eq "$BIN_FREE_LEN" ] && TXT_FILES+=("$F")
done

if [ "${#TXT_FILES[@]}" -gt 0 ]; then
	sed -i 's/\r$//' "${TXT_FILES[@]}"
fi

# 转换后复核：逐文件按字节判定是否仍含 CR。
# 不用 `grep -qU $'\r'`：该写法在 Git Bash / MSYS 下对 CR 的匹配语义不可靠，
# 改用 POSIX 参数展开 `$(cat "$F" | tr -d '\r')` 前后长度比较，
# 只依赖 tr 与 ${#var}，跨平台行为一致。
CR_LEFT_FILES=()
for F in "${TXT_FILES[@]}"; do
	ORIG_LEN=$(wc -c < "$F")
	STRIPPED_LEN=$(tr -d '\r' < "$F" | wc -c)
	if [ "$ORIG_LEN" != "$STRIPPED_LEN" ]; then
		CR_LEFT_FILES+=("$F")
	fi
done

if [ "${#CR_LEFT_FILES[@]}" -ne 0 ]; then
	echo "::error::${PKG1} 仍存在含 CR 的文本文件，行尾归一化未完成"
	for F in "${CR_LEFT_FILES[@]}"; do
		echo "  含 CR: $F"
	done
	exit 1
fi
echo "==> 行尾复核通过：${#TXT_FILES[@]} 个文本文件均为 LF（另跳过 $(( ${#PKG_FILES[@]} - ${#TXT_FILES[@]} )) 个二进制文件）"

# 可执行位补齐：git clone 会保留上游 mode，但上游若曾以 Windows 提交或经过
# archive 下载，x 位可能丢失，导致 procd 启动 init.d 时 Permission denied。
# 路径与上游仓库实测目录结构一致；缺失时仅告警不中断（防御性）。
for FILE in \
	"./${PKG1}/root/etc/init.d/netmonitor" \
	"./${PKG1}/root/usr/libexec/netmonitor/netmon-daemon.sh"; do
	if [ -f "$FILE" ]; then
		chmod +x "$FILE"
	else
		echo "::warning::${FILE} 缺失：上游目录结构可能已调整"
	fi
done

echo "==> ${PKG1} 就位：$(cd "./${PKG1}" && ls | tr '\n' ' ')"

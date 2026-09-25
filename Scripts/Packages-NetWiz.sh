#!/bin/bash
# SPDX-License-Identifier: MIT
# NetWiz 变体专用：把 luci-app-netwiz 源码放进 package/
#
# 为什么不写进 Scripts/Packages.sh：那是全机型共用入口，改动它会影响
# H5000M / AP3000M / X86 三套既有构建。NetWiz 变体才需要这个包，因此独立
# 成脚本，由 WRT-CORE 中带 contains(env.WRT_CONFIG,'NETWIZ') 条件的步骤调用，
# 现有机型构建路径完全不执行本脚本。
#
# 上游仓库是 monorepo 形态：仓库根目录放 install.sh / probe.py / worker.js /
# README.md 等开发辅助文件，OpenWrt 包本体在根目录下的 luci-app-netwiz/ 一级
# 子目录里。OpenWrt 只认「package/<包名>/Makefile」这一层，因此必须把子目录
# 整体搬到 package/luci-app-netwiz/，不能直接 clone 到 package/ 根下。
#
# 用法（在 OpenWrt 源码树的 package/ 目录下执行）：
#   $GITHUB_WORKSPACE/Scripts/Packages-NetWiz.sh

set -euo pipefail

PKG_NAME=luci-app-netwiz
PKG_REPO=huchd0/luci-app-netwiz
PKG_BRANCH="${NETWIZ_BRANCH:-main}"

# 上游仓库根目录名（clone 目标），与包目录名区分开，避免搬移时自我覆盖
REPO_DIR=".netwiz-upstream"

echo "==> 拉取 ${PKG_NAME}（${PKG_REPO}@${PKG_BRANCH}）"

# 幂等：重复执行先清干净，避免残留旧版本目录造成包内容混杂
rm -rf "./${PKG_NAME}" "./${REPO_DIR}"

git clone --depth=1 --single-branch --branch "${PKG_BRANCH}" \
	"https://github.com/${PKG_REPO}.git" "./${REPO_DIR}"

# 发布构建用不到的目录：.git 体积大，.github 是上游 CI
rm -rf "./${REPO_DIR}/.git" "./${REPO_DIR}/.github"

# 上游把包本体放在一级子目录，整目录搬到 package/ 根下
if [ ! -d "./${REPO_DIR}/${PKG_NAME}" ]; then
	echo "::error::${REPO_DIR}/${PKG_NAME} 不存在：上游仓库布局可能已变更"
	echo "目录内容：$(ls -A "./${REPO_DIR}" | tr '\n' ' ')"
	rm -rf "./${REPO_DIR}"
	exit 1
fi

mv "./${REPO_DIR}/${PKG_NAME}" "./${PKG_NAME}"
rm -rf "./${REPO_DIR}"

# 上游开发辅助文件不参与打包，已在上面随 REPO_DIR 一并丢弃；
# 包目录内自带的 README.md / LICENSE 保留，无副作用。

# ===== 行尾归一化：CRLF → LF（本脚本的核心必要步骤）=====
#
# 实测上游仓库（huchd0/luci-app-netwiz）提交的 20 个文件全部是 CRLF，
# 包括 Makefile、全部 init.d 服务、rpcd 插件、hotplug 守卫与 menu.d/acl.d JSON。
# 这不是可选项，几个具体后果：
#   - Makefile：`include $(TOPDIR)/feeds/luci/luci.mk` 的行尾 \r 会被并入
#     文件名，make 报 "luci.mk\r: No such file or directory"，包直接编不过。
#   - init.d / 脚本 shebang：变成 "#!/bin/sh /etc/rc.common\r"，procd 经
#     rc.common 派发时解释器路径被污染，服务起不来或 ubus 注册失败。
#   - menu.d / acl.d JSON：\r 是字符串外的非法空白，LuCI 解析失败，表现为
#     「包装上了但界面里找不到入口」，或 rpcd 拒绝 ACL 校验。
#
# 为什么不能依赖 WRT-CORE.yml 里既有的「脚本格式规整（CRLF → LF）」步骤：
# 那一步只覆盖 `find ./ -maxdepth 3`（即 OpenWrt 源码树顶层三级的 txt/sh），
# 且执行时机在取包之前 —— 本脚本落盘的文件它完全看不到，顺序上已错过。
# 因此必须在包就位后就地转换。
#
# 包内无二进制文件（纯 shell / JS / CSS / PO / JSON），全量文本转换是安全的。
# 用 sed 一次性扫过全部文件：不含 CR 的文件是无副作用的空操作，
# 因此不需要先逐个 grep 判断（`grep -qU $'\r'` 在 Git Bash / MSYS 下
# 对 CR 的匹配不可靠，实测会把已归零的文件误判为含 CR，故不复用它做判据）。
mapfile -t PKG_FILES < <(find "./${PKG_NAME}" -type f)
sed -i 's/\r$//' "${PKG_FILES[@]}"

# 转换后复核：逐文件按字节判定是否仍含 CR。
#
# 不用 `grep -qU $'\r'`：该写法在 Git Bash / MSYS 下对 CR 的匹配语义不可靠
# （实测会把 CR 已归零的 Makefile 仍判为含 CR），一旦 runner 环境漂移就会
# 产生假失败。改用 POSIX 参数展开 `$(cat "$F" | tr -d '\r')` 前后长度比较，
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
	echo "::error::${PKG_NAME} 仍存在含 CR 的文件，行尾归一化未完成"
	for F in "${CR_LEFT_FILES[@]}"; do
		echo "  含 CR: $F"
	done
	exit 1
fi
echo "==> 行尾复核通过：${#PKG_FILES[@]} 个文件均为 LF"

# 上游 Makefile 用 `include $(TOPDIR)/feeds/luci/luci.mk` 绝对路径形式，
# 在 OpenWrt 源码树内可直接解析，无需像上游 CI 那样把 ../../luci.mk 改写掉。
# 这里做一次断言：若上游改回相对路径，luci.mk 在 feeds 未展开为软链时会失效。
if ! grep -q 'feeds/luci/luci.mk' "./${PKG_NAME}/Makefile"; then
	echo "::error::${PKG_NAME}/Makefile 未引用 feeds/luci/luci.mk：上游打包方式可能已变更"
	grep -n 'luci.mk' "./${PKG_NAME}/Makefile" || echo "（Makefile 中无 luci.mk 引用）"
	exit 1
fi

# 可执行位补齐：git clone 会保留上游 mode，但上游仓库若曾以 Windows 提交
# 或经过 archive 下载，x 位可能丢失，导致 procd 启动 init.d 时 Permission denied。
for FILE in \
	"root/usr/libexec/rpcd/netwiz" \
	"root/usr/libexec/rpcd/netwiz_dev" \
	"root/usr/libexec/netwiz-autodetect.sh" \
	"root/usr/libexec/netwiz-monitor-loop.sh" \
	"root/etc/init.d/netwiz-monitor" \
	"root/etc/init.d/netwiz-recovery" \
	"root/etc/init.d/netwiz-watchdog" \
	"root/etc/hotplug.d/dhcp/99-netwiz-guard"; do
	if [ -f "./${PKG_NAME}/${FILE}" ]; then
		chmod +x "./${PKG_NAME}/${FILE}"
	else
		echo "::warning::${PKG_NAME}/${FILE} 缺失：上游目录结构可能已调整"
	fi
done

echo "==> ${PKG_NAME} 就位：$(cd "./${PKG_NAME}" && ls | tr '\n' ' ')"

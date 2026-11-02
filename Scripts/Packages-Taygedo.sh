#!/bin/bash
# SPDX-License-Identifier: MIT
# luci-app-taygedo 取包：从 LianXia233/taygedo-CI 提取 OpenWrt 包，并把
# 「包内声明的 Release 资产」与「上游实际已发布的资产」对齐。
#
# 用法（在 OpenWrt 源码树的 package/ 目录下执行）：
#   $GITHUB_WORKSPACE/Scripts/Packages-Taygedo.sh
#
# 环境变量（均可选）：
#   TAYGEDO_REPO     上游仓库，默认 LianXia233/taygedo-CI
#   TAYGEDO_BRANCH   上游分支，默认 main
#   TAYGEDO_ARCH     目标架构，仅 x86_64 / aarch64；留空按 WRT_TARGET 推导
#   TAYGEDO_TAG      强制指定 Release tag（vX.Y.Z 或 nightly），跳过自动对齐
#
# ── 为什么要有这个脚本（而不是把逻辑塞进 Packages-NetMonitor.sh）─────────────
# taygedo 早期只服务 H5000M 自用配置，取包逻辑与 luci-app-netmonitor 共处
# 一个脚本、由 contains(WRT_CONFIG,'NETMONITOR') 触发，并把资产名硬编码为
# `taygedo-rs-aarch64-unknown-linux-musl.tar.gz`。
#
# 上游 2026-11-03 起把 Rust 后端拆成 webui / openwrt 两个**编译期互斥**的
# 产物，OpenWrt 侧必须用 `*-openwrt.tar.gz`；无后缀的那份是自带 WebUI 的
# 通用版，装进路由器等于把已删掉的 WebUI 又塞回去。硬编码旧名会让取包
# 静默下错文件（或 404），所以这里改成：从包 Makefile 的 TAYGEDO_ARCHIVE
# 模板解析真实资产名，再拿它去探测 Release。
#
# 同时改为**配置驱动**：任何 Config/*.txt 只要写 CONFIG_PACKAGE_luci-app-taygedo=y
# 就会导入，不再要求机型名里带 NETMONITOR。
set -euo pipefail

PKG="luci-app-taygedo"
REPO="${TAYGEDO_REPO:-LianXia233/taygedo-CI}"
BRANCH="${TAYGEDO_BRANCH:-main}"
UPSTREAM_DIR=".${PKG}-upstream"
MK="./${PKG}/Makefile"

say() { echo "==> $*"; }
die() { echo "::error::$*" >&2; exit 1; }

# ===========================================================================
# 0) 目标架构 → Rust musl triple
# ===========================================================================
# 上游 Makefile 只映射 x86_64 与 aarch64 两个 $(ARCH)（见其架构映射注释），
# 其余架构在包内 Build/Prepare 才会 fail-fast。这里提前判定，让「架构不支持」
# 在取包阶段就带着清晰的 triple 说明失败，而不是等到固件编译中期。
TG_ARCH="${TAYGEDO_ARCH:-}"
if [ -z "$TG_ARCH" ]; then
	case "${WRT_TARGET:-}" in
		x86*) TG_ARCH="x86_64" ;;
		"") : ;;
		*) TG_ARCH="aarch64" ;;
	esac
fi
# WRT_TARGET 未导出时（本地手跑）回退读配置文件
if [ -z "$TG_ARCH" ]; then
	CFG_ROOT="${GITHUB_WORKSPACE:-$(pwd)/../..}/Config"
	if [ -n "${WRT_CONFIG:-}" ] && [ -f "${CFG_ROOT}/${WRT_CONFIG}.txt" ]; then
		if grep -qx 'CONFIG_TARGET_x86_64=y' "${CFG_ROOT}/${WRT_CONFIG}.txt"; then
			TG_ARCH="x86_64"
		else
			TG_ARCH="aarch64"
		fi
	fi
fi
[ -n "$TG_ARCH" ] || die "${PKG}: 无法判定目标架构（TAYGEDO_ARCH / WRT_TARGET / WRT_CONFIG 均为空）"

case "$TG_ARCH" in
	x86_64)  TG_TRIPLE="x86_64-unknown-linux-musl" ;;
	aarch64) TG_TRIPLE="aarch64-unknown-linux-musl" ;;
	*) die "${PKG}: 不支持的目标架构 '${TG_ARCH}'（上游仅产出 x86_64 / aarch64 的 musl 预编译二进制）" ;;
esac
say "目标架构 ${TG_ARCH} → ${TG_TRIPLE}"

# ===========================================================================
# 1) 取包（monorepo：包本体在 openwrt/luci-app-taygedo/）
# ===========================================================================
say "拉取 ${REPO}@${BRANCH}"
rm -rf "./${PKG}" "./${UPSTREAM_DIR}"
git clone --depth=1 --single-branch --branch "${BRANCH}" \
	"https://github.com/${REPO}.git" "./${UPSTREAM_DIR}"

# 布局断言：上游若调整 monorepo 结构，显式失败而不是产出缺文件的包
if [ ! -d "./${UPSTREAM_DIR}/openwrt/${PKG}" ]; then
	echo "::error::${UPSTREAM_DIR}/openwrt/${PKG} 不存在：上游仓库布局可能已变更"
	echo "openwrt/ 目录内容：$(ls -A "./${UPSTREAM_DIR}/openwrt" 2>/dev/null | tr '\n' ' ')"
	exit 1
fi
mv "./${UPSTREAM_DIR}/openwrt/${PKG}" "./${PKG}"
rm -rf "./${UPSTREAM_DIR}"

[ -f "$MK" ] || die "${MK} 不存在：期望的 taygedo Makefile 未就位"

# ===========================================================================
# 2) Makefile 自检（防上游回归）
# ===========================================================================
# 以下四项均为历史上真实踩过的坑（详见 Packages-NetMonitor.sh 旧注释与上游
# v0.5.1 修复记录），上游已原生修复，这里只做回归守卫：
#   a) CONFIG_ARCH —— 包上下文里该变量为空，分支全落空会下错架构；
#   b) download.pl —— 参数签名不匹配，缺参直接 exit 255；
#   c) $(TARGET_STRIP) —— 宿主执行目标架构 ELF，报 cannot execute binary file；
#   d) 解析期 $(error) —— make defconfig 元数据扫描阶段 $(ARCH) 为空即语法错误，
#      本包会被 packageinfo 丢弃，表现为「.config 里根本没有这个包」。
if grep -q 'CONFIG_ARCH' "$MK"; then
	die "${MK} 仍含 CONFIG_ARCH：上游未采用 ARCH 修复，请复核"
fi
if grep -q 'download\.pl' "$MK"; then
	die "${MK} 仍调用 download.pl：上游未采用 curl 修复，请复核"
fi
if grep -qE '^[[:space:]]*\$\(TARGET_STRIP\)' "$MK"; then
	die "${MK} Build/Compile 仍用 TARGET_STRIP：可能把目标二进制当宿主命令执行，请复核"
fi
if grep -E '^[[:space:]]*[^#].*\$\(error' "$MK"; then
	die "${MK} 含解析期 \$(error) 分支：会导致元数据扫描丢弃本包、.config 未选中"
fi

# e) 新增守卫：OpenWrt 形态必须是 -openwrt 后缀产物
#    上游双形态拆分后，无后缀的 taygedo-rs-<triple>.tar.gz 是 **webui** 形态
#    （自带首页/登录/改密/静态资源）。下错文件不会编译失败，只会把本应被
#    移除的 WebUI 悄悄带回路由器 —— 这是最危险的一类回归，必须显式拦截。
TG_ARCHIVE_TPL=$(sed -n 's/^[[:space:]]*TAYGEDO_ARCHIVE:=[[:space:]]*\(.*\)$/\1/p' "$MK" | head -n1)
if [ -z "$TG_ARCHIVE_TPL" ]; then
	die "${MK} 未声明 TAYGEDO_ARCHIVE：无法解析预编译资产名"
fi
case "$TG_ARCHIVE_TPL" in
	*-openwrt.tar.gz) ;;
	*)
		die "${MK} 的 TAYGEDO_ARCHIVE='${TG_ARCHIVE_TPL}' 不是 *-openwrt.tar.gz：可能取到自带 WebUI 的通用版产物，请复核上游双形态打包"
		;;
esac

# 展开 Makefile 变量：$(TAYGEDO_TRIPLE) / ${TAYGEDO_TRIPLE}
TG_ARCHIVE=$(printf '%s' "$TG_ARCHIVE_TPL" \
	| sed -e "s/\$(TAYGEDO_TRIPLE)/${TG_TRIPLE}/g" \
	      -e "s/\${TAYGEDO_TRIPLE}/${TG_TRIPLE}/g")
say "预编译资产名 ${TG_ARCHIVE}"

# 包声明的架构映射必须覆盖当前目标：若 Makefile 的 ifeq 分支未包含本架构，
# $(TAYGEDO_TRIPLE) 展开为空 → 资产名退化成 taygedo-rs--openwrt.tar.gz。
case "$TG_ARCHIVE" in
	*'$('*|*'${'*|*--openwrt*)
		die "${MK} 未能推出 ${TG_ARCH} 的资产名（得到 '${TG_ARCHIVE}'）：上游架构映射可能缺少该分支"
		;;
esac

TG_REPO_URL=$(sed -n 's/^[[:space:]]*TAYGEDO_REPO:=[[:space:]]*\([^[:space:]]*\).*/\1/p' "$MK" | head -n1)
[ -n "$TG_REPO_URL" ] || TG_REPO_URL="https://github.com/${REPO}"
CUR_VER=$(sed -n 's/^[[:space:]]*PKG_VERSION:=[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$MK" | head -n1)
[ -n "$CUR_VER" ] || die "${MK} 未声明 PKG_VERSION"

# ===========================================================================
# 3) Release 版本对齐
# ===========================================================================
# 背景：上游先 bump PKG_VERSION 再发 tag 是常态，存在「代码版本领先于实际
# Release」的时间窗；反过来（本次）也会出现「tag 已发但资产是旧命名」——
# v0.7.1 发布于双形态拆分之前，Release 里只有无后缀的通用版 tar.gz。
# 两种情况都会让 Build/Prepare 的 curl 在深层编译期报
#   make[3]: [.../.prepared_...] Error 22   （curl 22 = HTTP 404）
# 信息晦涩且要等几十分钟才暴露。这里把探测提前到取包阶段。
probe() { curl -fsSIL -o /dev/null --max-time 20 "$1" >/dev/null 2>&1; }
asset_url() { printf '%s/releases/download/%s/%s' "$TG_REPO_URL" "$1" "$TG_ARCHIVE"; }

TAG="${TAYGEDO_TAG:-v${CUR_VER}}"
if probe "$(asset_url "$TAG")"; then
	say "Release 资产可达：${TAG}/${TG_ARCHIVE}"
else
	say "Release ${TAG} 无 ${TG_ARCHIVE}，改为按已发布资产反查可用 tag"

	API="https://api.github.com/repos/${REPO}/releases?per_page=100"
	# 鉴权说明（这里踩过一次坑）：
	#   Actions 里的 env GITHUB_TOKEN 是**当前仓库**的 installation token，
	#   拿它去调另一个仓库（taygedo-CI）的 API 会 404/403 —— 不是权限不够，
	#   而是它对目标仓库根本不可见。因此这里**默认匿名访问**（公开仓库的
	#   Release 列表匿名可读，单次构建只调一次，60 次/小时的额度足够）。
	#   若 runner IP 被共享限流，可在仓库 Secrets 里配 TAYGEDO_TOKEN（对
	#   taygedo-CI 有只读权限的 PAT）来提额，无需改脚本。
	AUTH=()
	if [ -n "${TAYGEDO_TOKEN:-}" ]; then
		AUTH=(-H "Authorization: Bearer ${TAYGEDO_TOKEN}")
	fi
	JSON=$(curl -fsSL --retry 3 --max-time 40 "${AUTH[@]}" \
		-H "Accept: application/vnd.github+json" "$API") \
		|| die "${PKG}: 无法读取 ${REPO} 的 Release 列表（网络或 GitHub 匿名限流）。
  可在仓库 Secrets 配置 TAYGEDO_TOKEN（对 ${REPO} 有只读权限的 PAT）后重试。"

	# 只认「确实带目标资产」的 tag：单纯按时间取最新 tag 会挑到没有该架构
	# 产物的构建（例如只出了 x86_64），仍然 404。
	FOUND_TAG=""
	while IFS= read -r T; do
		[ -n "$T" ] || continue
		if probe "$(asset_url "$T")"; then
			FOUND_TAG="$T"
			break
		fi
	done < <(printf '%s' "$JSON" | jq -r --arg a "$TG_ARCHIVE" \
		'.[] | select([.assets[]?.name] | index($a)) | .tag_name')

	[ -n "$FOUND_TAG" ] || die "${PKG}: ${REPO} 的任何 Release 都不含 ${TG_ARCHIVE}。
  上游很可能尚未在双形态拆分后重新发版。处理方式（任选其一）：
    1) 在 ${REPO} 打新 tag（vX.Y.Z）触发 build-release，产出 *-openwrt.tar.gz；
    2) 手动触发 workflow_dispatch 生成 nightly（同样含 -openwrt 资产）；
    3) 设置 TAYGEDO_TAG=<含该资产的 tag> 强制指定。"

	TAG="$FOUND_TAG"
	say "已对齐到含目标资产的 tag：${TAG}"
fi

# 把对齐结果写回 Makefile
#   - vX.Y.Z：PKG_VERSION 与 TAYGEDO_VER 一起改，包版本与二进制版本保持一致；
#   - nightly 等非语义化 tag：只改 TAYGEDO_VER，PKG_VERSION 保持（nightly 的
#     内容就是当前 main 的 Cargo.toml 版本，二者本就同源）。
NEW_VER="${TAG#v}"
if [ "$TAG" != "v${CUR_VER}" ]; then
	case "$TAG" in
		v[0-9]*.[0-9]*.[0-9]*)
			[ "$NEW_VER" = "$CUR_VER" ] || {
				sed -i "s/^\([[:space:]]*PKG_VERSION:=[[:space:]]*\)[0-9][0-9.]*/\1${NEW_VER}/" "$MK"
				say "PKG_VERSION ${CUR_VER} → ${NEW_VER}"
			}
			;;
		*)
			say "非语义化 tag（${TAG}），仅覆盖下载 tag，PKG_VERSION 保持 ${CUR_VER}"
			;;
	esac
	# TAYGEDO_VER 默认写的是 `v$(PKG_VERSION)`，直接钉成实际 tag
	if grep -qE '^[[:space:]]*TAYGEDO_VER:=' "$MK"; then
		sed -i "s|^\([[:space:]]*TAYGEDO_VER:=\).*|\1${TAG}|" "$MK"
	else
		sed -i "s|^\([[:space:]]*TAYGEDO_REPO:=.*\)|\1\nTAYGEDO_VER:=${TAG}|" "$MK"
	fi
	say "TAYGEDO_VER → ${TAG}"
fi

# ===========================================================================
# 4) 预下载 + 归档内容校验
# ===========================================================================
# 提前把资产落到 dl/，包内 Build/Prepare 见到文件即跳过 curl（其逻辑是
# `if [ ! -f "$(TAYGEDO_DL)" ]`），因此这一步等价于「把 404 和坏归档提前到
# 取包阶段」。同时校验压缩包内确实有 taygedo-rs 可执行文件，防止上游改了
# 打包布局（例如多套一层目录）导致 install 阶段 cp 失败。
DL_DIR="../dl"
mkdir -p "$DL_DIR"
DL_FILE="${DL_DIR}/${TG_ARCHIVE}"
DL_URL="$(asset_url "$TAG")"

if [ -f "$DL_FILE" ] && [ -s "$DL_FILE" ]; then
	say "复用已下载资产：${DL_FILE}"
else
	say "下载 ${DL_URL}"
	curl -fsSL --retry 3 --retry-all-errors --max-time 300 -o "${DL_FILE}.part" "$DL_URL" \
		|| { rm -f "${DL_FILE}.part"; die "${PKG}: 下载 ${DL_URL} 失败"; }
	mv -f "${DL_FILE}.part" "$DL_FILE"
fi

tar tzf "$DL_FILE" 2>/dev/null | grep -qx 'taygedo-rs' \
	|| die "${DL_FILE} 内未找到顶层 taygedo-rs：上游打包布局可能已变更（当前内容：$(tar tzf "$DL_FILE" 2>/dev/null | head -5 | tr '\n' ' ')）"
say "归档校验通过：$(du -h "$DL_FILE" | cut -f1) ${TG_ARCHIVE}"

# ===========================================================================
# 5) 行尾归一化（CRLF → LF）+ 可执行位补齐
# ===========================================================================
# 上游 .gitattributes 为 `* text=auto eol=lf`，正常 clone 即 LF；这里做幂等
# 归一化，防止 runner 环境漂移或上游改动 .gitattributes 时 CR 残留：
#   - Makefile 的 include 路径带 \r → "No such file or directory"；
#   - init.d 的 shebang 变成 "#!/bin/sh /etc/rc.common\r" → procd 起不来。
# 只处理文本文件：逐字节判定是否含 NUL（二进制），避免 sed 破坏二进制。
mapfile -t ALL_FILES < <(find "./${PKG}" -type f)
TXT_FILES=()
for F in "${ALL_FILES[@]}"; do
	ORIG_LEN=$(wc -c < "$F")
	BIN_FREE_LEN=$(tr -d '\0' < "$F" | wc -c)
	[ "$ORIG_LEN" -eq "$BIN_FREE_LEN" ] && TXT_FILES+=("$F")
done
if [ "${#TXT_FILES[@]}" -gt 0 ]; then
	sed -i 's/\r$//' "${TXT_FILES[@]}"
fi

CR_LEFT=()
for F in "${TXT_FILES[@]}"; do
	if [ "$(wc -c < "$F")" != "$(tr -d '\r' < "$F" | wc -c)" ]; then
		CR_LEFT+=("$F")
	fi
done
if [ "${#CR_LEFT[@]}" -ne 0 ]; then
	echo "::error::${PKG} 仍存在含 CR 的文本文件，行尾归一化未完成"
	printf '  含 CR: %s\n' "${CR_LEFT[@]}"
	exit 1
fi

# 可执行位：git clone 通常保留 mode，但经 archive 下载或 Windows 提交会丢 x 位，
# procd 启动 init.d 时直接 Permission denied。缺失仅告警不中断（防御性）。
for FILE in "./${PKG}/root/etc/init.d/taygedo"; do
	if [ -f "$FILE" ]; then
		chmod +x "$FILE"
	else
		echo "::warning::${FILE} 缺失：上游目录结构可能已调整"
	fi
done

say "${PKG} 就位：$(cd "./${PKG}" && ls | tr '\n' ' ')"
say "版本 ${TAG} · 架构 ${TG_ARCH} · 资产 ${TG_ARCHIVE}"

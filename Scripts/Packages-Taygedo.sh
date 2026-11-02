#!/bin/bash
# SPDX-License-Identifier: MIT
# luci-app-taygedo 取包：从 LianXia233/taygedo-CI 提取 OpenWrt 包与 Rust 源码。
#
# 用法（在 OpenWrt 源码树的 package/ 目录下执行）：
#   $GITHUB_WORKSPACE/Scripts/Packages-Taygedo.sh
#
# 环境变量（均可选）：
#   TAYGEDO_REPO      上游仓库，默认 LianXia233/taygedo-CI
#   TAYGEDO_BRANCH    上游分支/tag，默认 main
#   TAYGEDO_ARCH      目标架构，仅 x86_64 / aarch64；留空按 WRT_TARGET 推导
#   TAYGEDO_PREBUILT  1 = 走预编译 Release 下载（旧行为）；默认 0 = 源码编译
#   TAYGEDO_TAG       预编译模式下强制指定 Release tag
#
# ── 两种模式 ────────────────────────────────────────────────────────────────
# 源码编译（默认）：把仓库的 Rust 工程复制到包目录 src/，随后由
#   Scripts/Build-Taygedo.sh 在固件编译前交叉编译，产物落到包目录 local/。
#   优点：与固件同工具链、同 musl、同 feature，不依赖跨仓库发版节奏。
#
# 预编译下载（TAYGEDO_PREBUILT=1）：保持原逻辑，把 Release 里的
#   `taygedo-rs-<triple>-openwrt.tar.gz` 预下载到 dl/。
#   作为源码编译不可用时的回退（例如 runner 缺 Docker 且工具链异常）。
#
# ── 为什么取包要独立成脚本 ──────────────────────────────────────────────────
# taygedo 早期只服务 H5000M 自用配置，取包逻辑与 luci-app-netmonitor 共处
# 一个脚本、由 contains(WRT_CONFIG,'NETMONITOR') 触发，并把资产名硬编码为
# `taygedo-rs-aarch64-unknown-linux-musl.tar.gz`。上游把 Rust 后端拆成
# webui / openwrt 两个编译期互斥产物后，无后缀的那份是自带 WebUI 的通用版，
# 装进路由器等于把已删掉的 WebUI 又塞回去，所以必须按后缀区分。现在改为
# **配置驱动**：任何 Config/*.txt 写了 CONFIG_PACKAGE_luci-app-taygedo=y 就导入。
set -euo pipefail

PKG="luci-app-taygedo"
REPO="${TAYGEDO_REPO:-LianXia233/taygedo-CI}"
BRANCH="${TAYGEDO_BRANCH:-main}"
UPSTREAM_DIR=".${PKG}-upstream"
MK="./${PKG}/Makefile"
MODE="${TAYGEDO_PREBUILT:-0}"

say() { echo "==> $*"; }
die() { echo "::error::$*" >&2; exit 1; }

# ===========================================================================
# 0) 目标架构 → Rust musl triple
# ===========================================================================
# 上游 Makefile 只映射 x86_64 / aarch64；其余架构在预编译路径下包内
# Build/Prepare 会 fail-fast。这里提前判定，让「架构不支持」在取包阶段就带着
# 清晰的 triple 说明失败，而不是等到固件编译中期。
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
	*) die "${PKG}: 不支持的目标架构 '${TG_ARCH}'（上游仅支持 x86_64 / aarch64 的 musl 构建）" ;;
esac
say "目标架构 ${TG_ARCH} → ${TG_TRIPLE}"

# ===========================================================================
# 1) 取包（monorepo：包本体在 openwrt/luci-app-taygedo/）
# ===========================================================================
say "拉取 ${REPO}@${BRANCH}"
rm -rf "./${PKG}" "./${UPSTREAM_DIR}"
git clone --depth=1 --single-branch --branch "${BRANCH}" \
	"https://github.com/${REPO}.git" "./${UPSTREAM_DIR}"

SRC_REV="$(git -C "./${UPSTREAM_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"

# 布局断言：上游若调整 monorepo 结构，显式失败而不是产出缺文件的包
if [ ! -d "./${UPSTREAM_DIR}/openwrt/${PKG}" ]; then
	echo "::error::${UPSTREAM_DIR}/openwrt/${PKG} 不存在：上游仓库布局可能已变更"
	echo "openwrt/ 目录内容：$(ls -A "./${UPSTREAM_DIR}/openwrt" 2>/dev/null | tr '\n' ' ')"
	exit 1
fi
mv "./${UPSTREAM_DIR}/openwrt/${PKG}" "./${PKG}"

[ -f "$MK" ] || die "${MK} 不存在：期望的 taygedo Makefile 未就位"

# ===========================================================================
# 2) Makefile 自检（防上游回归，两种模式都做）
# ===========================================================================
# 以下四项均为历史上真实踩过的坑，上游已原生修复，这里只做回归守卫：
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

# ===========================================================================
# 3) 源码编译模式：落位 Rust 工程
# ===========================================================================
if [ "$MODE" != "1" ]; then
	# Makefile 必须支持「本地产物优先」，否则脚本白编：二进制放好了但包仍然
	# 去下载 Release，等于源码编译没生效且没有任何报错。
	grep -q 'TAYGEDO_LOCAL_BIN' "$MK" \
		|| die "${MK} 未声明 TAYGEDO_LOCAL_BIN：上游 Makefile 尚不支持本地产物优先（源码编译模式无法生效）。
  可临时改用预编译模式：TAYGEDO_PREBUILT=1"

	for F in Cargo.toml Cargo.lock; do
		[ -f "./${UPSTREAM_DIR}/${F}" ] || die "上游缺少 ${F}：无法源码编译"
	done
	[ -d "./${UPSTREAM_DIR}/src" ] || die "上游缺少 src/：无法源码编译"

	# 目录名必须是 rust/ 而不是 src/：Rust 工程自己就有 src/，若把
	# Cargo.toml 和它平铺到包目录的 src/ 下，`path = "src/main.rs"` 会解析成
	# `<pkg>/src/src/main.rs` 而实际文件在 `<pkg>/src/main.rs`，cargo 报
	# "couldn't read src/main.rs" —— 目录层级一错，整个编译直接失败。
	RUST_DIR="./${PKG}/rust"
	say "源码编译模式：复制 Rust 工程 → ${PKG}/rust"
	mkdir -p "$RUST_DIR"
	cp -a "./${UPSTREAM_DIR}/Cargo.toml" "./${UPSTREAM_DIR}/Cargo.lock" "$RUST_DIR/"
	cp -a "./${UPSTREAM_DIR}/src" "$RUST_DIR/src"
	[ -d "./${UPSTREAM_DIR}/.cargo" ] && cp -a "./${UPSTREAM_DIR}/.cargo" "$RUST_DIR/.cargo"
	# static/ 只在 webui feature 下被 include_str! 引用，openwrt 形态不会展开；
	# 仍一并复制，避免上游把某个资源共享到两种形态时编译期缺文件。
	[ -d "./${UPSTREAM_DIR}/static" ] && cp -a "./${UPSTREAM_DIR}/static" "$RUST_DIR/static"
	[ -f "./${UPSTREAM_DIR}/LICENSE" ] && cp -a "./${UPSTREAM_DIR}/LICENSE" "$RUST_DIR/LICENSE"
	printf '%s\n' "$SRC_REV" > "$RUST_DIR/.taygedo-src-rev"

	rm -rf "./${UPSTREAM_DIR}"

	# 源码变更后旧产物必须失效：Build-Taygedo.sh 靠 BUILD-INFO 里的 src_rev
	# 判断复用，这里顺手清掉本地二进制，避免「改了代码仍打旧包」。
	rm -rf "./${PKG}/local"

	say "工程就位：$(cd "$RUST_DIR" && ls | tr '\n' ' ')"
else

# ===========================================================================
# 4) 预编译模式：Release 资产对齐 + 预下载
# ===========================================================================
rm -rf "./${PKG}/local" "./${PKG}/rust"

# e) OpenWrt 形态必须是 -openwrt 后缀产物
#    无后缀的 taygedo-rs-<triple>.tar.gz 是 webui 形态（自带首页/登录/改密/
#    静态资源）。下错文件不会编译失败，只会把本应被移除的 WebUI 悄悄带回
#    路由器 —— 最危险的一类回归，必须显式拦截。
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

# 背景：上游先 bump PKG_VERSION 再发 tag 是常态，存在「代码版本领先于实际
# Release」的时间窗；反过来也会出现「tag 已发但资产是旧命名」。两种情况都会让
# Build/Prepare 的 curl 在深层编译期报
#   make[3]: [.../.prepared_...] Error 22   （curl 22 = HTTP 404）
# 信息晦涩且要等几十分钟才暴露。这里把探测提前到取包阶段。
#
# 实现方式：**一次性拉 Release 列表，在本地按 assets 名字匹配**，而不是对每个
# 候选 tag 发 HEAD。实测 GitHub 对「不存在的 release 资产」并不稳定返回 404，
# 常见表现是连接挂起直到超时（curl exit 28）；HEAD 做否定判断既慢又不可靠。
asset_url() { printf '%s/releases/download/%s/%s' "$TG_REPO_URL" "$1" "$TG_ARCHIVE"; }

API="https://api.github.com/repos/${REPO}/releases?per_page=100"
# 鉴权说明：Actions 里的 env GITHUB_TOKEN 是**当前仓库**的 installation token，
# 拿它去调另一个仓库的 API 会 404/403。因此这里默认匿名访问（公开仓库的
# Release 列表匿名可读，单次构建只调一次）。若 runner IP 被共享限流，可在
# 仓库 Secrets 里配 TAYGEDO_TOKEN（对 taygedo-CI 只读的 PAT）提额。
AUTH=()
if [ -n "${TAYGEDO_TOKEN:-}" ]; then
	AUTH=(-H "Authorization: Bearer ${TAYGEDO_TOKEN}")
fi

if [ -n "${TAYGEDO_TAG:-}" ]; then
	TAG="$TAYGEDO_TAG"
	say "使用显式指定的 tag：${TAG}"
else
	JSON=$(curl -fsSL --retry 3 --max-time 40 "${AUTH[@]}" \
		-H "Accept: application/vnd.github+json" "$API") \
		|| die "${PKG}: 无法读取 ${REPO} 的 Release 列表（网络或 GitHub 匿名限流）。
  可在仓库 Secrets 配置 TAYGEDO_TOKEN（对 ${REPO} 有只读权限的 PAT）后重试，
  或用 TAYGEDO_TAG=<tag> 直接指定。"

	# 匹配规则：优先「包内声明的版本 tag」，否则取列表中最新的、确实带该资产
	# 的 tag。只认带目标资产的 release —— 单纯按时间取最新 tag 会挑到没有该
	# 架构产物的构建（例如只出了 x86_64），仍然 404。
	TAG=$(printf '%s' "$JSON" | jq -r --arg a "$TG_ARCHIVE" --arg pref "v${CUR_VER}" '
		[ .[] | select([.assets[]?.name] | index($a)) ] as $hits
		| ($hits | map(.tag_name)) as $tags
		| if ($tags | index($pref)) then $pref
		  elif ($tags | length) > 0 then $tags[0]
		  else "" end')

	[ -n "$TAG" ] || die "${PKG}: ${REPO} 的任何 Release 都不含 ${TG_ARCHIVE}。
  处理方式（任选其一）：
    1) 改回源码编译模式（去掉 TAYGEDO_PREBUILT=1）；
    2) 在 ${REPO} 打新 tag（vX.Y.Z）触发 build-release；
    3) 设置 TAYGEDO_TAG=<含该资产的 tag> 强制指定。"

	if [ "$TAG" = "v${CUR_VER}" ]; then
		say "Release 资产命中声明版本：${TAG}/${TG_ARCHIVE}"
	else
		say "声明版本 v${CUR_VER} 无 ${TG_ARCHIVE}，已对齐到含该资产的 tag：${TAG}"
	fi
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
	if grep -qE '^[[:space:]]*TAYGEDO_VER:=' "$MK"; then
		sed -i "s|^\([[:space:]]*TAYGEDO_VER:=\).*|\1${TAG}|" "$MK"
	else
		sed -i "s|^\([[:space:]]*TAYGEDO_REPO:=.*\)|\1\nTAYGEDO_VER:=${TAG}|" "$MK"
	fi
	say "TAYGEDO_VER → ${TAG}"
fi

# 预下载 + 归档内容校验：Build/Prepare 见到文件即跳过 curl，因此这一步等价于
# 「把 404 和坏归档提前到取包阶段」。同时校验压缩包内确实有 taygedo-rs。
#
# 复用陷阱：资产名里**不含版本号**，而 dl/ 被 actions/cache 跨构建持久化。
# 若只按「文件存在就复用」，发版前落进去的 nightly 二进制会一直被当成正式版
# 打进固件，且没有任何报错。因此另外记一个来源标记。
DL_DIR="../dl"
mkdir -p "$DL_DIR"
DL_FILE="${DL_DIR}/${TG_ARCHIVE}"
DL_URL="$(asset_url "$TAG")"
STAMP="${DL_DIR}/.taygedo-source"

case "$TAG" in
	v[0-9]*.[0-9]*.[0-9]*)
		REUSE=1
		if [ -f "$STAMP" ] && [ "$(cat "$STAMP" 2>/dev/null)" != "$TAG" ]; then
			rm -f "$DL_FILE"
			say "来源 tag 变更（$(cat "$STAMP" 2>/dev/null) → ${TAG}），丢弃 dl/ 中的旧资产"
		fi
		;;
	*)
		REUSE=0
		say "滚动 tag（${TAG}）不复用缓存，强制重新下载"
		;;
esac

if [ "$REUSE" = "1" ] && [ -s "$DL_FILE" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$TAG" ]; then
	say "复用已下载资产：${DL_FILE}"
else
	say "下载 ${DL_URL}"
	curl -fsSL --retry 3 --retry-all-errors --max-time 300 -o "${DL_FILE}.part" "$DL_URL" \
		|| { rm -f "${DL_FILE}.part"; die "${PKG}: 下载 ${DL_URL} 失败"; }
	mv -f "${DL_FILE}.part" "$DL_FILE"
	printf '%s\n' "$TAG" > "$STAMP"
fi

tar tzf "$DL_FILE" 2>/dev/null | grep -qx 'taygedo-rs' \
	|| die "${DL_FILE} 内未找到顶层 taygedo-rs：上游打包布局可能已变更（当前内容：$(tar tzf "$DL_FILE" 2>/dev/null | head -5 | tr '\n' ' ')）"
say "归档校验通过：$(du -h "$DL_FILE" | cut -f1) ${TG_ARCHIVE}"

rm -rf "./${UPSTREAM_DIR}"
fi

# ===========================================================================
# 5) 行尾归一化（CRLF → LF）+ 可执行位补齐
# ===========================================================================
# 上游 .gitattributes 为 `* text=auto eol=lf`，正常 clone 即 LF；这里做幂等
# 归一化，防止 runner 环境漂移或上游改动 .gitattributes 时 CR 残留：
#   - Makefile 的 include 路径带 \r → "No such file or directory"；
#   - init.d 的 shebang 变成 "#!/bin/sh /etc/rc.common\r" → procd 起不来。
# 只处理文本文件：逐字节判定是否含 NUL（二进制），避免 sed 破坏二进制与图片。
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

# ===========================================================================
# 6) 摘要
# ===========================================================================
if [ "$MODE" = "1" ]; then
	say "${PKG} 就位（预编译模式）：$(cd "./${PKG}" && ls | tr '\n' ' ')"
	say "架构 ${TG_ARCH} · 资产 ${TG_ARCHIVE} · tag ${TAG}"
else
	say "${PKG} 就位（源码编译模式）：$(cd "./${PKG}" && ls | tr '\n' ' ')"
	say "架构 ${TG_ARCH} · triple ${TG_TRIPLE} · 上游 ${REPO}@${BRANCH} (${SRC_REV})"
	say "下一步由 Scripts/Build-Taygedo.sh 交叉编译 → ${PKG}/local/taygedo-rs"
fi

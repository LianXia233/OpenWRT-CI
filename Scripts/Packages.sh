#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	elif [[ "$PKG_SPECIAL" == "all" ]]; then
		find ./$REPO_NAME/ -mindepth 1 -maxdepth 1 -type d -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name/all，可选，pkg为提取匹配包；name为重命名；all为提取全部一级包"
# 主题：保留 aurora（默认）与 argon（含配套修复），其余精简
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"

UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

# Honk eBPF 透明代理：使用上游预编译 APK（见下方 INSTALL_HONK_PREBUILT）
# 说明：honk 为 Rust/eBPF 架构，从源码编译会超过 GitHub 6 小时上限导致构建取消，
# 因此改为下载上游发布的预编译包，并在首次开机时离线安装进固件。

UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

#UPDATE_PACKAGE "athena-led" "unraveloop/JDC-AX6600-Athena-LED-Controller" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "sbwml/luci-app-diskman" "main"
UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"
UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"

# ===== MT 模式（MT_MODE）：独立插件配置层 =====
# 允许值：空 / MT5700 / MT5700M；非法值直接终止。
# 空  —— 不克隆、不折叠任何 MT 插件
# MT5700  —— 仅 luci-app-mt5700（单包自含 Rust 后端）
# MT5700M —— luci-app-mt5700m（需 FOLD）+ QModem feed（sms-tool_q / ubus-at-daemon）
MT_MODE="${MT_MODE:-}"
echo " "
echo "===== MT_MODE=${MT_MODE:-（空）} ====="
case "$MT_MODE" in
	""|MT5700|MT5700M) ;;
	*)
		echo "::error::非法 MT_MODE='$MT_MODE'（仅允许空 / MT5700 / MT5700M），终止 CI"
		exit 1
		;;
esac

# QModem feed 仅 MT5700M 需要（提供 sms-tool_q / ubus-at-daemon）
if [ "$MT_MODE" = "MT5700M" ]; then
	UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"

	# QModem 包共用 version.mk 的 QMODEM_VERSION（当前上游发布 "3.4.0-rc.3"）。
	# OpenWrt 新版 apk 打包器不接受 `-rc.N`：版本串被拼成 "3.4.0-rc.3-rN" 后，
	# apk mkpkg 报 "package version is invalid"（Error 99），阻断整个固件构建
	# （sms-tool_q 今日三连发全灭即此因）。这里在克隆后把 X.Y.Z-rc.N 改写为
	# apk 合法的 X.Y.Z_rcN；QModem 各包源码均内嵌仓库 src/，无版本化下载依赖，
	# 改写只影响包版本元数据。若上游已改为合法版本，本规则自动跳过。
	FIX_QMODEM_VERSION() {
		local VER_FILE="./QModem/version.mk"
		[ -f "$VER_FILE" ] || { echo "qmodem: version.mk not found, skip"; return 0; }
		if grep -qE '^QMODEM_VERSION:=[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+$' "$VER_FILE"; then
			sed -i -E 's/^(QMODEM_VERSION:=)([0-9]+\.[0-9]+\.[0-9]+)-rc\.([0-9]+)$/\1\2_rc\3/' "$VER_FILE"
			echo "qmodem: QMODEM_VERSION sanitized to $(grep -E '^QMODEM_VERSION:=' "$VER_FILE")"
		else
			echo "qmodem: QMODEM_VERSION already apk-valid, no change"
		fi
	}
	FIX_QMODEM_VERSION
fi
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "axonhub gecoosac sing-box luci-app-homeproxy luci-app-timewol luci-app-wolplus luci-app-wolultra"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

# FAN789 插件及其他专用硬件插件
UPDATE_PACKAGE "luci-app-h5000m-fancontrol" "FAN789/luci-app-h5000m-fancontrol" "main"
UPDATE_PACKAGE "luci-app-airpi-fancontrol" "LianXia233/luci-app-airpi3000m-fancontrol" "main" "all" "luci-app-airpi-fancontrol kmod-airpi-gpio-fan"

# ===== MT5700M（方案 A）：luci-app-mt5700m monorepo 折叠 =====
# luci-app-mt5700m 是两层 monorepo：仓库根没有 Makefile，真正可编译的包是
#   luci-app-mt5700m/luci-app-mt5700m            (LuCI 壳，含 Makefile)
#   mt5700webui-openwrt-server/at-webserver/     (Rust AT 后端源码，无 OpenWrt Makefile)
# 上游发布流程（scripts/build-release.sh）会先用 cargo 交叉编译出静态二进制
# at-webserver，再把 www/5700 前端 + 二进制 + init.d 脚本“折叠”进 LuCI 壳后
# 一起编译。若只编译 LuCI 壳，固件会缺少 /usr/bin/at-webserver（以及
# /usr/sbin/mt5700m-at 软链）与 /www/5700 WebUI，管理页的 AT 终端/拨号会全部失效。
# 因此这里复刻上游折叠流程（见下方 FOLD_MT5700M）：
#   1. 把 LuCI 壳（仓库内同名子目录）提升到 package/ 一级；
#   2. 按编译目标架构用 cargo + rust-lld（自包含 musl，无需 OpenWrt 交叉工具链）
#      编译 Rust 后端：mediatek → aarch64-unknown-linux-musl，x86 → x86_64-unknown-linux-musl；
#   3. 把 www/5700、二进制、init.d 折叠进壳目录。
# 注意：不能用 UPDATE_PACKAGE 的 "all" —— 壳目录与仓库根同名，cp -rf 会复制进自身。
FOLD_MT5700M() {
	local SHELL_DIR="./luci-app-mt5700m"
	local SERVER_DIR="./luci-app-mt5700m/mt5700webui-openwrt-server/at-webserver"
	local TMP_SHELL="./luci-app-mt5700m_shell"
	local RUST_TARGET="aarch64-unknown-linux-musl"
	local BIN_PATH=""

	[ -d "$SHELL_DIR" ] || { echo "luci-app-mt5700m: clone not found, skip fold"; return 0; }
	[ -d "$SHELL_DIR/luci-app-mt5700m" ] || { echo "luci-app-mt5700m: shell dir missing in repo, skip fold"; return 0; }
	[ -d "$SERVER_DIR" ] || { echo "luci-app-mt5700m: at-webserver source missing in repo, skip fold"; return 0; }

	# 第一层：LuCI 壳（先用临时名避开与仓库根同名冲突）
	rm -rf "$TMP_SHELL"
	mv -f "$SHELL_DIR/luci-app-mt5700m" "$TMP_SHELL"

	# 目标架构 → Rust 交叉编译目标
	case "${WRT_TARGET:-${WRT_CONFIG:-}}" in
		x86) RUST_TARGET="x86_64-unknown-linux-musl" ;;
	esac

	# 折叠前端 + init.d（与后端二进制无关，先铺好目录）
	mkdir -p "$TMP_SHELL/htdocs" "$TMP_SHELL/root/usr/bin" "$TMP_SHELL/root/etc/init.d"
	cp -a "$SERVER_DIR/files/www/5700" "$TMP_SHELL/htdocs/5700"
	cp -f "$SERVER_DIR/files/etc/init.d/at-webserver" "$TMP_SHELL/root/etc/init.d/at-webserver"
	chmod 0755 "$TMP_SHELL/root/etc/init.d/at-webserver"

	# 编译 Rust 后端（std-only，零第三方依赖，rust-lld 自包含链接）
	if [ "${WRT_TEST:-false}" != "true" ]; then
		if ! command -v rustup >/dev/null 2>&1; then
			curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
				| sh -s -- -y --profile minimal --default-toolchain stable
		fi
		export PATH="$HOME/.cargo/bin:$PATH"
		rustup target add "$RUST_TARGET" >/dev/null 2>&1 || true

		BIN_PATH="$SERVER_DIR/target/$RUST_TARGET/release/at-webserver"
		if ! (cd "$SERVER_DIR" && \
			RUSTFLAGS="-C link-self-contained=yes -C linker=rust-lld" \
			cargo build --release --locked --target "$RUST_TARGET"); then
			echo "ERROR: luci-app-mt5700m: failed to build at-webserver ($RUST_TARGET)!" >&2
			echo "固件将缺少 /usr/bin/at-webserver（/usr/sbin/mt5700m-at）与 /www/5700，插件不可用。" >&2
			exit 1
		fi
		[ -f "$BIN_PATH" ] || { echo "ERROR: luci-app-mt5700m: at-webserver binary missing after build!" >&2; exit 1; }

		cp -f "$BIN_PATH" "$TMP_SHELL/root/usr/bin/at-webserver"
		chmod 0755 "$TMP_SHELL/root/usr/bin/at-webserver"
	else
		echo "luci-app-mt5700m: TEST 模式，跳过 Rust 后端编译（仅生成配置）"
	fi

	# 清理仓库根残留（含不再需要的 at-webserver 源码目录），还原正式包名
	rm -rf "$SHELL_DIR"
	mv -f "$TMP_SHELL" "$SHELL_DIR"

	if [ -f "$SHELL_DIR/root/usr/bin/at-webserver" ] && [ -f "$SHELL_DIR/htdocs/5700/index.html" ]; then
		echo "luci-app-mt5700m: folded www/5700 + at-webserver backend ($RUST_TARGET)"
	else
		echo "WARNING: luci-app-mt5700m: folded without at-webserver backend (TEST 模式)" >&2
	fi
}

# ===== MT5700（方案 B）：luci-app-mt5700 单包（Rust 后端由包内 src/Makefile 编译）=====
# 该包 Makefile 的 LUCI_DEPENDS 为空，不依赖 sms-tool_q / ubus-at-daemon。
# 包内 src/Makefile 会在 OpenWrt 包编译阶段调用宿主 cargo 交叉编译 at-webserver-rust，
# 因此这里需要预先装好 rustup + 目标 target，并把 cargo PATH / RUSTFLAGS
# 写入 GITHUB_ENV，供后续 Compile Firmware 步骤使用。
# 链接器必须用 rust-lld（自包含 musl），否则 rustc 会驱动宿主 cc，交叉编译失败。
SETUP_RUST_FOR_MT5700() {
	local RUST_TARGET="aarch64-unknown-linux-musl"
	case "${WRT_TARGET:-${WRT_CONFIG:-}}" in
		x86) RUST_TARGET="x86_64-unknown-linux-musl" ;;
	esac

	if [ "${WRT_TEST:-false}" = "true" ]; then
		echo "luci-app-mt5700: TEST 模式，跳过 rustup 安装（仅生成配置）"
		return 0
	fi

	if ! command -v rustup >/dev/null 2>&1; then
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
			| sh -s -- -y --profile minimal --default-toolchain stable
	fi
	export PATH="$HOME/.cargo/bin:$PATH"
	rustup target add "$RUST_TARGET" >/dev/null 2>&1 || true
	echo "luci-app-mt5700: rustup ready, target=$RUST_TARGET"

	# 让后续 GitHub Actions 步骤（尤其 Compile Firmware）能找到 cargo，
	# 并带上与 MT5700M FOLD 相同的 rust-lld 交叉链接参数。
	# PATH 只能通过 GITHUB_PATH 追加；不要写入 GITHUB_ENV 的 PATH（会整段覆盖）。
	if [ -n "${GITHUB_PATH:-}" ]; then
		echo "$HOME/.cargo/bin" >> "$GITHUB_PATH"
	fi
	if [ -n "${GITHUB_ENV:-}" ]; then
		echo "CARGO_HOME=$HOME/.cargo" >> "$GITHUB_ENV"
		echo "RUSTUP_HOME=$HOME/.rustup" >> "$GITHUB_ENV"
		echo "RUSTFLAGS=-C link-self-contained=yes -C linker=rust-lld" >> "$GITHUB_ENV"
	fi
}

case "$MT_MODE" in
	MT5700M)
		echo "MT_MODE=MT5700M：克隆并折叠 luci-app-mt5700m"
		UPDATE_PACKAGE "luci-app-mt5700m" "LianXia233/luci-app-mt5700m" "main"
		FOLD_MT5700M
		# 防污染：若 feeds/工作区意外出现 luci-app-mt5700，主动移除
		rm -rf ./luci-app-mt5700
		;;
	MT5700)
		echo "MT_MODE=MT5700：克隆 luci-app-mt5700（不安装 mt5700m / sms-tool_q / ubus-at-daemon）"
		UPDATE_PACKAGE "luci-app-mt5700" "LianXia233/luci-app-mt5700" "main"
		SETUP_RUST_FOR_MT5700
		# 防污染：若工作区意外出现 mt5700m 相关目录，主动移除
		rm -rf ./luci-app-mt5700m ./luci-app-mt5700m_shell
		;;
	*)
		echo "MT_MODE 为空：跳过所有 MT 插件克隆"
		rm -rf ./luci-app-mt5700 ./luci-app-mt5700m ./luci-app-mt5700m_shell
		;;
esac

UPDATE_PACKAGE "luci-app-h5000m-netmode" "FAN789/luci-app-h5000m-netmode" "main"

#安装 Honk 预编译 APK（避免从源码编译 Rust/eBPF 导致超过 6 小时上限）
# 流程：
#   1. 按编译目标架构从上游最新 release 下载 honk 与 luci-app-honk 的 openwrt-25.12 APK：
#        x86      -> x86_64
#        mediatek -> aarch64_cortex-a53（MT798x / MT7622 均为 Cortex-A53，MTK 机型专用）
#        其余     -> aarch64_generic
#      （与 immortalwrt master 的 APK 格式匹配）
#   2. 将 APK 放入固件 files 覆盖层（/etc/honk/），并写入 uci-defaults 脚本，
#      在设备首次开机时离线 apk add 安装（依赖由 GENERAL.txt 编入镜像，无需联网）。
# 注意：上游 APK 基于 OpenWrt 25.12 构建，与 immortalwrt master 同内核/同 musl，ABI 兼容。
INSTALL_HONK_PREBUILT() {
	echo " "

	# 确定目标架构（优先用 WRT-CORE 导出的 WRT_TARGET，回退到 WRT_CONFIG）
	local HONK_ARCH="aarch64_generic"
	case "${WRT_TARGET:-${WRT_CONFIG:-}}" in
		x86) HONK_ARCH="x86_64" ;;
		mediatek) HONK_ARCH="aarch64_cortex-a53" ;;
	esac

	# 定位 OpenWrt 工作区与 files 覆盖层
	local WRT_FILES="${GITHUB_WORKSPACE:-$(pwd)/..}/wrt/files"
	local HONK_DIR="$WRT_FILES/etc/honk"
	local UCI_DIR="$WRT_FILES/etc/uci-defaults"
	mkdir -p "$HONK_DIR" "$UCI_DIR"

	# 获取上游最新 release 的资产下载地址，筛选本架构的 honk / luci-app-honk（排除 legacy / cortex-a53）
	local REL_JSON
	REL_JSON="$(curl -fsSL --retry 5 --retry-all-errors \
		"https://api.github.com/repos/breeze303/openwrt-honk/releases/latest")" || {
		echo "honk prebuilt: failed to fetch release list!"
		return 1
	}

	local DL_URLS
	DL_URLS="$(printf '%s' "$REL_JSON" | jq -r \
		--arg arch "$HONK_ARCH" \
		'.assets[] | select(.name | test("-"+$arch+"-openwrt-25.12.apk$")) | select(.name | test("legacy") | not) | .browser_download_url')" || {
		echo "honk prebuilt: failed to parse release assets!"
		return 1
	}

	if [ -z "$DL_URLS" ]; then
		echo "honk prebuilt: no matching APK for arch $HONK_ARCH!"
		return 1
	fi

	local URL COUNT=0
	for URL in $DL_URLS; do
		echo "honk prebuilt: downloading $URL"
		curl -fsSL --retry 5 --retry-all-errors -o "$HONK_DIR/$(basename "$URL")" "$URL" && COUNT=$((COUNT + 1))
	done

	if [ "$COUNT" -eq 0 ]; then
		echo "honk prebuilt: all downloads failed!"
		return 1
	fi

	# 写入首次开机安装脚本（离线 apk add，依赖已在镜像内）
	cat > "$UCI_DIR/99-honk-install" <<'EOF'
#!/bin/sh
HONK_DIR="/etc/honk"
if command -v apk >/dev/null 2>&1 && [ -d "$HONK_DIR" ]; then
	if apk add --allow-untrusted "$HONK_DIR"/*.apk >/dev/null 2>&1; then
		rm -f "$HONK_DIR"/*.apk
		echo "honk: prebuilt packages installed at first boot."
	else
		echo "honk: prebuilt install skipped (missing dependencies or unsupported target)."
	fi
fi
EOF
	chmod +x "$UCI_DIR/99-honk-install"

	echo "honk prebuilt: $COUNT package(s) staged for $HONK_ARCH, will install at first boot."
}
# 临时禁用 Honk 插件（2026-08-12）：取消下行注释即可重新启用
# INSTALL_HONK_PREBUILT

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi

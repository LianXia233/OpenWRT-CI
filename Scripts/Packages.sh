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
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "axonhub gecoosac sing-box luci-app-homeproxy luci-app-timewol luci-app-wolplus luci-app-wolultra"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

# FAN789 插件及其他专用硬件插件
UPDATE_PACKAGE "luci-app-h5000m-fancontrol" "FAN789/luci-app-h5000m-fancontrol" "main"
UPDATE_PACKAGE "luci-app-airpi-fancontrol" "LianXia233/luci-app-airpi3000m-fancontrol" "main" "all" "luci-app-airpi-fancontrol kmod-airpi-gpio-fan"
UPDATE_PACKAGE "luci-app-mt5700m" "LianXia233/luci-app-mt5700m" "main"
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

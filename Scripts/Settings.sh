#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#===== 显式配置文件：局域网 / 无线默认值（Config/Defaults.txt）=====
# 优先级：工作流显式传入的 WRT_* 环境变量 > 配置文件默认值 > 脚本内置兜底。
# 配置文件缺失时不报错，直接回落内置兜底（本地手动构建同样可用）。
SYSTEM_CFG="${GITHUB_WORKSPACE:-.}/Config/Defaults.txt"
if [ -f "$SYSTEM_CFG" ]; then
	# shellcheck source=/dev/null
	source "$SYSTEM_CFG"
fi

# 设备 WiFi 世代选择：AP3000M 为 WiFi6（802.11ax），H5000M 为 WiFi7（802.11be）。
# 无线默认值按世代区分（Config/Defaults.txt 中 *_WIFI7 后缀为 WiFi7 专属默认，
# 无后缀为 WiFi6 默认，保持历史兼容）；WRT_DEVICE 由工作流按配置名推导，
# 本地手动构建时回退到 WRT_CONFIG 首段，未知设备一律按 WiFi6 处理。
WRT_DEVICE="${WRT_DEVICE:-${WRT_CONFIG%%-*}}"
if [ "$WRT_DEVICE" = "H5000M" ]; then
	WIFI_SSID="${WIFI_SSID_WIFI7:-$WIFI_SSID}"
	WIFI_PASSWORD="${WIFI_PASSWORD_WIFI7:-$WIFI_PASSWORD}"
	WIFI_ENCRYPTION="${WIFI_ENCRYPTION_WIFI7:-$WIFI_ENCRYPTION}"
	WIFI_COUNTRY="${WIFI_COUNTRY_WIFI7:-$WIFI_COUNTRY}"
	WIFI_2G_MODE="${WIFI_2G_MODE_WIFI7:-$WIFI_2G_MODE}"
	WIFI_5G_MODE="${WIFI_5G_MODE_WIFI7:-$WIFI_5G_MODE}"
	WIFI_2G_WIDTH="${WIFI_2G_WIDTH_WIFI7:-$WIFI_2G_WIDTH}"
	WIFI_5G_WIDTH="${WIFI_5G_WIDTH_WIFI7:-$WIFI_5G_WIDTH}"
fi

# 环境变量（CI 输入）优先；未显式提供时取配置文件默认值
WRT_IP="${WRT_IP:-$LAN_IP}"
WRT_PW="${WRT_PW:-$LAN_PASSWORD}"
WRT_NAME="${WRT_NAME:-$HOST_NAME}"
WRT_SSID="${WRT_SSID:-$WIFI_SSID}"
WRT_WORD="${WRT_WORD:-$WIFI_PASSWORD}"
WRT_THEME="${WRT_THEME:-aurora}"
# 无线策略（沿用原硬编码默认，现可经配置文件覆盖）
WIFI_ENCRYPTION="${WIFI_ENCRYPTION:-psk-mixed}"
WIFI_COUNTRY="${WIFI_COUNTRY:-CN}"
WIFI_2G_MODE="${WIFI_2G_MODE:-AX}"
WIFI_5G_MODE="${WIFI_5G_MODE:-AX}"
WIFI_2G_WIDTH="${WIFI_2G_WIDTH:-40}"
WIFI_5G_WIDTH="${WIFI_5G_WIDTH:-160}"

# 频宽数值 -> htmode 字符串（旧式 set-wireless.sh 分支使用）
# 世代前缀：AX（WiFi6/802.11ax）→ HE，BE（WiFi7/802.11be）→ EHT；
# 2.4G / 5G 同步同一 WiFi 版本：AP3000M 双频 AX，H5000M 双频 BE。
case "$WIFI_2G_MODE" in
	BE) WIFI_2G_HTMODE="EHT${WIFI_2G_WIDTH}" ;;
	*)  WIFI_2G_HTMODE="HE${WIFI_2G_WIDTH}" ;;
esac
case "$WIFI_5G_MODE" in
	BE) WIFI_5G_HTMODE="EHT${WIFI_5G_WIDTH}" ;;
	*)  WIFI_5G_HTMODE="HE${WIFI_5G_WIDTH}" ;;
esac

# 把解析后的最终值回写 GITHUB_ENV：后续步骤（如 Release 说明）展示实际生效值
if [ -n "${GITHUB_ENV:-}" ]; then
	{
		echo "WRT_IP=$WRT_IP"
		echo "WRT_PW=$WRT_PW"
		echo "WRT_NAME=$WRT_NAME"
		echo "WRT_SSID=$WRT_SSID"
		echo "WRT_WORD=$WRT_WORD"
		echo "WRT_THEME=$WRT_THEME"
	} >> "$GITHUB_ENV"
fi

#移除luci-app-attendedsysupgrade
# 用 find -print0 | xargs -0 -r：find 无结果时不执行 sed（-r），避免 sed 缺文件
# 参数时退化为读 stdin；-print0/-0 保证含空格路径也不会被拆词
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 | xargs -0 -r sed -i "/attendedsysupgrade/d"
#修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 | xargs -0 -r sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g"
#修改immortalwrt.lan关联IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -print0 | xargs -0 -r sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g"
#添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -print0 | xargs -0 -r sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g"

WIFI_SH=$(find ./target/linux/mediatek/filogic/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" "$WIFI_SH"
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" "$WIFI_SH"
	#修改加密方式（默认 WPA-PSK/WPA2-PSK Mixed Mode，可经 Config/Defaults.txt 覆盖）
	sed -i "s/encryption='.*'/encryption='$WIFI_ENCRYPTION'/g" "$WIFI_SH"
	#设置国家码（默认 CN，可经 Config/Defaults.txt 覆盖）
	sed -i "s/country='.*'/country='$WIFI_COUNTRY'/g" "$WIFI_SH"
	#修改2.4G默认频宽、5G默认频宽（默认 40/160MHz，可经 Config/Defaults.txt 覆盖）
	sed -i "s/htmode='HT20'/htmode='$WIFI_2G_HTMODE'/g" "$WIFI_SH"
	sed -i "s/htmode='VHT80'/htmode='$WIFI_5G_HTMODE'/g" "$WIFI_SH"
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" "$WIFI_UC"
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" "$WIFI_UC"
	#修改加密方式（默认 WPA-PSK/WPA2-PSK Mixed Mode，可经 Config/Defaults.txt 覆盖）
	sed -i "s/encryption='.*'/encryption='$WIFI_ENCRYPTION'/g" "$WIFI_UC"
	#设置国家码（默认 CN，可经 Config/Defaults.txt 覆盖）
	sed -i "s/country='.*'/country='$WIFI_COUNTRY'/g" "$WIFI_UC"
	#修改2.4G默认频宽、5G默认频宽（默认 40/160MHz，可经 Config/Defaults.txt 覆盖；
	#WiFi7 设备上限放宽到 320MHz，硬件不支持时由驱动自动回落）
	sed -i "s/width = 20;/width = $WIFI_2G_WIDTH;/g" "$WIFI_UC"
	sed -i "s/width > 80)/width > $WIFI_5G_WIDTH)/g" "$WIFI_UC"
	sed -i "s/width = 80;/width = $WIFI_5G_WIDTH;/g" "$WIFI_UC"
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"
#修改默认时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" "$CFG_FILE"
sed -i "s/zonename='.*'/zonename='Asia\/Shanghai'/g" "$CFG_FILE"

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat "$GITHUB_WORKSPACE/Config/PRIVATE.txt" >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

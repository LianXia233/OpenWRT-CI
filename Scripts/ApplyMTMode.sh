#!/bin/bash
# SPDX-License-Identifier: MIT
# MT 模式配置层应用脚本（由 WRT-CORE 在 Custom Settings 阶段调用）
#
# 职责：
#   1. 校验 MT_MODE 合法性（仅允许 空 / MT5700 / MT5700M）
#   2. 按模式向 .config 叠加独立插件配置层
#   3. 在配置生成前主动写入互斥包的 =n，防止 make defconfig 被间接依赖拉回
#
# 使用方式（在 OpenWrt 源码根目录执行，且机型配置 + GENERAL 已写入 .config 之后）：
#   MT_MODE=MT5700M $GITHUB_WORKSPACE/Scripts/ApplyMTMode.sh
#
# MT_MODE 含义：
#   ""        —— 不安装任何 MT 插件（原有普通 CI 行为）
#   MT5700    —— 仅 luci-app-mt5700（方案 B）
#   MT5700M   —— luci-app-mt5700m + sms-tool_q + ubus-at-daemon（方案 A）
#   其他值    —— 直接 ::error:: 并 exit 1

set -euo pipefail

MODE="${MT_MODE:-}"
CFG_GITHUB="${GITHUB_WORKSPACE:-}"
if [ -n "$CFG_GITHUB" ]; then
	CFG_DIR="$CFG_GITHUB/Config"
else
	CFG_DIR="$(cd "$(dirname "$0")/../Config" && pwd)"
fi

echo "::group::检测 MT 模式"

case "$MODE" in
	"" )
		echo "::notice::MT_MODE 为空：不安装任何 MT5700 / MT5700M 相关插件"
		;;
	MT5700 )
		echo "::notice::MT_MODE=MT5700：仅安装 luci-app-mt5700（方案 B）"
		;;
	MT5700M )
		echo "::notice::MT_MODE=MT5700M：安装 luci-app-mt5700m + sms-tool_q + ubus-at-daemon（方案 A）"
		;;
	* )
		echo "::error::非法 MT_MODE='$MODE'（仅允许空 / MT5700 / MT5700M），终止 CI"
		exit 1
		;;
esac

# 必须在 OpenWrt 源码根目录（存在 .config 或即将生成）
if [ ! -f ./.config ] && [ ! -f ./Makefile ]; then
	echo "::error::ApplyMTMode.sh 必须在 OpenWrt 源码根目录执行"
	exit 1
fi

# 写入互斥保护：无论本模式是否启用，都先把对侧包显式置 n
# 这样即使机型配置/PRIVATE/WRT_PACKAGE 意外写入对侧包，也会被覆盖为禁用。
write_disable() {
	local pkg
	for pkg in "$@"; do
		echo "CONFIG_PACKAGE_${pkg}=n" >> ./.config
		echo "  禁用 ${pkg}"
	done
}

case "$MODE" in
	MT5700 )
		echo "叠加配置层：Config/MT5700.txt"
		[ -f "$CFG_DIR/MT5700.txt" ] || { echo "::error::缺少 $CFG_DIR/MT5700.txt"; exit 1; }
		cat "$CFG_DIR/MT5700.txt" >> ./.config
		echo "互斥保护：强制禁用 MT5700M 侧包"
		write_disable luci-app-mt5700m luci-i18n-mt5700m-zh-cn sms-tool_q ubus-at-daemon
		;;
	MT5700M )
		echo "叠加配置层：Config/MT5700M.txt"
		[ -f "$CFG_DIR/MT5700M.txt" ] || { echo "::error::缺少 $CFG_DIR/MT5700M.txt"; exit 1; }
		cat "$CFG_DIR/MT5700M.txt" >> ./.config
		echo "互斥保护：强制禁用 MT5700 侧包"
		write_disable luci-app-mt5700 luci-i18n-mt5700-zh-cn
		# 驱动互斥兜底（详见 Config/MT5700M.txt 同名段落）：
		# MT5700M 的 QMI WWAN 驱动由 QModem feed 的 qmodem 主包经 vendor choice 拉入
		# （kmod-qmi_wwan_f / kmod-qmi_wwan_q / kmod-qmi_wwan_s，分别产出
		#  qmi_wwan_f.ko / qmi_wwan_q.ko / qmi_wwan_s.ko）。而机型配置 + GENERAL.txt
		# 会启用 feeds/packages 侧产出同名 .ko 的驱动，二者装进同一 rootfs 即争抢
		# 文件归属，apk 拒绝覆盖，package/install 以非零退出、整包构建中断。
		# 这里在 Config/MT5700M.txt 之后再次写入，覆盖机型配置 / PRIVATE.txt /
		# WRT_PACKAGE 可能引入的 =y。
		echo "驱动互斥保护：强制禁用 packages feed 侧 QMI WWAN vendor 驱动"
		write_disable \
			kmod-usb-net-qmi-wwan-fibocom \
			kmod-usb-net-qmi-wwan-quectel
		;;
	"" )
		echo "空模式：显式禁用全部 MT 相关包（防止被其他配置层拉入）"
		write_disable \
			luci-app-mt5700 luci-i18n-mt5700-zh-cn \
			luci-app-mt5700m luci-i18n-mt5700m-zh-cn \
			sms-tool_q ubus-at-daemon
		;;
esac

echo "::endgroup::"

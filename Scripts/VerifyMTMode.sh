#!/bin/bash
# SPDX-License-Identifier: MIT
# MT 模式最终 .config 互斥验证（由 WRT-CORE 在 make defconfig 之后调用）
#
# 检查点：
#   - MT5700：必须存在 luci-app-mt5700；必须不存在 mt5700m / sms-tool_q / ubus-at-daemon
#   - MT5700M：必须存在 mt5700m / sms-tool_q / ubus-at-daemon；必须不存在 luci-app-mt5700
#   - 空模式：上述四类包全部不得被选中
#
# 在 OpenWrt 源码根目录执行。发现违规时 ::error:: 并 exit 1。

set -euo pipefail

MODE="${MT_MODE:-}"
DOT_CONFIG="./.config"

echo "::group::验证 MT 模式包选择"

if [ ! -f "$DOT_CONFIG" ]; then
	echo "::error::未找到 $DOT_CONFIG，请先执行 make defconfig"
	exit 1
fi

# 从最终 .config 读取包是否被选中（y 或 m 均视为选中）
pkg_selected() {
	local pkg="$1"
	grep -qE "^CONFIG_PACKAGE_${pkg}=[ym]" "$DOT_CONFIG"
}

pkg_disabled() {
	local pkg="$1"
	# 未出现，或显式 =n
	if grep -qE "^CONFIG_PACKAGE_${pkg}=[ym]" "$DOT_CONFIG"; then
		return 1
	fi
	return 0
}

report_pkg() {
	local pkg="$1"
	if pkg_selected "$pkg"; then
		echo "  [选中] $pkg"
	else
		echo "  [未选中] $pkg"
	fi
}

echo "::notice::MT_MODE=${MODE:-（空）}"
echo "最终 .config 包状态："
for p in luci-app-mt5700 luci-app-mt5700m sms-tool_q ubus-at-daemon; do
	report_pkg "$p"
done

FAIL=0

check_must() {
	local pkg="$1"
	if ! pkg_selected "$pkg"; then
		echo "::error::MT_MODE=${MODE} 要求必须选中 ${pkg}，但最终 .config 中未选中"
		FAIL=1
	fi
}

check_must_not() {
	local pkg="$1"
	if pkg_selected "$pkg"; then
		echo "::error::MT_MODE=${MODE} 要求不得选中 ${pkg}，但最终 .config 中被选中（配置污染）"
		FAIL=1
	fi
}

case "$MODE" in
	MT5700 )
		check_must luci-app-mt5700
		check_must_not luci-app-mt5700m
		check_must_not sms-tool_q
		check_must_not ubus-at-daemon
		# 反向依赖探测：mt5700m 不应被任何包以 =y 拉入
		if grep -qE '^CONFIG_PACKAGE_luci-app-mt5700m=[ym]' "$DOT_CONFIG"; then
			echo "::error::检测到 MT5700 与 MT5700M 软件包冲突"
		fi
		;;
	MT5700M )
		check_must luci-app-mt5700m
		check_must sms-tool_q
		check_must ubus-at-daemon
		check_must_not luci-app-mt5700
		if grep -qE '^CONFIG_PACKAGE_luci-app-mt5700=[ym]' "$DOT_CONFIG"; then
			echo "::error::检测到 MT5700M 与 MT5700 软件包冲突"
		fi
		;;
	"" )
		check_must_not luci-app-mt5700
		check_must_not luci-app-mt5700m
		check_must_not sms-tool_q
		check_must_not ubus-at-daemon
		;;
	* )
		echo "::error::非法 MT_MODE='$MODE'（仅允许空 / MT5700 / MT5700M）"
		FAIL=1
		;;
esac

if [ "$FAIL" -ne 0 ]; then
	echo "::error::MT 模式互斥验证失败，已中止编译"
	echo "::endgroup::"
	exit 1
fi

echo "::notice::MT 模式互斥验证通过"
echo "::endgroup::"

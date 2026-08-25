#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -d "$GITHUB_WORKSPACE/wrt/package" ]; then
	PKG_PATH="$GITHUB_WORKSPACE/wrt/package"
else
	PKG_PATH="$(pwd)"
fi

#预置HomeProxy数据
HP_DIR="$(find "$PKG_PATH" -maxdepth 1 -type d -name '*homeproxy*' -print -quit)"
if [ -n "$HP_DIR" ]; then
	echo " "

	HP_RESOURCES="$HP_DIR/root/etc/homeproxy/resources"
	HP_DASHBOARD="$HP_DIR/root/etc/homeproxy/dashboard"
	HP_IP_SOURCE="https://cdn.jsdelivr.net/gh/Loyalsoldier/surge-rules@release/cncidr.txt"
	HP_GEOSITE_SOURCE="https://cdn.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set-unstable/geosite-cn.srs"
	HP_IP_VERSION_URL="https://github.com/Loyalsoldier/surge-rules/releases/latest"
	HP_GEOSITE_VERSION_URL="https://github.com/SagerNet/sing-geosite/releases/latest"
	HP_DASHBOARD_SOURCE="https://codeload.github.com/SagerNet/sing-box-dashboard/zip/refs/heads/gh-pages"
	HP_DASHBOARD_VERSION_URL="https://github.com/SagerNet/sing-box-dashboard/commits/gh-pages.atom"
	HP_USER_AGENT="HomeProxy resource preset"

	HP_PREREQUISITES_MISSING=0
	for HP_COMMAND in curl awk; do
		command -v "$HP_COMMAND" > /dev/null 2>&1 || {
			echo "homeproxy resource preset requires $HP_COMMAND!"
			HP_PREREQUISITES_MISSING=1
		}
	done
	HP_PRESET_FAILED=0
	if [ "${HP_PREREQUISITES_MISSING:-0}" -eq 1 ]; then
		HP_PRESET_FAILED=1
	else
		HP_TMP="$(mktemp -d)"
		if [ -z "$HP_TMP" ]; then
			echo "failed to prepare homeproxy resource preset directory!"
			HP_PRESET_FAILED=1
		fi
	fi
	HP_DASHBOARD_STAGE="${HP_DASHBOARD}.new.$$"
	if [ "$HP_PRESET_FAILED" -eq 0 ]; then
		trap 'rm -rf "$HP_TMP" "$HP_DASHBOARD_STAGE"' EXIT INT TERM
	fi

	hp_fetch_release_version() {
		local effective_url version

		effective_url="$(curl -fsSL --compressed --retry 3 --retry-all-errors \
			--retry-delay 1 \
			--connect-timeout 10 --max-time 30 -A "$HP_USER_AGENT" \
			-o /dev/null -w '%{url_effective}' "$1")" || return 1
		version="${effective_url##*/}"
		case "$version" in
		''|*[!0-9]*) return 1 ;;
		esac
		printf '%s\n' "$version"
	}

	hp_download() {
		curl -fsSL --compressed --retry 3 --retry-all-errors --retry-delay 1 \
			--connect-timeout 10 \
			--max-time 60 -A "$HP_USER_AGENT" -o "$2" "$1" && [ -s "$2" ]
	}

	hp_fetch_dashboard_version() {
		local feed version

		feed="$(curl -fsSL --compressed --retry 3 --retry-all-errors \
			--retry-delay 1 --connect-timeout 10 --max-time 30 \
			-A "$HP_USER_AGENT" "$HP_DASHBOARD_VERSION_URL")" || return 1
		version="$(printf '%s\n' "$feed" | awk -F '[<>]' '
			/<updated>/ {
				version = $3
				gsub(/[-:TZ]/, "", version)
				print version
				exit
			}
		')"
		case "$version" in
		??????????????) case "$version" in *[!0-9]*) return 1 ;; esac ;;
		*) return 1 ;;
		esac
		printf '%s\n' "$version"
	}

	hp_replace_file() {
		local source_file="$1" target_file="$2" temporary_file

		temporary_file="${target_file}.tmp.$$"
		cp "$source_file" "$temporary_file" || return 1
		chmod 0644 "$temporary_file" || return 1
		mv -f "$temporary_file" "$target_file"
	}

	hp_update_ip() {
		local version file

		version="$(hp_fetch_release_version "$HP_IP_VERSION_URL")" || return 1
		hp_download "$HP_IP_SOURCE?v=$version" "$HP_TMP/cncidr.txt" || return 1
		awk -F, -v ipv4="$HP_TMP/china_ip4.txt" -v ipv6="$HP_TMP/china_ip6.txt" '
			$1 == "IP-CIDR" { print $2 > ipv4 }
			$1 == "IP-CIDR6" { print $2 > ipv6 }
		' "$HP_TMP/cncidr.txt" || return 1
		[ -s "$HP_TMP/china_ip4.txt" ] && [ -s "$HP_TMP/china_ip6.txt" ] || return 1
		awk '
			BEGIN {
				print "{\"version\":5,\"rules\":[{\"ip_cidr\":["
				first = 1
			}
			NF {
				printf "%s\"%s\"", first ? "" : ",", $0
				first = 0
			}
			END { print "]}]}" }
		' "$HP_TMP/china_ip4.txt" "$HP_TMP/china_ip6.txt" > "$HP_TMP/geoip_cn.json" || return 1
		[ -s "$HP_TMP/geoip_cn.json" ] || return 1
		printf '%s\n' "$version" > "$HP_TMP/china_ip4.ver"
		printf '%s\n' "$version" > "$HP_TMP/china_ip6.ver"
		for file in china_ip4.txt china_ip4.ver china_ip6.txt china_ip6.ver geoip_cn.json; do
			hp_replace_file "$HP_TMP/$file" "$HP_RESOURCES/$file" || return 1
		done
		echo "homeproxy resources: china_ip $version"
	}

	hp_update_geosite() {
		local version

		version="$(hp_fetch_release_version "$HP_GEOSITE_VERSION_URL")" || return 1
		hp_download "$HP_GEOSITE_SOURCE?v=$version" "$HP_TMP/geosite_cn.srs" || return 1
		printf '%s\n' "$version" > "$HP_TMP/geosite_cn.ver"
		hp_replace_file "$HP_TMP/geosite_cn.srs" "$HP_RESOURCES/geosite_cn.srs" || return 1
		hp_replace_file "$HP_TMP/geosite_cn.ver" "$HP_RESOURCES/geosite_cn.ver" || return 1
		echo "homeproxy resources: geosite_cn $version"
	}

	hp_update_dashboard() {
		local version source_dir old_dir

		command -v unzip > /dev/null 2>&1 || return 1
		command -v find > /dev/null 2>&1 || return 1
		version="$(hp_fetch_dashboard_version)" || return 1
		hp_download "$HP_DASHBOARD_SOURCE?v=$version" "$HP_TMP/dashboard.zip" || return 1
		unzip -q "$HP_TMP/dashboard.zip" -d "$HP_TMP/dashboard" || return 1
		source_dir="$(find "$HP_TMP/dashboard" -mindepth 1 -maxdepth 1 -type d -print -quit)"
		[ -n "$source_dir" ] && [ -f "$source_dir/index.html" ] || return 1

		rm -rf "$HP_DASHBOARD_STAGE"
		mkdir -p "$HP_DASHBOARD_STAGE" &&
			cp -a "$source_dir/." "$HP_DASHBOARD_STAGE/" &&
			printf '%s\n' "$version" > "$HP_DASHBOARD_STAGE/dashboard.ver" || return 1
		rm -f "$HP_DASHBOARD_STAGE/.etag"
		chmod -R a+rX "$HP_DASHBOARD_STAGE" || return 1

		old_dir="${HP_DASHBOARD}.old.$$"
		rm -rf "$old_dir"
		{ [ ! -d "$HP_DASHBOARD" ] || mv "$HP_DASHBOARD" "$old_dir"; } || return 1
		if mv "$HP_DASHBOARD_STAGE" "$HP_DASHBOARD"; then
			rm -rf "$old_dir"
			echo "homeproxy dashboard: $version"
			return 0
		fi
		rm -rf "$HP_DASHBOARD"
		[ ! -d "$old_dir" ] || mv "$old_dir" "$HP_DASHBOARD"
		return 1
	}

	if [ "$HP_PRESET_FAILED" -eq 0 ] && ! mkdir -p "$HP_RESOURCES" "$HP_DASHBOARD"; then
		echo "failed to prepare homeproxy resource directories!"
		HP_PRESET_FAILED=1
	fi

	if [ "$HP_PRESET_FAILED" -eq 0 ]; then
		if ! hp_update_ip; then
			echo "failed to update homeproxy IP resources; continuing!"
			HP_PRESET_FAILED=1
		fi

		if ! hp_update_geosite; then
			echo "failed to update homeproxy geosite; continuing!"
			HP_PRESET_FAILED=1
		fi

		if ! hp_update_dashboard; then
			echo "failed to update homeproxy dashboard; continuing!"
			HP_PRESET_FAILED=1
		fi

		rm -rf "$HP_TMP" "$HP_DASHBOARD_STAGE"
		trap - EXIT INT TERM
	fi

	if [ "$HP_PRESET_FAILED" -eq 0 ]; then
		echo "homeproxy data has been updated!"
	else
		echo "homeproxy resource preset completed with errors; continuing other handlers!"
	fi
fi

#修复homeproxy ucode兼容性问题
# update_subscriptions.uc: luci.sys.init_action不存在 → system()调用
# generate_client.uc: math.isnan不存在 → type() === 'double'
HP_SCRIPTS="$HP_DIR/root/etc/homeproxy/scripts"
HP_FIXES="$GITHUB_WORKSPACE/Scripts/homeproxy"
if [ -n "$HP_DIR" ] && [ -d "$HP_SCRIPTS" ] && [ -d "$HP_FIXES" ]; then
	echo " "
	if cp -f "$HP_FIXES/update_subscriptions.uc" "$HP_SCRIPTS/" && \
	   cp -f "$HP_FIXES/generate_client.uc" "$HP_SCRIPTS/"; then
		echo "homeproxy ucode compatibility fixes applied!"
	else
		echo "homeproxy ucode fix failed; continuing!"
	fi
fi

#修改argon主题字体和颜色
if [ -d "$PKG_PATH/luci-theme-argon" ]; then
	echo " "
	if sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" \
		"$PKG_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"; then
		echo "theme-argon has been fixed!"
	else
		echo "theme-argon fix failed; continuing!"
	fi
fi

#修改aurora菜单式样
if [ -d "$PKG_PATH/luci-app-aurora-config" ]; then
	echo " "
	if find "$PKG_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec \
		sed -i "s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +; then
		echo "theme-aurora has been fixed!"
	else
		echo "theme-aurora fix failed; continuing!"
	fi
fi

#修改mini-diskmanager菜单位置
if [ -d "$PKG_PATH/luci-app-mini-diskmanager" ]; then
	echo " "
	if sed -i "s/services/system/g" \
		"$PKG_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"; then
		echo "mini-diskmanager has been fixed!"
	else
		echo "mini-diskmanager fix failed; continuing!"
	fi
fi

#修复TailScale配置文件冲突
FEEDS_PACKAGES="$PKG_PATH/../feeds/packages"
TS_FILE="$(find "$FEEDS_PACKAGES" -maxdepth 3 -type f -wholename '*/tailscale/Makefile' -print -quit 2>/dev/null)"
if [ -f "$TS_FILE" ]; then
	echo " "

	if sed -i '/\/files/d' "$TS_FILE"; then
		echo "tailscale has been fixed!"
	else
		echo "tailscale fix failed; continuing!"
	fi
fi

#修复Rust编译失败
RUST_FILE="$(find "$FEEDS_PACKAGES" -maxdepth 3 -type f -wholename '*/rust/Makefile' -print -quit 2>/dev/null)"
if [ -f "$RUST_FILE" ]; then
	echo " "

	if sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"; then
		echo "rust has been fixed!"
	else
		echo "rust fix failed; continuing!"
	fi
fi

#AP3000M EEPROM 自动初始化 (备份EEPROM模板 + uci-defaults)
if [ "$WRT_CONFIG" = "AP3000M" ]; then
	echo " "
	echo "AP3000M EEPROM fix: injecting..."

	EEPROM_DIR="$GITHUB_WORKSPACE/AP3000M-EEPROM"
	WRT_FILES="$PKG_PATH/../files"

	if [ -d "$EEPROM_DIR" ]; then
		# 固件目录
		mkdir -p "$WRT_FILES/lib/firmware/mediatek/"
		cp "$EEPROM_DIR/mt7981_eeprom_mt7976_dbdc.bin" "$WRT_FILES/lib/firmware/mediatek/"

		# uci-defaults 脚本（首次启动自动 patch MAC 并修正 radio1 为 5g）
		mkdir -p "$WRT_FILES/etc/uci-defaults/"
		cp "$EEPROM_DIR/99-ap3000m-eeprom" "$WRT_FILES/etc/uci-defaults/"
		chmod +x "$WRT_FILES/etc/uci-defaults/99-ap3000m-eeprom"

		echo "AP3000M EEPROM fix injected!"
	else
		echo "AP3000M-EEPROM directory not found; skipping EEPROM fix!"
	fi
fi


#MT7987 WED (Wireless Ethernet Dispatch) V3.1 硬件路径支持（仅 H5000M-WIFI-YES 机型）
# 背景：immortalwrt master（内核 6.18）缺少 MT7987 的 WED hwpath 补丁
# （联发科 mtk-openwrt-feeds 的 999-wed-10-add-mt7987-hwpath-support.patch），
# DTS 缺 wo-ccif 节点导致 mtk_wed_wo_init 返回 -ENODEV、WED 强制回落 N，
# dmesg 报 "platform 15010000.wed: failed to attach wed device"。
# 本段把已移植到 6.18 API 的 WED V3.1 补丁注入 target/linux/mediatek/patches-*，
# 并同步修正 mt76 侧 hw_rro 枚举赋值，使 MT7987（H5000M 平台）硬件加速可用。
# 注意：本补丁仅适用于 H5000M（MT7987+MT7992）机型，其他机型（AP3000M / X86 等）
# SoC 与 WiFi 芯片不同，注入会导致编译失败，因此只对 H5000M-WIFI-YES 注入。
WED_PATCHES_SRC="$GITHUB_WORKSPACE/Scripts/patches/wed"
if [ "$WRT_CONFIG" = "H5000M-WIFI-YES" ] && [ -d "$WED_PATCHES_SRC" ]; then
	echo " "
	echo "WED patch injection: target machine is H5000M-WIFI-YES, applying mt7987 WED v3.1 patches..."

	WED_APPLIED=0

	# 1) 内核侧：MT7987 WED V3.1 支持补丁（含 mtk_wed.c/.h/_regs.h/_debugfs.c/_mcu.c/_wo.c 与公共头）
	WED_PATCH_DIRS="$(find "$GITHUB_WORKSPACE/wrt/target/linux/mediatek" -maxdepth 1 -type d -name 'patches-*' 2>/dev/null)"
	for PD in $WED_PATCH_DIRS; do
		[ -d "$PD" ] || continue
		if cp -f "$WED_PATCHES_SRC"/999-mtk7987-wed-v31.patch "$PD/"; then
			echo "mt7987 WED v3.1 patch copied to: $PD"
			WED_APPLIED=1
		fi
	done

	# 2) mt76 侧：WED 公共头 wlan.hw_rro 由 bool 改为 enum 后，
	#    mt7996/mmio.c 仍需按 hwrro_mode 传枚举（否则 V3.1 被折叠成 V3）
	MT76_PATCH_DIRS="$(
		find "$GITHUB_WORKSPACE/wrt/package/kernel/mt76" -maxdepth 1 -type d -name 'patches' 2>/dev/null
		find "$GITHUB_WORKSPACE/wrt/feeds/packages" -maxdepth 4 -type d -path '*/kernel/mt76/patches' 2>/dev/null
	)"
	for PD in $MT76_PATCH_DIRS; do
		[ -d "$PD" ] || continue
		if cp -f "$WED_PATCHES_SRC"/998-mt76-wed-hwrro-enum.patch "$PD/"; then
			echo "mt76 hw_rro enum patch copied to: $PD"
			WED_APPLIED=1
		fi
	done

	if [ "$WED_APPLIED" -eq 1 ]; then
		echo "mt7987 WED v3.1 support has been injected!"
	else
		echo "mt7987 WED patch target not found (mediatek target or mt76 missing); continuing!"
	fi
fi

#修复 dockerd 在 CI runner 上的构建失败
# 根因：moby 的 hack/make/binary-daemon 中 copy_binaries() 在宿主已安装 docker
# （存在 /usr/local/bin/runc）且同架构时，会尝试从宿主 PATH 拷贝
# containerd / runc / rootlesskit / dockerd-rootless.sh 等“嵌套可执行文件”，
# 但 GitHub Actions runner 上这些并不在 PATH，command -v 返回空导致 cp '' 报错，
# 配合 set -e 直接中断编译（报错位置：make[3]: *** [Makefile:166: .../.built] Error 1）。
# 修复策略（双保险，确保万无一失）：
#   1) 保留 999-fix-nested-binaries.patch 放入 patches/（OpenWrt 标准机制，能用时生效）；
#   2) 额外把 fix-binary-daemon.sh 拷入 dockerd 包目录，并修改其 Build/Compile，
#      在源码解包后、执行 ./hack/make.sh binary 之前对 hack/make/binary-daemon
#      做就地 sed 修正，并以 `source`（.）方式注入，避免 `bash "; \` 把
#      DOCKER_GITCOMMIT / GO_PKG_VARS 等前缀环境变量截断——否则 ./hack/make.sh binary
#      会因缺少 DOCKER_GITCOMMIT 而报错（error: .git directory missing and DOCKER_GITCOMMIT not specified）。
DOCKERD_PATCHES_SRC="$GITHUB_WORKSPACE/Scripts/patches/dockerd"
if [ -d "$DOCKERD_PATCHES_SRC" ]; then
	echo " "

	# 收集 dockerd 包可能存在的所有位置（拷贝与软链两种安装方式均覆盖）
	DOCKERD_DIRS="$(
		find "$FEEDS_PACKAGES" -maxdepth 3 -type d -wholename '*/dockerd' 2>/dev/null
		find "$PKG_PATH/feeds/packages" -maxdepth 2 \( -type d -o -type l \) -name 'dockerd' 2>/dev/null
	)"

	APPLIED=0
	for D in $DOCKERD_DIRS; do
		[ -e "$D" ] || continue
		mkdir -p "$D/patches"
		# 1) 标准补丁机制（能用时生效）
		if cp -f "$DOCKERD_PATCHES_SRC"/*.patch "$D/patches/" 2>/dev/null; then
			echo "dockerd patch copied to: $D/patches"
			APPLIED=1
		fi
		# 2) 修正脚本也放入包目录，供 Build/Compile 直接调用
		if cp -f "$DOCKERD_PATCHES_SRC/fix-binary-daemon.sh" "$D/" 2>/dev/null; then
			chmod +x "$D/fix-binary-daemon.sh"
			echo "dockerd fix script copied to: $D"
			APPLIED=1
		fi
	done

	# 修改 dockerd Makefile 的 Build/Compile，在 ./hack/make.sh binary 之前调用修正脚本
	DOCKERD_MAKEFILES="$(
		find "$FEEDS_PACKAGES" -maxdepth 3 -type f -wholename '*/dockerd/Makefile' 2>/dev/null
		find "$PKG_PATH/feeds/packages" -maxdepth 2 -type f -name 'Makefile' -path '*/dockerd/*' 2>/dev/null
	)"
	for MK in $DOCKERD_MAKEFILES; do
		[ -f "$MK" ] || continue
		python3 - "$MK" <<'PYEOF'
import sys
mk = sys.argv[1]
s = open(mk, encoding='utf-8').read()
marker = '\t./hack/make.sh binary\n'
# 注意：必须用 `&& \` 续行符结尾，确保 ./hack/make.sh binary 与
# cd/注入脚本处于同一条 make recipe（同一 shell）中执行；
# 否则它会退化为独立 recipe 行，在包目录而非 PKG_BUILD_DIR 下执行，
# 导致 `./hack/make.sh: No such file or directory`（Error 127）。
inject = '\tcd $(PKG_BUILD_DIR) && . "$(CURDIR)/fix-binary-daemon.sh" "$(PKG_BUILD_DIR)" && \\\n'
if 'fix-binary-daemon.sh' in s:
	pass  # 已注入，跳过（幂等）
elif marker in s:
	s = s.replace(marker, inject + marker, 1)
	open(mk, 'w', encoding='utf-8').write(s)
	print('dockerd Makefile Build/Compile patched: ' + mk)
else:
	print('dockerd Makefile marker not found, skip: ' + mk)
PYEOF
		APPLIED=1
	done

	if [ "$APPLIED" -eq 1 ]; then
		echo "dockerd build fix has been applied!"
	else
		echo "dockerd build fix failed; continuing!"
	fi
fi

#修复 honk 包安装阶段 /var 目录冲突
# 根因：honk 的 Package/honk/install 中执行 $(INSTALL_DIR) $(1)/var/share/honk，
# 会在 pkgdir 下创建 var/ 目录；但 OpenWrt rootfs 中 /var 是指向 /tmp 的符号链接，
# 构建系统复制 pkgdir 到 rootfs 时 cp 无法用目录覆盖符号链接，报错：
#   cp: cannot overwrite non-directory '.../root-mediatek/./var' with directory '.../.pkgdir/honk/./var'
# 修复方式：移除 install 中的 /var/share/honk 创建与 chmod；运行时数据目录由
# honk.init 的 prepare_subscription_store() 在启动时自动 mkdir -p 创建。
HONK_FILE="$(find "$PKG_PATH" -maxdepth 2 -type f -wholename '*/honk/Makefile' -print -quit 2>/dev/null)"
if [ -f "$HONK_FILE" ]; then
	echo " "

	if sed -i '/chmod 0700 \$(1)\/var\/share\/honk/d; s# \$(1)/var/share/honk##g' "$HONK_FILE"; then
		echo "honk /var directory conflict has been fixed!"
	else
		echo "honk fix failed; continuing!"
	fi
fi

#修复 sing-box 1.14.0-rc.1 与 golang.org/x/net >= v0.58.0 的 connPool linkname 不兼容
# 根因：sing-box/transport/v2rayhttp/force_close.go 通过 //go:linkname 访问
# golang.org/x/net/http2.(*Transport).connPool 内部方法，但 x/net >= v0.58.0
# 移除/重命名了该方法，导致链接阶段 undefined reference 错误。
# 修复：移除 go:linkname 声明，将 http2.Transport 分支改为直接返回 transport
# （http2.Transport 无公开的 CloseIdleConnections 方法，连接由 GC 回收）。
SINGBOX_FORCE_CLOSE="$(find "$PKG_PATH" -maxdepth 5 -type f -wholename '*/sing-box/transport/v2rayhttp/force_close.go' -print -quit 2>/dev/null)"
if [ -f "$SINGBOX_FORCE_CLOSE" ]; then
	echo " "
	python3 - "$SINGBOX_FORCE_CLOSE" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    lines = f.readlines()
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    if '//go:linkname transportConnPool' in line:
        i += 1
        if i < len(lines) and 'func transportConnPool' in lines[i]:
            i += 1
        continue
    if 'case *http2.Transport:' in line:
        new_lines.append(line)
        new_lines.append('\t\t// golang.org/x/net >= v0.58.0 removed the internal connPool method,\n')
        new_lines.append('\t\t// breaking the go:linkname hack. Simply return the transport.\n')
        i += 1
        while i < len(lines) and 'return transport' not in lines[i]:
            i += 1
        if i < len(lines):
            new_lines.append(lines[i])
            i += 1
        continue
    new_lines.append(line)
    i += 1
with open(path, 'w') as f:
    f.writelines(new_lines)
print("sing-box force_close.go patched successfully")
PYEOF
	if [ $? -eq 0 ]; then
		echo "sing-box connPool linkname fix applied!"
	else
		echo "sing-box fix failed; continuing!"
	fi
fi

#!/bin/bash
# CI 修复脚本：修正 moby 的 hack/make/binary-daemon 在交叉编译宿主上的构建失败。
#
# 根因：copy_binaries() 在宿主已安装 docker（存在 /usr/local/bin/runc）且同架构时，
# 会尝试从宿主 PATH 拷贝 containerd / runc / rootlesskit / dockerd-rootless.sh 等
# “嵌套可执行文件”到 bundle 目录。但 GitHub Actions runner 上这些并不在 PATH，
# command -v 返回空，导致 `cp -f ""` 报错，配合 set -e 直接中断编译。
#
# 修复：把拷贝改为“仅当该可执行文件存在于 PATH 时才拷贝，缺失则跳过”。
# containerd / runc / tini 等本就由独立的 OpenWrt 包在运行时提供，无需打入 bundle。
#
# 用法：fix-binary-daemon.sh <PKG_BUILD_DIR>
#   <PKG_BUILD_DIR> 为解包后的 moby 源码目录（内含 hack/make/binary-daemon）。

set -u

BUILD_DIR="${1:-.}"
TARGET="$BUILD_DIR/hack/make/binary-daemon"

if [ ! -f "$TARGET" ]; then
	echo "fix-binary-daemon: $TARGET not found, skip"
	exit 0
fi

if sed -i 's#cp -f "$(command -v "$file")" "$dir/"#bin="$(command -v "$file" 2>/dev/null || true)"; [ -n "$bin" ] \&\& cp -f "$bin" "$dir/"#' "$TARGET"; then
	echo "fix-binary-daemon: patched $TARGET"
else
	echo "fix-binary-daemon: sed failed on $TARGET" >&2
fi

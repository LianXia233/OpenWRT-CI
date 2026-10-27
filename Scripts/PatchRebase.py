#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PatchRebase —— 客制补丁上下文自动重定基。

背景
----
OpenWrt/ImmortalWrt 的包常带客制补丁（如 firewall4 的 fullcone 支持）。
上游一旦重构补丁所触及的函数，补丁的“上下文行”就会变化，
表现为 prepare 阶段 `Hunk #N FAILED`，整包编译中断，而补丁本身的语义并没有过时。

本脚本只做一件事：**重建 hunk 的上下文行**，绝不猜测补丁的增删内容。
  1. 先在解包后的源码上 `patch --dry-run`：能原样应用就一字不改；
  2. 打不上时，对每个 hunk 用「删除行块」在目标文件中做唯一锚点定位，
     再按 hunk 原有的增删结构重建上下文；
  3. 重建结果必须整体 dry-run 通过才写回补丁文件，否则保持原样并以非 0 退出。

用法
----
    PatchRebase.py --wrt ./wrt --package package/network/config/firewall4
    PatchRebase.py --wrt ./wrt --package package/network/config/firewall4 --all

`--all` 表示该包 patches/ 下所有补丁都参与检查（默认只处理无法应用的补丁，
能打上的补丁不会被动到）。
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")


class Hunk:
    def __init__(self, header, lines):
        self.header = header
        self.lines = lines
        m = HUNK_RE.match(header)
        if not m:
            raise ValueError("无法解析 hunk 头: %r" % header)
        self.old_start = int(m.group(1))
        self.old_count = 1 if m.group(2) is None else int(m.group(2))
        self.new_start = int(m.group(3))
        self.new_count = 1 if m.group(4) is None else int(m.group(4))
        self.tail = m.group(5)

    def header_with(self, old_start, old_count, new_start, new_count):
        return "@@ -%d,%d +%d,%d @@%s" % (old_start, old_count, new_start, new_count, self.tail)


class FilePatch:
    def __init__(self, header, target):
        self.header = header
        self.target = target
        self.hunks = []

    @property
    def is_new_file(self):
        return self.header and self.header[0].startswith("--- /dev/null")


def parse_patch(text):
    lines = text.splitlines()
    pre = []
    i = 0
    while i < len(lines):
        if (
            lines[i].startswith("--- ")
            and i + 1 < len(lines)
            and lines[i + 1].startswith("+++ ")
        ):
            break
        pre.append(lines[i])
        i += 1

    files = []
    while i < len(lines):
        if not (lines[i].startswith("--- ") and i + 1 < len(lines) and lines[i + 1].startswith("+++ ")):
            # 段外的杂行（例如签名）忽略
            i += 1
            continue
        header = [lines[i], lines[i + 1]]
        target = lines[i + 1][4:].strip()
        target = target.split("\t")[0]
        if target.startswith("b/"):
            target = target[2:]
        fp = FilePatch(header, target)
        i += 2
        cur = None
        while i < len(lines):
            ln = lines[i]
            if ln.startswith("@@ "):
                cur = Hunk(ln, [])
                fp.hunks.append(cur)
                i += 1
                continue
            if ln.startswith("--- ") and i + 1 < len(lines) and lines[i + 1].startswith("+++ "):
                break
            if cur is None:
                i += 1
                continue
            if ln == "" :
                # 空行在补丁里等价于空 context 行
                cur.lines.append(" ")
            elif ln[0] in " +-\\":
                cur.lines.append(ln)
            else:
                break
            i += 1
        files.append(fp)
    return pre, files


def dump_patch(pre, files):
    out = list(pre)
    for fp in files:
        out.extend(fp.header)
        for h in fp.hunks:
            out.append(h.header)
            out.extend(h.lines)
    return "\n".join(out) + "\n"


def old_sequence(hunk):
    """hunk 的旧侧序列 [(kind, text)]，kind 为 ' '(context) 或 '-'(删除)。"""
    seq = []
    for ln in hunk.lines:
        if ln[:1] in (" ", "-"):
            seq.append((ln[:1], ln[1:]))
    return seq


def find_all_matches(target, block):
    if not block:
        return []
    n, m = len(target), len(block)
    hits = []
    for i in range(n - m + 1):
        if all(target[i + j] == block[j] for j in range(m)):
            hits.append(i)
    return hits


def locate_exact(hunk, target):
    """hunk 旧侧序列在目标文件里的唯一匹配位置（0 基），无唯一匹配返回 None。"""
    seq = [t for _, t in old_sequence(hunk)]
    if not seq:
        return None
    hits = find_all_matches(target, seq)
    return hits[0] if len(hits) == 1 else None


def rebuild_hunk(hunk, target, delta):
    """按删除行唯一锚点重建 hunk 上下文；失败返回 None。"""
    seq = old_sequence(hunk)
    if not seq:
        return None

    # 把 seq 中连续的删除行分组，记录每组在 seq 内的起始下标
    blocks = []
    idx = 0
    while idx < len(seq):
        if seq[idx][0] == "-":
            start = idx
            block = []
            while idx < len(seq) and seq[idx][0] == "-":
                block.append(seq[idx][1])
                idx += 1
            blocks.append((start, block))
        else:
            idx += 1

    for block_start, block in blocks:
        hits = find_all_matches(target, block)
        if len(hits) != 1:
            continue
        start = hits[0] - block_start
        if start < 0 or start + len(seq) > len(target):
            continue
        window = target[start : start + len(seq)]
        # 校验：window 内所有删除行必须与补丁一致
        if any(window[j] != seq[j][1] for j, (kind, _) in enumerate(seq) if kind == "-"):
            continue

        new_lines = []
        cursor = start
        for ln in hunk.lines:
            prefix = ln[:1]
            if prefix == " ":
                new_lines.append(" " + target[cursor])
                cursor += 1
            elif prefix == "-":
                new_lines.append(ln)
                cursor += 1
            else:
                new_lines.append(ln)

        hunk.lines = new_lines
        hunk.header = hunk.header_with(
            start + 1, len(seq), start + 1 + delta, hunk.new_count
        )
        hunk.old_start = start + 1
        hunk.old_count = len(seq)
        return start
    return None


def decompress_cmd(path):
    if path.endswith(".zst"):
        return ["zstd", "-dc"]
    if path.endswith(".gz"):
        return ["gzip", "-dc"]
    if path.endswith(".xz"):
        return ["xz", "-dc"]
    if path.endswith(".bz2"):
        return ["bzip2", "-dc"]
    return None


def unpack_source(tar_path, dest):
    cmd = decompress_cmd(tar_path)
    if not cmd:
        return False
    with open(tar_path, "rb") as src:
        p1 = subprocess.Popen(cmd, stdin=src, stdout=subprocess.PIPE)
        p2 = subprocess.Popen(["tar", "-xf", "-", "-C", dest], stdin=p1.stdout)
        p1.stdout.close()
        rc1 = p1.wait()
        rc2 = p2.wait()
    if rc1 != 0 or rc2 != 0:
        return False
    # 单一顶层目录时下钻一层，对齐 OpenWrt 的 build_dir 布局
    entries = os.listdir(dest)
    if len(entries) == 1 and os.path.isdir(os.path.join(dest, entries[0])):
        return os.path.join(dest, entries[0])
    return dest


def find_source_tar(wrt, pkg_rel):
    makefile = os.path.join(wrt, pkg_rel, "Makefile")
    name = None
    if os.path.isfile(makefile):
        for ln in open(makefile, encoding="utf-8", errors="ignore"):
            m = re.match(r"^\s*PKG_NAME\s*:?=\s*(\S+)", ln)
            if m:
                name = m.group(1)
                break
    if not name:
        return []
    return sorted(glob.glob(os.path.join(wrt, "dl", name + "-*.tar.*")))


def apply_dry_run(srcroot, patch_path, timeout=300):
    r = subprocess.run(
        ["patch", "-p1", "--dry-run", "--forward", "-i", os.path.abspath(patch_path)],
        cwd=srcroot,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
    )
    return r.returncode == 0, r.stdout.decode("utf-8", "replace")


def touch_build_dir(wrt, pkg_rel):
    """清理可能残留的 prepare 失败标记，保证下次 make 重新解包打补丁。"""
    name_dir = os.path.basename(pkg_rel)
    for d in glob.glob(os.path.join(wrt, "build_dir", "*", name_dir + "-*")):
        shutil.rmtree(d, ignore_errors=True)


def process(wrt, pkg_rel, handle_all):
    patches_dir = os.path.join(wrt, pkg_rel, "patches")
    if not os.path.isdir(patches_dir):
        print("[skip] %s 无 patches 目录" % pkg_rel)
        return 0

    patches = sorted(glob.glob(os.path.join(patches_dir, "*.patch")))
    if not patches:
        print("[skip] %s patches 为空" % pkg_rel)
        return 0

    tars = find_source_tar(wrt, pkg_rel)
    if not tars:
        print("[skip] 未在 %s/dl 找到 %s 源码包" % (wrt, pkg_rel))
        return 0
    tar_path = tars[-1]
    print("[info] 源码包: %s" % os.path.basename(tar_path))

    tmp = tempfile.mkdtemp(prefix="patchrebase-")
    try:
        srcroot = unpack_source(tar_path, tmp)
        if not srcroot or not os.path.isdir(srcroot):
            print("[skip] 解包失败")
            return 0

        changed = []
        for p in patches:
            ok, out = apply_dry_run(srcroot, p)
            if ok:
                if not handle_all:
                    continue
                print("[ok] %s 可原样应用" % os.path.basename(p))
                continue

            print("[warn] %s 无法原样应用，尝试重建上下文" % os.path.basename(p))
            pre, files = parse_patch(open(p, encoding="utf-8", errors="surrogateescape").read())
            failed = []

            for fp in files:
                if fp.is_new_file:
                    continue
                tgt = os.path.join(srcroot, fp.target)
                if not os.path.isfile(tgt):
                    failed.append((p, fp.target, "目标文件不存在"))
                    continue
                target = open(tgt, encoding="utf-8", errors="surrogateescape").read().splitlines()

                delta = 0
                for idx, h in enumerate(fp.hunks):
                    old_count0, new_count0 = h.old_count, h.new_count
                    # 原地能唯一命中（可能带偏移）就不动它，只处理真正失配的 hunk
                    if locate_exact(h, target) is None:
                        pos = rebuild_hunk(h, target, delta)
                        if pos is None:
                            failed.append(
                                (p, fp.target, "第 %d 个 hunk 无法用删除行唯一定位" % (idx + 1))
                            )
                            continue
                        print(
                            "    %s hunk #%d 已重定基 → 新起始行 %d"
                            % (os.path.basename(fp.target), idx + 1, h.old_start)
                        )
                    delta += new_count0 - old_count0

            new_text = dump_patch(pre, files)
            tmp_patch = os.path.join(tmp, "rebuilt.patch")
            with open(tmp_patch, "w", encoding="utf-8", errors="surrogateescape", newline="\n") as fh:
                fh.write(new_text)

            ok2, out2 = apply_dry_run(srcroot, tmp_patch)
            if not ok2:
                print("    [fail] 重建后仍无法应用：\n%s" % out2.strip()[-1500:])
                print("    保持原补丁不变，请人工检查 %s" % p)
                return 1

            with open(p, "w", encoding="utf-8", errors="surrogateescape", newline="\n") as fh:
                fh.write(new_text)
            changed.append(os.path.basename(p))
            print("[done] %s 已重写" % os.path.basename(p))

        if changed:
            touch_build_dir(wrt, pkg_rel)
            print("[done] 已重定基: %s" % ", ".join(changed))
        else:
            print("[info] 无需改动")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wrt", default="./wrt", help="OpenWrt 源码树根目录")
    ap.add_argument("--package", required=True, help="相对 wrt 的包路径，如 package/network/config/firewall4")
    ap.add_argument("--all", action="store_true", help="对所有补丁做检查并重建")
    args = ap.parse_args()

    if not os.path.isdir(args.wrt):
        print("[skip] %s 不存在" % args.wrt)
        return 0
    return process(os.path.abspath(args.wrt), args.package, args.all)


if __name__ == "__main__":
    sys.exit(main())

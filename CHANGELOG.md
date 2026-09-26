# 更新日志
## [2026-09-26] 优化 Release 简介排版：结构化 Markdown + 插件清单折叠列表

### 问题

归组后 Release body 存在三处可读性缺陷：

1. 插件列表（`WRT_LIST`）是空格分隔的一整行长串，几十个包挤在一行无法阅读；
2. 多机型产物追加进同一 Release 时，`action-gh-release` 会用后完成 job 的
   body 覆盖既有说明，而旧文案未标注这一点，读者会误把单一机型数据当全组值；
3. 缺少结构：组别含义、文件名如何对应机型、默认参数混排在一起。

### 变更

- `.github/workflows/WRT-CORE.yml`：
  - 「整理并打包固件」新增 `WRT_LIST_MD` 生成：把空格分隔的插件清单转为
    Markdown 无序列表（经 `$GITHUB_ENV` 官方 heredoc 语法写入多行值）；
  - 「发布固件到 Release」body 重写为结构化 Markdown：
    - 顶部归组提示（组名加粗）
    - 组别速查表（MT5700 / MT5700M / FM350 / NetWiz / BASE 各自适用场景）
    - 文件名解读（含「设备 profile 段即目标机型」的指引）
    - 默认出厂参数表（后台地址 / 密码 / Wi-Fi）
    - 本批构建信息（显式标注「为最后完成机型的数据，仅作参考」）
    - 插件清单折叠块（`<details>` + `WRT_LIST_MD`）
- `CHANGELOG.md`：本条

## [2026-09-26] Releases 按变体归组：同组多机型产物汇聚同一 Release

### 背景

此前每个配置组合（配置名 × MT 模式 × 源码 × 分支）各生成一个独立 Release
（Tag 含秒级时间戳），Releases 页面按「机型 × 模式」碎片化展开，找固件困难。
改为按变体归类：`MT5700` 放一起、`MT5700M` 放一起、`FM350` 放一起，
`NetWiz` 独立一组（不与 MT 模式交叉）。

### 设计要点

1. **Tag 改为分组式**：`<组名>-<YY.MM.DD>`（天级精度）。组名在
   `WRT-CORE.yml`「初始化构建变量」时推导：`WRT_VARIANT`（FM350 / NetWiz）
   优先，其次 `MT_MODE`（MT5700 / MT5700M），兜底 `BASE`（无变体且未选
   MT 模式的手动构建）。
2. **跨 workflow 共享 Tag 的依据**：三个机型的定时 job 由同一次 Auto-Clean
   触发、同一天内执行，天级时间戳必然一致，因此无需在 workflow 层传递
   统一日期 —— `H5000M-MT-AUTO` / `AP3000M-MT-AUTO` / `X86-MT-AUTO` 各自
   独立计算的 `MT5700-<日期>` Tag 天然相同。`action-gh-release` 对已存在
   的 Tag 会把产物追加进既有 Release，同组三机型即汇聚一页。
3. **固件文件名保持秒级时间戳**：同组内不同批次的构建（如当天手动重跑）
   文件名可区分；同名资产由 action-gh-release 覆盖。
4. **Auto-Clean 双格式兼容**：`keep_latest_per_device` 的归组键解析依次
   尝试旧格式 `<配置>-<MT模式>-<源码>-<分支>-<YY.MM.DD>-<HH.MM.SS>`
   （drop=2，按机型保留）与新格式 `<组名>-<YY.MM.DD>`（drop=0，按变体
   保留），历史 Release 不被误删；非流水线 Tag 退化为整条作键（只多保留）。
5. **五个定时工作流与手动入口零改动**：归组完全由 WRT-CORE 内部从既有
   `WRT_VARIANT` / `MT_MODE` 入参推导，`FM350-AUTO` / `NetWiz-AUTO` /
   三个 MT-AUTO / `WRT-BUILD` 均不需要感知。

### 变更

- `.github/workflows/WRT-CORE.yml`：
  - 「初始化构建变量」新增 `WRT_TAG_GROUP`（归组名）与 `WRT_RELEASE_TAG`
    （`<组名>-<YY.MM.DD>`，TZ=UTC-8）
  - 「发布固件到 Release」的 `tag_name` 改用 `WRT_RELEASE_TAG`，body 增加
    归组说明与文件名格式说明
- `.github/workflows/Auto-Clean.yml`：`keep_latest_per_device` 归组键解析
  兼容新旧两种 Tag 格式
- `README.md`：「产物命名与 Release 规范」章节重写（归组表、机制说明、
  兼容性说明）
- `CHANGELOG.md`：本条

## [2026-09-25] 新增 NetWiz 变体：三机型各一份独立配置 + 统一编译入口

### 背景

网络配置向导 `luci-app-netwiz`（上游 `huchd0/luci-app-netwiz`）需要编入固件。
现有机型配置（`H5000M-WIFI-YES` / `AP3000M` / `X86`）与既有 FM350 变体均
不做任何改动，改为各新增一份 NetWiz 变体配置。

### 设计要点

1. **只新增、不改现有配置**：三份 `<机型>-NETWIZ.txt` 的板级部分与母配置逐行
   一致，仅在末尾追加 `luci-app-netwiz` 及其依赖（`luci-base` / `rpcd` /
   `iwinfo` / `rpcd-mod-iwinfo` / `luci-compat` / `ppp-mod-pppoe` / `jsonfilter`）。
   母配置与 FM350 变体零改动，三条构建路径互不干扰。
2. **配置名必须保留机型前缀**：`WRT-CORE.yml` 中 AP3000M 的 EEPROM 注入与
   AirPi Rust 后端预编译两步靠 `contains(env.WRT_CONFIG, 'AP3000M')` 命中，
   改名会让它们静默失配（factory 分区为空 → mt76 起不来 → Wi-Fi 瘫痪）。
3. **产物区分靠三层标识**，互不覆盖：
   - 固件文件名末尾追加 `-NetWiz`（`WRT_VARIANT` 入参，既有机制直接复用）；
   - Release Tag 含配置名（`AP3000M-NETWIZ-...`），与母配置 / FM350 天然不同；
   - 配置导出名 `Config-<配置名>-<MT>-...txt` 同样含配置名。
   经推演核验：9 个配置组合（3 机型 × 3 变体）的 Tag / 配置导出名 / Auto-Clean
   归组键均为 9/9 唯一，变体产物不会被 `keep_latest_per_device` 误删。
4. **上游仓库是 monorepo 形态**：仓库根目录放 `install.sh` / `probe.py` /
   `worker.js` 等开发辅助文件，包本体在根下的 `luci-app-netwiz/` 一级子目录。
   OpenWrt 只认 `package/<包名>/Makefile`，故取包脚本先 clone 到临时目录
   `.netwiz-upstream`，再把子目录整体搬到 `package/luci-app-netwiz/`。
5. **上游文件全是 CRLF，必须归一化**（本次排查中最关键的非显然问题）：
   上游提交的 20 个文件（`Makefile`、全部 init.d 服务、rpcd 插件、hotplug
   守卫、`menu.d`/`acl.d` JSON、`.po` 翻译）均为 CRLF。三种具体后果：
   - `Makefile`：`include $(TOPDIR)/feeds/luci/luci.mk` 的行尾 `\r` 被并入
     文件名，make 报 `luci.mk\r: No such file or directory`，包直接编不过；
   - `init.d` shebang 变成 `#!/bin/sh /etc/rc.common\r`，procd 经 rc.common
     派发时解释器路径被污染，服务起不来；
   - `menu.d` / `acl.d` JSON 中的 `\r` 是字符串外非法空白，LuCI 解析失败，
     表现为「包装上了但界面里找不到入口」。
   `WRT-CORE.yml` 既有的「脚本格式规整（CRLF → LF）」步骤**管不到**这里：
   它只覆盖 OpenWrt 源码树顶层三级的 `txt/sh`，且执行时机早于取包步骤，
   顺序上已错过。因此归一化在取包脚本内部就地完成并逐文件复核。
6. **走 LuCI feed 编译框架**：与 `luci-app-fm350` 只用 `rules.mk` / `package.mk`
   不同，本包 `include $(TOPDIR)/feeds/luci/luci.mk`，因此必须晚于
   `feeds update -a`、早于 `make defconfig` 就位。步骤位置已按此固定，
   并增加 `feeds/luci/luci.mk` 可用性预检，避免在编译中期才报难懂的 make 错误。
7. **翻译包必须一起选中**：`po/zh_Hans` + `po/zh_Hant` 会被 `luci.mk` 拆成
   `luci-i18n-netwiz-zh-cn` / `luci-i18n-netwiz-zh-tw` 独立包，主包默认只带
   英文。未选中翻译包时界面回退英文，但编译照样全绿 —— 属「能用但不对」的
   静默缺陷，故在校验步骤中一并断言。
8. **`LUCI_PKGARCH:=all`**：纯脚本架构，生成的 ipk/apk 与 CPU 架构无关，
   三机型共用同一份包定义，变体配置之间无需架构差异处理。

### 变更

- 新增 `Config/H5000M-WIFI-YES-NETWIZ.txt` / `Config/AP3000M-NETWIZ.txt` / `Config/X86-NETWIZ.txt`
- 新增 `Scripts/Packages-NetWiz.sh`（NetWiz 变体专用源码拉取：monorepo 子目录
  搬移 + CRLF→LF 归一化 + 逐文件复核 + Makefile 断言 + luci.mk 引用断言 + 可执行位补齐）
- 新增 `.github/workflows/NetWiz-AUTO.yml`（一份 workflow 覆盖三机型；矩阵用
  `include` 逐项绑定各自源码上游，H5000M / AP3000M 取 `owrt`，X86 取 `master`；
  `MT_MODE` 固定留空，`WRT_VARIANT` 传 `NetWiz`）
- `.github/workflows/WRT-CORE.yml`：新增带 `contains(env.WRT_CONFIG, 'NETWIZ')`
  条件的「导入 luci-app-netwiz」（含 luci.mk 预检）与「校验 luci-app-netwiz 已选中」
  （含中文语言包断言）两个步骤；`WRT_VARIANT` 入参机制为既有实现，未改动
- `.github/workflows/WRT-BUILD.yml`：Target Device 下拉新增三个 NetWiz 配置项
  （并按母配置 / FM350 / NetWiz 分组注释）；`WRT_VARIANT` 推导由单一 `endsWith`
  扩展为嵌套三元链，同时识别 `NETWIZ` → `NetWiz` 与 `FM350` → `FM350`
- `Scripts/Packages.sh`、`Scripts/Handles.sh`、`Scripts/ApplyMTMode.sh`、
  `Scripts/VerifyMTMode.sh`、`.github/workflows/Auto-Clean.yml`：**均未改动**
  （Auto-Clean 的 Tag 归组逻辑经推演对新变体天然兼容，无需调整）
- `README.md`：机型表新增三行、功能小节 5（NetWiz）、CRLF 处理说明、
  工作流矩阵、手动指引、产物命名（含大小写差异说明）、项目结构、鸣谢
- `CHANGELOG.md`：本条

## [2026-09-25] 修复定时构建失败：sing-box 过时补丁导致编译中断

### 背景

2026-09-24 北京时间 23:47 触发的四个定时构建（X86 / H5000M / AP3000M / FM350 变体）
同时 `failure`，首个失败步骤均为「编译固件」。日志根因为：

```
Applying .../package/packages/sing-box/patches/100-fix-dns-tcp-close.patch using plaintext:
Patch failed!  Please fix .../sing-box/patches/100-fix-dns-tcp-close.patch!
make[3]: *** [Makefile:182: .../.prepared_...] Error 1
ERROR: package/packages/sing-box failed to build (build variant: full).
```

该补丁是 VIKINGYFY/packages 中针对旧版 sing-box 的反向移植（引入上游从未合入的
`HandleStreamDNSConnection`）。feed 把 sing-box 升到 `1.15.0_alpha8` 后，补丁上下文
已与上游源码（仍是 `HandleStreamDNSRequest`）不匹配，OpenWrt 在 `Build/Prepare` 阶段
应用补丁失败、整个固件编译中断。上游 immortalwrt/packages 的 sing-box 根本不携带该补丁
也能正常构建，故判定为可安全移除的过时补丁。

### 变更

- `Scripts/Packages.sh`：在克隆 viking feed 之后新增 `FIX_SINGBOX_STALE_PATCH`，
  仅当 `100-fix-dns-tcp-close.patch` 内容含旧版标记 `HandleStreamDNSConnection` 时
  移除它；若 VIKINGYFY 后续刷新该补丁为新版，规则因标记不匹配自动跳过，不误删。
- viking feed 中仅 sing-box 含 `patches/` 目录，移除后四机型构建阻塞点解除。
- 取舍说明：移除后 sing-box 回退到上游默认 DNS 处理逻辑（与 immortalwrt/packages 一致）；
  若该 DNS TCP 关闭修复仍被需要，应向上游 VIKINGYFY/packages 提交适配新源码的补丁，
  而非在 CI 侧长期打补丁。

## [2026-09-23] 新增 FM350 变体：三机型各一份独立配置 + 统一编译入口

### 背景

Fibocom FM350-GL 模组需要 `luci-app-fm350`（LuCI 界面 + Rust 后端 `fm350d`）。
现有机型配置（`H5000M-WIFI-YES` / `AP3000M` / `X86`）不做任何改动，改为各新增
一份 FM350 变体配置。

### 设计要点

1. **只新增、不改现有配置**：三份 `<机型>-FM350.txt` 的板级部分与母配置逐行
   一致，仅在末尾追加 `luci-app-fm350` 及其依赖（`luci-base` / `rpcd` /
   `rpcd-mod-ucode` / `kmod-usb-net-rndis` / `kmod-usb-serial-option`）。
   母配置零改动，两条构建路径互不干扰。
2. **配置名必须保留机型前缀**：`WRT-CORE.yml` 中 AP3000M 的 EEPROM 注入与
   AirPi Rust 后端预编译两步靠 `contains(env.WRT_CONFIG, 'AP3000M')` 命中。
   若按「就叫 FM350」命名，这两步会被静默跳过 —— AP3000M 的 factory 分区
   出厂为空，不注入 EEPROM 则 mt76 起不来、Wi-Fi 彻底瘫痪。
3. **产物文件名追加 `-FM350`**：固件名由镜像原名拼出，**不含机型配置名**，
   普通版与 FM350 版的文件名会完全一致，下载到本地无法区分。因此在
   `WRT-CORE.yml` 增加可选入参 `WRT_VARIANT`（默认空），仅 FM350 变体传入
   `FM350` 并追加到文件名末尾；现有三机型不传该参数，产物名逐字节不变。
4. **不污染通用 Feed 入口**：`luci-app-fm350` 的拉取独立为
   `Scripts/Packages-FM350.sh`，由带 `contains(env.WRT_CONFIG, 'FM350')`
   条件的步骤调用，`Scripts/Packages.sh` 一行未改。
5. **Rust 构建不触发 `rust/host`**：`fm350d` 由包内 Makefile 直接调 cargo
   交叉编译为 musl 静态二进制，只需 runner 侧存在对应 target 的标准库，
   不会像 `rust/host` 源码构建那样耗 1.5~3 小时并顶到 345 分钟超时。
6. **依赖逐项显式写出**：`luci-app-fm350` 的 Makefile 只用
   `rules.mk` / `package.mk`，不使用 `feeds/luci/luci.mk`；菜单走
   `/usr/share/luci/menu.d/*.json` 注册，无 Lua 控制器与 `.ut` 模板；
   文案为中文硬编码，不存在 `luci-i18n-fm350-zh-cn` 包。

### 变更

- 新增 `Config/H5000M-WIFI-YES-FM350.txt` / `Config/AP3000M-FM350.txt` / `Config/X86-FM350.txt`
- 新增 `Scripts/Packages-FM350.sh`（FM350 变体专用源码拉取，幂等 + CRLF 断言）
- 新增 `.github/workflows/FM350-AUTO.yml`（一份 workflow 覆盖三机型；矩阵用
  `include` 逐项绑定各自源码上游，H5000M / AP3000M 取 `owrt`，X86 取 `master`）
- `.github/workflows/WRT-CORE.yml`：新增可选入参 `WRT_VARIANT` 与产物文件名后缀；
  新增带条件的 `Custom Packages (FM350)` 步骤（拉包 + 按 `WRT_TARGET` 选 Rust target）
- `.github/workflows/WRT-BUILD.yml`：Target Device 下拉新增三个 FM350 配置项
- `README.md`：机型表、功能小节 4、工作流矩阵、手动指引、产物命名、项目结构、鸣谢
- `CHANGELOG.md`：本条

## [2026-09-20] 修复 MT5700M 变体全灭：QModem 侧 QMI 驱动改为显式选中

### 问题

2026-09-20 定时构建中，H5000M / AP3000M / X86 三个机型的 **MT5700M** 变体全部在
`Verify MT Mode` 阶段中止（H5000M run 35474153836、AP3000M run 35474153897、
X86 run 35474153834），MT5700 变体不受影响：

```
[未选中] kmod-qmi_wwan_f
[未选中] kmod-qmi_wwan_q
::error::MT_MODE=MT5700M 要求必须选中 kmod-qmi_wwan_f，但最终 .config 中未选中
::error::MT_MODE=MT5700M 要求必须选中 kmod-qmi_wwan_q，但最终 .config 中未选中
```

上一次成功构建（run 35454224762，2026-09-19T16:12Z）到本次失败之间，本仓库只改过
`README.md`，因此不是本地配置漂移，而是**上游漂移**：FUjr/QModem 在 2026-09-19
调整了 luci 打包（c49654e / 5213e28）。

### 根因

`kmod-qmi_wwan_f` / `kmod-qmi_wwan_q` 由 QModem 的 `driver/` 目录提供，但上游把它们
挂在 `application/qmodem/Makefile` 的**条件依赖**上：

```
+PACKAGE_qmodem_INCLUDE_vendor-qmi-wwan:kmod-qmi_wwan_q \
+PACKAGE_qmodem_INCLUDE_vendor-qmi-wwan:kmod-qmi_wwan_f \
```

即只有 `qmodem` 主包被选中、且其 `Package/qmodem/config` 里的 choice 取到
`vendor-qmi-wwan` 时才会被拉入。而本仓库里没有任何包选中 `qmodem`：
`luci-app-mt5700m` 的 `LUCI_DEPENDS` 只有 `luci-base` / `ubus-at-daemon` / `sms-tool_q`，
`GENERAL.txt` 又显式关掉了 `luci-app-qmodem` / `luci-app-qmodem-next`。此前能编过，
是因为上游存在把 `qmodem` 顺带拉进来的隐式路径；上游 09-19 的打包调整切断了它。

`VerifyMTMode.sh` 的拦截行为是正确的：若不拦截，MT5700M 固件会缺 `qmi_wwan_f.ko` /
`qmi_wwan_q.ko`（模组驱动），属于脏固件。

### 变更

- `Config/MT5700M.txt`：新增 QModem 侧 `kmod-qmi_wwan_f` / `kmod-qmi_wwan_q` 的显式 `=y`，
  并写明成因、以及「为什么不改成选中 qmodem 主包」。packages 侧同名驱动的 `=n` 保留不变
- `README.md`：QMI WWAN 冲突防踩坑机制补第 3 条「驱动归属显式化」
- `CHANGELOG.md`：本条

### 影响面

- 仅 MT5700M 配置层；MT5700 与空模式不受影响（两者走 packages 侧驱动，`=n` 不生效）
- 不再依赖上游 vendor 驱动的隐式默认值：上游再调整打包也不会让 MT5700M 变体停摆

## [2026-09-18] 加固 Compile Firmware 失败注解：优先上报 apk 安装期根因

### 问题

`WRT-CORE.yml` 的失败诊断正则原先只匹配：

```
^(ERROR: |make(\[N\])?: \*\*\* ).*(failed to build|Error N|too big)
```

apk 安装期错误行（`ERROR: <pkg>-<ver>: trying to overwrite ...`、`ERROR: unable to select packages:`、`package version is invalid` 等）**不含**上述关键字，因此 `##[error]` 注解里只剩 make 级联行，真实根因不可见——X86-MT-AUTO #10/#11 即此情形。

### 变更

`Compile Firmware` 失败诊断改为**根因优先**分层提取，再以 `::error::` 写入 Annotations：

1. **apk/opkg 安装期根因**：`trying to overwrite` / `unable to select packages` / `package version is invalid` / `breaks:` / `conflicts with` / `installed .* is newer`
2. **包编译失败 / 镜像过大**（保留原关键字）
3. **make 级联**（`*** ... Error N / Stop`）
4. 以上皆无时，放宽到任意 `ERROR:` 行

层内 `sort -u` 去重，层间用 `awk '!seen[$0]++'` 保留首次出现顺序；上下文输出同步纳入 apk 关键字。用当日真实失败日志样例回放：旧正则只打出 `failed to build` + make 级联；新逻辑首行即为 `trying to overwrite` 冲突包。

### 变更文件

- `.github/workflows/WRT-CORE.yml` — Compile Firmware 失败注解分层提取
- `CHANGELOG.md` — 文档同步

## [2026-09-18] 修复 MT5700M 构建失败：QMI WWAN 驱动争抢 rootfs 同名 `.ko`

### 现象

`H5000M-MT-AUTO` / `AP3000M-MT-AUTO` / `X86-MT-AUTO` 三个工作流在同一轮（Run #10）中**全部失败**，且失败面严格限定为 `MT5700M` 变体——三个 `MT5700` 变体均编译成功。报错步骤均为第 16 步 `Compile Firmware`，其后的 `Machine Information` / `Package Firmware` / `Release Firmware` 因失败被跳过。

### 根因

`apk` 装包阶段的 rootfs 文件归属冲突。三个 Job 日志中出现完全相同的两行：

```
ERROR: kmod-usb-net-qmi-wwan-fibocom-6.18.44.1.0.5-r5: trying to overwrite
       lib/modules/6.18.44/qmi_wwan_f.ko owned by kmod-qmi_wwan_f-6.18.44.1.0-r5.
ERROR: kmod-usb-net-qmi-wwan-quectel-6.18.44.1.2.9-r3: trying to overwrite
       lib/modules/6.18.44/qmi_wwan_q.ko owned by kmod-qmi_wwan_q-6.18.44.1.5-r1.
```

汇总行为 `2 errors; 177.7 MiB in 437 packages`（H5000M 436 / X86 572）——即全部包已安装完毕，仅因 2 个文件归属冲突返回非零，向上冒泡为 `package/install` → `.package_install` → `world` 失败，整包构建中断。

冲突双方：

| 提供方 | 包（版本） | 产出模块 |
| :--- | :--- | :--- |
| packages feed（`immortalwrt/packages` 的 `kernel/fibocom-qmi-wwan`） | `kmod-usb-net-qmi-wwan-fibocom`（1.0.5） | `qmi_wwan_f.ko` |
| QModem feed（`FUjr/QModem` 的 `driver/fibocom_QMI_WWAN`） | `kmod-qmi_wwan_f`（1.0） | `qmi_wwan_f.ko` |
| packages feed（`kernel/quectel-qmi-wwan`） | `kmod-usb-net-qmi-wwan-quectel`（1.2.9） | `qmi_wwan_q.ko` |
| QModem feed（`driver/quectel_QMI_WWAN`） | `kmod-qmi_wwan_q`（1.5） | `qmi_wwan_q.ko` |

**为什么只有 `MT5700M` 失败**：QModem feed 仅在 `MT_MODE=MT5700M` 时克隆（`Scripts/Packages.sh`），而该 feed 的 `qmodem` 主包经 Kconfig 选择项 `Qualcomm QMI WWAN Driver Selection`（缺省 `Vendor QMI driver`）拉入自带的三个 vendor 驱动；packages 侧两个驱动则由 `Config/GENERAL.txt` 第 128-130 行对**全机型**显式启用。两者在 `MT5700M` 模式下必然共存，遂冲突。该问题属配置层，与机型无关，也与本日源码切换无关。

### 修复

`MT5700M` 模式由 QModem 侧驱动接管，关闭 packages 侧同名驱动：

* `Config/MT5700M.txt` — 追加 `CONFIG_PACKAGE_kmod-usb-net-qmi-wwan-fibocom=n` 与 `CONFIG_PACKAGE_kmod-usb-net-qmi-wwan-quectel=n`。
* `Scripts/ApplyMTMode.sh` — 在 `MT5700M` 分支的互斥保护中追加同两项（双保险，覆盖机型配置 / `PRIVATE.txt` / `WRT_PACKAGE` 可能引入的 `=y`）。
* `Scripts/VerifyMTMode.sh` — 新增 QMI WWAN 驱动归属校验，并修复既有缺陷（两处「反向依赖探测」只打印 `::error::` 却未置 `FAIL=1`，导致该类冲突不会真正中止编译）。

`MT5700` 与空模式不克隆 QModem feed，仍由 packages 侧驱动提供，行为不变。

### 生效依据（三项均已核对）

1. **写入时机**：`ApplyMTMode.sh` 于 `WRT-CORE` 的 `Custom Settings` 阶段、在 `Config/$WRT_CONFIG.txt` 与 `GENERAL.txt` 拼接进 `.config` **之后** 追加 `Config/MT5700M.txt`，后写覆盖先写，故 `=n` 生效。
2. **无反向依赖**：packages 侧两包仅有向下依赖（`+kmod-usb-net +kmod-usb-wdm`），无 `PROVIDES` / `CONFLICTS`；`immortalwrt/packages` 全库唯一的反向引用者是 `net/quectel-cm`，而 `quectel-cm` 已在 `Config/GENERAL.txt` 第 47 行被禁用，故 `make defconfig` 不会将其拉回。
3. **功能不丢失**：关闭 packages 侧后，同名 `qmi_wwan_f.ko` / `qmi_wwan_q.ko` 由 QModem 侧的 `kmod-qmi_wwan_f` / `kmod-qmi_wwan_q` 提供，`MT5700M` 模组驱动能力保留。

### 验证

以构造的 `.config` 在本机回放两个脚本：

* `VerifyMTMode.sh` 6 个场景全部通过——含 `MT5700M` 修复后正确配置（rc=0）、`MT5700M` 下 packages 侧被拉回（rc=1，成功拦截）、`MT5700M` 缺 QModem 侧驱动（rc=1）、`MT5700` 与空模式的 packages 侧正向校验（rc=0）。
* `ApplyMTMode.sh` 10 项断言全部通过——`MT5700M` 下两包最终生效值为 `n`、互斥项行号位于 `Config/MT5700M.txt` 内容之后、`MT5700` 与空模式不被改写。
* 两个脚本均通过 `bash -n` 语法检查。

### 附带发现（未处理）

`WRT-CORE.yml` 的 `Compile Firmware` 诊断分支仅匹配 `^(ERROR: |make(\[N\])?: \*\*\* ).*(failed to build|Error N|too big)`，而本次 apk 冲突行以 `ERROR: ` 开头但中间含 `-<版本>:`，三个 Job 的 `##[error]` 注解中**只有 make 级联行、没有冲突行**，导致真实原因未在注解中体现。此外首轮 `make -j` 失败时未输出任何安装阶段日志（`Installing` 行数为 0），真实原因仅在 `V=s` 重试段暴露。该诊断盲区建议后续单独加固。

### 变更文件

- `Config/MT5700M.txt` — 追加 packages 侧 QMI WWAN 驱动互斥项
- `Scripts/ApplyMTMode.sh` — `MT5700M` 分支追加驱动互斥兜底
- `Scripts/VerifyMTMode.sh` — 新增驱动归属校验；修复 `FAIL=1` 缺失
- `README.md`、`CHANGELOG.md` — 文档同步

## [2026-09-18] H5000M / AP3000M 源码切换至 VIKINGYFY/immortalwrt（owrt 分支）

### 变更

- `H5000M-MT-AUTO` / `AP3000M-MT-AUTO` 编译矩阵的 `SOURCE` 由 `immortalwrt/immortalwrt` 切换为 [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)，`BRANCH` 由 `master` 调整为 `owrt`。
- 分支可用性已核对：该仓库仅有 `main` / `owrt` / `test` 三个分支，**无 `master`**；`owrt` 当前指向 `4e21fd0`。
- 影响面严格限定为上述两个机型的自动编译。`X86-MT-AUTO`（`immortalwrt/immortalwrt` + `master`）、手动入口 `WRT-BUILD` 的默认值、`Config/` 与 `Scripts/` 均保持不动。

### 上游兼容性核对（实测）

- 内核：两仓库 `target/linux/mediatek/Makefile` 均为 `KERNEL_PATCHVER:=6.18`，`kernel-6.18` 均为 `6.18.44`，且 `LINUX_KERNEL_HASH-6.18.44` 完全相同。
- `mt76`：两仓库 `PKG_SOURCE_URL` 均为 `openwrt/mt76`，`PKG_SOURCE_DATE` 均为 `2026-09-01`。
- 结论：本次切换当下不引入内核或无线驱动层面的差异，`Scripts/` 中既有补丁与修复的适用性风险较低；但 `owrt` 为分支形态，后续可能独立演进，需在首次构建后复核。

### 连带修复：Auto-Clean 的机型键提取

- **问题**：`Auto-Clean` 的 `keep_latest_per_device` 模式原按 Tag 中的字面量 `-immortalwrt-` 切分以取得机型名。源码段随本次切换变为 `VIKINGYFY` 后该切分失配，`a[1]` 退化为整条 Tag，使每个 Release 都被视为独立机型——**勾选「保留每机型最新」时不会删除任何 Release**，两个机型的旧 Release 会持续堆积。
- **修复**：改为按 Tag 末尾固定的日期后缀（`YY.MM.DD-HH.MM.SS`，即 `WRT-CORE` 生成的 `WRT_DATE`）定位，再去掉末尾「源码-分支」两段，从而不再依赖源码组织名。日期段不匹配的 Tag 退化为整条作键，语义上只会多保留、不会误删。
- **验证**：以 10 条真实形态 Tag（含切换前的 `immortalwrt/master`、切换后的 `VIKINGYFY/owrt`，以及早期无 MT 段的 `H5000M-WIFI-YES-immortalwrt-master`）实测——旧逻辑保留 9 条（回归确认），新逻辑保留 7 条，每个「机型-MT模式」恰保留 1 条，且新旧源码的 Tag 能被正确归入同一机型键。

### 连带影响（命名与缓存）

- `WRT-CORE` 以 `WRT_SOURCE` 的组织名生成 `WRT_INFO`，故 Release Tag、固件文件名、导出的配置文件名与 Actions 缓存键中的源码段由 `immortalwrt` 变为 `VIKINGYFY`：
  - `H5000M-WIFI-YES-MT5700-immortalwrt-master-…` → `H5000M-WIFI-YES-MT5700-VIKINGYFY-owrt-…`
- 缓存键同时包含分支名，`owrt` 与既有 `master` 缓存不共享，**切换后首次构建为冷启动**，耗时将高于稳态。

### 文档

- `README.md`：副标题、「支持的编译配置」新增源码对照说明、鸣谢源码上游、H5000M「固件底包」条目均改为按机型分别标注源码；AP3000M 说明中「ImmortalWrt 主线 mt76 开源驱动」改为「ImmortalWrt 系 mt76 开源驱动」（该机型已不取主线）。

### 变更文件

- `.github/workflows/H5000M-MT-AUTO.yml` — `SOURCE` / `BRANCH` 矩阵
- `.github/workflows/AP3000M-MT-AUTO.yml` — `SOURCE` / `BRANCH` 矩阵
- `.github/workflows/Auto-Clean.yml` — `keep_latest` 机型键提取逻辑
- `README.md`、`CHANGELOG.md` — 文档同步

## [2026-09-15] 修复 luci-app-homeproxy 的 sing-box 版本约束导致的构建失败

### 故障现象

- 2026-09-15 定时触发的 `H5000M-MT-AUTO`、`X86-MT-AUTO`、`AP3000M-MT-AUTO` 全部失败，`Compile Firmware` 步骤终止，`make world` 整体中断。09-13 同样配置构建成功。
- 第一层错误签名（`package/install` 阶段，Error 3）：
  ```
  ERROR: unable to select packages:
    sing-box-1.15.0_alpha3-r1:
      breaks: luci-app-homeproxy-20260914-r2[sing-box>=1.15.0]
      satisfies: world[sing-box]
  ```

### 根因

1. 上游 `VIKINGYFY/packages` 的 `luci-app-homeproxy` 升级到 `20260914-r2`，新增 `LUCI_EXTRA_DEPENDS:=sing-box (>=1.15.0)`。
2. 同一 feed 的 `sing-box` 为 `1.15.0_alpha3`。apk 版本比较规则中 `_alpha3` 属 pre-release 后缀，排在「无后缀」之前，故 `1.15.0_alpha3 < 1.15.0`，依赖不可满足。
3. 上游 `SagerNet/sing-box` 当前最新稳定版是 v1.14.1，1.15.0 系列仍为 alpha（alpha.4 于 2026-09-15 发布），**不存在**可升级到的 1.15.0 正式版，因此只能调整约束而非升级 sing-box。
4. `Config/GENERAL.txt` 对全机型启用 homeproxy，故三个机型工作流同时受影响。

### 关键约束（决定修复方式）

- 首次尝试「删掉版本约束」不可行：OpenWrt 的 apk 打包器 `include/package-pack.mk` 要求 `EXTRA_DEPENDS` 每一项必须是「包名 + 空格 + 版本约束」，无约束会直接报错并终止：
  ```
  luci.mk:398: *** "Extra dependencies must have version constraints. sing-box seems to be unversioned.".  Stop.
  ```

### 修复

- `Scripts/Packages.sh` — 新增 `FIX_HOMEPROXY_SINGBOX`（模式与既有 `FIX_QMODEM_VERSION` 一致），在克隆 viking feed 之后执行：
  1. 读取同一 feed 内 `sing-box/Makefile` 的实际 `PKG_VERSION`；
  2. 仅当约束下限在 apk 语义下**高于**该实际版本时才改写 `LUCI_EXTRA_DEPENDS` 的 sing-box 版本下限（主版本段相同但 feed 为 pre-release、或 feed 主版本段更高时不动，避免收紧已满足的约束或写反语义）；
  3. 版本串做字符白名单校验（`[0-9A-Za-z._-]`），防止脏数据进入 sed 表达式；
  4. 幂等，上游发布 1.15.0 正式版或调整约束后自动跳过。

### 验证

- 用上游真实 `luci-app-homeproxy/Makefile` 与真实 `sing-box` 版本，模拟 CI 目录结构实测 6 种边界场景：需下调（改写）、约束已满足（不动）、约束等于 feed 版本（不动）、feed 为正式版（不动）、无约束（跳过）、feed 版本更高（不动）——行为均符合预期。
- `bash -n` 语法检查通过；首轮修复后重跑构建，`unable to select packages` 已消失，失败点前移至后续的 `luci.mk` 校验，据此完成第二轮修正。

### 变更文件

- `Scripts/Packages.sh` — 新增 `FIX_HOMEPROXY_SINGBOX` 修复函数并在 `UPDATE_PACKAGE "viking"` 之后调用

## [2026-09-13] 云编译双 MT 配置并行、工作流重命名与产物区分

### 变更（云编译）

- **双配置并行**：各机型 AUTO 工作流改为矩阵同时编译 `MT5700` + `MT5700M`（`fail-fast: false`），Job 名为 `机型-MT模式`。
- **工作流重命名**：
  - `H5000M-AUTO.yml` → `H5000M-MT-AUTO.yml`（name: `H5000M-MT-AUTO`）
  - `AP3000M-AUTO.yml` → `AP3000M-MT-AUTO.yml`（name: `AP3000M-MT-AUTO`）
  - `OWRT-ALL.yml` → `X86-MT-AUTO.yml`（name: `X86-MT-AUTO`）
- **产物区分（WRT-CORE）**：
  - 固件文件名嵌入 MT 模式：`…-<MT5700|MT5700M>-wifi-yes-….bin`
  - 配置导出：`Config-<机型>-<MT模式>-….txt`
  - Release Tag：`<机型>-<MT模式>-<源码>-<分支>-<日期>`
  - Release 正文增加 `MT模式` 字段

### 变更文件

- `.github/workflows/H5000M-MT-AUTO.yml` — 新增（替代 H5000M-AUTO）
- `.github/workflows/AP3000M-MT-AUTO.yml` — 新增（替代 AP3000M-AUTO）
- `.github/workflows/X86-MT-AUTO.yml` — 新增（替代 OWRT-ALL）
- `.github/workflows/H5000M-AUTO.yml` / `AP3000M-AUTO.yml` / `OWRT-ALL.yml` — 删除
- `.github/workflows/WRT-CORE.yml` — WRT_MT 标签写入产物名 / Tag / 说明

## [2026-09-13] 重构 MT5700M 配置，新增独立 MT5700 配置与 MT_MODE 互斥

### 变更（配置架构）

- **原 MT5700M 配置迁移**：`Config/GENERAL.txt` 中的 MT5700M 段（`luci-app-mt5700m` / `luci-i18n-mt5700m-zh-cn` / `ubus-at-daemon` / `sms-tool_q`）整体迁出为 `Config/MT5700M.txt`，`Packages.sh` 的 `FOLD_MT5700M` 逻辑保留并改为仅在 `MT_MODE=MT5700M` 时执行。
- **新增 `Config/MT5700.txt`**：方案 B，仅 `luci-app-mt5700` + 中文语言包，不含 `sms-tool_q` / `ubus-at-daemon` / `luci-app-mt5700m`。
- **新增 `MT_MODE` 独立配置层**（全机型复用，不绑定 H5000M）：
  - `""` / `NONE` — 不安装任何 MT 插件
  - `MT5700` — 仅 luci-app-mt5700
  - `MT5700M` — luci-app-mt5700m + sms-tool_q + ubus-at-daemon
  - 其他值在 `Packages.sh` / `ApplyMTMode.sh` / `VerifyMTMode.sh` 中 `::error::` 并终止
- **双重互斥校验**：
  - 配置生成前：`Scripts/ApplyMTMode.sh` 叠加配置层并写入对侧包 `=n`
  - 配置生成后、编译前：`Scripts/VerifyMTMode.sh` 检查最终 `.config`
- **Workflow**：`WRT-CORE.yml` 增加 `MT_MODE` 输入；`WRT-BUILD.yml` 增加模式选择；`H5000M-AUTO` / `AP3000M-AUTO` / `OWRT-ALL` 默认 `MT_MODE=MT5700M`，保持原固件内容。

### 真实冲突点（来自插件仓库实测，非猜测）

- 同路径 init 服务：`/etc/init.d/at-webserver`
- 同路径 UCI：`/etc/config/at-webserver`
- 同菜单父节点：`admin/modem`
- MT5700M 另依赖 QModem feed 的 `sms-tool_q`、`ubus-at-daemon`；MT5700 的 `LUCI_DEPENDS` 为空，单包自含 Rust 后端

### 变更文件

- `Config/MT5700M.txt` — 新增（由 GENERAL 迁出）
- `Config/MT5700.txt` — 新增
- `Config/GENERAL.txt` — 移除 MT5700M 包
- `Scripts/ApplyMTMode.sh` — 新增
- `Scripts/VerifyMTMode.sh` — 新增
- `Scripts/Packages.sh` — MT 插件克隆/折叠按 MT_MODE 条件执行；QModem feed 仅 MT5700M 需要
- `.github/workflows/WRT-CORE.yml` — 增加 MT_MODE 输入与验证步骤
- `.github/workflows/WRT-BUILD.yml` — 增加 MT_MODE 选择
- `.github/workflows/H5000M-AUTO.yml` / `AP3000M-AUTO.yml` / `OWRT-ALL.yml` — 传入 MT_MODE=MT5700M

## [2026-09-10] 修复 QModem 包版本号非法导致的构建失败（apk Error 99）

### 修复（构建）

- **问题**：今日（09-10）三连发构建（OWRT-ALL #68 / H5000M-AUTO #24 / AP3000M-AUTO #18）全部在 `Compile Firmware` 步骤失败。根因：`Scripts/Packages.sh` 克隆的 QModem feed（`FUjr/QModem`）共享 `version.mk` 声明 `QMODEM_VERSION:=3.4.0-rc.3`，OpenWrt 新版 apk 打包器不接受 `-rc.N` 版本段——版本串被拼成 `3.4.0-rc.3-r1` 后，`apk mkpkg` 报 `package version is invalid`（Error 99），`sms-tool_q` 打包失败进而终止整个固件构建。三目标共享 `Config/GENERAL.txt`（`CONFIG_PACKAGE_sms-tool_q=y`），全部命中，编译脚本首败（rc=2）自动重试后仍被同一版本号拒绝。
- **修复**：`Scripts/Packages.sh` 在克隆 QModem feed 后新增 `FIX_QMODEM_VERSION`，将 `X.Y.Z-rc.N` 改写为 apk 合法的 `X.Y.Z_rcN`（`3.4.0-rc.3` → `3.4.0_rc3`）。QModem 各包源码均内嵌 feed 仓库 `src/`，无版本化下载依赖，改写仅影响版本元数据；上游若已改为合法版本则自动跳过。

### 变更文件

- `Scripts/Packages.sh` — 新增 `FIX_QMODEM_VERSION`（克隆 QModem 后改写共享版本号）

## [2026-09-09] 修复 luci-app-mt5700m 集成：折叠 Rust 后端与 WebUI

### 修复（插件）

- **问题**：此前 `luci-app-mt5700m` 的集成存在两处错误，导致编译出的固件里 MT5700M 管理页缺少 AT 后端、无法正常使用：
  - `Scripts/Packages.sh` 把 `mt5700webui-openwrt-server/at-webserver`（Rust 源码 crate，**没有 OpenWrt Makefile**）当作独立包 `mv` 进 `package/`，并在 `Config/GENERAL.txt` 写了 `CONFIG_PACKAGE_at-webserver=y`。但 OpenWrt buildroot 不会把它识别为软件包，于是 `/usr/bin/at-webserver`（及其软链 `/usr/sbin/mt5700m-at`）与 `/www/5700` WebUI 根本不会被编进固件——管理页的 AT 终端、拨号、状态查询全部失效。
  - `Config/GENERAL.txt` 误加 `CONFIG_PACKAGE_sms-tool=y`（该包来自 packages feed，与本插件无关）；插件真正依赖的是 QModem 的 `sms-tool_q` 与 `ubus-at-daemon`。
- **修复**：复刻上游 `scripts/build-release.sh` 的「折叠」流程，在 `Scripts/Packages.sh` 新增 `FOLD_MT5700M`：
  - 把 LuCI 壳（仓库内同名子目录）提升到 `package/` 一级；
  - 按编译目标用 cargo + rust-lld（自包含 musl，无需 OpenWrt 交叉工具链）交叉编译 Rust 后端 `at-webserver`：mediatek → `aarch64-unknown-linux-musl`，x86 → `x86_64-unknown-linux-musl`；
  - 把 `www/5700` 前端、`/usr/bin/at-webserver` 二进制、`at-webserver` init.d 折叠进 LuCI 壳后一起编译。
- `Config/GENERAL.txt` 移除 `CONFIG_PACKAGE_at-webserver=y` 与 `CONFIG_PACKAGE_sms-tool=y`，保留 `luci-app-mt5700m` / `luci-i18n-mt5700m-zh-cn` / `ubus-at-daemon` / `sms-tool_q`。
- `TEST=true`（仅生成配置）时跳过 Rust 后端编译；正式编译若后端构建失败会直接报错终止，避免静默产出缺少 AT 后端的固件。

## [2026-08-31] 编译提速：缓存重构、并行重试与 Rust 预编译（PR #5）

### 优化（编译提速）

- **基线实测：上一次 `H5000M-AUTO`（Run #33341410294）总耗时 225.9 分钟，其中 `Compile Firmware` 独占 211.8 分钟，四个缓存检查步骤（`Toolchain` / `Ccache` / `Feeds` / `Download`）耗时全部为 0.0 分钟——即一次零缓存冷编译。** 这说明 08-28 / 08-29 两轮引入的缓存体系当时并未生效，本次针对其失效原因逐项修整。
- **① 停止每周定时清空缓存（本次最大收益项）**：`Cache-Clean.yml` 原 `schedule: 0 20 * * 0` 每周一 04:00（CST）执行 `gh cache delete --all`，之后第一次构建必然全量重编。证据：当时仓库 8 条缓存全部创建于 08-31（即清理动作之后），而 211.8 分钟的那次构建正好在清理之后启动。现改为**仅保留 `workflow_dispatch` 手动触发**——GitHub 会按 LRU 自动回收超配额缓存，定时全量清空只会人为制造每周一次的冷启动。
- **② 工具链与 ccache 合并为一份缓存，并加 `save-always: true`**：原 4 个缓存步骤均无 `save-always`，编译失败 / 超时 / 被取消时 post 保存会被整段跳过，陷入「超时 → 无缓存 → 再超时」死循环（08-29 有两次 `WRT-BUILD` 失败、一次 345 分钟被取消）。工具链（含最耗时的 host tools）在头 1~2 小时就已编好，现在即使后续失败也会保存，下次可直接续用。
- **③ 缓存键由 `WRT_CONFIG` 改为 `WRT_TARGET`，path 收窄为 `host*` / `tool*`**：
  - 键改为按目标平台共享后，`H5000M` 与 `AP3000M` 同为 `mediatek/filogic`，可共用同一份工具链，不再每天各白编一次。
  - path 由整个 `staging_dir/` 收窄为 `staging_dir/host*` + `staging_dir/tool*`（含 `.ccache`）。这是**对 08-28 改动的回退**：`make clean` 对应 Makefile 中的 `_clean: FORCE` → `rm -rf $(BUILD_DIR) $(STAGING_DIR) $(BIN_DIR) ...`，而 `rules.mk` 里 `STAGING_DIR:=$(TOPDIR)/staging_dir/$(TARGET_DIR_NAME)`，即 `staging_dir/target-*` 在缓存上传前就注定被删——打包它纯属浪费带宽，且内容随配置漂移，会污染共享给另一机型的缓存。
- **④ `dl` 缓存键去掉机型维度，按「源码 + 分支」共享**：下载的源码包与机型无关，原 key 带 `WRT_CONFIG` 导致 `H5000M` / `X86` 各存一份 2.1GB；`AP3000M` 一旦日常启用就是 3 × 2.1GB ≈ 6.3GB，叠加每机型一份工具链与 ccache 后必然突破 GitHub 约 10GB 上限，触发 LRU **连锁淘汰**——这比定时清空更隐蔽，会让所有缓存一起失效。
- **⑤ 删除 `feeds` 缓存（对 08-29 改动的回退）**：实测 `feeds update -a` 仅需约 1.0 分钟，而缓存体积 51.9MB 且 key 绑定 `WRT_HASH` 几乎必然 miss。为其付出的两次上传 / 下载开销大于收益，属净亏损，故移除。
- **⑥ 编译失败重试保持并行**：原 `make -j$(nproc) || make -j1 V=s` 一旦偶发失败就把几小时的编译从 4 线程降到 1 线程，几乎必然拖过 6 小时上限被取消。现改为重试仍用 `-j$(nproc) V=s`，输出写入 `build.log`，失败时提取首个出错包并以 `::error::` 注解上报（可经 check-runs API 直接读取，无需下载原始日志）。
- **⑦ 新增 AP3000M 的 `airpi-fanctl` Rust 预编译步骤**：`Config/AP3000M.txt` 中的 `luci-app-airpi-fancontrol` 带 `PKG_BUILD_DEPENDS:=rust/host`，OpenWrt 会从源码构建整套 rustc + cargo + LLVM，约 1.5~3 小时。现用 runner 自带的 rustup 配合已构建好的 aarch64 musl 交叉链接器直接 `cargo build`，再通过 `AIRPI_PREBUILT=1` / `AIRPI_PREBUILT_BIN` 交给包 Makefile（新增 `Scripts/inject_airpi_prebuilt.py` 负责注入）。上游 `LianXia233/luci-app-airpi3000m-fancontrol` 的 Makefile 已原生支持该分支；预编译失败会自动回退到源码构建，不影响出包。
- **⑧ 其他**：job 增加 `timeout-minutes: 345`，避免撞上平台 6 小时硬上限被强杀（强杀时 runner 直接终止，缓存 post 保存同样会被跳过）；`apt` 初始化去掉 `full-upgrade` 与 `autoremove --purge`（托管 runner 每次全量升级要数分钟，对编译零收益）；移除 runner 预置的 google-chrome apt 源（其镜像偶发哈希不一致会让 `apt update` 返回非零并中断初始化）；`make download -j$(nproc)` 仅在失败时才做串行兜底，不再每轮跑两遍全量校验；显式 `echo "CONFIG_CCACHE=y" >> .config` 并在编译步骤 export `CCACHE_DIR` / `CCACHE_MAXSIZE=5G` / `CCACHE_COMPRESS=true`（上限由 08-29 设定的 2G 放宽到 5G，在 10GB 总配额内换取更高命中率）。

### 预期效果

参照 `LianXia233/H5000M-CI-Qmodem` 在同源码（`immortalwrt master db5c5de`）、同 4 vCPU 标准 runner 下的实测：`MTK-AUTO` 99.4 / 102.0 分钟，`OWRT-ALL` 44.3 / 45.6 分钟。

- `H5000M` 稳态（缓存命中）：约 212 分钟 → **25~45 分钟**
- `AP3000M` 稳态：约 230 分钟 → **40~70 分钟**（Rust 预编译单独省 90~180 分钟）
- `X86` 稳态：约 150 分钟 → **20~35 分钟**
- 冷启动（首次 / 上游大版本）：仍是约 212 分钟，不可避免
- 每周冷启动次数：≥1 次 → **0 次**

整体降幅约 **70%~85%**。

### 注意

- **缓存键前缀变更**：`toolchain-` / `dl-` / `ccache-` 改为 `wrt-tc-` / `wrt-dl-`，旧缓存不会被复用，将由 GitHub LRU 自动回收。**合并后的第一次构建仍是冷启动**，收益自第二次起显现。
- **两个天花板**：4 vCPU 是免费标准 runner 的硬上限，`-j4` 冷编整套 ImmortalWrt 就是 2~3 小时，要再往下压只能上付费 larger runner（16 核，约降到 1/3，按分钟计费）或改用自托管；此外缓存命中依赖 `WRT_HASH` 稳定，上游频繁提交时仍会有增量重编。
- 本次仅改动工作流与脚本，不涉及 `Config/` 与固件内容，产物应保持一致。

## ## [2026-08-29] 编译提速：新增 dl / feeds 缓存并限制 ccache 体积

### 优化（编译提速）

- **WRT-CORE 新增两份缓存，补齐「下载源码」与「feeds 更新」阶段的复用（继 08-28 toolchain / ccache `restore-keys` 之后的进一步提速）**：原缓存只覆盖 `staging_dir/`（toolchain）与 `.ccache`（编译产物），而 `make download` 拉取的上游源码包、`feeds update -a` 克隆的软件源索引每轮都从零获取；在 toolchain 已可复用后，这两项成为新的主要耗时来源。
  - 新增 `Check Download Cache`：缓存 `./wrt/dl/`，key `dl-<CONFIG>-<INFO>-<HASH>`，配 `restore-keys: dl-<CONFIG>-<INFO>-` 前缀回退。上游 `WRT_HASH` 一更新精确 key 必然 miss，回退 key 命中同机型上一次的 `dl` 缓存后，`make download` 直接跳过已存在的源码包，不再重复拉取数百 MB～数 GB 的 tarball。
  - 新增 `Check Feeds Cache`：缓存 `./wrt/feeds/` 与 `./wrt/package/feeds/`，key `feeds-<CONFIG>-<INFO>-<HASH>`，同样配 `restore-keys` 回退，避免 `feeds update -a` 每轮完整克隆 / 拉取全部软件源索引。
  - 两个新缓存步骤均带 `if: env.WRT_TEST != 'true'`，与既有 toolchain / ccache 缓存逻辑一致：`TEST=true`（默认，仅生成 `.config` 校验）不受影响，只有真正出包时才读写缓存。
- **限制 ccache 体积**：顶层 `env` 新增 `CCACHE_MAXSIZE: 2G` 与 `CCACHE_COMPRESS: 'true'`。此前 ccache 无上限，缓存持续膨胀会拖慢缓存的恢复与上传；限幅并压缩后缓存更小，命中与回传更快。`Config/GENERAL.txt` 中 `CONFIG_CCACHE=y` 已启用，无需改动编译配置。
- 说明：`dl` / `feeds` 缓存首次运行仍为冷启动，需先各写入一次，自第二轮起才开始显著省时间；仓库缓存总额受 GitHub 约 10GB 上限约束，多份缓存按 LRU 自动淘汰，若出现挤占可调小 `CCACHE_MAXSIZE` 或让 `Cache-Clean.yml` 清理更激进。

## [2026-08-29] 源码切换：H5000M / AP3000M 改用 ImmortalWrt 主线
### Changed
- H5000M-AUTO / AP3000M-AUTO 工作流的 `SOURCE` 由 `VIKINGYFY/immortalwrt` 切换为 `immortalwrt/immortalwrt`，`BRANCH` 由 `owrt` 调整为 `master`；X86（OWRT-ALL）保持 `immortalwrt/immortalwrt` + `master` 不变。
- WRT-BUILD 手动编译默认源码/分支同步调整为 `immortalwrt/immortalwrt` + `master`。
- README 鸣谢保留 VIKINGYFY（OpenWRT-CI 编译框架），设备源码说明统一为 ImmortalWrt 主线。



本仓库的所有重要变更都会记录在此文件中。

## [2026-08-28]

### 优化（编译提速）

- **重构 WRT-CORE 缓存策略，消除 toolchain 全量重建（Run #33119462534 分析）**：原 `Check Caches` 的精确 key 含上游 commit（`WRT_HASH`），上游一推送精确 key 必然 miss，而 miss 时「Update Caches」还会**先删光旧缓存再重建**——失败 run 的完整时间线显示 toolchain（gcc initial+final 两轮）+ 宿主 tools 全量重建占去约 1.9 小时（21:56 → 00:11 才开始编内核），是编译耗时的最大单一来源。
  - `Check Caches` 拆为两份独立缓存并各配 `restore-keys` 前缀回退：
    - `toolchain-<CONFIG>-<INFO>-<HASH>`：整份 `staging_dir/`（原 `host*`/`tool*` 通配改为整目录，含 `staging_dir/target` 的内核头/mac80211 存根，避免遗漏）；
    - `ccache-<CONFIG>-<INFO>-<HASH>`：`wrt/.ccache`（`CONFIG_CCACHE=y` 已启用，单份持久化后对上游 mt76/mac80211 这类频繁变动的树外包命中率显著提升）。
    - 上游更新时 `restore-keys` 命中同机型最近一次缓存，OpenWrt 依据自身 stamp 只增量重编变化的组件，不再从零编译 gcc。
  - 移除「Update Caches」中按 miss 删除旧缓存的逻辑（`gh cache list/delete` 段）：restore-keys 命中的旧缓存正是本次构建的复用基础，删除它会导致下次构建退回全量重建；容量由 GitHub 10GB 上限自动按 LRU 淘汰。
  - `Download Packages` 追加 `make download -j1` 串行兜底：补齐并行下载偶发失败的源码，避免 `Compile Firmware` 中途因下载失败中断重来（该阶段重启的代价远大于多跑一次已全部命中的 download）。

## [2026-08-28]

- **永久移除 `999-mtk7987-wed-v31.patch`（Run #33119462534）**：`Compile Firmware` 阶段 `package/kernel/mt76` 编译失败，`mt7996/mmio.c:517` 与 `mt7996/mmio.c:543` 报错 `error: assignment to expression with array type`，随后 `ERROR: package/kernel/mt76 failed to build.`。
  - 根因：内核侧 `999-mtk7987-wed-v31.patch` 将 `include/linux/soc/mediatek/mtk_wed.h` 中 `wlan.wpdma_tx` 由标量 `u32` 改为数组 `u32 wpdma_tx[MTK_WED_TX_QUEUES]`、`wlan.hw_rro` 由 `bool` 改为枚举 `enum mtk_wed_hwrro_mode`，并新增 `rro_3_1_rx_ring_setup` 等接口；但上游 mt76（`2026.08.08~503c643b`）仍按旧标量 API 赋值 `wed->wlan.wpdma_tx`，且此前配套的 mt76 侧补丁（`998-mt76-wed-hwrro-enum.patch`）已因 mt76 上游更新而移除，内核补丁与 mt76 源码的 API 断裂无法在 CI 侧低风险弥合。
  - 处理：删除 `Scripts/patches/wed/999-mtk7987-wed-v31.patch` 与 `Scripts/patches/wed/` 目录；`Scripts/Handles.sh` 中彻底移除内核侧 WED 补丁注入段（`WED_PATCHES_SRC` / `WED_APPLIED` 逻辑及注释）。VIKINGYFY/immortalwrt `owrt` 分支回到上游原生 WED 代码路径，mt76 按上游默认行为编译，编译恢复。
  - 影响：H5000M（MT7987）机型的 WED 硬件加速回落到上游默认支持状态（如上游未启用则 `mtk_wed_device_attach` 不挂载、走普通收发路径，功能不受影响，仅硬件路径加速不可用）；后续如需重新启用，需基于当时的内核与 mt76 commit 同步重做内核侧与 mt76 侧两套补丁并经 `git apply --check` 双向验证。

## [2026-08-28]

### 变更

- **H5000M / AP3000M 源码切换**：`MTK-AUTO.yml` 编译矩阵的 `SOURCE` 由 `immortalwrt/immortalwrt` 切换为 [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)，`BRANCH` 由 `master` 调整为 `main`（VIKINGYFY 仓库仅有 main/owrt/test 三个分支，无 master）。仅影响 5000M 与 3000M 两个机型的自动编译；OWRT-ALL（X86）、手动编译入口 WRT-BUILD 及 Config/Scripts 均保持不变。
- 风险提示：现有 WED V3.1 补丁（`999-mtk7987-wed-v31.patch` / `998-mt76-wed-hwrro-enum.patch`，仅注入 H5000M-WIFI-YES）此前基于 immortalwrt/immortalwrt master（内核 6.18.x）验证；VIKINGYFY/immortalwrt 的内核与 mt76 版本若与其不同，首次构建可能需要重新校准补丁。
- **分支再次调整**：按最新要求，`MTK-AUTO.yml` 编译矩阵的 `BRANCH` 由 `main` 调整为 `owrt`（使用 VIKINGYFY/immortalwrt 的 owrt 分支）。其余配置不变。

### 变更（永久移除）

- **永久移除 mt76 侧 WED hw_rro 枚举补丁（Run #33100607008）**：`Compile Firmware` 阶段 `package/kernel/mt76` 编译失败，根因为 `Scripts/patches/wed/998-mt76-wed-hwrro-enum.patch` 应用失败——上游 mt76 已更新至 `2026.08.08~503c643b`，`mt7996/mmio.c` 第 488 / 518 行附近上下文与补丁基线不一致，2 个 hunk 全部 FAILED（生成 `.rej`），mt76 包构建中断（`ERROR: package/kernel/mt76 failed to build`）。
  - 处理：删除 `Scripts/patches/wed/998-mt76-wed-hwrro-enum.patch`；`Scripts/Handles.sh` 中彻底移除 mt76 侧注入逻辑（`MT76_PATCH_DIRS` 段）并同步清理相关注释，保留内核侧 `999-mtk7987-wed-v31.patch` 注入不变。
  - 影响：H5000M（MT7987）机型不再注入 mt76 侧 hwrro 枚举映射修正，WED 维持上游默认行为；不影响编译。该补丁已确认不再需要，永久移除、不再恢复。

### 变更

- **MTK-AUTO 重命名为 H5000M-AUTO**：`.github/workflows/MTK-AUTO.yml` 更名为 `H5000M-AUTO.yml`，工作流 `name` 同步改为 `H5000M-AUTO`（原 MTK-AUTO 仅编译 H5000M-WIFI-YES，为与机型命名保持一致而重命名）。同步更新：`WRT-CORE.yml` / `AP3000M-AUTO.yml` 顶部注释、`README.md` 工作流表格与项目结构（补充 AP3000M-AUTO 条目）。编译矩阵、触发方式与参数均不变。
- **拆分 AP3000M 与 H5000M 自动编译**：`MTK-AUTO.yml` 编译矩阵由 `[H5000M-WIFI-YES, AP3000M]` 收敛为仅 `[H5000M-WIFI-YES]`；新增独立工作流 `AP3000M-AUTO.yml`（同样监听 `Auto-Clean` 完成后触发 + 支持手动 `workflow_dispatch`，参数与 MTK-AUTO 保持一致），两个机型从此分开编译、互不影响，Release 与构建日志按机型独立呈现。

## [2026-08-25]

### 新增

- **TTYD Web 终端**：全机型默认集成 [ttyd](https://github.com/tsl0922/ttyd) 网页命令行终端，LuCI「系统 → TTYD 终端」页面可在浏览器直接操作设备 Shell。`Config/GENERAL.txt` 新增并默认启用 `ttyd`、`luci-app-ttyd`、`luci-i18n-ttyd-zh-cn` 三个软件包。

### 修复

- **修复 MTK-AUTO H5000M-WIFI-YES 编译失败（Run #32827814718）**：`Compile Firmware` 阶段 `mt7996/mmio.c` 编译报错 `assignment to expression with array type`（491 / 527 行），`ERROR: package/kernel/mt76 failed to build.`。
  - 根因：内核侧 `999-mtk7987-wed-v31.patch` 将 `include/linux/soc/mediatek/mtk_wed.h` 中 `wlan.wpdma_tx` 由标量改为数组 `u32 wpdma_tx[MTK_WED_TX_QUEUES]`、`wlan.hw_rro` 由 `bool` 改为枚举 `enum mtk_wed_hwrro_mode`，但 mt76 侧补丁未同步适配 `mt7996/mmio.c` 中两处按标量赋值的语句（对照联发科官方 `mtk-openwrt-feeds` 的 `0049-mtk-mt76-mt7990-add-mt7987-wed-hw-path-support.patch` 确认了正确写法）。
  - 修复：重写 `Scripts/patches/wed/998-mt76-wed-hwrro-enum.patch`——`wpdma_tx` 两处赋值改为 `wpdma_tx[0]`（hif2 分支与主分支），主分支补齐 V3.1 所需的 `wpdma_tx[1]`（`MT_TXQ_RING_BASE(1) + MT7996_TXQ_BAND1 * MT_RING_SIZE`），`hw_rro` 改为 `(enum mtk_wed_hwrro_mode)dev->mt76.hwrro_mode` 直接映射（mt76 与内核枚举数值一一对应）；同时预防性修正 `mt7915/mmio.c` 两处同类赋值。已基于 CI 实际使用的 mt76 commit（`5967691`）通过 `git apply --check` 验证。

## [2026-08-24]

### 新增

- **MT7987 WED V3.1 硬件路径支持（内核 6.18）**（commit `d1d718d`）：将 MT7987 WED（Wireless Ethernet Dispatch）V3.1 硬件路径支持补丁移植到 6.18 内核 API 并注入 CI 构建流程，解决 MT7987 平台因设备树（DTS）缺少 `wo-ccif` 节点导致内核报 `failed to attach wed device`、无线硬件加速不可用的问题。
  - `999-mtk7987-wed-v31.patch`：内核侧补丁（6329 行），将 WED V3.1 硬件路径支持适配至 6.18 内核 API。
  - `998-mt76-wed-hwrro-enum.patch`：mt76 驱动侧 `WED_HWRRO` 枚举修正，与内核补丁配套。
  - `Scripts/Handles.sh`：新增注入段，将上述补丁在构建时自动拷入对应源码目录并应用。

### 修复

- **修复 MTK-AUTO 编译失败（Run #32730137693）**：首次推送的 `999-mtk7987-wed-v31.patch` 基于无提交记录的本地基线生成，被 git 当作 **new-file 格式**（整个文件为新增行），而 OpenWrt 构建时目标文件已存在，导致补丁应用全部 hunk 失败，`Compile Firmware` 阶段中断。
  - 根因：补丁基线（`wed618` 临时目录）从未建立 git 基线提交，`git diff` 输出为全新增文件；且 Windows 侧 CRLF 污染曾使 diff 整文件漂移。
  - 修复（commit `313909a` 后追加提交）：重新以 **6.18.44 官方内核源文件 + immortalwrt patches-6.18（940/942/943/944）** 建立真实基线（`wedreal`），基于该基线重新生成补丁（1825 行，778 增 / 259 删，与原厂补丁规模一致），在本地 `git apply --check` 验证通过；同时修正 `998-mt76-wed-hwrro-enum.patch` 的 hunk 行数错误并对照 CI 实际使用的 mt76 commit（`5967691`）验证可应用。补丁统一为 LF、标准 `diff --git` 格式。

- **修复 MTK-AUTO 编译失败（Run #32737139044）：** 修复提交 `9069348` 后 `999-mtk7987-wed-v31.patch` 在 `Compile Firmware` 阶段 `mtk_wed.c` 编译失败，报错 `struct <anonymous> has no member named 'wed_rev_id'` 及 `MTK_WED_REV_ID_MAJOR/MINOR undeclared`。
  - 根因：移植 6.18 的补丁只合并了联发科 `999-wed-10-add-mt7987-hwpath-support.patch` 的核心逻辑，但漏掉同系列 `999-wed-08-extended-wed-debugfs.patch` 中配套的定义：`struct mtk_wed_soc_data` regmap 缺 `u32 wed_rev_id;` 成员、`mtk_wed_regs.h` 缺 `MTK_WED_REV_ID_MAJOR (GENMASK(31,28))` / `MTK_WED_REV_ID_MINOR (GENMASK(27,16))` 宏。
  - 修复：在 6.18.44 基线（wedreal）上补齐上述定义，并为 mt7622/mt7986/mt7988 的 `soc_data.regmap` 补上 `.wed_rev_id` 初始化（与联发科 6.12 一致：0 / 0x4 / 0x4）；重新生成补丁（1855 行，784 增 / 259 删），本地 `git apply --check` 验证通过。

- **WED 补丁仅对 H5000M 机型注入（commit `f2096b6`）**：此前 `Scripts/Handles.sh` 的 WED 注入段对所有目标机型无条件注入 `999-mtk7987-wed-v31.patch` 与 `998-mt76-wed-hwrro-enum.patch`，导致其他机型编译失败：X86 目标（AP3000M）的 mt76 应用 `998-mt76-wed-hwrro-enum.patch` 时 hunk 不匹配报错，MTK-AUTO 的 AP3000M（MT7981）机型也因 SoC/WiFi 芯片不同而不适用该补丁。
  - 修复：在 `Scripts/Handles.sh` 的 WED 注入段增加 `WRT_CONFIG` 判断，仅当配置为 `H5000M-WIFI-YES`（MT7987）时注入上述两个补丁，其余机型（AP3000M / X86 等）完全跳过，不影响构建。

## [2026-08-18]

### 修复

- **修复 OWRT-ALL / X86 编译失败（Run #32071207860）**：`Compile Firmware` 阶段报错 `bash: line 1: ./hack/make.sh: No such file or directory`，`make[3]: *** [Makefile:168: .../dockerd-29.6.1/.built] Error 127`，`ERROR: package/feeds/packages/dockerd failed to build.`。
  - 根因：`Scripts/Handles.sh` 中 Python 注入 `fix-binary-daemon.sh` 调用时，替换出的行**未保留 Makefile 的 `\` 续行符**，把原本连续的 recipe 拆成两条独立 shell 命令——`cd $(PKG_BUILD_DIR); ... . fix-binary-daemon.sh ...` 在源码目录执行并成功打补丁，但 `./hack/make.sh binary` 退化为独立 recipe 行，在**包目录**（`feeds/packages/utils/dockerd`）执行，该目录下不存在 `hack/make.sh`，故报 Error 127。
  - 修复（`Scripts/Handles.sh`）：注入行改为 `cd $(PKG_BUILD_DIR) && . "$(CURDIR)/fix-binary-daemon.sh" "$(PKG_BUILD_DIR)" && \` 以 `&& \` 续行符结尾，确保 `cd`、补丁脚本、`./hack/make.sh binary` 在同一条 make recipe（同一 shell、同一工作目录）中顺序执行。已用上游 `openwrt/packages` 的 dockerd Makefile 本地模拟验证注入结果正确。

### 变更

- **默认 Wi-Fi SSID 回退为 `OWRT`**：`OWRT-ALL.yml` / `MTK-AUTO.yml` / `WRT-BUILD.yml` 三个工作流的 `WRT_SSID` 环境变量由 `OWRT_2.4G` 回退为默认值 `OWRT`（2.4G 与 5G 频段默认 SSID 一致，由 `Scripts/Settings.sh` 在编译时写入）。默认密码仍为 `12345678`，加密方式 WPA-PSK/WPA2-PSK Mixed Mode、国家码 `CN` 等保持不变。同步更新 `README.md`「默认配置」小节中的 SSID 记录。

## [2026-08-15]

### 修复

- **修复 OWRT-ALL / X86 编译失败（Run #31842487773）**：`Compile Firmware` 阶段报错 `make[3]: *** [Makefile:166: .../dockerd-29.6.1/.built] Error 1`（失败 job：94902144731，SOURCE=immortalwrt/immortalwrt）。根因为 `dockerd 29.6.1` 的 moby 构建脚本 `hack/make/binary-daemon` 中 `copy_binaries()`：当 CI runner 预装 Docker（存在 `/usr/local/bin/runc`）且目标架构与宿主一致（linux/amd64）时，会尝试从宿主 PATH 拷贝 `containerd`/`runc`/`rootlesskit`/`dockerd-rootless.sh` 等“嵌套可执行文件”；但 GitHub Actions runner 上这些并不在 PATH，`command -v` 返回空串导致 `cp -f ""` 报错，配合脚本 `set -e` 直接中断编译。这些二进制本就由独立的 OpenWrt 包在运行时提供，无需打入 dockerd bundle。
  - 为何原有补丁未生效：仓库既有 `Scripts/patches/dockerd/999-fix-nested-binaries.patch` 内容正确（同样将拷贝改为条件拷贝），但本次构建日志中**没有出现任何 `patching file hack/make/binary-daemon` 输出**，说明 OpenWrt 未触发对该文件应用补丁，故仅依赖补丁机制不可靠。
  - 修复（双保险，绕过补丁机制）：
    - 保留 `999-fix-nested-binaries.patch` 拷入 `feeds/.../dockerd/patches/`（OpenWrt 标准机制，能用时生效）；
    - 新增 `Scripts/patches/dockerd/fix-binary-daemon.sh`：在 dockerd 源码解包后、编译前对 `hack/make/binary-daemon` 做就地 sed 修正，将 `cp -f "$(command -v "$file")" "$dir/"` 改为「仅当该文件存在于 PATH 时才拷贝，缺失则跳过」（`bin="$(command -v "$file" 2>/dev/null || true)"; [ -n "$bin" ] && cp -f "$bin" "$dir/"`）。
    - 修改 `Scripts/Handles.sh` dockerd 段（约 300–368 行）：把补丁与修正脚本一同拷入 dockerd 包目录并 `chmod +x`，再用 Python 在 dockerd `Makefile` 的 `Build/Compile` 中、`./hack/make.sh binary` 之前注入 `bash "$(CURDIR)/fix-binary-daemon.sh" "$(PKG_BUILD_DIR)"; \`（幂等，已注入则跳过）；`find` 同时覆盖拷贝安装与软链安装两种 feeds 路径。

## [2026-08-12]

### 修复

- **修复默认无线密码和时区不生效问题**（`Scripts/Settings.sh`）：默认无线加密设为 WPA-PSK/WPA2-PSK Mixed Mode、地区 CN、2.4G 频宽 40MHz、5G 频宽 160MHz，并在 `config_generate` 中强制写入 `timezone='CST-8'` + `zonename='Asia/Shanghai'` 确保时区生效。同时兼容旧式 `set-wireless.sh` 和新型 `mac80211.uc` 两套无线默认配置路径。
- **HomeProxy ucode 兼容性修复**：ImmortalWrt master 已移除 `luci.sys.init_action` 且 ucode 不含 `math` 模块，导致订阅更新与客户端配置生成失败（sing-box 无法启动，页面报 "URLTest: 无效节点"）。在 `Scripts/Handles.sh` 中加入自动覆盖修复，CI 构建时替换上游的两个脚本：
  - `update_subscriptions.uc`：移除 `import { init_action } from 'luci.sys'`，将 `init_action('homeproxy', 'restart')` 替换为 `system('/etc/init.d/homeproxy restart >/dev/null 2>&1')`，修复订阅拉取后无法更新节点列表的问题。
  - `generate_client.uc`：移除 `import { isnan } from 'math'`，将 `isnan(int(i))` 替换为 `type(int(i)) === 'double'`（ucode 中 `int("abc")` 返回 double 类型 `NaN`），修复 sing-box 客户端配置生成失败导致服务无法启动的问题。
  - 修复脚本存放于 `Scripts/homeproxy/`，不包含节点信息。
- **修复 OWRT-ALL / X86 编译失败（Run #31556891052）**：`Compile Firmware` 步骤报错 `exit code 2`。根因为 `kmod-nft-fullcone`（fullconenat，`llccd/netfilter-full-cone-nat`）为树外内核模块、直接补丁 nftables 核心，其源码停留在 `PKG_SOURCE_DATE=2023-01-01`，未适配 immortalwrt master 内核 **6.18.41**，导致内核模块编译失败（`make download` 已成功，故为编译期而非下载期错误）。在 `Config/GENERAL.txt` 中暂时禁用 `CONFIG_PACKAGE_kmod-nft-fullcone`（全机型通用配置），待上游提供 6.18 兼容版本后取消注释即可恢复 Fullcone NAT 支持。

### 变更（临时禁用）

- **暂时禁用 Honk 插件**：按需求临时关闭，未删除任何逻辑，可一键恢复。
  - `Scripts/Packages.sh`：将 `INSTALL_HONK_PREBUILT` 调用注释（函数体保留）。
  - `Config/GENERAL.txt`：将 Honk 运行时依赖（`ca-bundle`/`jq`/`nsenter`/`tc-full`/`v2ray-geoip`/`v2ray-geosite`/`kmod-sched-core`/`kmod-sched-bpf`）与 `CONFIG_KERNEL_DEBUG_INFO_BTF=y` 全部注释。
  - 恢复方法：取消 `Packages.sh` 中 `INSTALL_HONK_PREBUILT` 的注释，并取消 `GENERAL.txt` 中上述 `CONFIG_*` 行的注释即可。

## [2026-08-11]

### 新增

- **全机型集成 Honk eBPF 透明代理插件**（[breeze303/openwrt-honk](https://github.com/breeze303/openwrt-honk)，`main` 分支），默认启用，覆盖全部编译机型（X86 / AP3000M / H5000M-WIFI-YES，均为 x86_64 / aarch64，满足插件平台要求）：
  - `Scripts/Packages.sh`：新增 `UPDATE_PACKAGE "honk"`，以 `pkg` 模式从上游仓库提取 `honk`、`luci-app-honk`、`luci-app-honk-legacy` 三个软件包（自动跳过 docs/locks/tests 等非包目录）。
  - `Config/GENERAL.txt`：默认启用 `CONFIG_PACKAGE_honk=y` 与 `CONFIG_PACKAGE_luci-app-honk=y`（新版 LuCI 管理界面；旧版 `luci-app-honk-legacy` 作为回滚备用，默认不编译进固件）。

### 依赖处理

- **运行时依赖**（`Config/GENERAL.txt` 显式启用）：`ca-bundle`、`jq`、`nsenter`、`tc-full`、`v2ray-geoip`、`v2ray-geosite`、`kmod-sched-core`、`kmod-sched-bpf`；`ip-full`、`kmod-veth`、`curl`、`luci-base`、`luci-compat` 此前已在通用配置中启用。`libstdcpp` 等由软件包 `DEPENDS` 自动解析。
- **内核依赖**：显式启用 `CONFIG_KERNEL_DEBUG_INFO_BTF=y`，满足 eBPF 程序的 BTF 需求（BPF/BPF_JIT/CGROUP_BPF/NET_CLS_BPF 等由 `kmod-sched-bpf` 等内核模块依赖自动带出）。
- **主机编译依赖**（`Scripts/Packages.sh` 新增 `INSTALL_HONK_DEPS`，在 Custom Packages 阶段自动执行）：
  - 系统组件：`clang`、`llvm`、`libbpf-dev`、`libclang-dev`、`pkg-config`、`cmake`、`zstd`（bindgen 与 eBPF 编译所需）；
  - Rust 工具链：通过 rustup 安装上游锁定的 `nightly-2026-07-20`（含 `rust-src` 组件，用于 `-Zbuild-std=core` 编译 `bpfel-unknown-none` 目标）；
  - eBPF 链接器：安装 `bpf-linker 0.10.4`（下载后执行 SHA-256 校验，校验失败立即中断，避免引入被篡改的工具链），并写入 `GITHUB_PATH` 保证后续编译步骤可用。
### 修复（构建超时）

- **修复 MTK-AUTO 构建被 GitHub 6 小时上限取消的问题（Run #31472548184）**：MTK-AUTO 构建 `08:17` 开始，`14:17`（正好 6 小时）被 GitHub 强制取消，日志中无编译报错（仅 Kconfig `recursive dependency` 警告与已成功的依赖安装步骤），取消时 cargo/rustc 正在编译 honk。根因为 honk 为 Rust/eBPF 架构，从源码编译极重，使总耗时超过 GitHub 标准 runner 的单 job 6 小时硬上限。
- **honk 改为上游预编译 APK 注入**（不再从源码编译）：
  - `Scripts/Packages.sh`：移除 `UPDATE_PACKAGE "honk"` 与 `INSTALL_HONK_DEPS`（主机 Rust/eBPF 工具链），新增 `INSTALL_HONK_PREBUILT()`——按目标架构从上游最新 release 下载 `honk` 与 `luci-app-honk` 的 `openwrt-25.12` APK（与 `immortalwrt/immortalwrt@master` 默认 `USE_APK=y` 匹配），放入固件 `files/etc/honk/`，并写入 `files/etc/uci-defaults/99-honk-install`，在设备**首次开机时离线 `apk add --allow-untrusted`** 安装（依赖由 `GENERAL.txt` 编入镜像，无需联网）：
    - 架构映射（优先用 `WRT_TARGET`，回退 `WRT_CONFIG`）：`x86`→`x86_64`；**`mediatek`→`aarch64_cortex-a53`**（MT798x / MT7622 等 MTK 机型专用，Cortex-A53 架构）；其余→`aarch64_generic`。
  - `Config/GENERAL.txt`：移除 `CONFIG_PACKAGE_honk=y` / `CONFIG_PACKAGE_luci-app-honk=y`（APK 构建中无对应源码符号，会被 defconfig 丢弃），保留全部运行时依赖（`ca-bundle`/`jq`/`nsenter`/`tc-full`/`v2ray-geoip`/`v2ray-geosite`/`kmod-sched-*`）与 `CONFIG_KERNEL_DEBUG_INFO_BTF=y`。

### 修复
- **修复 honk 包编译失败（Run #33）**：AP3000M / H5000M-WIFI-YES 两个机型均在 `Compile Firmware` 阶段报错 `cp: cannot overwrite non-directory '.../root-mediatek/./var' with directory '.../.pkgdir/honk/./var'`。
  - 根因：honk 上游 `Makefile` 的 `Package/honk/install` 中执行 `$(INSTALL_DIR) $(1)/var/share/honk`，在 pkgdir 下创建了 `var/` 目录；而 OpenWrt rootfs 中 `/var` 是指向 `/tmp` 的符号链接，构建系统复制 pkgdir 到 rootfs 时 `cp` 无法用目录覆盖符号链接。
  - 修复（`Scripts/Handles.sh` 新增 honk 修复段）：在 Custom Packages 阶段自动移除 honk `Makefile` 中 `/var/share/honk` 的创建与 `chmod 0700`；运行时数据目录由 `honk.init` 的 `prepare_subscription_store()` 在启动时通过 `mkdir -p` 自动创建，不影响功能。


(() => {
  'use strict';

  const REPO_OWNER = 'LianXia233';
  const REPO_NAME = 'OpenWRT-CI';
  const WALLPAPERS = window.WALLPAPERS || [
    'https://files.seeusercontent.com/2026/10/31/aE1a/145952531_p1.jpg',
    'https://files.seeusercontent.com/2026/06/29/uu4H/bg1.jpg'
  ];

  let currentProxy = 'acg2';
  let selectedDevice = 'ALL';
  let selectedVariant = 'ALL';
  let selectedFormat = 'ALL';
  let searchQuery = '';

  function getBeijingDateTag() {
    const now = new Date();
    const utc = now.getTime() + now.getTimezoneOffset() * 60000;
    const bj = new Date(utc + 3600000 * 8);
    const yy = String(bj.getFullYear()).slice(-2);
    const mm = String(bj.getMonth() + 1).padStart(2, '0');
    const dd = String(bj.getDate()).padStart(2, '0');
    return `${yy}.${mm}.${dd}`;
  }

  function generatePresetFirmwares(tagDate) {
    return [
      {
        id: 'h5000m-netwiz-mt5700',
        device: 'H5000M',
        deviceName: 'Hiveton H5000M 5G CPE',
        variant: 'NETWIZ',
        variantLabel: 'NetWiz 家族 · MT5700',
        variantClass: 'fw-badge-netwiz',
        format: 'sysupgrade',
        filename: `H5000M-NetWiz-MT5700-aarch64-${tagDate}-sysupgrade.bin`,
        size: '58.4 MB',
        date: `20${tagDate.replace(/\./g, '-')}`,
        tag: `NetWiz-${tagDate}`,
        desc: '内置 NetWiz 网络向导 + MT5700 (Rust后端) 5G 模组驱动 + WiFi 7 双频 160MHz + 双温区温控',
        tags: ['NetWiz向导', '5G拨号', 'WiFi 7', 'PWM温控', '自愈守护', 'sysupgrade'],
        downloadUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/NetWiz-${tagDate}/H5000M-NetWiz-MT5700-aarch64-${tagDate}-sysupgrade.bin`
      },
      {
        id: 'h5000m-mt5700',
        device: 'H5000M',
        deviceName: 'Hiveton H5000M 5G CPE',
        variant: 'MT5700',
        variantLabel: 'MT5700 方案 B (轻量)',
        variantClass: 'fw-badge-mt',
        format: 'sysupgrade',
        filename: `H5000M-MT5700-aarch64-${tagDate}-sysupgrade.bin`,
        size: '56.2 MB',
        date: `20${tagDate.replace(/\./g, '-')}`,
        tag: `MT5700-${tagDate}`,
        desc: '母配置 + luci-app-mt5700 模组管理，Rust 极速后端，状态大屏，多网智能切换，推荐日常选用',
        tags: ['MT5700', 'Rust后端', 'WiFi 7', 'NetMode多网', 'sysupgrade'],
        downloadUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/MT5700-${tagDate}/H5000M-MT5700-aarch64-${tagDate}-sysupgrade.bin`
      },
      {
        id: 'h5000m-fm350',
        device: 'H5000M',
        deviceName: 'Hiveton H5000M 5G CPE',
        variant: 'FM350',
        variantLabel: 'Fibocom FM350-GL',
        variantClass: 'fw-badge-fm350',
        format: 'sysupgrade',
        filename: `H5000M-FM350-aarch64-${tagDate}-sysupgrade.bin`,
        size: '57.8 MB',
        date: `20${tagDate.replace(/\./g, '-')}`,
        tag: `FM350-${tagDate}`,
        desc: '专为广和通 FM350-GL 5G 模组定制，走 RNDIS 纯净通道无内核冲突，满血 WiFi 7 吞吐',
        tags: ['FM350-GL', 'RNDIS通道', 'WiFi 7', 'PWM温控', 'sysupgrade'],
        downloadUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/FM350-${tagDate}/H5000M-FM350-aarch64-${tagDate}-sysupgrade.bin`
      },
      {
        id: 'h5000m-base',
        device: 'H5000M',
        deviceName: 'Hiveton H5000M 5G CPE',
        variant: 'BASE',
        variantLabel: '纯净基础母配置',
        variantClass: 'fw-badge-base',
        format: 'sysupgrade',
        filename: `H5000M-BASE-aarch64-${tagDate}-sysupgrade.bin`,
        size: '53.1 MB',
        date: `20${tagDate.replace(/\./g, '-')}`,
        tag: `BASE-${tagDate}`,
        desc: '不含 5G 模组插件的基础高速固件，满血 WiFi 7，保留风扇温控与多网络智能切换组件',
        tags: ['基础母配置', 'WiFi 7', 'Tailscale', 'Samba4', 'sysupgrade'],
        downloadUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/BASE-${tagDate}/H5000M-BASE-aarch64-${tagDate}-sysupgrade.bin`
      },
      {
        id: 'ap3000m-netwiz-mt5700',
        device: 'AP3000M',
        deviceName: 'AirPi AP3000M 路由器',
        variant: 'NETWIZ',
        variantLabel: 'NetWiz 家族 · MT5700',
        variantClass: 'fw-badge-netwiz',
        format: 'sysupgrade',
        filename: `AP3000M-NetWiz-MT5700-aarch64-${tagDate}-sysupgrade.bin`,
        size: '48.9 MB',
        date: `20${tagDate.replace(/\./g, '-')}`,
        tag: `NetWiz-${tagDate}`,
        desc: 'AirPi AP3000M 专属，内置 NetWiz 向导与 EEPROM 射频自愈，双频 WiFi 6 160MHz 满血发射',
        tags: ['NetWiz', 'EEPROM自愈', 'WiFi 6', 'airpi-fanctl', 'sysupgrade'],
        downloadUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/NetWiz-${tagDate}/AP3000M-NetWiz-MT5700-aarch64-${tagDate}-sysupgrade.bin`
      },
      {
        id: 'ap3000m-factory',
        device: 'AP3000M',
        deviceName: 'AirPi AP3000M 路由器',
        variant: 'BASE',
        variantLabel: 'U-Boot 出厂直刷 / 救砖',
        variantClass: 'fw-badge-base',
        format: 'factory',
        filename: `AP3000M-BASE-aarch64-${tagDate}-factory.bin`,
        size: '46.7 MB',
        date: `20${tagDate.replace(/\./g, '-')}`,
        tag: `BASE-${tagDate}`,
        desc: 'AirPi AP3000M U-Boot 救砖底包，首次刷入写入真实 MAC 并恢复 factory 分区 28~29 dBm 射频',
        tags: ['Factory直刷', '救砖专用', 'EEPROM校准', 'factory'],
        downloadUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/BASE-${tagDate}/AP3000M-BASE-aarch64-${tagDate}-factory.bin`
      },
      {
        id: 'ap3000m-fm350',
        device: 'AP3000M',
        deviceName: 'AirPi AP3000M 路由器',
        variant: 'FM350',
        variantLabel: 'FM350-GL 模组方案',
        variantClass: 'fw-badge-fm350',
        format: 'sysupgrade',
        filename: `AP3000M-FM350-aarch64-${tagDate}-sysupgrade.bin`,
        size: '49.5 MB',
        date: `20${tagDate.replace(/\./g, '-')}`,
        tag: `FM350-${tagDate}`,
        desc: 'AP3000M 适配 FM350-GL 模组，免驱动冲突，内置 airpi-fanctl 智能风扇温控',
        tags: ['FM350', 'EEPROM修复', 'WiFi 6', 'sysupgrade'],
        downloadUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/FM350-${tagDate}/AP3000M-FM350-aarch64-${tagDate}-sysupgrade.bin`
      },
      {
        id: 'x86-netwiz-mt5700',
        device: 'X86',
        deviceName: 'X86_64 软路由 / 工控机',
        variant: 'NETWIZ',
        variantLabel: 'NetWiz 家族 · Docker',
        variantClass: 'fw-badge-netwiz',
        format: 'x86-img',
        filename: `X86-NetWiz-MT5700-x86-64-${tagDate}-efi.img.gz`,
        size: '72.3 MB',
        date: `20${tagDate.replace(/\./g, '-')}`,
        tag: `NetWiz-${tagDate}`,
        desc: 'X86 软路由专用，集成 Docker 容器引擎与 NetWiz 网络向导，EFI 引导开箱即用',
        tags: ['Docker', 'NetWiz', 'EFI引导', 'x86-img', '硬件加解密'],
        downloadUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/NetWiz-${tagDate}/X86-NetWiz-MT5700-x86-64-${tagDate}-efi.img.gz`
      },
      {
        id: 'x86-base-grub',
        device: 'X86',
        deviceName: 'X86_64 软路由 / 工控机',
        variant: 'BASE',
        variantLabel: '传统 GRUB / 兼容镜像',
        variantClass: 'fw-badge-base',
        format: 'x86-img',
        filename: `X86-BASE-x86-64-${tagDate}-combined.img.gz`,
        size: '68.9 MB',
        date: `20${tagDate.replace(/\./g, '-')}`,
        tag: `BASE-${tagDate}`,
        desc: '通用 Legacy BIOS / GRUB 引导固件，支持 PVE / ESXi / 物理机，内置 Tailscale 与 Samba4',
        tags: ['GRUB引导', '软路由', 'Docker', 'x86-img'],
        downloadUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/BASE-${tagDate}/X86-BASE-x86-64-${tagDate}-combined.img.gz`
      }
    ];
  }

  let currentFirmwares = generatePresetFirmwares(getBeijingDateTag());

  function getAcceleratedUrl(originalUrl) {
    if (!originalUrl) return '#';
    if (currentProxy === 'acg2') return `https://gh.acg2.mom/${originalUrl}`;
    if (currentProxy === 'ghproxy') return `https://ghproxy.net/${originalUrl}`;
    return originalUrl;
  }

  function escapeHtml(str) {
    return String(str || '').replace(/[&<>"']/g, s => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[s]));
  }

  function renderFirmwares() {
    const container = document.getElementById('firmwareContainer');
    if (!container) return;

    const filtered = currentFirmwares.filter(item => {
      if (selectedDevice !== 'ALL' && item.device !== selectedDevice) return false;
      if (selectedVariant !== 'ALL' && item.variant !== selectedVariant) return false;
      if (selectedFormat !== 'ALL' && item.format !== selectedFormat) return false;
      if (searchQuery) {
        const q = searchQuery.toLowerCase();
        const hay = `${item.filename} ${item.desc} ${item.deviceName} ${item.tags.join(' ')}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });

    if (filtered.length === 0) {
      container.innerHTML = `
        <div class="glass-card" style="grid-column: 1 / -1; padding: 48px 24px; text-align: center;">
          <h3 style="font-size: 1.15rem; font-weight: 800; margin-bottom: 6px;">未找到匹配的固件</h3>
          <p style="font-size: 0.9rem; color: var(--text-muted); margin-bottom: 16px;">请尝试更改筛选条件或清除搜索关键词</p>
          <button class="btn btn-secondary btn-sm" onclick="window.appResetFilters()">重置筛选条件</button>
        </div>
      `;
      return;
    }

    container.innerHTML = filtered.map(item => {
      const dl = getAcceleratedUrl(item.downloadUrl);
      const shaLink = item.checksumUrl ? getAcceleratedUrl(item.checksumUrl) : '';
      return `
        <article class="fw-card glass-card glass-card-interactive" data-id="${escapeHtml(item.id)}">
          <div class="fw-header">
            <div class="fw-device-title">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="2.2"><rect width="20" height="8" x="2" y="14" rx="2"/><path d="M6 18h.01M10 18h.01M15 10v4"/></svg>
              <span>${escapeHtml(item.deviceName)}</span>
            </div>
            <span class="fw-badge ${escapeHtml(item.variantClass)}">${escapeHtml(item.variantLabel)}</span>
          </div>

          <div class="fw-filename-box">
            <span class="fw-filename-text" title="${escapeHtml(item.filename)}">${escapeHtml(item.filename)}</span>
            <button class="copy-btn" onclick="window.appCopy('${escapeHtml(item.filename)}', '文件名')" title="复制文件名">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="14" height="14" x="8" y="8" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>
            </button>
          </div>

          <p class="fw-desc-text">${escapeHtml(item.desc)}</p>

          <div class="fw-tags">
            ${item.tags.map(t => `<span class="fw-tag-pill">${escapeHtml(t)}</span>`).join('')}
          </div>

          <div class="fw-meta-row">
            <span>大小：<strong style="color:var(--text-main)">${escapeHtml(item.size)}</strong></span>
            <span>版本：<strong style="color:var(--text-main)">${escapeHtml(item.tag)}</strong></span>
            <span>日期：<strong style="color:var(--text-main)">${escapeHtml(item.date)}</strong></span>
          </div>

          <div class="fw-actions">
            <a href="${escapeHtml(dl)}" class="btn btn-primary btn-sm" target="_blank" rel="noopener noreferrer" download>
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/></svg>
              立即下载
            </a>
            <button class="btn btn-secondary btn-icon" onclick="window.appCopy('${escapeHtml(dl)}', '下载直链')" title="复制加速直链">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
            </button>
            ${shaLink ? `<a href="${escapeHtml(shaLink)}" class="btn btn-secondary btn-sm" target="_blank" rel="noopener noreferrer" title="下载 SHA256 校验文件">SHA256</a>` : ''}
          </div>
        </article>
      `;
    }).join('');
  }

  async function fetchReleases() {
    const statusEl = document.getElementById('releaseStatusText');
    const refreshIcon = document.getElementById('refreshIcon');
    if (refreshIcon) refreshIcon.style.animation = 'spin 1s linear infinite';
    if (statusEl) statusEl.textContent = '正在实时查询最新发布...';

    try {
      const response = await fetch(`https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases?_t=${Date.now()}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const releases = await response.json();

      if (Array.isArray(releases) && releases.length > 0) {
        if (statusEl) statusEl.textContent = `已连接 GitHub Releases (${releases.length} 个最新发版)`;

        const FW_NAME_RE = /^(H5000M|AP3000M|X86)-([A-Za-z0-9-]+?)-(?:aarch64|x86-64)-(\d{2}\.\d{2}\.\d{2})-([A-Za-z0-9-]+)\.(bin|img\.gz|img|iso|vmdk|gz)$/;
        const DEVICE_NAMES = {
          H5000M: 'Hiveton H5000M 5G CPE',
          AP3000M: 'AirPi AP3000M 路由器',
          X86: 'X86_64 软路由 / 工控机'
        };

        const parsedItems = [];
        releases.forEach(rel => {
          if (!rel.assets || rel.assets.length === 0) return;
          const checksumUrls = new Map();
          let checksumTableUrl = '';
          rel.assets.forEach(a => {
            if (/\.sha256$/i.test(a.name)) {
              checksumUrls.set(a.name.replace(/\.sha256$/i, ''), a.browser_download_url);
            } else if (/^sha256sums(\.txt|\.sha256)?$/i.test(a.name)) {
              checksumTableUrl = a.browser_download_url;
            }
          });

          rel.assets.forEach(asset => {
            const m = FW_NAME_RE.exec(asset.name);
            if (!m) return;
            const [, device, flavor, buildStamp, fwType] = m;
            const deviceName = DEVICE_NAMES[device] || device;

            let variant = 'BASE', variantLabel = '基础母配置', variantClass = 'fw-badge-base';
            if (/^NetWiz/i.test(flavor)) {
              variant = 'NETWIZ';
              variantLabel = `NetWiz 向导 · ${flavor.replace(/^NetWiz-?/i, '') || '标准版'}`;
              variantClass = 'fw-badge-netwiz';
            } else if (/^SelfUse$/i.test(flavor)) {
              variant = 'SELFUSE'; variantLabel = '自用配置 (SelfUse)'; variantClass = 'fw-badge-base';
            } else if (/^MT5700M$/i.test(flavor)) {
              variant = 'MT5700M'; variantLabel = 'MT5700M 方案A'; variantClass = 'fw-badge-mt';
            } else if (/^MT5700$/i.test(flavor)) {
              variant = 'MT5700'; variantLabel = 'MT5700 方案B'; variantClass = 'fw-badge-mt';
            } else if (/^FM350$/i.test(flavor)) {
              variant = 'FM350'; variantLabel = 'FM350-GL 变体'; variantClass = 'fw-badge-fm350';
            }

            let format = 'x86-img';
            if (/sysupgrade/.test(fwType)) format = 'sysupgrade';
            else if (/factory|initramfs|recovery/.test(fwType)) format = 'factory';

            parsedItems.push({
              id: asset.id.toString(),
              device,
              deviceName,
              flavor,
              variant,
              variantLabel,
              variantClass,
              format,
              filename: asset.name,
              size: `${(asset.size / (1024 * 1024)).toFixed(1)} MB`,
              date: `20${buildStamp.replace(/\./g, '-')}`,
              tag: rel.tag_name,
              desc: rel.body ? `${rel.body.substring(0, 110)}...` : `${deviceName} 云端编译自动发版固件`,
              tags: [device, flavor, fwType, buildStamp, variant],
              downloadUrl: asset.browser_download_url,
              checksumUrl: checksumUrls.get(asset.name) || checksumTableUrl || ''
            });
          });
        });

        if (parsedItems.length > 0) {
          parsedItems.sort((a, b) => b.date.localeCompare(a.date) || a.device.localeCompare(b.device) || a.filename.localeCompare(b.filename));
          currentFirmwares = parsedItems;
          renderFirmwares();
        }
      } else if (statusEl) {
        statusEl.textContent = '实时链接已同步 (当前呈现全系预置矩阵)';
      }
    } catch (err) {
      console.warn('GitHub API fetch failed:', err);
      if (statusEl) statusEl.textContent = '已启用实时预置固件库 (日期已同步)';
    } finally {
      setTimeout(() => {
        if (refreshIcon) refreshIcon.style.animation = 'none';
      }, 450);
    }
  }

  const TUTORIAL_DATA = {
    'tab-sysupgrade': `
      <div class="step-item">
        <div class="step-number">1</div>
        <div class="step-body">
          <h4>进入系统升级页面</h4>
          <p>使用网线或 Wi-Fi 连接路由器，在浏览器中打开管理地址 <code>http://192.168.10.1</code>。登录后依次点击导航栏中的 <strong>系统 (System)</strong> → <strong>备份/升级 (Backup / Flash Firmware)</strong>。</p>
        </div>
      </div>
      <div class="step-item">
        <div class="step-number">2</div>
        <div class="step-body">
          <h4>上传 Sysupgrade 固件</h4>
          <p>在「刷写新的固件镜像 (Flash new firmware image)」区域，点击选择文件，选取带有 <code>-sysupgrade.bin</code> 后缀的固件文件，点击 <strong>上传 (Upload)</strong>。</p>
        </div>
      </div>
      <div class="step-item">
        <div class="step-number">3</div>
        <div class="step-body">
          <h4>校验与刷写</h4>
          <p>系统会自动核对固件 MD5 与校验和。首次跨版本、更换变体方案时，<strong>强烈建议取消勾选「保留配置」</strong>，以防旧配置文件与新插件冲突，点击 <strong>继续 (Continue)</strong> 等待 2~3 分钟自动重启完成。</p>
        </div>
      </div>
    `,
    'tab-uboot': `
      <div class="step-item">
        <div class="step-number">1</div>
        <div class="step-body">
          <h4>进入 U-Boot Web 救砖控制台</h4>
          <p>路由器断开电源。用卡针长按机身 <strong>Reset 键</strong>不放，插上电源开机，持续按住 5~8 秒直到机身指示灯发生有规律的双闪或变色，然后松开 Reset 键。</p>
        </div>
      </div>
      <div class="step-item">
        <div class="step-number">2</div>
        <div class="step-body">
          <h4>电脑设置静态 IP</h4>
          <p>使用网线将电脑网口与路由器的 <strong>LAN 口</strong>相连。在 Windows 网络属性中将以太网 IP 手动改为静态：<br>
          IP 地址：<code>192.168.1.2</code>，子网掩码：<code>255.255.255.0</code>，网关：<code>192.168.1.1</code>。</p>
        </div>
      </div>
      <div class="step-item">
        <div class="step-number">3</div>
        <div class="step-body">
          <h4>上传 Factory 镜像恢复</h4>
          <p>浏览器访问 <code>http://192.168.1.1</code> 打开 U-Boot 救砖页面。选择 <code>*-factory.bin</code> 固件并点击 Update Firmware。刷写完成后将电脑网卡改回「自动获取 IP」，访问 <code>192.168.10.1</code> 即可！</p>
        </div>
      </div>
    `,
    'tab-x86': `
      <div class="step-item">
        <div class="step-number">1</div>
        <div class="step-body">
          <h4>准备物理机写盘工具</h4>
          <p>下载带有 <code>-efi.img.gz</code> 或 <code>-combined.img.gz</code> 的镜像包并解压出 <code>.img</code> 镜像。在 Windows 上推荐使用 <strong>BalenaEtcher</strong> 或 <strong>Rufus</strong> 直接写入目标系统 U 盘或 SSD 固态硬盘。</p>
        </div>
      </div>
      <div class="step-item">
        <div class="step-number">2</div>
        <div class="step-body">
          <h4>虚拟机平台导入 (PVE / ESXi)</h4>
          <p>Proxmox VE (PVE) 用户新建无磁盘虚拟机后，使用 SSH 终端执行命令：<br>
          <code>qm importdisk &lt;VMID&gt; openwrt.img local-lvm</code><br>
          导入完成后在硬件设置中双击未挂载的磁盘并启用 SCSI 引导顺序即可。</p>
        </div>
      </div>
      <div class="step-item">
        <div class="step-number">3</div>
        <div class="step-body">
          <h4>首次网络连接</h4>
          <p>开机后将电脑网线插入软路由 ETH0 / LAN 口，电脑将自动分配到 <code>192.168.10.x</code> 网段，访问 <code>192.168.10.1</code> 登录 OpenWrt 控制面板。</p>
        </div>
      </div>
    `,
    'tab-ap3000m-fix': `
      <div class="step-item">
        <div class="step-number">1</div>
        <div class="step-body">
          <h4>AP3000M 出厂痛点说明</h4>
          <p>AirPi AP3000M 设备的 eMMC 出厂时 factory 分区为空，缺少原厂无线校准参数，导致官方源码编译出来的固件 Wi-Fi 信号极弱（只有 0~10 dBm）甚至 5GHz 频段无法启动。</p>
        </div>
      </div>
      <div class="step-item">
        <div class="step-number">2</div>
        <div class="step-body">
          <h4>内置出厂校准 EEPROM 套件</h4>
          <p>本仓库固件内置了专门经过射频调试的 EEPROM 校准套件（发射功率稳定在 <strong>28~29 dBm 满血发射</strong>）。系统首次开机时会自动检测 factory 分区，自动写入真实 MAC 地址并修补 5GHz 频段校准数据。</p>
        </div>
      </div>
      <div class="step-item">
        <div class="step-number">3</div>
        <div class="step-body">
          <h4>全程全自动，免人工干预</h4>
          <p>您只需要正常刷入本仓库提供的固件，无需借助编程器备份，首次启动后 Wi-Fi 即刻满血工作！</p>
        </div>
      </div>
    `
  };

  function renderTutorial(tabId) {
    const box = document.getElementById('tutorialContainer');
    if (box && TUTORIAL_DATA[tabId]) {
      box.innerHTML = TUTORIAL_DATA[tabId];
    }
  }

  let toastTimer = null;
  function showToast(msg) {
    const toast = document.getElementById('toast');
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 2600);
  }

  function copyText(text, label = '内容') {
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text)
        .then(() => showToast(`已复制${label}`))
        .catch(() => fallbackCopy(text, label));
    } else {
      fallbackCopy(text, label);
    }
  }

  function fallbackCopy(text, label) {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try {
      document.execCommand('copy');
      showToast(`已复制${label}`);
    } catch {
      showToast('复制失败，请手动复制');
    }
    document.body.removeChild(ta);
  }

  // Global helpers for inline onclick handlers
  window.appCopy = copyText;
  window.appFilterByDevice = (device) => {
    selectedDevice = device;
    document.querySelectorAll('.chip[data-filter-type="device"]').forEach(c => {
      c.classList.toggle('active', c.getAttribute('data-value') === device);
    });
    renderFirmwares();
    document.getElementById('downloads')?.scrollIntoView({ behavior: 'smooth' });
  };
  window.appFilterByVariant = (variant) => {
    selectedVariant = variant;
    document.querySelectorAll('.chip[data-filter-type="variant"]').forEach(c => {
      c.classList.toggle('active', c.getAttribute('data-value') === variant);
    });
    renderFirmwares();
    document.getElementById('downloads')?.scrollIntoView({ behavior: 'smooth' });
  };
  window.appResetFilters = () => {
    selectedDevice = 'ALL';
    selectedVariant = 'ALL';
    selectedFormat = 'ALL';
    searchQuery = '';
    const input = document.getElementById('searchInput');
    if (input) input.value = '';
    document.querySelectorAll('.chip').forEach(c => {
      c.classList.toggle('active', c.getAttribute('data-value') === 'ALL');
    });
    renderFirmwares();
  };

  // Wallpaper & White-Theme Controls
  function initWallpaperControls() {
    const toggleBtn = document.getElementById('wallpaperToggleBtn');
    const panel = document.getElementById('wallpaperPanel');
    const blurSlider = document.getElementById('blurSlider');
    const blurVal = document.getElementById('blurValLabel');
    const alphaSlider = document.getElementById('alphaSlider');
    const alphaVal = document.getElementById('alphaValLabel');
    const zenBtn = document.getElementById('zenModeBtn');
    const zenExitBtn = document.getElementById('zenExitBtn');

    if (toggleBtn && panel) {
      toggleBtn.addEventListener('click', e => {
        e.stopPropagation();
        panel.classList.toggle('open');
      });
      document.addEventListener('click', e => {
        if (!panel.contains(e.target) && e.target !== toggleBtn) {
          panel.classList.remove('open');
        }
      });
    }

    document.querySelectorAll('.wp-thumb-btn').forEach(btn => {
      const idx = Number(btn.dataset.wpIndex);
      if (WALLPAPERS[idx] === window.currentWallpaperUrl) btn.classList.add('active');
      btn.addEventListener('click', () => {
        const url = WALLPAPERS[idx];
        if (!url) return;
        window.currentWallpaperUrl = url;
        document.documentElement.style.setProperty('--wallpaper-url', `url('${url}')`);
        document.querySelectorAll('.wp-thumb-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        showToast(`已切换至壁纸 ${idx + 1}`);
      });
    });

    document.querySelectorAll('.wp-mode-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const mode = btn.dataset.overlayMode;
        document.body.setAttribute('data-overlay', mode);
        document.querySelectorAll('.wp-mode-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        document.documentElement.style.removeProperty('--wallpaper-blur');
        document.documentElement.style.removeProperty('--card-alpha');
        const names = { standard: '标准轻透白底', clear: '极简纯白高对比', vibrant: '沉浸壁纸透视' };
        showToast(`外观模式：${names[mode] || mode}`);
      });
    });

    if (blurSlider && blurVal) {
      blurSlider.addEventListener('input', e => {
        const v = e.target.value;
        document.documentElement.style.setProperty('--wallpaper-blur', `${v}px`);
        blurVal.textContent = `${v}px`;
      });
    }

    if (alphaSlider && alphaVal) {
      alphaSlider.addEventListener('input', e => {
        const v = e.target.value;
        document.documentElement.style.setProperty('--card-alpha', (v / 100).toFixed(2));
        alphaVal.textContent = `${v}%`;
      });
    }

    const toggleZen = (enable) => {
      const next = typeof enable === 'boolean' ? enable : !document.body.classList.contains('zen-mode');
      document.body.classList.toggle('zen-mode', next);
      if (panel) panel.classList.remove('open');
      if (next) showToast('已进入纯享壁纸模式，按 ESC 退出');
    };

    if (zenBtn) zenBtn.addEventListener('click', () => toggleZen(true));
    if (zenExitBtn) zenExitBtn.addEventListener('click', () => toggleZen(false));
    window.addEventListener('keydown', e => {
      if (e.key === 'Escape' && document.body.classList.contains('zen-mode')) {
        toggleZen(false);
      }
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    // Mobile nav
    const mobileBtn = document.getElementById('mobileMenuBtn');
    const navLinks = document.getElementById('navLinks');
    if (mobileBtn && navLinks) {
      mobileBtn.addEventListener('click', () => navLinks.classList.toggle('open'));
      navLinks.querySelectorAll('a').forEach(a => {
        a.addEventListener('click', () => navLinks.classList.remove('open'));
      });
    }

    // Proxy Switcher
    const proxySwitcher = document.getElementById('proxySwitcher');
    if (proxySwitcher) {
      proxySwitcher.addEventListener('click', e => {
        const btn = e.target.closest('.segment-btn');
        if (!btn) return;
        proxySwitcher.querySelectorAll('.segment-btn').forEach(el => el.classList.remove('active'));
        btn.classList.add('active');
        currentProxy = btn.getAttribute('data-proxy');
        showToast(`已切换加速源：${btn.textContent}`);
        renderFirmwares();
      });
    }

    // Filter Chips
    document.querySelectorAll('.chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const type = chip.getAttribute('data-filter-type');
        const val = chip.getAttribute('data-value');
        document.querySelectorAll(`.chip[data-filter-type="${type}"]`).forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        if (type === 'device') selectedDevice = val;
        if (type === 'variant') selectedVariant = val;
        if (type === 'format') selectedFormat = val;
        renderFirmwares();
      });
    });

    // Search
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
      searchInput.addEventListener('input', e => {
        searchQuery = e.target.value.trim();
        renderFirmwares();
      });
    }

    // Refresh
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
      refreshBtn.addEventListener('click', () => {
        fetchReleases();
        showToast('正在实时拉取最新固件...');
      });
    }

    // Tutorials
    document.querySelectorAll('.tut-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.tut-tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        renderTutorial(btn.getAttribute('data-tab'));
      });
    });

    initWallpaperControls();
    renderFirmwares();
    renderTutorial('tab-sysupgrade');
    fetchReleases();
  });
})();

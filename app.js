/* ════════════════════════════════════════════════════════════════
   xcode · scroll-driven dynamic island browser
   single page · scroll the list · preview follows · tap apply
   ════════════════════════════════════════════════════════════════ */

// ─────────────────────── LIVE CONTEXT (mock data driving widgets)
const ctx = {
  // Metrics modeled after what iOS actually exposes:
  //   cpu / fps     → host_processor_info, CADisplayLink (live)
  //   memory        → mach_task_basic_info (resident/footprint)
  //   battery       → UIDevice.batteryLevel + batteryState
  //   thermal       → ProcessInfo.thermalState (4-step enum)
  //   diskFree      → URLResourceValues volumeAvailableCapacityForImportantUsageKey
  //   pressure/alt  → CMAltimeter
  //   accel/gyro    → CMMotionManager
  //   heading       → CLLocationManager.heading
  //   brightness    → UIScreen.brightness
  //   volume        → AVAudioSession.outputVolume
  //   refreshRate   → UIScreen.maximumFramesPerSecond
  //   uptime        → ProcessInfo.systemUptime
  //   lowPower      → ProcessInfo.isLowPowerModeEnabled
  //   cores         → ProcessInfo.activeProcessorCount / processorCount
  //   network       → NWPathMonitor + CTTelephonyNetworkInfo
  //   steps         → CMPedometer
  metrics: {
    cpu: 42, fps: 58,
    memUsedGB: 1.8, memTotalGB: 6.0,
    battery: 87, batteryState: 'unplugged',     // unplugged | charging | full
    thermal: 'nominal',                          // nominal | fair | serious | critical
    diskFreeGB: 64.2, diskTotalGB: 128.0,

    // sensors
    pressureHpa: 1013.2,                         // CMAltimeter relativeAltitude pairs with this
    altitudeM:   3.5,                            // relative altitude (meters from baseline)
    brightness:  62,                             // 0–100%
    volume:      40,                             // 0–100%
    heading:     127,                            // 0–360°
    steps:       8243,                           // since midnight, pedometer
    accel: { x: 0.02, y: -0.01, z: -0.99 },      // G; resting iPhone face up reads ~ -1g on Z
    gyro:  { x: 0.0,  y: 0.0,   z: 0.0 },        // rad/s
    proximity: false,                            // UIDevice.proximityState

    // device + environment
    cores:        6,                             // ProcessInfo.activeProcessorCount (e.g. A17 Pro)
    coresTotal:   6,                             // ProcessInfo.processorCount
    uptimeS:      4*3600 + 23*60 + 11,           // ProcessInfo.systemUptime (seconds)
    lowPower:     false,
    refreshHz:    120,                           // UIScreen.maximumFramesPerSecond
    network:      'wifi',                        // wifi | cellular | wired | none
    cellTech:     '5G',                          // 5G NR | LTE | 3G | —
    carrier:      'PLDT Mobile',
    deviceModel:  'iPhone 15 Pro',
    iosVersion:   '17.4'
  },
  weather: { temp: 21, glyph: '☀', desc: 'sunny' },
  clock: '9:41',
  date: 'THU 21'
};

// ─────────────────────── DESIGN CATALOG
const DESIGNS = [
  {
    id: 'weather-now',
    name: 'weather now',
    category: 'WEATHER',
    short: c => `<span class="w"><span class="w-weather-glyph">${c.weather.glyph}</span><span class="w-val">${Math.round(c.weather.temp)}°</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px;">
          <span class="w" style="gap:8px"><span class="w-weather-glyph">${c.weather.glyph}</span><span class="w-big">${Math.round(c.weather.temp)}°</span></span>
          <span class="w-sub">SUNNY · CUPERTINO</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a;">
          <span>HI 24°</span><span>LO 16°</span><span>HUM 42%</span><span>WIND 5</span>
        </div>
      </div>`
  },
  {
    id: 'fps-counter',
    name: 'framerate',
    category: 'DEVICE',
    short: c => `<span class="w"><span class="w-lbl">fps</span><span class="w-val">${Math.round(c.metrics.fps)}</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row">
          <span class="w" style="gap:6px"><span class="w-lbl" style="font-size:11px">FPS</span><span class="w-big">${Math.round(c.metrics.fps)}</span></span>
          <span class="w-sub">/ 120 TARGET</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a;">
          <span>FRAME ${(1000/c.metrics.fps).toFixed(1)}MS</span>
          <span class="w-pulse-dot"></span>
          <span>SAMPLING</span>
        </div>
      </div>`
  },
  {
    id: 'cpu-temp',
    name: 'cpu + thermal',
    category: 'DEVICE',
    short: c => `
      <span class="w"><span class="w-lbl">cpu</span><span class="w-val">${Math.round(c.metrics.cpu)}%</span></span>
      <span class="w"><span class="w-lbl">th</span><span class="w-val" style="text-transform:uppercase;font-size:10px">${c.metrics.thermal.slice(0,4)}</span></span>`,
    long: c => `
      <div class="long-grid">
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">CPU</span><span class="w-big">${Math.round(c.metrics.cpu)}<span style="font-size:0.6em;color:#5a5a5a">%</span></span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">THERMAL</span><span class="w-big" style="text-transform:uppercase;font-size:18px">${c.metrics.thermal}</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">MEM</span><span class="w-big">${c.metrics.memUsedGB.toFixed(1)}<span style="font-size:0.5em;color:#5a5a5a">GB</span></span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">FPS</span><span class="w-big">${Math.round(c.metrics.fps)}</span></span>
      </div>`
  },
  {
    id: 'now-playing',
    name: 'now playing',
    category: 'MEDIA',
    short: () => `
      <span class="w-gif">♪</span>
      <span class="w-bars"><span></span><span></span><span></span><span></span><span></span></span>`,
    long: () => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span style="display:flex;align-items:center;gap:10px">
            <span class="w-gif" style="background:linear-gradient(135deg,#666,#bbb,#444);">♪</span>
            <span style="display:flex;flex-direction:column;line-height:1.2">
              <span style="font-size:12px;font-weight:600;color:#fafafa">Sun goes Down</span>
              <span style="font-size:10px;color:#9a9a9a">Lykke Li · Wounded Rhymes</span>
            </span>
          </span>
          <span class="w-bars"><span></span><span></span><span></span><span></span><span></span></span>
        </div>
        <div class="w-progress"></div>
      </div>`
  },
  {
    id: 'recording',
    name: 'recording',
    category: 'MEDIA',
    short: c => `
      <span class="w"><span class="w-pulse-dot"></span><span class="w-val" style="font-size:11px">REC</span></span>
      <span class="w"><span class="w-val">${c.clock}</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-pulse-dot"></span><span class="w-big" style="letter-spacing:0.04em">RECORDING</span></span>
          <span class="w-big">${c.clock}</span>
        </div>
        <div class="long-row">
          <span class="w-sub">SCREEN · 1080P</span>
          <span class="w-bars"><span></span><span></span><span></span><span></span><span></span></span>
        </div>
      </div>`
  },
  {
    id: 'sample-gif',
    name: 'sample gif',
    category: 'FUN',
    short: () => `<span class="w-gif">▶</span><span class="w-val" style="font-size:11px">LOOP</span>`,
    long: () => `
      <div style="display:flex;align-items:center;gap:18px;width:100%;justify-content:center">
        <span class="w-gif">▶</span>
        <span style="display:flex;flex-direction:column;line-height:1.2;gap:2px">
          <span class="w-big" style="font-size:18px">sample.gif</span>
          <span class="w-sub">2.4MB · LOOPING</span>
        </span>
      </div>`
  },
  {
    id: 'big-clock',
    name: 'big clock',
    category: 'TIME',
    short: c => `<span class="w-big">${c.clock}</span>`,
    long: c => `
      <div class="long-stack">
        <span class="w-big" style="font-size:38px">${c.clock}</span>
        <span class="w-sub">${c.date} · ${ctx.weather.glyph} ${Math.round(c.weather.temp)}°</span>
      </div>`
  },
  {
    id: 'download',
    name: 'download progress',
    category: 'DEVICE',
    short: () => `<span class="w-spinner"></span><span class="w-val" style="font-size:11px">64%</span>`,
    long: () => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-spinner"></span><span class="w-big">64%</span></span>
          <span class="w-sub">2.4 MB/S · ETA 12S</span>
        </div>
        <div class="w-progress"></div>
      </div>`
  },
  {
    id: 'live-stream',
    name: 'live stream',
    category: 'MEDIA',
    short: () => `
      <span class="w" style="background:#fafafa;color:#000;padding:2px 8px;border-radius:10px;gap:5px;">
        <span style="width:6px;height:6px;background:#000;border-radius:50%;animation:dotPulse 1.4s ease-in-out infinite"></span>
        <span style="font-size:10px;font-weight:700">LIVE</span>
      </span>
      <span class="w"><span class="w-val">1.2K</span></span>`,
    long: () => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="background:#fafafa;color:#000;padding:3px 12px;border-radius:14px;gap:6px">
            <span style="width:8px;height:8px;background:#000;border-radius:50%;animation:dotPulse 1.4s ease-in-out infinite"></span>
            <span style="font-size:13px;font-weight:700">LIVE</span>
          </span>
          <span class="w-big">1,247</span>
        </div>
        <div class="long-row">
          <span class="w-sub">YOUTUBE · 23M</span>
          <span class="w-sub">PEAK 1,381</span>
        </div>
      </div>`
  },
  {
    id: 'weather-clock',
    name: 'weather + clock',
    category: 'WEATHER',
    short: c => `
      <span class="w"><span class="w-val">${c.clock}</span></span>
      <span class="w"><span class="w-weather-glyph">${c.weather.glyph}</span><span class="w-val">${Math.round(c.weather.temp)}°</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:8px">
          <span class="w-big" style="font-size:24px">${c.clock}</span>
          <span class="w" style="gap:8px"><span class="w-weather-glyph" style="font-size:24px">${c.weather.glyph}</span><span class="w-big">${Math.round(c.weather.temp)}°</span></span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a;letter-spacing:0.04em">
          <span>10 · 21°</span><span>11 · 22°</span><span>12 · 23°</span><span>13 · 24°</span><span>14 · 23°</span>
        </div>
      </div>`
  },
  {
    id: 'battery-watch',
    name: 'battery watch',
    category: 'DEVICE',
    short: c => `
      <span class="w"><span class="w-lbl">⚡</span><span class="w-val">${Math.round(c.metrics.battery)}%</span></span>
      <span class="w-pulse-dot"></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:14px">⚡</span><span class="w-big">${Math.round(c.metrics.battery)}%</span></span>
          <span class="w-sub">CHARGING · 24M LEFT</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>SAFARI 12%</span><span>YOUTUBE 8%</span><span>MAIL 4%</span>
        </div>
      </div>`
  },
  {
    id: 'heart-rate',
    name: 'heart rate',
    category: 'HEALTH',
    short: () => `<span class="w"><span class="w-pulse-dot" style="background:#fafafa"></span><span class="w-val">72</span><span class="w-unit">BPM</span></span>`,
    long: () => `<span class="w"><span class="w-pulse-dot" style="background:#fafafa"></span><span class="w-val">72</span><span class="w-unit">BPM</span></span>`
  },
  {
    id: 'steps',
    name: 'step counter',
    category: 'HEALTH',
    short: () => `<span class="w"><span class="w-lbl">steps</span><span class="w-val">8,243</span></span>`,
    long: () => `<span class="w"><span class="w-lbl">steps</span><span class="w-val">8,243</span></span>`
  },
  {
    id: 'workout',
    name: 'workout timer',
    category: 'HEALTH',
    short: () => `<span class="w"><span class="w-lbl">run</span><span class="w-val">23:14</span></span>`,
    long: () => `<span class="w"><span class="w-lbl">run</span><span class="w-val">23:14</span></span>`
  },
  {
    id: 'minimal-pulse',
    name: 'just a pulse',
    category: 'FUN',
    short: () => `<span class="w-pulse-dot"></span>`,
    long: () => `
      <div class="long-stack" style="gap:10px">
        <span class="w-pulse-dot" style="width:18px;height:18px"></span>
        <span class="w-sub">YOUR PHONE IS OK</span>
      </div>`
  }
];

// ─────────────────────── STATE
const state = {
  focusedId: 'weather-now',   // what's in the preview frame (driven by scroll)
  appliedId: 'weather-now',   // what's actually applied (sticky until tap)
  size: 'short',              // 'short' | 'long'
  filter: 'ALL',              // category filter or 'ALL'
  tab: 'island',              // 'island' | 'performance' | 'settings'
  prefs: {
    animations: true,
    compact: false,
    refreshMs: 1000,
    liveData: true,
    defaultSize: 'short'
  }
};

// rolling 60s history of CPU samples for the performance graph
const cpuHistory = [];
const HISTORY_LEN = 60;

// ─────────────────────── HELPERS
const $ = sel => document.querySelector(sel);
const $$ = sel => document.querySelectorAll(sel);
const designById = id => DESIGNS.find(d => d.id === id);

// ─────────────────────── RENDER
// Build the category list once, in the order they should appear
function getCategories() {
  const order = ['DEVICE', 'MEDIA', 'WEATHER', 'HEALTH', 'TIME', 'FUN'];
  const counts = {};
  DESIGNS.forEach(d => { counts[d.category] = (counts[d.category] || 0) + 1; });
  // Keep declared order, then any new ones at the end
  const declared = order.filter(c => counts[c]);
  const extras = Object.keys(counts).filter(c => !order.includes(c));
  return [...declared, ...extras].map(c => ({ key: c, count: counts[c] }));
}

function getFilteredDesigns() {
  if (state.filter === 'ALL') return DESIGNS;
  return DESIGNS.filter(d => d.category === state.filter);
}

function renderChips() {
  const el = $('#filter-chips');
  const cats = getCategories();
  const items = [
    { key: 'ALL', label: 'ALL', count: DESIGNS.length },
    ...cats.map(c => ({ key: c.key, label: c.key, count: c.count }))
  ];
  el.innerHTML = items.map(it => `
    <button class="chip ${state.filter === it.key ? 'on' : ''}" data-filter="${it.key}">
      ${it.label}<span class="chip-n">${it.count}</span>
    </button>
  `).join('');
  el.querySelectorAll('.chip').forEach(c => {
    c.addEventListener('click', () => setFilter(c.dataset.filter));
  });
}

function renderList() {
  const list = $('#design-list');
  const designs = getFilteredDesigns();
  $('#list-count').textContent = designs.length;

  let html = '';
  if (state.filter === 'ALL') {
    // Group under category headers
    const cats = getCategories();
    cats.forEach(cat => {
      const inCat = DESIGNS.filter(d => d.category === cat.key);
      html += `<div class="list-group-head"><span>— ${cat.key}</span><div class="lg-rule"></div><span class="lg-count">${cat.count}</span></div>`;
      html += inCat.map(d => rowHtml(d)).join('');
    });
  } else {
    html = designs.map(d => rowHtml(d)).join('');
  }
  html += '<div class="list-spacer-bottom"></div>';
  list.innerHTML = html;

  // Tap → focus + scroll into the focal zone
  list.querySelectorAll('.drow').forEach(r => {
    r.addEventListener('click', () => {
      setFocus(r.dataset.id, { scroll: true });
    });
  });

  // If current focus filtered out, snap to first visible
  if (!designs.find(d => d.id === state.focusedId)) {
    if (designs[0]) setFocus(designs[0].id, { scroll: false });
  }
}

function rowHtml(d) {
  return `
    <div class="drow ${d.id === state.focusedId ? 'is-focused' : ''}" data-id="${d.id}">
      <div class="drow-preview">${d.short(ctx)}</div>
      <div class="drow-meta">
        <div class="drow-name">${d.name}${d.id === state.appliedId ? ' <span class="applied-tag">APPLIED</span>' : ''}</div>
        <div class="drow-cat">${d.category}</div>
      </div>
      <div class="drow-arrow">›</div>
    </div>
  `;
}

function renderPreview() {
  const d = designById(state.focusedId);
  if (!d) return;

  // Header
  $('#preview-name').textContent = d.name;
  $('#preview-cat').textContent = d.category;

  // State tag
  const tag = $('#active-state');
  if (d.id === state.appliedId) {
    tag.textContent = 'APPLIED';
    tag.classList.add('is-active');
  } else {
    tag.textContent = 'PREVIEWING';
    tag.classList.remove('is-active');
  }

  // Preview island content (animate in by re-keying)
  const previewEl = $('#preview-island');
  if (state.size === 'long') previewEl.classList.add('long');
  else previewEl.classList.remove('long');
  // LONG = same content as SHORT, just a wider pill (more horizontal breathing room)
  previewEl.innerHTML = d.short(ctx);
  // Trigger pop animation
  previewEl.style.animation = 'none';
  previewEl.offsetHeight; // reflow
  previewEl.style.animation = '';

  // Apply button
  const applyBtn = $('#apply-btn');
  if (d.id === state.appliedId) {
    applyBtn.classList.add('applied');
    applyBtn.textContent = '✓ applied';
  } else {
    applyBtn.classList.remove('applied');
    applyBtn.textContent = 'apply';
  }

  // Size toggle
  $$('.size-toggle button').forEach(b => b.classList.toggle('on', b.dataset.size === state.size));

  // Real island at top of phone always shows the focused design (live preview)
  renderRealIsland();
}

function renderRealIsland() {
  // Top dynamic island removed — preview-only mode.
  const el = $('#island');
  if (!el) return;
  // Defensive: keep behavior if element ever returns
  const d = designById(state.focusedId);
  if (!d) {
    el.classList.remove('long');
    el.style.width = '124px';
    el.innerHTML = '<span class="empty-hint">EMPTY</span>';
    return;
  }
  el.innerHTML = d.short(ctx);
  el.classList.toggle('long', state.size === 'long');
  el.style.width = 'auto';
  requestAnimationFrame(() => {
    const w = el.scrollWidth;
    const min = state.size === 'long' ? 220 : 124;
    const max = state.size === 'long' ? 320 : 240;
    el.style.width = Math.max(min, Math.min(w + 4, max)) + 'px';
  });
}

function updateRowFocus() {
  $$('.drow').forEach(r => {
    r.classList.toggle('is-focused', r.dataset.id === state.focusedId);
  });
  // also refresh applied tag positions if needed
  $$('.drow').forEach(r => {
    const nameEl = r.querySelector('.drow-name');
    const id = r.dataset.id;
    const d = designById(id);
    nameEl.innerHTML = `${d.name}${id === state.appliedId ? ' <span class="applied-tag">APPLIED</span>' : ''}`;
  });
}

// ─────────────────────── SCROLL → FOCUS
// Determine which row is closest to the focal line (top of the visible list area)
let scrollRaf = null;
function onScroll() {
  if (scrollRaf) return;
  scrollRaf = requestAnimationFrame(() => {
    scrollRaf = null;
    const list = $('#design-list');
    const listRect = list.getBoundingClientRect();
    const focal = listRect.top + 30;  // focal line: ~30px from top of list

    let closestRow = null;
    let closestDist = Infinity;

    $$('.drow').forEach(r => {
      const rect = r.getBoundingClientRect();
      const center = rect.top + rect.height / 2;
      const dist = Math.abs(center - focal);
      if (dist < closestDist) {
        closestDist = dist;
        closestRow = r;
      }
    });

    if (closestRow && closestRow.dataset.id !== state.focusedId) {
      setFocus(closestRow.dataset.id, { scroll: false });
    }
  });
}

function setFocus(id, opts = {}) {
  if (state.focusedId === id) return;
  state.focusedId = id;
  updateRowFocus();
  renderPreview();
  if (opts.scroll) {
    const row = document.querySelector(`.drow[data-id="${id}"]`);
    if (row) row.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
}

// ─────────────────────── ACTIONS
function setSize(size) {
  state.size = size;
  renderPreview();
}

function setFilter(filter) {
  if (state.filter === filter) return;
  state.filter = filter;
  renderChips();
  renderList();
}

function applyCurrent() {
  if (state.focusedId === state.appliedId) return;
  state.appliedId = state.focusedId;
  renderPreview();
  updateRowFocus();
  const btn = $('#apply-btn');
  btn.classList.add('flash');
  setTimeout(() => btn.classList.remove('flash'), 600);
}

// ─────────────────────── LIVE TICK (so widgets feel alive)
function tick() {
  if (!state.prefs.liveData) return;
  const m = ctx.metrics;

  // CPU · 0–100%, %-busy across all cores (host_processor_info)
  m.cpu = clamp(m.cpu + jitter(6), 4, 98);
  // FPS · CADisplayLink. iPhones cap at 60 or 120 (ProMotion)
  m.fps = clamp(m.fps + jitter(4), 30, m.refreshHz);
  // Memory footprint · mach_task_basic_info (resident_size + compressed)
  m.memUsedGB = clamp(m.memUsedGB + jitter(0.04), 0.4, m.memTotalGB - 0.2);
  // Battery level (0..100). Charging state changes occasionally.
  m.battery = clamp(m.battery + (m.batteryState === 'charging' ? 0.05 : jitter(0.15)), 5, 100);
  // Thermal state · ProcessInfo. Mostly stays nominal/fair, drift up under load.
  if (Math.random() < 0.02) {
    const states = ['nominal', 'fair', 'serious', 'critical'];
    const cur = states.indexOf(m.thermal);
    const next = clamp(cur + (Math.random() < 0.6 ? -1 : 1), 0, 3);
    m.thermal = states[next];
  }
  // Disk free · slowly drifts down
  m.diskFreeGB = clamp(m.diskFreeGB + jitter(0.02), 1, m.diskTotalGB);

  // ─ Sensors
  m.pressureHpa = clamp(m.pressureHpa + jitter(0.08), 950, 1050);
  m.altitudeM   = clamp(m.altitudeM   + jitter(0.12), -50, 200);
  m.brightness  = clamp(m.brightness  + jitter(1.2),   0, 100);
  m.volume      = clamp(m.volume      + jitter(0.8),   0, 100);
  m.heading     = (m.heading + (Math.random() - 0.5) * 4 + 360) % 360;
  m.steps       = m.steps + (Math.random() < 0.4 ? Math.floor(Math.random() * 3) : 0);

  // accel/gyro: keep base posture (face up ≈ -1g on Z) plus small jitter
  m.accel.x = clamp(0.02 + jitter(0.12), -1.5, 1.5);
  m.accel.y = clamp(-0.01 + jitter(0.12), -1.5, 1.5);
  m.accel.z = clamp(-0.99 + jitter(0.06), -1.5, 1.5);
  m.gyro.x  = clamp(jitter(0.4), -3, 3);
  m.gyro.y  = clamp(jitter(0.4), -3, 3);
  m.gyro.z  = clamp(jitter(0.4), -3, 3);

  // ─ Environment
  m.uptimeS += state.prefs.refreshMs / 1000;
  // Occasionally flip proximity / low power for a sign of life
  if (Math.random() < 0.005) m.proximity = !m.proximity;
  if (m.battery < 20 && !m.lowPower && Math.random() < 0.05) m.lowPower = true;
  if (m.battery > 80 && m.lowPower) m.lowPower = false;

  // push CPU sample for graph
  cpuHistory.push(m.cpu);
  if (cpuHistory.length > HISTORY_LEN) cpuHistory.shift();

  const d = new Date();
  ctx.clock = `${d.getHours()}:${String(d.getMinutes()).padStart(2,'0')}`;

  // Only re-render the active tab's content
  if (state.tab === 'island') {
    renderPreview();
    $$('.drow').forEach(r => {
      const id = r.dataset.id;
      const design = designById(id);
      const previewCell = r.querySelector('.drow-preview');
      if (previewCell && design) {
        previewCell.innerHTML = design.short(ctx);
      }
    });
  } else if (state.tab === 'performance') {
    renderPerformance();
  }
  // Real island still mirrors live data regardless of tab
  renderRealIsland();
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function jitter(span) { return (Math.random() - 0.5) * span; }
// ─────────────────────── TAB SWITCHING
function setTab(tab) {
  if (state.tab === tab) return;
  state.tab = tab;
  $$('.tab-panel').forEach(p => p.classList.toggle('is-active', p.dataset.tab === tab));
  $$('.tabbar .tab').forEach(b => b.classList.toggle('on', b.dataset.tab === tab));

  // First render of a tab when entering
  if (tab === 'performance') renderPerformance();
}

// ─────────────────────── PERFORMANCE TAB
const THERMAL_RANK = { nominal: 1, fair: 2, serious: 3, critical: 4 };

function renderPerformance() {
  const m = ctx.metrics;

  // ─ CPU
  setText('#perf-cpu', Math.round(m.cpu));
  setBar('cpu', m.cpu, 100);

  // ─ Memory · used / total
  setText('#perf-mem', m.memUsedGB.toFixed(1));
  setText('#perf-mem-src', `${m.memUsedGB.toFixed(1)} / ${m.memTotalGB.toFixed(1)} GB`);
  setBar('memory', m.memUsedGB, m.memTotalGB);

  // ─ FPS · target = 120 for ProMotion
  setText('#perf-fps', Math.round(m.fps));
  setBar('fps', m.fps, 120);

  // ─ Thermal · 4-step enum, no °C reading
  setText('#perf-thermal', m.thermal);
  const lit = THERMAL_RANK[m.thermal] || 0;
  $$('.thermal-track .ts').forEach((seg, i) => {
    seg.classList.toggle('lit', i < lit);
  });

  // ─ Battery
  setText('#perf-batt', Math.round(m.battery));
  setText('#perf-batt-state', m.batteryState.toUpperCase());
  setBar('battery', m.battery, 100);

  // ─ Disk · free
  setText('#perf-disk', m.diskFreeGB.toFixed(1));
  setText('#perf-disk-src', `${m.diskFreeGB.toFixed(1)} / ${m.diskTotalGB.toFixed(0)} GB`);
  setBar('disk', m.diskFreeGB, m.diskTotalGB);

  // ─ Cores
  setText('#perf-cores', `${m.cores}/${m.coresTotal}`);
  setBar('cores', m.cores, m.coresTotal);

  // ─ Display & audio
  setText('#perf-fps-target', `/${m.refreshHz}`);
  setText('#perf-bright', Math.round(m.brightness));
  setBar('brightness', m.brightness, 100);
  setText('#perf-vol', Math.round(m.volume));
  setBar('volume', m.volume, 100);

  // ─ Sensors
  setText('#perf-press', m.pressureHpa.toFixed(1));
  setText('#perf-alt',   `${m.altitudeM >= 0 ? '+' : ''}${m.altitudeM.toFixed(1)} m`);

  setText('#perf-head', `${Math.round(m.heading)}°`);
  const needle = $('#compass-needle');
  if (needle) needle.style.transform = `translate(-50%, -100%) rotate(${m.heading}deg)`;

  // accel: each axis bar centers at 50%; scale ±2g range
  fillAxis('#perf-ax', '#perf-ax-bar', m.accel.x, 2);
  fillAxis('#perf-ay', '#perf-ay-bar', m.accel.y, 2);
  fillAxis('#perf-az', '#perf-az-bar', m.accel.z, 2);
  // gyro: ±3 rad/s
  fillAxis('#perf-gx', '#perf-gx-bar', m.gyro.x, 3);
  fillAxis('#perf-gy', '#perf-gy-bar', m.gyro.y, 3);
  fillAxis('#perf-gz', '#perf-gz-bar', m.gyro.z, 3);

  setText('#perf-steps', m.steps.toLocaleString());
  setBar('steps', m.steps, 10000);

  setText('#perf-prox', m.proximity ? 'NEAR' : 'FAR');

  // ─ Network & device info
  setText('#perf-net',     m.network.toUpperCase());
  setText('#perf-cell',    m.cellTech);
  setText('#perf-carrier', m.carrier);
  setText('#perf-refresh', `${m.refreshHz} Hz`);
  setText('#perf-lowpower', m.lowPower ? 'ON' : 'OFF');
  setText('#perf-uptime',  formatUptime(m.uptimeS));
  setText('#perf-device',  m.deviceModel);
  setText('#perf-ios',     m.iosVersion);

  // ─ CPU history graph
  const line = $('#perf-line');
  if (line && cpuHistory.length > 1) {
    const w = 300, h = 80, pad = 4;
    const points = cpuHistory.map((v, i) => {
      const x = (i / (HISTORY_LEN - 1)) * w;
      const y = h - pad - (v / 100) * (h - pad * 2);
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    }).join(' ');
    line.setAttribute('points', points);
  }
  setText('#perf-graph-now', Math.round(m.cpu) + '%');

  // ─ MetricKit-style daily report (synthetic but stable-ish)
  // These map to real MXMetricPayload fields
  const mk = ctx._mk || (ctx._mk = synthMetricKit());
  setText('#mxm-cpu',    `${mk.cpuTimeS} s`);
  setText('#mxm-peak',   `${mk.peakMemMB} MB`);
  setText('#mxm-launch', `${mk.launch95ms} ms`);
  setText('#mxm-hangs',  `${mk.hangS} s`);
  setText('#mxm-disk',   `${mk.diskMB} MB`);
  setText('#mxm-net',    `${mk.cellKB} KB`);
}

function synthMetricKit() {
  // Generated once per session — represents the "last daily diagnostic"
  return {
    cpuTimeS:   (180 + Math.random() * 240).toFixed(0),     // MXCPUMetric.cumulativeCPUTime
    peakMemMB:  (220 + Math.random() * 180).toFixed(0),     // MXMemoryMetric.peakMemoryUsage
    launch95ms: (380 + Math.random() * 220).toFixed(0),     // MXAppLaunchMetric.histogrammedTimeToFirstDraw p95
    hangS:      (1.2 + Math.random() * 3).toFixed(2),       // MXAppResponsivenessMetric.histogrammedAppHangTime
    diskMB:     (12  + Math.random() * 40).toFixed(1),      // MXDiskIOMetric.cumulativeLogicalWrites
    cellKB:     (40  + Math.random() * 220).toFixed(0)      // MXNetworkTransferMetric.cumulativeCellularUpload
  };
}

function setBar(metric, val, max) {
  const card = document.querySelector(`.perf-card[data-metric="${metric}"]`);
  if (!card) return;
  const bar = card.querySelector('.pc-bar > span');
  if (!bar) return;
  const pct = Math.max(0, Math.min(100, (val / max) * 100));
  bar.style.width = pct.toFixed(1) + '%';
}

// Bipolar bar that grows left or right of center based on sign of value (range ± `range`)
function fillAxis(valSel, barSel, val, range) {
  const valEl = document.querySelector(valSel);
  const barEl = document.querySelector(barSel);
  if (valEl) valEl.textContent = (val >= 0 ? '+' : '') + val.toFixed(2);
  if (!barEl) return;
  const pct = Math.max(-1, Math.min(1, val / range)) * 50; // -50%..+50%
  if (pct >= 0) {
    barEl.style.left = '50%';
    barEl.style.width = pct.toFixed(1) + '%';
  } else {
    barEl.style.left = (50 + pct).toFixed(1) + '%';
    barEl.style.width = Math.abs(pct).toFixed(1) + '%';
  }
}

function formatUptime(s) {
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60);
  if (h > 0) return `${h}h ${m}m ${sec}s`;
  if (m > 0) return `${m}m ${sec}s`;
  return `${sec}s`;
}

function setText(sel, val) {
  const el = $(sel);
  if (el) el.textContent = val;
}

// ─────────────────────── SETTINGS
let tickTimer = null;
function startTickTimer() {
  if (tickTimer) clearInterval(tickTimer);
  tickTimer = setInterval(tick, state.prefs.refreshMs);
}

function applyAnimPref() {
  document.body.classList.toggle('no-anim', !state.prefs.animations);
}
function applyCompactPref() {
  document.body.classList.toggle('compact', state.prefs.compact);
}

function wireSettings() {
  // Animations
  $('#set-anim').addEventListener('change', e => {
    state.prefs.animations = e.target.checked;
    applyAnimPref();
  });
  // Compact
  $('#set-compact').addEventListener('change', e => {
    state.prefs.compact = e.target.checked;
    applyCompactPref();
  });
  // Refresh rate
  $('#set-refresh').querySelectorAll('button').forEach(b => {
    b.addEventListener('click', () => {
      state.prefs.refreshMs = parseInt(b.dataset.rate, 10);
      $('#set-refresh').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
      startTickTimer();
    });
  });
  // Live data
  $('#set-live').addEventListener('change', e => {
    state.prefs.liveData = e.target.checked;
  });
  // Default size
  $('#set-default-size').querySelectorAll('button').forEach(b => {
    b.addEventListener('click', () => {
      state.prefs.defaultSize = b.dataset.size;
      $('#set-default-size').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
      setSize(b.dataset.size);
    });
  });
  // Reset applied
  $('#set-reset').addEventListener('click', () => {
    state.appliedId = 'weather-now';
    setFocus('weather-now', { scroll: false });
    renderPreview();
    updateRowFocus();
  });
  // Static "about" count
  setText('#set-design-count', DESIGNS.length);
}

// ─────────────────────── BOOT
function init() {
  // Initial render
  renderChips();
  renderList();
  renderPreview();

  // Scroll listener
  $('#design-list').addEventListener('scroll', onScroll, { passive: true });

  // Apply
  $('#apply-btn').addEventListener('click', applyCurrent);

  // Size toggle
  $$('.size-toggle button').forEach(b => {
    b.addEventListener('click', () => setSize(b.dataset.size));
  });

  // Tab bar
  $$('.tabbar .tab').forEach(b => {
    b.addEventListener('click', () => setTab(b.dataset.tab));
  });

  // Settings
  wireSettings();
  applyAnimPref();
  applyCompactPref();

  // Live data
  startTickTimer();
}

document.addEventListener('DOMContentLoaded', init);

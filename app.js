/* ════════════════════════════════════════════════════════════════
   xcode · scroll-driven dynamic island browser
   single page · scroll the list · preview follows · tap apply
   ════════════════════════════════════════════════════════════════ */

// ─────────────────────── LIVE CONTEXT (mock data driving widgets)
const ctx = {
  metrics: { cpu: 42, fps: 58, temp: 38.5, battery: 87, memory: 3.4 },
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
    name: 'cpu + temp',
    category: 'DEVICE',
    short: c => `
      <span class="w"><span class="w-lbl">cpu</span><span class="w-val">${Math.round(c.metrics.cpu)}%</span></span>
      <span class="w"><span class="w-lbl">°c</span><span class="w-val">${c.metrics.temp.toFixed(1)}</span></span>`,
    long: c => `
      <div class="long-grid">
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">CPU</span><span class="w-big">${Math.round(c.metrics.cpu)}<span style="font-size:0.6em;color:#5a5a5a">%</span></span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">TEMP</span><span class="w-big">${c.metrics.temp.toFixed(1)}<span style="font-size:0.5em;color:#5a5a5a">°C</span></span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">MEM</span><span class="w-big">${c.metrics.memory.toFixed(1)}<span style="font-size:0.5em;color:#5a5a5a">GB</span></span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">PWR</span><span class="w-big">3.2<span style="font-size:0.5em;color:#5a5a5a">W</span></span></span>
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
  filter: 'ALL'               // category filter or 'ALL'
};

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
  const el = $('#island');
  const d = designById(state.focusedId);
  if (!d) {
    el.classList.remove('long');
    el.style.width = '124px';
    el.innerHTML = '<span class="empty-hint">EMPTY</span>';
    return;
  }
  // LONG = same content, just wider
  el.innerHTML = d.short(ctx);
  el.classList.toggle('long', state.size === 'long');
  // Auto-fit width based on content + the short/long padding
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
  const m = ctx.metrics;
  m.cpu     = clamp(m.cpu     + jitter(6),   8, 98);
  m.fps     = clamp(m.fps     + jitter(5),  30, 120);
  m.temp    = clamp(m.temp    + jitter(0.3), 32, 48);
  m.battery = clamp(m.battery + jitter(0.2), 10, 100);
  m.memory  = clamp(m.memory  + jitter(0.12), 2.0, 5.5);

  const d = new Date();
  ctx.clock = `${d.getHours()}:${String(d.getMinutes()).padStart(2,'0')}`;

  renderPreview();
  // Update list previews too (lightweight: just innerHTML the mini preview cells)
  $$('.drow').forEach(r => {
    const id = r.dataset.id;
    const design = designById(id);
    const previewCell = r.querySelector('.drow-preview');
    if (previewCell && design) {
      previewCell.innerHTML = design.short(ctx);
    }
  });
}
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function jitter(span) { return (Math.random() - 0.5) * span; }

// ─────────────────────── CLOCK (status bar)
function updateClock() {
  const d = new Date();
  $('#clock').textContent = `${d.getHours()}:${String(d.getMinutes()).padStart(2,'0')}`;
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

  // Clock
  updateClock();
  setInterval(updateClock, 30 * 1000);

  // Live data
  setInterval(tick, 1000);
}

document.addEventListener('DOMContentLoaded', init);

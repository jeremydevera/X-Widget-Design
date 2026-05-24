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
    chip:         'A17 Pro',                     // hardware-string lookup (no public API)
    ramGB:        8,                             // ProcessInfo.physicalMemory rounded
    displayRes:   '2556 × 1179',                 // UIScreen.nativeBounds * scale
    locale:       'en-US',                       // Locale.current.identifier
    timeZone:     'Asia/Manila',                 // TimeZone.current.identifier
    uptimeS:      4*3600 + 23*60 + 11,           // ProcessInfo.systemUptime (seconds)
    lowPower:     false,
    refreshHz:    120,                           // UIScreen.maximumFramesPerSecond
    network:      'wifi',                        // wifi | cellular | wired | none
    cellTech:     '5G',                          // 5G NR | LTE | 3G | —
    carrier:      'PLDT Mobile',
    deviceModel:  'iPhone 15 Pro',
    iosVersion:   '17.4'
  },
  weather: {
    temp: 21, glyph: '☀', desc: 'sunny',
    uv: 6,                                   // 0-11 (UV index, WeatherKit.uvIndex)
    wind: 12,                                // km/h (WeatherKit.wind.speed)
    precip: 18,                              // % chance next hour
    aqi: 42,                                 // air quality index (public AQI APIs)
    hourly: [21, 22, 23, 24, 23, 22]         // next 6 hours °C
  },
  crypto: {
    btc: { price: 67284, change: 2.4 },     // USD, % 24h
    eth: { price:  3142, change: -0.8 },
    sol: { price:   168, change: 5.2 },
    portfolio: { value: 12483, change: 1.7 }, // USD total, % 24h
    gasGwei: 12,                             // ETH gas in gwei
    fearGreed: 67,                           // 0-100 fear & greed index
    nftFloor: { name: 'BAYC', floor: 18.4, change: -2.1 } // ETH floor + 24h %
  },
  sport: {
    live: { home: 'LAL', homeScore: 87, away: 'BOS', awayScore: 92, period: 'Q4', clock: '2:14' },
    next: { team: 'LAL', opponent: 'GSW', startsIn: 'IN 3H 24M', venue: 'HOME' },
    standing: { team: 'LAL', rank: 4, conference: 'WEST', record: '32-18' },
    f1:   { driver: 'VER', position: 'P1', lap: 47, total: 70, gap: '+2.1S' },
    soccer: { home: 'ARS', homeScore: 2, away: 'CHE', awayScore: 1, minute: 73 },
    tennis: { p1: 'ALC', p2: 'SIN', sets: '2-1', game: '40-30', court: 'CT 1' },
    golf:   { player: 'SCHEFFLER', score: '-12', position: 'T1', hole: 14 },
    mma:    { red: 'PEREIRA', blue: 'ANKALAEV', round: 3, time: '2:14', method: 'LIVE' },
    olympics: { country: 'USA', gold: 32, silver: 28, bronze: 24 }
  },
  health: {
    calories: 412,                            // kcal active today
    distanceKm: 4.7,                          // distance walked today
    sleepHr: 7.2,                             // last night sleep hours
    mindfulMin: 12,                           // mindful minutes today
    o2: 98                                    // SpO2 % from Apple Watch
  },
  time: {
    timerLeft: 14*60 + 23,                    // active timer (s remaining)
    stopwatch: 23*60 + 47,                    // running stopwatch (s)
    pomodoroLeft: 18*60 + 12,                 // pomodoro session (s)
    pomodoroPhase: 'FOCUS',                   // FOCUS | BREAK
    nextEvent: { title: 'Standup', startsIn: 'IN 14M', cal: 'Work' }
  },
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

  // ────────── CRYPTO (CoinGecko / Coinbase public price APIs) ──────────
  {
    id: 'btc-price',
    name: 'bitcoin price',
    category: 'CRYPTO',
    short: c => `
      <span class="w"><span class="w-lbl">btc</span><span class="w-val">$${formatPrice(c.crypto.btc.price)}</span></span>
      <span class="w"><span class="w-val ${c.crypto.btc.change >= 0 ? '' : 'w-down'}" style="font-size:10px">${c.crypto.btc.change >= 0 ? '▲' : '▼'}${Math.abs(c.crypto.btc.change).toFixed(1)}%</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">BTC</span><span class="w-big">$${formatPrice(c.crypto.btc.price)}</span></span>
          <span class="w-sub" style="color:${c.crypto.btc.change >= 0 ? '#fff' : '#888'}">${c.crypto.btc.change >= 0 ? '▲' : '▼'} ${Math.abs(c.crypto.btc.change).toFixed(2)}% 24H</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>HIGH $${formatPrice(c.crypto.btc.price * 1.012)}</span>
          <span>LOW $${formatPrice(c.crypto.btc.price * 0.978)}</span>
          <span>VOL $42B</span>
        </div>
      </div>`
  },
  {
    id: 'eth-price',
    name: 'ethereum price',
    category: 'CRYPTO',
    short: c => `
      <span class="w"><span class="w-lbl">eth</span><span class="w-val">$${formatPrice(c.crypto.eth.price)}</span></span>
      <span class="w"><span class="w-val ${c.crypto.eth.change >= 0 ? '' : 'w-down'}" style="font-size:10px">${c.crypto.eth.change >= 0 ? '▲' : '▼'}${Math.abs(c.crypto.eth.change).toFixed(1)}%</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">ETH</span><span class="w-big">$${formatPrice(c.crypto.eth.price)}</span></span>
          <span class="w-sub" style="color:${c.crypto.eth.change >= 0 ? '#fff' : '#888'}">${c.crypto.eth.change >= 0 ? '▲' : '▼'} ${Math.abs(c.crypto.eth.change).toFixed(2)}% 24H</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>GAS 12 GWEI</span>
          <span>STAKING 3.4%</span>
          <span>TVL $58B</span>
        </div>
      </div>`
  },
  {
    id: 'crypto-trio',
    name: 'top 3 crypto',
    category: 'CRYPTO',
    short: c => `
      <span class="w"><span class="w-lbl">btc</span><span class="w-val" style="font-size:11px">$${formatPriceShort(c.crypto.btc.price)}</span></span>
      <span class="w"><span class="w-lbl">eth</span><span class="w-val" style="font-size:11px">$${formatPriceShort(c.crypto.eth.price)}</span></span>`,
    long: c => `
      <div class="long-grid">
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">BTC</span><span class="w-big">$${formatPriceShort(c.crypto.btc.price)}</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">${c.crypto.btc.change >= 0 ? '▲' : '▼'}</span><span class="w-big" style="font-size:14px;color:${c.crypto.btc.change >= 0 ? '#fff' : '#888'}">${Math.abs(c.crypto.btc.change).toFixed(1)}%</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">ETH</span><span class="w-big">$${formatPriceShort(c.crypto.eth.price)}</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">SOL</span><span class="w-big">$${Math.round(c.crypto.sol.price)}</span></span>
      </div>`
  },
  {
    id: 'crypto-portfolio',
    name: 'portfolio value',
    category: 'CRYPTO',
    short: c => `
      <span class="w"><span class="w-lbl">$</span><span class="w-val">${formatPrice(c.crypto.portfolio.value)}</span></span>
      <span class="w"><span class="w-val ${c.crypto.portfolio.change >= 0 ? '' : 'w-down'}" style="font-size:10px">${c.crypto.portfolio.change >= 0 ? '▲' : '▼'}${Math.abs(c.crypto.portfolio.change).toFixed(1)}%</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w-big" style="font-size:24px">$${formatPrice(c.crypto.portfolio.value)}</span>
          <span class="w-sub" style="color:${c.crypto.portfolio.change >= 0 ? '#fff' : '#888'}">${c.crypto.portfolio.change >= 0 ? '▲' : '▼'} $${Math.abs(c.crypto.portfolio.value * c.crypto.portfolio.change / 100).toFixed(2)}</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>BTC 64%</span><span>ETH 22%</span><span>SOL 9%</span><span>USDC 5%</span>
        </div>
      </div>`
  },

  // ────────── SPORTS (ESPN / league public APIs · per-game push via ActivityKit) ──────────
  {
    id: 'sport-live',
    name: 'live game',
    category: 'SPORTS',
    short: c => `
      <span class="w"><span class="w-lbl" style="font-size:9px">${c.sport.live.home}</span><span class="w-val">${c.sport.live.homeScore}</span></span>
      <span class="w-sub" style="font-size:9px">${c.sport.live.period}</span>
      <span class="w"><span class="w-val">${c.sport.live.awayScore}</span><span class="w-lbl" style="font-size:9px">${c.sport.live.away}</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:13px">${c.sport.live.home}</span><span class="w-big">${c.sport.live.homeScore}</span></span>
          <span class="w-sub">${c.sport.live.period} · ${c.sport.live.clock}</span>
          <span class="w" style="gap:8px"><span class="w-big">${c.sport.live.awayScore}</span><span class="w-lbl" style="font-size:13px">${c.sport.live.away}</span></span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span class="w-pulse-dot" style="width:6px;height:6px"></span>
          <span>NBA · CRYPTO.COM ARENA</span>
          <span>TNT</span>
        </div>
      </div>`
  },
  {
    id: 'sport-next',
    name: 'next game',
    category: 'SPORTS',
    short: c => `
      <span class="w"><span class="w-lbl" style="font-size:9px">${c.sport.next.team}</span><span class="w-val" style="font-size:11px">vs ${c.sport.next.opponent}</span></span>
      <span class="w-sub" style="font-size:9px">${c.sport.next.startsIn}</span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-big">${c.sport.next.team}</span><span class="w-lbl" style="font-size:14px">vs</span><span class="w-big">${c.sport.next.opponent}</span></span>
          <span class="w-sub">${c.sport.next.startsIn}</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>${c.sport.next.venue}</span>
          <span>NBA · TONIGHT</span>
          <span>SET REMINDER</span>
        </div>
      </div>`
  },
  {
    id: 'sport-standing',
    name: 'team standing',
    category: 'SPORTS',
    short: c => `
      <span class="w"><span class="w-lbl">#${c.sport.standing.rank}</span><span class="w-val" style="font-size:11px">${c.sport.standing.team}</span></span>
      <span class="w-sub" style="font-size:9px">${c.sport.standing.record}</span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:14px">#${c.sport.standing.rank}</span><span class="w-big">${c.sport.standing.team}</span></span>
          <span class="w-big" style="font-size:18px">${c.sport.standing.record}</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>${c.sport.standing.conference} · NBA</span>
          <span>WIN STREAK 4</span>
          <span>HOME 18-7</span>
        </div>
      </div>`
  },
  {
    id: 'sport-f1',
    name: 'f1 race',
    category: 'SPORTS',
    short: c => `
      <span class="w"><span class="w-lbl">${c.sport.f1.position}</span><span class="w-val" style="font-size:11px">${c.sport.f1.driver}</span></span>
      <span class="w-sub" style="font-size:9px">L${c.sport.f1.lap}/${c.sport.f1.total}</span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:14px">${c.sport.f1.position}</span><span class="w-big">${c.sport.f1.driver}</span></span>
          <span class="w-big" style="font-size:18px">${c.sport.f1.gap}</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>LAP ${c.sport.f1.lap}/${c.sport.f1.total}</span>
          <span>MONACO GP</span>
          <span class="w-pulse-dot" style="width:6px;height:6px"></span>
        </div>
      </div>`
  },

  // ────────── DEVICE · expanded (host_processor_info / mach / NWPathMonitor) ──────────
  {
    id: 'memory-watch',
    name: 'memory usage',
    category: 'DEVICE',
    short: c => `<span class="w"><span class="w-lbl">mem</span><span class="w-val">${c.metrics.memUsedGB.toFixed(1)}<span class="w-unit">GB</span></span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">MEMORY</span><span class="w-big">${c.metrics.memUsedGB.toFixed(2)}</span><span class="w-unit">GB</span></span>
          <span class="w-sub">/ ${c.metrics.memTotalGB.toFixed(1)} GB · ${Math.round(c.metrics.memUsedGB / c.metrics.memTotalGB * 100)}%</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>FOOTPRINT</span><span>RESIDENT</span><span>COMPRESSED</span>
        </div>
      </div>`
  },
  {
    id: 'storage-free',
    name: 'storage free',
    category: 'DEVICE',
    short: c => `<span class="w"><span class="w-lbl">disk</span><span class="w-val">${c.metrics.diskFreeGB.toFixed(0)}<span class="w-unit">GB</span></span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">FREE</span><span class="w-big">${c.metrics.diskFreeGB.toFixed(1)}</span><span class="w-unit">GB</span></span>
          <span class="w-sub">${Math.round(c.metrics.diskFreeGB / c.metrics.diskTotalGB * 100)}% of ${c.metrics.diskTotalGB} GB</span>
        </div>
        <div class="w-progress"></div>
      </div>`
  },
  {
    id: 'network-speed',
    name: 'network status',
    category: 'DEVICE',
    short: c => `
      <span class="w"><span class="w-pulse-dot"></span><span class="w-val" style="font-size:11px">${c.metrics.network.toUpperCase()}</span></span>
      <span class="w"><span class="w-val">${c.metrics.cellTech}</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-pulse-dot"></span><span class="w-big" style="font-size:18px">${c.metrics.network.toUpperCase()}</span></span>
          <span class="w-big">${c.metrics.cellTech}</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>${c.metrics.carrier}</span><span>↓ 142 MBPS</span><span>↑ 28 MBPS</span>
        </div>
      </div>`
  },
  {
    id: 'brightness-vol',
    name: 'brightness + vol',
    category: 'DEVICE',
    short: c => `
      <span class="w"><span class="w-lbl">☀</span><span class="w-val">${Math.round(c.metrics.brightness)}%</span></span>
      <span class="w"><span class="w-lbl">♪</span><span class="w-val">${Math.round(c.metrics.volume)}%</span></span>`,
    long: c => `
      <div class="long-grid">
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">BRIGHT</span><span class="w-big">${Math.round(c.metrics.brightness)}<span style="font-size:0.5em;color:#5a5a5a">%</span></span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">VOL</span><span class="w-big">${Math.round(c.metrics.volume)}<span style="font-size:0.5em;color:#5a5a5a">%</span></span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">REFRESH</span><span class="w-big">${c.metrics.refreshHz}<span style="font-size:0.5em;color:#5a5a5a">HZ</span></span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">PWR</span><span class="w-big" style="font-size:14px;text-transform:uppercase">${c.metrics.lowPower ? 'LOW' : 'NORMAL'}</span></span>
      </div>`
  },
  {
    id: 'uptime',
    name: 'uptime',
    category: 'DEVICE',
    short: c => {
      const h = Math.floor(c.metrics.uptimeS / 3600);
      const m = Math.floor((c.metrics.uptimeS % 3600) / 60);
      return `<span class="w"><span class="w-lbl">up</span><span class="w-val">${h}h ${m}m</span></span>`;
    },
    long: c => {
      const h = Math.floor(c.metrics.uptimeS / 3600);
      const m = Math.floor((c.metrics.uptimeS % 3600) / 60);
      const s = Math.floor(c.metrics.uptimeS % 60);
      return `
        <div class="long-stack">
          <div class="long-row" style="margin-bottom:6px">
            <span class="w-big" style="font-size:22px">${h}h ${m}m ${s}s</span>
            <span class="w-sub">SINCE LAST REBOOT</span>
          </div>
          <div class="long-row" style="font-size:10px;color:#9a9a9a">
            <span>${c.metrics.deviceModel}</span><span>iOS ${c.metrics.iosVersion}</span><span>${c.metrics.cores} CORES</span>
          </div>
        </div>`;
    }
  },

  // ────────── WEATHER · expanded (WeatherKit + AQI public APIs) ──────────
  {
    id: 'weather-uv',
    name: 'uv index',
    category: 'WEATHER',
    short: c => `<span class="w"><span class="w-lbl">uv</span><span class="w-val">${c.weather.uv}</span></span>`,
    long: c => {
      const lvl = c.weather.uv >= 8 ? 'VERY HIGH' : c.weather.uv >= 6 ? 'HIGH' : c.weather.uv >= 3 ? 'MODERATE' : 'LOW';
      return `
        <div class="long-stack">
          <div class="long-row" style="margin-bottom:6px">
            <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">UV</span><span class="w-big">${c.weather.uv}</span></span>
            <span class="w-sub">${lvl}</span>
          </div>
          <div class="long-row" style="font-size:10px;color:#9a9a9a">
            <span>PROTECT 12-3PM</span><span>SPF 30+</span><span>SUNGLASSES</span>
          </div>
        </div>`;
    }
  },
  {
    id: 'weather-wind',
    name: 'wind speed',
    category: 'WEATHER',
    short: c => `<span class="w"><span class="w-lbl">wind</span><span class="w-val">${c.weather.wind}<span class="w-unit">km/h</span></span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">WIND</span><span class="w-big">${c.weather.wind}</span><span class="w-unit">KM/H</span></span>
          <span class="w-sub">SW · GUSTS 28</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>BEAUFORT 4</span><span>MODERATE BREEZE</span>
        </div>
      </div>`
  },
  {
    id: 'weather-rain',
    name: 'rain chance',
    category: 'WEATHER',
    short: c => `<span class="w"><span class="w-lbl">☂</span><span class="w-val">${c.weather.precip}%</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:14px">☂</span><span class="w-big">${c.weather.precip}%</span></span>
          <span class="w-sub">NEXT HOUR · 0.4MM</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>10AM 12%</span><span>11AM 22%</span><span>12PM 38%</span><span>1PM 18%</span>
        </div>
      </div>`
  },
  {
    id: 'weather-aqi',
    name: 'air quality',
    category: 'WEATHER',
    short: c => `<span class="w"><span class="w-lbl">aqi</span><span class="w-val">${c.weather.aqi}</span></span>`,
    long: c => {
      const lvl = c.weather.aqi <= 50 ? 'GOOD' : c.weather.aqi <= 100 ? 'MODERATE' : c.weather.aqi <= 150 ? 'UNHEALTHY' : 'HAZARDOUS';
      return `
        <div class="long-stack">
          <div class="long-row" style="margin-bottom:6px">
            <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">AQI</span><span class="w-big">${c.weather.aqi}</span></span>
            <span class="w-sub">${lvl}</span>
          </div>
          <div class="long-row" style="font-size:10px;color:#9a9a9a">
            <span>PM2.5 12</span><span>PM10 24</span><span>O3 38</span><span>NO2 18</span>
          </div>
        </div>`;
    }
  },
  {
    id: 'weather-forecast',
    name: 'hourly forecast',
    category: 'WEATHER',
    short: c => `
      <span class="w"><span class="w-weather-glyph">${c.weather.glyph}</span><span class="w-val">${Math.round(c.weather.temp)}°</span></span>
      <span class="w"><span class="w-val" style="font-size:11px">${c.weather.hourly[3]}°</span><span class="w-lbl" style="font-size:9px">+3H</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:8px">
          <span class="w-big" style="font-size:24px">${Math.round(c.weather.temp)}°</span>
          <span class="w-sub">CUPERTINO · FEELS ${Math.round(c.weather.temp - 1)}°</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a;letter-spacing:0.04em">
          ${c.weather.hourly.map((t, i) => `<span>${10 + i} · ${t}°</span>`).join('')}
        </div>
      </div>`
  },

  // ────────── HEALTH · expanded (HealthKit · HKQuantityType) ──────────
  {
    id: 'calories',
    name: 'active calories',
    category: 'HEALTH',
    short: c => `<span class="w"><span class="w-lbl">kcal</span><span class="w-val">${c.health.calories}</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">ACTIVE</span><span class="w-big">${c.health.calories}</span><span class="w-unit">KCAL</span></span>
          <span class="w-sub">/ 600 GOAL · ${Math.round(c.health.calories / 600 * 100)}%</span>
        </div>
        <div class="w-progress"></div>
      </div>`
  },
  {
    id: 'distance',
    name: 'distance today',
    category: 'HEALTH',
    short: c => `<span class="w"><span class="w-lbl">dist</span><span class="w-val">${c.health.distanceKm.toFixed(1)}<span class="w-unit">km</span></span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">WALKED</span><span class="w-big">${c.health.distanceKm.toFixed(2)}</span><span class="w-unit">KM</span></span>
          <span class="w-sub">${(c.health.distanceKm * 0.621).toFixed(1)} MI · TODAY</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>WALK 3.2KM</span><span>RUN 1.5KM</span><span>HIKE 0KM</span>
        </div>
      </div>`
  },
  {
    id: 'sleep',
    name: 'sleep hours',
    category: 'HEALTH',
    short: c => `<span class="w"><span class="w-lbl">zzz</span><span class="w-val">${c.health.sleepHr.toFixed(1)}<span class="w-unit">hr</span></span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">LAST NIGHT</span><span class="w-big">${c.health.sleepHr.toFixed(1)}<span style="font-size:0.5em;color:#5a5a5a">H</span></span></span>
          <span class="w-sub">23:14 → 06:26</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>DEEP 1.4H</span><span>REM 1.8H</span><span>CORE 3.6H</span><span>AWAKE 0.4H</span>
        </div>
      </div>`
  },
  {
    id: 'mindful',
    name: 'mindful minutes',
    category: 'HEALTH',
    short: c => `<span class="w"><span class="w-lbl">om</span><span class="w-val">${c.health.mindfulMin}<span class="w-unit">min</span></span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-pulse-dot" style="background:#fafafa"></span><span class="w-big">${c.health.mindfulMin}</span><span class="w-unit">MIN</span></span>
          <span class="w-sub">/ 15 GOAL · TODAY</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>BREATHE 4M</span><span>MEDITATE 8M</span><span>STREAK 12D</span>
        </div>
      </div>`
  },
  {
    id: 'spo2',
    name: 'blood oxygen',
    category: 'HEALTH',
    short: c => `<span class="w"><span class="w-lbl">spo₂</span><span class="w-val">${c.health.o2}<span class="w-unit">%</span></span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">SPO₂</span><span class="w-big">${c.health.o2}</span><span class="w-unit">%</span></span>
          <span class="w-sub">NORMAL · 4 MIN AGO</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>AVG 24H 97%</span><span>MIN 95%</span><span>MAX 99%</span>
        </div>
      </div>`
  },

  // ────────── TIME · expanded (Foundation Date + Calendar / EventKit) ──────────
  {
    id: 'timer',
    name: 'timer',
    category: 'TIME',
    short: c => {
      const m = Math.floor(c.time.timerLeft / 60);
      const s = c.time.timerLeft % 60;
      return `<span class="w"><span class="w-lbl">⏱</span><span class="w-val">${m}:${String(s).padStart(2,'0')}</span></span>`;
    },
    long: c => {
      const m = Math.floor(c.time.timerLeft / 60);
      const s = c.time.timerLeft % 60;
      return `
        <div class="long-stack">
          <div class="long-row" style="margin-bottom:6px">
            <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:14px">⏱</span><span class="w-big" style="font-size:24px">${m}:${String(s).padStart(2,'0')}</span></span>
            <span class="w-sub">REMAINING · 30M SET</span>
          </div>
          <div class="w-progress"></div>
        </div>`;
    }
  },
  {
    id: 'stopwatch',
    name: 'stopwatch',
    category: 'TIME',
    short: c => {
      const m = Math.floor(c.time.stopwatch / 60);
      const s = c.time.stopwatch % 60;
      return `<span class="w"><span class="w-pulse-dot" style="width:6px;height:6px"></span><span class="w-val">${m}:${String(s).padStart(2,'0')}</span></span>`;
    },
    long: c => {
      const m = Math.floor(c.time.stopwatch / 60);
      const s = c.time.stopwatch % 60;
      return `
        <div class="long-stack">
          <div class="long-row" style="margin-bottom:6px">
            <span class="w" style="gap:8px"><span class="w-pulse-dot"></span><span class="w-big" style="font-size:26px">${m}:${String(s).padStart(2,'0')}</span></span>
            <span class="w-sub">RUNNING</span>
          </div>
          <div class="long-row" style="font-size:10px;color:#9a9a9a">
            <span>LAP 1 · 5:21</span><span>LAP 2 · 6:14</span><span>LAP 3 · 5:48</span>
          </div>
        </div>`;
    }
  },
  {
    id: 'pomodoro',
    name: 'pomodoro',
    category: 'TIME',
    short: c => {
      const m = Math.floor(c.time.pomodoroLeft / 60);
      const s = c.time.pomodoroLeft % 60;
      return `<span class="w"><span class="w-lbl">${c.time.pomodoroPhase === 'FOCUS' ? '◐' : '☕'}</span><span class="w-val">${m}:${String(s).padStart(2,'0')}</span></span>`;
    },
    long: c => {
      const m = Math.floor(c.time.pomodoroLeft / 60);
      const s = c.time.pomodoroLeft % 60;
      return `
        <div class="long-stack">
          <div class="long-row" style="margin-bottom:6px">
            <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:14px">${c.time.pomodoroPhase === 'FOCUS' ? '◐' : '☕'}</span><span class="w-big">${c.time.pomodoroPhase}</span></span>
            <span class="w-big" style="font-size:18px">${m}:${String(s).padStart(2,'0')}</span>
          </div>
          <div class="long-row" style="font-size:10px;color:#9a9a9a">
            <span>SESSION 3/4</span><span>NEXT BREAK 5M</span><span>STREAK 8D</span>
          </div>
        </div>`;
    }
  },
  {
    id: 'next-event',
    name: 'next event',
    category: 'TIME',
    short: c => `
      <span class="w"><span class="w-lbl">▦</span><span class="w-val" style="font-size:11px">${c.time.nextEvent.title}</span></span>
      <span class="w-sub" style="font-size:9px">${c.time.nextEvent.startsIn}</span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:14px">▦</span><span class="w-big">${c.time.nextEvent.title}</span></span>
          <span class="w-sub">${c.time.nextEvent.startsIn}</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>${c.time.nextEvent.cal}</span><span>5 ATTENDEES</span><span>ZOOM</span>
        </div>
      </div>`
  },
  {
    id: 'world-clock',
    name: 'world clocks',
    category: 'TIME',
    short: c => `
      <span class="w"><span class="w-lbl">SF</span><span class="w-val">${c.clock}</span></span>
      <span class="w"><span class="w-lbl">NY</span><span class="w-val">${addHours(c.clock, 3)}</span></span>`,
    long: c => `
      <div class="long-grid">
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">SF</span><span class="w-big">${c.clock}</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">NY</span><span class="w-big">${addHours(c.clock, 3)}</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">LDN</span><span class="w-big">${addHours(c.clock, 8)}</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">TKO</span><span class="w-big">${addHours(c.clock, 17)}</span></span>
      </div>`
  },

  // ────────── CRYPTO · expanded (CoinGecko / Etherscan / OpenSea APIs) ──────────
  {
    id: 'sol-price',
    name: 'solana price',
    category: 'CRYPTO',
    short: c => `
      <span class="w"><span class="w-lbl">sol</span><span class="w-val">$${Math.round(c.crypto.sol.price)}</span></span>
      <span class="w"><span class="w-val ${c.crypto.sol.change >= 0 ? '' : 'w-down'}" style="font-size:10px">${c.crypto.sol.change >= 0 ? '▲' : '▼'}${Math.abs(c.crypto.sol.change).toFixed(1)}%</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">SOL</span><span class="w-big">$${c.crypto.sol.price.toFixed(2)}</span></span>
          <span class="w-sub" style="color:${c.crypto.sol.change >= 0 ? '#fff' : '#888'}">${c.crypto.sol.change >= 0 ? '▲' : '▼'} ${Math.abs(c.crypto.sol.change).toFixed(2)}% 24H</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>HIGH $${(c.crypto.sol.price * 1.04).toFixed(2)}</span>
          <span>LOW $${(c.crypto.sol.price * 0.96).toFixed(2)}</span>
          <span>VOL $2.1B</span>
        </div>
      </div>`
  },
  {
    id: 'gas-fee',
    name: 'eth gas fee',
    category: 'CRYPTO',
    short: c => `<span class="w"><span class="w-lbl">gas</span><span class="w-val">${c.crypto.gasGwei}<span class="w-unit">gwei</span></span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">GAS</span><span class="w-big">${c.crypto.gasGwei}</span><span class="w-unit">GWEI</span></span>
          <span class="w-sub">${c.crypto.gasGwei < 20 ? 'LOW · GOOD TIME' : c.crypto.gasGwei < 50 ? 'MEDIUM' : 'HIGH'}</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>SLOW ${Math.max(1, c.crypto.gasGwei - 4)}</span><span>STD ${c.crypto.gasGwei}</span><span>FAST ${c.crypto.gasGwei + 6}</span><span>BLOCK 19,284,221</span>
        </div>
      </div>`
  },
  {
    id: 'fear-greed',
    name: 'fear & greed',
    category: 'CRYPTO',
    short: c => {
      const lbl = c.crypto.fearGreed >= 75 ? 'EXTREME GREED' : c.crypto.fearGreed >= 55 ? 'GREED' : c.crypto.fearGreed >= 45 ? 'NEUTRAL' : c.crypto.fearGreed >= 25 ? 'FEAR' : 'EXTREME FEAR';
      return `<span class="w"><span class="w-val">${c.crypto.fearGreed}</span><span class="w-lbl" style="font-size:9px">${lbl.split(' ')[0]}</span></span>`;
    },
    long: c => {
      const lbl = c.crypto.fearGreed >= 75 ? 'EXTREME GREED' : c.crypto.fearGreed >= 55 ? 'GREED' : c.crypto.fearGreed >= 45 ? 'NEUTRAL' : c.crypto.fearGreed >= 25 ? 'FEAR' : 'EXTREME FEAR';
      return `
        <div class="long-stack">
          <div class="long-row" style="margin-bottom:6px">
            <span class="w-big" style="font-size:26px">${c.crypto.fearGreed}</span>
            <span class="w-sub">${lbl}</span>
          </div>
          <div class="long-row" style="font-size:10px;color:#9a9a9a">
            <span>YESTERDAY 64</span><span>WEEK AVG 61</span><span>MONTH AVG 58</span>
          </div>
        </div>`;
    }
  },
  {
    id: 'nft-floor',
    name: 'nft floor price',
    category: 'CRYPTO',
    short: c => `
      <span class="w"><span class="w-lbl">${c.crypto.nftFloor.name}</span><span class="w-val">${c.crypto.nftFloor.floor.toFixed(1)}<span class="w-unit">Ξ</span></span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:11px">${c.crypto.nftFloor.name}</span><span class="w-big">${c.crypto.nftFloor.floor.toFixed(2)}</span><span class="w-unit">Ξ</span></span>
          <span class="w-sub" style="color:${c.crypto.nftFloor.change >= 0 ? '#fff' : '#888'}">${c.crypto.nftFloor.change >= 0 ? '▲' : '▼'} ${Math.abs(c.crypto.nftFloor.change).toFixed(1)}% 24H</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>VOL 142Ξ</span><span>SALES 12</span><span>OWNERS 5,438</span>
        </div>
      </div>`
  },
  {
    id: 'crypto-watchlist',
    name: 'watchlist',
    category: 'CRYPTO',
    short: c => `
      <span class="w"><span class="w-lbl">btc</span><span class="w-val ${c.crypto.btc.change >= 0 ? '' : 'w-down'}" style="font-size:10px">${c.crypto.btc.change >= 0 ? '▲' : '▼'}${Math.abs(c.crypto.btc.change).toFixed(1)}</span></span>
      <span class="w"><span class="w-lbl">eth</span><span class="w-val ${c.crypto.eth.change >= 0 ? '' : 'w-down'}" style="font-size:10px">${c.crypto.eth.change >= 0 ? '▲' : '▼'}${Math.abs(c.crypto.eth.change).toFixed(1)}</span></span>`,
    long: c => `
      <div class="long-grid">
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">BTC</span><span class="w-big" style="font-size:14px;color:${c.crypto.btc.change >= 0 ? '#fff' : '#888'}">${c.crypto.btc.change >= 0 ? '▲' : '▼'}${Math.abs(c.crypto.btc.change).toFixed(2)}%</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">ETH</span><span class="w-big" style="font-size:14px;color:${c.crypto.eth.change >= 0 ? '#fff' : '#888'}">${c.crypto.eth.change >= 0 ? '▲' : '▼'}${Math.abs(c.crypto.eth.change).toFixed(2)}%</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">SOL</span><span class="w-big" style="font-size:14px;color:${c.crypto.sol.change >= 0 ? '#fff' : '#888'}">${c.crypto.sol.change >= 0 ? '▲' : '▼'}${Math.abs(c.crypto.sol.change).toFixed(2)}%</span></span>
        <span class="w" style="justify-content:flex-start"><span class="w-lbl">F&G</span><span class="w-big" style="font-size:14px">${c.crypto.fearGreed}</span></span>
      </div>`
  },

  // ────────── SPORTS · expanded (ESPN / public sports APIs) ──────────
  {
    id: 'sport-soccer',
    name: 'soccer match',
    category: 'SPORTS',
    short: c => `
      <span class="w"><span class="w-lbl" style="font-size:9px">${c.sport.soccer.home}</span><span class="w-val">${c.sport.soccer.homeScore}</span></span>
      <span class="w-sub" style="font-size:9px">${c.sport.soccer.minute}'</span>
      <span class="w"><span class="w-val">${c.sport.soccer.awayScore}</span><span class="w-lbl" style="font-size:9px">${c.sport.soccer.away}</span></span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:13px">${c.sport.soccer.home}</span><span class="w-big">${c.sport.soccer.homeScore}</span></span>
          <span class="w-sub">${c.sport.soccer.minute}' · 2ND HALF</span>
          <span class="w" style="gap:8px"><span class="w-big">${c.sport.soccer.awayScore}</span><span class="w-lbl" style="font-size:13px">${c.sport.soccer.away}</span></span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span class="w-pulse-dot" style="width:6px;height:6px"></span>
          <span>EPL · EMIRATES STADIUM</span>
          <span>NBC SPORTS</span>
        </div>
      </div>`
  },
  {
    id: 'sport-tennis',
    name: 'tennis match',
    category: 'SPORTS',
    short: c => `
      <span class="w"><span class="w-lbl">${c.sport.tennis.p1}</span><span class="w-val" style="font-size:11px">${c.sport.tennis.sets}</span></span>
      <span class="w-sub" style="font-size:9px">${c.sport.tennis.game}</span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-big">${c.sport.tennis.p1}</span><span class="w-big" style="font-size:16px;color:#9a9a9a">vs</span><span class="w-big">${c.sport.tennis.p2}</span></span>
          <span class="w-big">${c.sport.tennis.sets}</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>${c.sport.tennis.court}</span>
          <span>GAME ${c.sport.tennis.game}</span>
          <span>SET 4 · 2H 14M</span>
        </div>
      </div>`
  },
  {
    id: 'sport-golf',
    name: 'golf leader',
    category: 'SPORTS',
    short: c => `
      <span class="w"><span class="w-lbl">${c.sport.golf.position}</span><span class="w-val" style="font-size:11px">${c.sport.golf.score}</span></span>
      <span class="w-sub" style="font-size:9px">H${c.sport.golf.hole}</span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:8px"><span class="w-lbl" style="font-size:14px">${c.sport.golf.position}</span><span class="w-big">${c.sport.golf.player}</span></span>
          <span class="w-big" style="font-size:22px">${c.sport.golf.score}</span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span>HOLE ${c.sport.golf.hole}/18</span>
          <span>THE MASTERS</span>
          <span>RD 4</span>
        </div>
      </div>`
  },
  {
    id: 'sport-mma',
    name: 'mma fight',
    category: 'SPORTS',
    short: c => `
      <span class="w"><span class="w-lbl" style="font-size:9px">R${c.sport.mma.round}</span><span class="w-val" style="font-size:11px">${c.sport.mma.time}</span></span>
      <span class="w-sub" style="font-size:9px">${c.sport.mma.method}</span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w" style="gap:6px"><span class="w-big" style="font-size:14px">${c.sport.mma.red}</span><span class="w-big" style="font-size:12px;color:#9a9a9a">vs</span><span class="w-big" style="font-size:14px">${c.sport.mma.blue}</span></span>
        </div>
        <div class="long-row" style="font-size:10px;color:#9a9a9a">
          <span class="w-pulse-dot" style="width:6px;height:6px"></span>
          <span>ROUND ${c.sport.mma.round}/5 · ${c.sport.mma.time}</span>
          <span>UFC 309</span>
        </div>
      </div>`
  },
  {
    id: 'sport-olympics',
    name: 'medal count',
    category: 'SPORTS',
    short: c => `
      <span class="w"><span class="w-lbl">${c.sport.olympics.country}</span><span class="w-val">${c.sport.olympics.gold}</span></span>
      <span class="w-sub" style="font-size:9px">GOLD</span>`,
    long: c => `
      <div class="long-stack">
        <div class="long-row" style="margin-bottom:6px">
          <span class="w-big" style="font-size:18px">${c.sport.olympics.country}</span>
          <span class="w-sub">RANK #1 · OLYMPICS</span>
        </div>
        <div class="long-row" style="font-size:11px;color:#9a9a9a">
          <span>🥇 ${c.sport.olympics.gold}</span>
          <span>🥈 ${c.sport.olympics.silver}</span>
          <span>🥉 ${c.sport.olympics.bronze}</span>
          <span>TOTAL ${c.sport.olympics.gold + c.sport.olympics.silver + c.sport.olympics.bronze}</span>
        </div>
      </div>`
  }
];

// ─────────────────────── STATE
const state = {
  focusedId: 'weather-now',   // what's in the preview frame (driven by scroll)
  appliedId: 'weather-now',   // what's actually applied (sticky until tap)
  size: 'short',              // 'short' | 'long' (set inside detail screen)
  filter: 'ALL',              // category filter, 'ALL', or 'FAV'
  query: '',                  // search query
  favorites: [],              // array of design ids
  edits: {},                  // per-design overrides keyed by design id
  tab: 'dashboard',           // 'dashboard' | 'skills' | 'island' | 'performance' | 'settings'
  perfView: 'chart',          // 'chart' | 'list' (Performance tab display mode)
  chartStyle: 1,              // locked to slim ring (option 1)
  skills: {
    enabled: [],              // array of skill ids that are ON
    config: {},               // per-skill custom config keyed by skill id
    cat: 'ALL'                // 'ALL' or one of SKILL_CATEGORIES
  },
  prefs: {
    compact: false,
    catTags: true,
    reduceMotion: false,
    theme: 'dark',           // dark | midnight | paper
    tempUnit: 'C',           // C | F
    distUnit: 'km',          // km | mi
    timeFmt: '24',           // 12 | 24
    currency: 'USD',         // USD | EUR | GBP | PHP
    weekStart: 'mon',        // mon | sun
    notify: true,
    sounds: false,
    haptics: true,
    quiet: false,
    analytics: false,
    crashes: true,
    icloud: true,
    refreshMs: 1000,         // kept internal — not exposed in settings anymore
    liveData: true           // kept internal — always live
  }
};

// rolling 60s history of CPU samples for the performance graph
const cpuHistory = [];
const HISTORY_LEN = 60;

// ─────────────────────── SKILLS CATALOG
// Each skill is "when X then Y" with a category.
// ico = letter shown in icon block. Icons & rules are descriptive — actual
// platform implementation would map to iOS Shortcuts personal automations,
// HealthKit observers, CMMotionManager, NWPathMonitor, etc.
//
// `params` defines the user-editable trigger fields. Supported kinds:
//   - 'segmented'  options: [{ value, label }]
//   - 'percent'    range: [min,max,step]
//   - 'minutes'    range: [min,max,step]
//   - 'time'       (HH:MM string)
//   - 'text'       (free-form short string)
const SKILLS = [
  // ── BATTERY ─────────────────────────────────────────────────
  { id: 'b-100', cat: 'BATTERY', ico: '⚡',
    name: 'full charge alert',
    when: c => `battery reaches ${c.threshold}%`,
    then: c => `${notifyText(c.notify)} when fully charged`,
    params: [
      { key: 'threshold', kind: 'percent',  label: 'TRIGGER %',     def: 100, range: [80, 100, 5] },
      { key: 'notify',    kind: 'segmented', label: 'NOTIFICATION', def: 'banner',
        options: [{value:'silent',label:'SILENT'},{value:'haptic',label:'HAPTIC'},{value:'banner',label:'BANNER'},{value:'sound',label:'SOUND'}] }
    ]
  },
  { id: 'b-low', cat: 'BATTERY', ico: '⚡',
    name: 'low battery warning',
    when: c => `battery drops below ${c.threshold}%`,
    then: c => `${notifyText(c.notify)} suggesting Low Power Mode`,
    params: [
      { key: 'threshold', kind: 'percent',  label: 'WARN AT',        def: 20, range: [5, 40, 5] },
      { key: 'notify',    kind: 'segmented', label: 'NOTIFICATION',  def: 'banner',
        options: [{value:'silent',label:'SILENT'},{value:'haptic',label:'HAPTIC'},{value:'banner',label:'BANNER'},{value:'sound',label:'SOUND'}] }
    ]
  },
  { id: 'b-80stop', cat: 'BATTERY', ico: '⚡',
    name: 'stop charging at 80%',
    when: c => `battery hits ${c.threshold}% while charging`,
    then: c => `${notifyText(c.notify)} "unplug to extend battery life"`,
    params: [
      { key: 'threshold', kind: 'percent', label: 'STOP AT', def: 80, range: [70, 95, 5] },
      { key: 'notify',    kind: 'segmented', label: 'NOTIFICATION', def: 'banner',
        options: [{value:'silent',label:'SILENT'},{value:'haptic',label:'HAPTIC'},{value:'banner',label:'BANNER'}] }
    ]
  },
  { id: 'b-overnight', cat: 'BATTERY', ico: '⚡',
    name: 'overnight charge alert',
    when: c => `plugged in between ${c.start} and ${c.end}`,
    then: c => `${notifyText(c.notify)} at ${c.cap}% suggesting unplug`,
    params: [
      { key: 'start',  kind: 'time',    label: 'START',         def: '23:00' },
      { key: 'end',    kind: 'time',    label: 'END',           def: '06:30' },
      { key: 'cap',    kind: 'percent', label: 'NOTIFY AT',     def: 80, range: [70, 95, 5] },
      { key: 'notify', kind: 'segmented', label: 'NOTIFICATION', def: 'banner',
        options: [{value:'silent',label:'SILENT'},{value:'haptic',label:'HAPTIC'},{value:'banner',label:'BANNER'}] }
    ]
  },

  // ── CONNECTIVITY ────────────────────────────────────────────
  { id: 'c-home-wifi', cat: 'CONNECTIVITY', ico: '◉',
    name: 'arrive home',
    when: c => `connect to "${c.ssid}" Wi-Fi`,
    then: c => `open ${c.app} + log arrival to Journal`,
    params: [
      { key: 'ssid', kind: 'text', label: 'WI-FI NAME',     def: 'Home' },
      { key: 'app',  kind: 'text', label: 'APP TO OPEN',     def: 'Home' }
    ]
  },
  { id: 'c-cellular', cat: 'CONNECTIVITY', ico: '◉',
    name: 'cellular fallback',
    when: c => `Wi-Fi drops below ${c.speed} Mbps`,
    then: c => `show network status + suggest cellular`,
    params: [
      { key: 'speed', kind: 'segmented', label: 'WI-FI SPEED FLOOR', def: 1,
        options: [{value:0.5,label:'0.5'},{value:1,label:'1'},{value:5,label:'5'},{value:10,label:'10'}] }
    ]
  },
  { id: 'c-airplane', cat: 'CONNECTIVITY', ico: '◉',
    name: 'flight mode reminder',
    when: c => `altitude > ${c.altitude}m and speed > ${c.speed} km/h`,
    then: c => `remind to enable Airplane Mode + start offline downloads`,
    params: [
      { key: 'altitude', kind: 'segmented', label: 'ALTITUDE', def: 1000,
        options: [{value:500,label:'500m'},{value:1000,label:'1000m'},{value:3000,label:'3000m'}] },
      { key: 'speed',    kind: 'segmented', label: 'GROUND SPEED', def: 200,
        options: [{value:150,label:'150'},{value:200,label:'200'},{value:300,label:'300'}] }
    ]
  },
  { id: 'c-bt-car', cat: 'CONNECTIVITY', ico: '◉',
    name: 'enter car',
    when: c => `connect to "${c.device}" Bluetooth`,
    then: c => `open Maps + start "${c.playlist}" playlist`,
    params: [
      { key: 'device',   kind: 'text', label: 'BLUETOOTH NAME', def: 'My Car' },
      { key: 'playlist', kind: 'text', label: 'PLAYLIST',       def: 'Commute' }
    ]
  },

  // ── FOCUS & TIME ────────────────────────────────────────────
  { id: 'f-work', cat: 'FOCUS', ico: '◐',
    name: 'work focus suggestion',
    when: c => `${daysLabel(c.days)} at ${c.start}`,
    then: c => `suggest Work Focus via Shortcut`,
    params: [
      { key: 'start', kind: 'time',      label: 'START', def: '09:00' },
      { key: 'days',  kind: 'segmented', label: 'DAYS',  def: 'weekdays',
        options: [{value:'weekdays',label:'WEEKDAYS'},{value:'weekends',label:'WEEKENDS'},{value:'all',label:'ALL'}] }
    ]
  },
  { id: 'f-sleep', cat: 'FOCUS', ico: '◐',
    name: 'wind down',
    when: c => `time hits ${c.start}`,
    then: c => `suggest Sleep Focus + remind to lower brightness`,
    params: [
      { key: 'start',     kind: 'time',    label: 'TRIGGER', def: '22:30' }
    ]
  },
  { id: 'f-deep', cat: 'FOCUS', ico: '◐',
    name: 'deep work block',
    when: c => `${daysLabel(c.days)} at ${c.start}`,
    then: c => `start ${c.duration}m Pomodoro + suggest DND`,
    params: [
      { key: 'start',    kind: 'time',      label: 'START',         def: '10:00' },
      { key: 'days',     kind: 'segmented', label: 'DAYS',          def: 'weekdays',
        options: [{value:'weekdays',label:'WEEKDAYS'},{value:'weekends',label:'WEEKENDS'},{value:'all',label:'ALL'}] },
      { key: 'duration', kind: 'minutes',   label: 'POMODORO LENGTH', def: 25, range: [15, 60, 5] }
    ]
  },
  { id: 'f-weekend', cat: 'FOCUS', ico: '◐',
    name: 'weekend mode',
    when: c => `Saturday or Sunday at ${c.start}`,
    then: c => `suggest Personal Focus via Shortcut`,
    params: [
      { key: 'start', kind: 'time', label: 'TRIGGER', def: '08:00' }
    ]
  },

  // ── HEALTH & ACTIVITY ───────────────────────────────────────
  { id: 'h-stand', cat: 'HEALTH', ico: '♥',
    name: 'stand reminder',
    when: c => `no motion for ${c.minutes} minutes during work hours`,
    then: c => `${notifyText(c.notify)} "stand for 2 minutes"`,
    params: [
      { key: 'minutes', kind: 'segmented', label: 'IDLE MINUTES', def: 50,
        options: [{value:30,label:'30'},{value:45,label:'45'},{value:50,label:'50'},{value:60,label:'60'}] },
      { key: 'notify',  kind: 'segmented', label: 'NOTIFICATION', def: 'haptic',
        options: [{value:'silent',label:'SILENT'},{value:'haptic',label:'HAPTIC'},{value:'banner',label:'BANNER'}] }
    ]
  },
  { id: 'h-steps', cat: 'HEALTH', ico: '♥',
    name: 'daily step goal',
    when: c => `steps exceed ${c.goal.toLocaleString()}`,
    then: c => `play celebration sound + log to Journal`,
    params: [
      { key: 'goal', kind: 'segmented', label: 'STEP GOAL', def: 10000,
        options: [{value:5000,label:'5K'},{value:8000,label:'8K'},{value:10000,label:'10K'},{value:15000,label:'15K'},{value:20000,label:'20K'}] }
    ]
  },
  { id: 'h-water', cat: 'HEALTH', ico: '♥',
    name: 'hydrate',
    when: c => `every ${c.interval} minutes between ${c.start} and ${c.end}`,
    then: c => `subtle haptic + "drink water" reminder`,
    params: [
      { key: 'interval', kind: 'segmented', label: 'INTERVAL', def: 90,
        options: [{value:30,label:'30M'},{value:60,label:'1H'},{value:90,label:'1H 30M'},{value:120,label:'2H'}] },
      { key: 'start', kind: 'time', label: 'WINDOW START', def: '09:00' },
      { key: 'end',   kind: 'time', label: 'WINDOW END',   def: '18:00' }
    ]
  },
  { id: 'h-walk', cat: 'HEALTH', ico: '♥',
    name: 'workout detected',
    when: c => `walking pace sustained > ${c.minutes} minutes`,
    then: c => `auto-start outdoor walk workout`,
    params: [
      { key: 'minutes', kind: 'segmented', label: 'AFTER MINUTES', def: 10,
        options: [{value:5,label:'5'},{value:10,label:'10'},{value:15,label:'15'},{value:20,label:'20'}] }
    ]
  },

  // ── PERFORMANCE ─────────────────────────────────────────────
  { id: 'p-thermal', cat: 'PERFORMANCE', ico: '▣',
    name: 'thermal warning',
    when: c => `thermal state reaches "${c.level}"`,
    then: c => `show banner + suggest closing background apps`,
    params: [
      { key: 'level', kind: 'segmented', label: 'THERMAL LEVEL', def: 'serious',
        options: [{value:'fair',label:'FAIR'},{value:'serious',label:'SERIOUS'},{value:'critical',label:'CRITICAL'}] }
    ]
  },
  { id: 'p-storage', cat: 'PERFORMANCE', ico: '▣',
    name: 'storage cleanup',
    when: c => `free storage falls below ${c.gb}GB`,
    then: c => `open photo duplicate scanner`,
    params: [
      { key: 'gb', kind: 'segmented', label: 'GB FREE', def: 5,
        options: [{value:2,label:'2'},{value:5,label:'5'},{value:10,label:'10'},{value:20,label:'20'}] }
    ]
  },
  { id: 'p-memory', cat: 'PERFORMANCE', ico: '▣',
    name: 'memory pressure',
    when: c => `this app's memory above ${c.gb}GB for ${c.minutes} minutes`,
    then: c => `clear caches + log diagnostic`,
    params: [
      { key: 'gb',      kind: 'segmented', label: 'MEMORY GB', def: 4,
        options: [{value:2,label:'2'},{value:3,label:'3'},{value:4,label:'4'},{value:5,label:'5'}] },
      { key: 'minutes', kind: 'segmented', label: 'FOR (MIN)', def: 2,
        options: [{value:1,label:'1'},{value:2,label:'2'},{value:5,label:'5'}] }
    ]
  },
  { id: 'p-launch', cat: 'PERFORMANCE', ico: '▣',
    name: 'app launch slow',
    when: c => `launch time exceeds ${c.ms}ms`,
    then: c => `capture diagnostic + log to MetricKit report`,
    params: [
      { key: 'ms', kind: 'segmented', label: 'THRESHOLD MS', def: 1500,
        options: [{value:1000,label:'1000'},{value:1500,label:'1500'},{value:2000,label:'2000'},{value:3000,label:'3000'}] }
    ]
  }
];

// Helpers used by skill `when`/`then` formatters
function notifyText(n) {
  switch (n) {
    case 'silent': return 'silent log';
    case 'haptic': return 'haptic tap';
    case 'banner': return 'banner';
    case 'sound':  return 'banner + chime';
    default:       return 'banner';
  }
}
function daysLabel(d) {
  switch (d) {
    case 'weekdays': return 'weekday';
    case 'weekends': return 'weekend';
    case 'all':      return 'every day';
    default:         return d || 'every day';
  }
}

// Resolve a skill's current config: defaults merged with saved overrides
function skillConfigFor(skillId) {
  const skill = SKILLS.find(s => s.id === skillId);
  if (!skill) return {};
  const defaults = {};
  (skill.params || []).forEach(p => { defaults[p.key] = p.def; });
  return { ...defaults, ...(state.skills.config[skillId] || {}) };
}

function patchSkillConfig(skillId, patch) {
  const cur = state.skills.config[skillId] || {};
  state.skills.config[skillId] = { ...cur, ...patch };
  saveState();
}

function resetSkillConfig(skillId) {
  delete state.skills.config[skillId];
  saveState();
}

function isSkillOn(skillId) {
  return state.skills.enabled.includes(skillId);
}

function setSkillEnabled(skillId, on) {
  const list = state.skills.enabled;
  const idx = list.indexOf(skillId);
  if (on && idx < 0) list.push(skillId);
  if (!on && idx >= 0) list.splice(idx, 1);
  saveState();
}

const SKILL_CATEGORIES = ['BATTERY', 'CONNECTIVITY', 'FOCUS', 'HEALTH', 'PERFORMANCE'];

// ─────────────────────── DASHBOARD DATA (7d trends · all measurable)
const dash = {
  // today
  stepsKm:      6.1,
  cpuPeak1h:    78,
  thermalPeak:  'fair',

  // 7-day trends (oldest first; last is "now")
  // All four come from real iOS sources:
  //   trendCpu     · sampled host_processor_info, peak per day (your app must run to record)
  //   trendMem     · MetricKit MXMemoryMetric.peakMemoryUsage (MB) — daily payload
  //   trendStorage · URLResourceValues.volumeAvailableCapacityForImportantUsage (sampled)
  //   trendLaunch  · MetricKit MXAppLaunchMetric (ms p95) — daily payload
  trendCpu:     [62, 71, 58, 80, 74, 69, 78],
  trendMem:     [218, 234, 226, 242, 248, 261, 254],
  trendStorage: [70.3, 69.8, 68.2, 66.9, 65.7, 64.6, 64.2],
  trendLaunch:  [410, 405, 398, 392, 388, 382, 378]
};

// ─────────────────────── PERSISTENCE
const STORAGE_KEY = 'xwd:v1';
function saveState() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      appliedId: state.appliedId,
      size: state.size,
      filter: state.filter,
      favorites: state.favorites,
      edits: state.edits,
      tab: state.tab,
      perfView: state.perfView,
      chartStyle: state.chartStyle,
      prefs: state.prefs,
      skills: state.skills
    }));
  } catch (e) { /* storage full or disabled */ }
}
function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    const saved = JSON.parse(raw);
    if (saved.appliedId && designById(saved.appliedId)) {
      state.appliedId = saved.appliedId;
      state.focusedId = saved.appliedId;
    }
    if (saved.size) state.size = saved.size;
    if (saved.filter) state.filter = saved.filter;
    if (Array.isArray(saved.favorites)) state.favorites = saved.favorites;
    if (saved.edits && typeof saved.edits === 'object') state.edits = saved.edits;
    if (saved.tab) state.tab = saved.tab;
    if (saved.perfView) state.perfView = saved.perfView;
    if (saved.chartStyle) state.chartStyle = saved.chartStyle;
    if (saved.prefs) Object.assign(state.prefs, saved.prefs);
    if (saved.skills) {
      if (Array.isArray(saved.skills.enabled)) state.skills.enabled = saved.skills.enabled;
      if (saved.skills.config && typeof saved.skills.config === 'object') state.skills.config = saved.skills.config;
      if (saved.skills.cat) state.skills.cat = saved.skills.cat;
    }
  } catch (e) { /* ignore corrupt save */ }
}

// ─────────────────────── PER-DESIGN EDITS
const COLOR_PALETTE = [
  { key: 'mono',   label: 'Mono',   css: '#fafafa' },
  { key: 'green',  label: 'Green',  css: '#34d399' },
  { key: 'orange', label: 'Orange', css: '#fb923c' },
  { key: 'blue',   label: 'Blue',   css: '#60a5fa' },
  { key: 'pink',   label: 'Pink',   css: '#f472b6' },
  { key: 'yellow', label: 'Yellow', css: '#facc15' }
];
const DEFAULT_EDIT = {
  refreshMs: 1000,
  color: 'mono',
  bold: true
};
// Per-category default refresh recommendations (what feels right for each data source)
const DEFAULT_REFRESH_BY_CAT = {
  CRYPTO:  15000,   // 15s — typical free price API rate limit
  SPORTS:   5000,   // 5s — live games update fast
  WEATHER: 60000,   // 1m — weather barely changes faster
  HEALTH:  60000,   // 1m — HealthKit observers fire on change anyway
  DEVICE:   1000,   // 1s — local sensor data
  TIME:     1000    // 1s — clock
};

function editFor(designId) {
  const d = designById(designId);
  const base = { ...DEFAULT_EDIT };
  if (d && DEFAULT_REFRESH_BY_CAT[d.category]) {
    base.refreshMs = DEFAULT_REFRESH_BY_CAT[d.category];
  }
  return { ...base, ...(state.edits[designId] || {}) };
}

// Apply the design's edit options as classes on a rendered widget element
function applyEditClasses(el, designId) {
  if (!el) return;
  const e = editFor(designId);
  // Strip any existing accent/extra classes
  el.classList.remove(
    'accent-mono', 'accent-green', 'accent-orange', 'accent-blue', 'accent-pink', 'accent-yellow',
    'is-bold', 'has-pulse'
  );
  el.classList.add(`accent-${e.color}`);
  if (e.bold) el.classList.add('is-bold');
}

function colorCssFor(key) {
  const c = COLOR_PALETTE.find(p => p.key === key);
  return c ? c.css : '#fafafa';
}

// ─────────────────────── HELPERS
const $ = sel => document.querySelector(sel);
const $$ = sel => document.querySelectorAll(sel);
const designById = id => DESIGNS.find(d => d.id === id);

// ─────────────────────── RENDER
// Build the category list once, in the order they should appear
function getCategories() {
  const order = ['DEVICE', 'CRYPTO', 'SPORTS', 'WEATHER', 'HEALTH', 'TIME'];
  const counts = {};
  DESIGNS.forEach(d => { counts[d.category] = (counts[d.category] || 0) + 1; });
  // Keep declared order, then any new ones at the end
  const declared = order.filter(c => counts[c]);
  const extras = Object.keys(counts).filter(c => !order.includes(c));
  return [...declared, ...extras].map(c => ({ key: c, count: counts[c] }));
}

function getFilteredDesigns() {
  let pool = DESIGNS;
  // Category / favorites filter
  if (state.filter === 'FAV') {
    pool = pool.filter(d => state.favorites.includes(d.id));
  } else if (state.filter !== 'ALL') {
    pool = pool.filter(d => d.category === state.filter);
  }
  // Search
  const q = state.query.trim().toLowerCase();
  if (q) {
    pool = pool.filter(d =>
      d.name.toLowerCase().includes(q) ||
      d.category.toLowerCase().includes(q)
    );
  }
  return pool;
}

function renderChips() {
  const el = $('#filter-chips');
  const cats = getCategories();
  const items = [
    { key: 'ALL', label: 'ALL', count: DESIGNS.length },
    { key: 'FAV', label: '★ FAVORITES', count: state.favorites.length, isFav: true },
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
  // When searching or filtering by category/favorites, show a flat list.
  // Only group when nothing's filtered.
  const grouped = state.filter === 'ALL' && !state.query.trim();

  if (designs.length === 0) {
    html = `<div class="list-empty">no designs match${state.query ? ` "${escapeHtml(state.query)}"` : ''}</div>`;
  } else if (grouped) {
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

  // Tap → open detail screen
  list.querySelectorAll('.drow').forEach(r => {
    r.addEventListener('click', () => openDetail(r.dataset.id));
  });
}

function rowHtml(d) {
  const e = editFor(d.id);
  const editClasses = `accent-${e.color}${e.bold ? ' is-bold' : ''}`;
  const isApplied = d.id === state.appliedId;
  return `
    <div class="drow ${isApplied ? 'is-applied' : ''}" data-id="${d.id}">
      <div class="drow-preview ${editClasses}">${d.short(ctx)}</div>
      <div class="drow-meta">
        <div class="drow-name">${d.name}${isApplied ? ' <span class="applied-tag">APPLIED</span>' : ''}</div>
        <div class="drow-cat">${d.category}</div>
      </div>
      <div class="drow-arrow">
        <svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3l5 5-5 5"/></svg>
      </div>
    </div>
  `;
}

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[c]));
}

function renderPreview() {
  const d = designById(state.focusedId);
  if (!d) return;

  // Header (kept for backward compatibility — elements may not exist)
  setText('#preview-name', d.name);
  setText('#preview-cat', d.category);

  // State tag (only if present)
  const tag = $('#active-state');
  if (tag) {
    if (d.id === state.appliedId) {
      tag.textContent = 'APPLIED';
      tag.classList.add('is-active');
    } else {
      tag.textContent = 'PREVIEWING';
      tag.classList.remove('is-active');
    }
  }

  // Preview island content
  const previewEl = $('#preview-island');
  previewEl.classList.toggle('long', state.size === 'long');
  previewEl.innerHTML = d.short(ctx);
  applyEditClasses(previewEl, d.id);

  // Only trigger the entrance animation when the *design* changes,
  // not on every live-data tick. Otherwise the pill blinks every refresh.
  if (renderPreview._lastId !== d.id || renderPreview._lastSize !== state.size) {
    previewEl.style.animation = 'none';
    previewEl.offsetHeight; // reflow
    previewEl.style.animation = '';
    renderPreview._lastId = d.id;
    renderPreview._lastSize = state.size;
  }

  // Apply button
  const applyBtn = $('#apply-btn');
  if (applyBtn) {
    if (d.id === state.appliedId) {
      applyBtn.classList.add('applied');
      applyBtn.textContent = '✓ applied';
    } else {
      applyBtn.classList.remove('applied');
      applyBtn.textContent = 'apply';
    }
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
  // The list no longer reflects "focused"; rows show "is-applied" instead.
  $$('.drow').forEach(r => {
    const id = r.dataset.id;
    const d = designById(id);
    const nameEl = r.querySelector('.drow-name');
    const isApplied = id === state.appliedId;
    r.classList.toggle('is-applied', isApplied);
    if (nameEl && d) {
      nameEl.innerHTML = `${d.name}${isApplied ? ' <span class="applied-tag">APPLIED</span>' : ''}`;
    }
  });
}

function setFocus(id, opts = {}) {
  if (state.focusedId === id) return;
  state.focusedId = id;
  renderPreview();
}

// ─────────────────────── ACTIONS
function setSize(size) {
  state.size = size;
  renderPreview();
  saveState();
}

function setFilter(filter) {
  if (state.filter === filter) return;
  state.filter = filter;
  renderChips();
  renderList();
  saveState();
}

function setQuery(q) {
  state.query = q;
  $('.search-bar').classList.toggle('has-text', q.length > 0);
  renderList();
}

function toggleFavorite(id) {
  const i = state.favorites.indexOf(id);
  if (i >= 0) state.favorites.splice(i, 1);
  else state.favorites.push(id);
  // If we're on the FAV tab and we just unfavorited, may need re-render
  renderChips();
  renderList();
  saveState();
}

function applyCurrent() {
  if (state.focusedId === state.appliedId) return;
  state.appliedId = state.focusedId;
  renderPreview();
  updateRowFocus();
  const btn = $('#apply-btn');
  btn.classList.add('flash');
  setTimeout(() => btn.classList.remove('flash'), 600);
  saveState();
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

  // ─ Crypto · slow random walk (markets are always nudging)
  ctx.crypto.btc.price = clamp(ctx.crypto.btc.price + jitter(ctx.crypto.btc.price * 0.0015), 1000, 200000);
  ctx.crypto.eth.price = clamp(ctx.crypto.eth.price + jitter(ctx.crypto.eth.price * 0.0018), 100, 10000);
  ctx.crypto.sol.price = clamp(ctx.crypto.sol.price + jitter(ctx.crypto.sol.price * 0.0025), 5, 1000);
  ctx.crypto.btc.change += jitter(0.04);
  ctx.crypto.eth.change += jitter(0.04);
  ctx.crypto.sol.change += jitter(0.06);
  ctx.crypto.btc.change = clamp(ctx.crypto.btc.change, -10, 10);
  ctx.crypto.eth.change = clamp(ctx.crypto.eth.change, -10, 10);
  ctx.crypto.sol.change = clamp(ctx.crypto.sol.change, -15, 15);
  // Portfolio tracks BTC weight roughly
  ctx.crypto.portfolio.value = clamp(ctx.crypto.portfolio.value + jitter(20), 1000, 1000000);
  ctx.crypto.portfolio.change = clamp(ctx.crypto.portfolio.change + jitter(0.05), -8, 8);

  // ─ Sports · occasional score change + clock tick (NBA-style Q4 winding down)
  if (Math.random() < 0.06) {
    const which = Math.random() < 0.5 ? 'homeScore' : 'awayScore';
    ctx.sport.live[which] += [1, 2, 3][Math.floor(Math.random() * 3)];
  }
  // F1 lap progression
  if (Math.random() < 0.02 && ctx.sport.f1.lap < ctx.sport.f1.total) {
    ctx.sport.f1.lap += 1;
  }
  // Soccer minute tick
  if (Math.random() < 0.04 && ctx.sport.soccer.minute < 90) {
    ctx.sport.soccer.minute += 1;
  }
  if (Math.random() < 0.01) {
    const which = Math.random() < 0.5 ? 'homeScore' : 'awayScore';
    ctx.sport.soccer[which] += 1;
  }
  // MMA round time counts down
  let [mmaMin, mmaSec] = ctx.sport.mma.time.split(':').map(n => parseInt(n, 10));
  if (mmaSec > 0) mmaSec--; else if (mmaMin > 0) { mmaMin--; mmaSec = 59; }
  ctx.sport.mma.time = `${mmaMin}:${String(mmaSec).padStart(2, '0')}`;

  // ─ Time · countdowns
  if (ctx.time.timerLeft > 0) ctx.time.timerLeft -= 1;
  ctx.time.stopwatch += 1;
  if (ctx.time.pomodoroLeft > 0) ctx.time.pomodoroLeft -= 1;
  else {
    // flip phase
    ctx.time.pomodoroPhase = ctx.time.pomodoroPhase === 'FOCUS' ? 'BREAK' : 'FOCUS';
    ctx.time.pomodoroLeft = ctx.time.pomodoroPhase === 'FOCUS' ? 25 * 60 : 5 * 60;
  }

  // ─ Crypto extras
  ctx.crypto.gasGwei = clamp(ctx.crypto.gasGwei + jitter(0.5), 5, 200);
  ctx.crypto.fearGreed = Math.round(clamp(ctx.crypto.fearGreed + jitter(0.6), 0, 100));
  ctx.crypto.nftFloor.floor = clamp(ctx.crypto.nftFloor.floor + jitter(0.05), 0.5, 200);
  ctx.crypto.nftFloor.change = clamp(ctx.crypto.nftFloor.change + jitter(0.04), -10, 10);

  // ─ Health drift
  ctx.health.calories  += Math.random() < 0.3 ? 1 : 0;
  ctx.health.distanceKm = clamp(ctx.health.distanceKm + (Math.random() < 0.2 ? 0.01 : 0), 0, 50);
  ctx.health.mindfulMin = clamp(ctx.health.mindfulMin + (Math.random() < 0.005 ? 1 : 0), 0, 60);
  ctx.health.o2 = clamp(Math.round(ctx.health.o2 + jitter(0.4)), 90, 100);

  // ─ Weather drift
  ctx.weather.uv     = clamp(Math.round(ctx.weather.uv + jitter(0.2)), 0, 11);
  ctx.weather.wind   = clamp(Math.round(ctx.weather.wind + jitter(0.4)), 0, 80);
  ctx.weather.precip = clamp(Math.round(ctx.weather.precip + jitter(1.5)), 0, 100);
  ctx.weather.aqi    = clamp(Math.round(ctx.weather.aqi + jitter(0.8)), 0, 300);

  // push CPU sample for graph
  cpuHistory.push(m.cpu);
  if (cpuHistory.length > HISTORY_LEN) cpuHistory.shift();

  const d = new Date();
  ctx.clock = `${d.getHours()}:${String(d.getMinutes()).padStart(2,'0')}`;

  // Only re-render the active tab's content
  if (state.tab === 'island') {
    // If detail screen is open, refresh the preview pill
    if ($('#detail-screen').classList.contains('is-open')) {
      renderPreview();
    }
    // Always refresh the mini previews in row cells
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
  } else if (state.tab === 'dashboard') {
    renderDashboard();
  }
  // Real island still mirrors live data regardless of tab
  renderRealIsland();
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function jitter(span) { return (Math.random() - 0.5) * span; }

// Format a USD price like 67,284 (no decimals over $100, two decimals under)
function formatPrice(v) {
  if (v >= 100) return Math.round(v).toLocaleString();
  return v.toFixed(2);
}
// Compact form: 67.3K, 3.14K, 168
function formatPriceShort(v) {
  if (v >= 1000) return (v / 1000).toFixed(1) + 'K';
  return Math.round(v).toString();
}

// Add hours to a "H:MM" clock string, modulo 24
function addHours(clock, hrs) {
  const [h, m] = clock.split(':').map(n => parseInt(n, 10));
  const newH = (h + hrs + 24) % 24;
  return `${newH}:${String(m).padStart(2, '0')}`;
}
// ─────────────────────── TAB SWITCHING
function setTab(tab) {
  if (state.tab === tab) return;
  state.tab = tab;
  $$('.tab-panel').forEach(p => p.classList.toggle('is-active', p.dataset.tab === tab));
  $$('.tabbar .tab').forEach(b => b.classList.toggle('on', b.dataset.tab === tab));

  // First render of a tab when entering
  if (tab === 'performance') renderPerformance();
  if (tab === 'dashboard')   renderDashboard();
  if (tab === 'skills')      renderSkills();
  saveState();
}

// ─────────────────────── SKILLS
function renderSkills() {
  // Counts per category
  const counts = { ALL: SKILLS.length };
  SKILL_CATEGORIES.forEach(c => {
    counts[c] = SKILLS.filter(s => s.cat === c).length;
  });

  // Category pills
  const catRow = $('#skills-cat-row');
  if (catRow) {
    const items = [{ key: 'ALL', label: 'ALL' }, ...SKILL_CATEGORIES.map(c => ({ key: c, label: c }))];
    catRow.innerHTML = items.map(it => `
      <button class="skills-cat ${state.skills.cat === it.key ? 'on' : ''}" data-cat="${it.key}">
        ${it.label}<span class="skills-cat-n">${counts[it.key]}</span>
      </button>
    `).join('');
    catRow.querySelectorAll('.skills-cat').forEach(b => {
      b.addEventListener('click', () => {
        state.skills.cat = b.dataset.cat;
        renderSkills();
        saveState();
      });
    });
  }

  // List
  const listEl = $('#skills-list');
  if (!listEl) return;

  const filter = state.skills.cat;
  let html = '';

  if (filter === 'ALL') {
    SKILL_CATEGORIES.forEach(cat => {
      const inCat = SKILLS.filter(s => s.cat === cat);
      if (inCat.length === 0) return;
      const onCount = inCat.filter(s => state.skills.enabled.includes(s.id)).length;
      html += `<div class="skills-group"><span>— ${cat}</span><div class="sg-rule"></div><span class="sg-count">${onCount}/${inCat.length} ON</span></div>`;
      html += inCat.map(skillRowHtml).join('');
    });
  } else {
    const inCat = SKILLS.filter(s => s.cat === filter);
    if (inCat.length === 0) {
      html = `<div class="skills-empty">no skills in this category yet</div>`;
    } else {
      html = inCat.map(skillRowHtml).join('');
    }
  }
  listEl.innerHTML = html;

  // Wire row tap → open detail
  listEl.querySelectorAll('.skill').forEach(row => {
    row.addEventListener('click', () => openSkillDetail(row.dataset.id));
  });

  updateSkillCounts();
}

function skillRowHtml(s) {
  const isOn = isSkillOn(s.id);
  const cfg = skillConfigFor(s.id);
  return `
    <div class="skill ${isOn ? 'is-on' : ''}" data-id="${s.id}">
      <div class="skill-icon">${s.ico}</div>
      <div class="skill-body">
        <div class="skill-name">${s.name}<span class="skill-cat-tag">${s.cat}</span>${isOn ? '<span class="enabled-tag">ENABLED</span>' : ''}</div>
        <div class="skill-rule">
          <span class="rule-line"><span class="when">when</span>${escapeHtml(typeof s.when === 'function' ? s.when(cfg) : s.when)}</span>
          <span class="rule-line"><span class="then">then</span>${escapeHtml(typeof s.then === 'function' ? s.then(cfg) : s.then)}</span>
        </div>
      </div>
      <div class="skill-arrow">
        <svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3l5 5-5 5"/></svg>
      </div>
    </div>
  `;
}

function updateSkillCounts() {
  const onCount = state.skills.enabled.length;
  setText('#skills-on-count', onCount);
  // Re-render category counts in the pills (no full list re-render)
  $$('.skills-group').forEach(g => {/* counts inside header are static, skip */});
}

function disableAllSkills() {
  if (state.skills.enabled.length === 0) return;
  state.skills.enabled = [];
  renderSkills();
  saveState();
  showToast('all skills disabled');
}

// ─────────────────────── SKILL DETAIL SCREEN
let activeSkillId = null;

function openSkillDetail(skillId) {
  const s = SKILLS.find(x => x.id === skillId);
  if (!s) return;
  activeSkillId = skillId;

  // Header
  setText('#skill-detail-name', s.name);
  setText('#skill-detail-cat', s.cat);

  // Enable card
  const isOn = isSkillOn(skillId);
  const card = $('.skill-enable-card');
  card.classList.toggle('is-on', isOn);
  setText('#skill-enable-status', isOn ? 'currently enabled' : 'currently disabled');
  $('#skill-enable-input').checked = isOn;

  // Render the editable params + live rule preview
  renderSkillParams();
  renderSkillRulePreview();

  // Slide in
  const screen = $('#skill-detail');
  screen.classList.add('is-open');
  screen.setAttribute('aria-hidden', 'false');
}

function closeSkillDetail() {
  const screen = $('#skill-detail');
  screen.classList.remove('is-open');
  screen.setAttribute('aria-hidden', 'true');
  activeSkillId = null;
}

function renderSkillRulePreview() {
  if (!activeSkillId) return;
  const s = SKILLS.find(x => x.id === activeSkillId);
  if (!s) return;
  const cfg = skillConfigFor(s.id);
  setText('#skill-rule-when', typeof s.when === 'function' ? s.when(cfg) : s.when);
  setText('#skill-rule-then', typeof s.then === 'function' ? s.then(cfg) : s.then);
}

function renderSkillParams() {
  if (!activeSkillId) return;
  const s = SKILLS.find(x => x.id === activeSkillId);
  if (!s) return;
  const cfg = skillConfigFor(s.id);
  const wrap = $('#skill-params');
  if (!wrap) return;

  const html = (s.params || []).map(p => {
    const val = cfg[p.key];
    return `
      <div class="skill-param" data-key="${p.key}">
        <div class="sp-head">
          <span class="sp-label">${p.label}</span>
          <span class="sp-value">${formatParamValue(p, val)}</span>
        </div>
        ${renderParamControl(p, val)}
      </div>
    `;
  }).join('');
  wrap.innerHTML = html || `<div class="skills-empty">no settings · this skill has no triggers to tune</div>`;

  // Wire each control
  (s.params || []).forEach(p => {
    const row = wrap.querySelector(`.skill-param[data-key="${p.key}"]`);
    if (!row) return;

    if (p.kind === 'segmented') {
      row.querySelectorAll('.seg button').forEach(btn => {
        btn.addEventListener('click', () => {
          // Coerce to original type
          let nextVal = btn.dataset.v;
          if (typeof p.options[0].value === 'number') nextVal = parseFloat(nextVal);
          patchSkillConfig(activeSkillId, { [p.key]: nextVal });
          renderSkillParams();
          renderSkillRulePreview();
          // Refresh row in list while the screen is open
          refreshSkillRow(activeSkillId);
        });
      });
    } else if (p.kind === 'percent' || p.kind === 'minutes') {
      // Render as a segmented set built from range
      row.querySelectorAll('.seg button').forEach(btn => {
        btn.addEventListener('click', () => {
          patchSkillConfig(activeSkillId, { [p.key]: parseInt(btn.dataset.v, 10) });
          renderSkillParams();
          renderSkillRulePreview();
          refreshSkillRow(activeSkillId);
        });
      });
    } else if (p.kind === 'time' || p.kind === 'text') {
      const input = row.querySelector('input');
      if (input) {
        input.addEventListener('change', () => {
          patchSkillConfig(activeSkillId, { [p.key]: input.value });
          renderSkillParams();
          renderSkillRulePreview();
          refreshSkillRow(activeSkillId);
        });
      }
    }
  });
}

function renderParamControl(p, val) {
  if (p.kind === 'segmented') {
    return `
      <div class="seg">
        ${p.options.map(o => `
          <button class="${String(o.value) === String(val) ? 'on' : ''}" data-v="${o.value}">${o.label}</button>
        `).join('')}
      </div>
    `;
  }
  if (p.kind === 'percent' || p.kind === 'minutes') {
    const [min, max, step] = p.range;
    const stops = [];
    for (let v = min; v <= max; v += step) stops.push(v);
    return `
      <div class="seg">
        ${stops.map(v => `
          <button class="${v === val ? 'on' : ''}" data-v="${v}">${v}${p.kind === 'percent' ? '%' : 'M'}</button>
        `).join('')}
      </div>
    `;
  }
  if (p.kind === 'time') {
    return `<input type="time" value="${val}">`;
  }
  if (p.kind === 'text') {
    return `<input type="text" value="${escapeHtml(val)}" placeholder="...">`;
  }
  return '';
}

function formatParamValue(p, val) {
  if (p.kind === 'segmented') {
    const o = p.options.find(x => String(x.value) === String(val));
    return o ? o.label : String(val);
  }
  if (p.kind === 'percent') return `${val}%`;
  if (p.kind === 'minutes') return `${val} min`;
  if (p.kind === 'time')    return val;
  if (p.kind === 'text')    return val;
  return String(val);
}

// Re-render a single row in place (for live updates while detail is open)
function refreshSkillRow(skillId) {
  const s = SKILLS.find(x => x.id === skillId);
  if (!s) return;
  const row = document.querySelector(`.skill[data-id="${skillId}"]`);
  if (!row) return;
  row.outerHTML = skillRowHtml(s);
  // Re-wire the new node
  const newRow = document.querySelector(`.skill[data-id="${skillId}"]`);
  if (newRow) newRow.addEventListener('click', () => openSkillDetail(skillId));
}

// ─────────────────────── DASHBOARD
function renderDashboard() {
  const m = ctx.metrics;

  // ─ Greeting + device line
  const h = new Date().getHours();
  const greet = h < 5 ? 'good night' : h < 12 ? 'good morning' : h < 18 ? 'good afternoon' : 'good evening';
  setText('#dash-greeting', greet);
  setText('#dash-device',   `${m.deviceModel} · iOS ${m.iosVersion}`);

  // ─ Storage totals (used + free)
  const usedGb = ctx.metrics.diskTotalGB - ctx.metrics.diskFreeGB;
  const freeGb = ctx.metrics.diskFreeGB;
  const freePct = freeGb / ctx.metrics.diskTotalGB;

  // ─ Health score (0–100): weighted blend of measurable iOS signals
  // CPU headroom + free storage + thermal + battery level + Low Power mode
  const thermalPenalty = THERMAL_RANK[m.thermal] || 1;            // 1..4
  const cpuHeadroom = 100 - m.cpu;                                 // % free CPU
  const lowPowerPenalty = m.lowPower ? 5 : 0;

  let score =
      (cpuHeadroom * 0.25) +
      (freePct * 100 * 0.30) +
      ((5 - thermalPenalty) / 4 * 100 * 0.25) +
      (m.battery * 0.20);
  score = Math.round(clamp(score - lowPowerPenalty, 0, 100));

  const status = score >= 85 ? 'EXCELLENT'
              : score >= 70 ? 'GOOD'
              : score >= 50 ? 'FAIR'
              : 'NEEDS ATTENTION';
  const statusClass = score >= 70 ? '' : score >= 50 ? 'warn' : 'bad';

  setText('#hh-score', score);
  const statusEl = $('#hh-status');
  if (statusEl) {
    statusEl.textContent = status;
    statusEl.classList.remove('warn', 'bad');
    if (statusClass) statusEl.classList.add(statusClass);
  }
  const ringEl = $('.hh-ring');
  if (ringEl) {
    ringEl.classList.remove('warn', 'bad');
    if (statusClass) ringEl.classList.add(statusClass);
  }

  // SVG arc · 326.7 = 2π * 52 (radius)
  const arc = $('#hh-arc');
  if (arc) {
    const C = 326.7;
    arc.setAttribute('stroke-dashoffset', (C * (1 - score / 100)).toFixed(1));
  }

  // Summary
  const issueCount = countIssues({ score, freePct, thermal: m.thermal, lowPower: m.lowPower });
  const summary = issueCount === 0
    ? `your phone is running smoothly · all systems nominal`
    : `${issueCount} ${issueCount === 1 ? 'issue' : 'issues'} to review · see alerts below`;
  setText('#hh-summary', summary);

  // Factors (only metrics iOS actually exposes)
  const factors = [
    { k: 'CPU headroom',  v: `${Math.round(cpuHeadroom)}%`,            bad: cpuHeadroom < 20 },
    { k: 'Storage free',  v: `${(freePct * 100).toFixed(0)}%`,          bad: freePct < 0.10 },
    { k: 'Thermal',       v: THERMAL_LABEL[m.thermal] || m.thermal.toUpperCase(), bad: thermalPenalty >= 3 },
    { k: 'Low power',     v: m.lowPower ? 'ON' : 'OFF',                bad: m.lowPower }
  ];
  const fEl = $('#hh-factors');
  if (fEl) {
    fEl.innerHTML = factors.map(f => `
      <div class="hh-factor ${f.bad ? 'bad' : ''}">
        <span>${f.k}</span><span class="hf-v">${f.v}</span>
      </div>
    `).join('');
  }

  // ─ Alerts (only based on factors iOS actually surfaces)
  const alerts = [];
  if (freePct < 0.10) alerts.push({ t: 'DISK', msg: `storage low · ${freeGb.toFixed(1)} GB free`, cls: 'warn' });
  if (thermalPenalty >= 3) alerts.push({ t: 'TEMP', msg: `device is ${THERMAL_LABEL[m.thermal] || m.thermal} · may throttle`, cls: 'warn' });
  if (m.cpu > 85) alerts.push({ t: 'CPU', msg: `CPU at ${Math.round(m.cpu)}% · heavy workload`, cls: 'warn' });
  if (m.lowPower) alerts.push({ t: 'PWR', msg: 'low power mode is on · background tasks deferred', cls: 'info' });
  if (m.battery < 20) alerts.push({ t: 'BATT', msg: `battery low · ${Math.round(m.battery)}% remaining`, cls: 'warn' });
  if (alerts.length === 0) alerts.push({ t: 'OK', msg: 'no issues detected', cls: 'info' });

  const aEl = $('#dash-alerts');
  if (aEl) {
    aEl.innerHTML = alerts.map(a => `
      <div class="alert ${a.cls}">
        <span class="alert-i">${a.t}</span>
        <span class="alert-msg">${a.msg}</span>
      </div>
    `).join('');
  }

  // ─ Today tiles (all measurable on iOS)
  setText('#today-uptime', formatUptime(m.uptimeS));
  setText('#today-steps',  m.steps.toLocaleString());
  setText('#today-steps-sub', `${dash.stepsKm.toFixed(1)} km`);
  setText('#today-cpu',    Math.round(dash.cpuPeak1h));
  setText('#today-thermal', THERMAL_LABEL[dash.thermalPeak] || dash.thermalPeak.toUpperCase());
  setText('#today-network', m.network.toUpperCase());
  setText('#today-cell',    m.network === 'cellular' ? m.cellTech : 'connected');
  setText('#today-mem',    m.memUsedGB.toFixed(1));

  // ─ Storage breakdown
  setText('#sto-used', usedGb.toFixed(1));
  setText('#sto-free', freeGb.toFixed(1));
  const fill = $('#sto-fill');
  if (fill) {
    fill.style.width = `${(usedGb / ctx.metrics.diskTotalGB * 100).toFixed(1)}%`;
  }

  // ─ Battery (live snapshot)
  setText('#batt-state', m.batteryState.toUpperCase());
  setText('#batt-pct',   Math.round(m.battery) + '%');
  // Drain rate from short-term sample buffer (only what we've actually seen)
  pushBatterySample(m.battery);
  const drain = computeBatteryDrain();
  setText('#batt-drain', drain != null ? `${drain.toFixed(1)}%/h` : '— %/h');
  if (drain != null && drain > 0.1) {
    const eta = m.battery / drain;
    const etaH = Math.floor(eta);
    const etaM = Math.round((eta - etaH) * 60);
    setText('#batt-eta', `${etaH}h ${etaM}m`);
  } else if (m.batteryState === 'charging') {
    setText('#batt-eta', '— · charging');
  } else {
    setText('#batt-eta', '—');
  }

  drawBatteryBar();

  // ─ Trends (sparklines · all measurable)
  drawSpark('#tr-cpu',  dash.trendCpu);
  drawSpark('#tr-mem',  dash.trendMem);
  drawSpark('#tr-sto',  dash.trendStorage);
  drawSpark('#tr-lt',   dash.trendLaunch);

  setText('#tr-cpu-now',  `${dash.trendCpu.slice(-1)[0]}%`);
  setText('#tr-mem-now',  `${dash.trendMem.slice(-1)[0]}MB`);
  setText('#tr-sto-now',  `${dash.trendStorage.slice(-1)[0].toFixed(1)}GB`);
  setText('#tr-lt-now',   `${dash.trendLaunch.slice(-1)[0]}ms`);
}

function countIssues({ freePct, thermal, lowPower }) {
  let n = 0;
  if (freePct < 0.10) n++;
  if ((THERMAL_RANK[thermal] || 1) >= 3) n++;
  if (lowPower) n++;
  return n;
}

function formatHoursMin(min) {
  const h = Math.floor(min / 60);
  const m = min % 60;
  return `${h}h ${m}m`;
}

function drawSpark(sel, series) {
  const el = $(sel);
  if (!el || !series.length) return;
  const w = 100, h = 30, pad = 2;
  const min = Math.min(...series);
  const max = Math.max(...series);
  const range = max - min || 1;
  const pts = series.map((v, i) => {
    const x = (i / (series.length - 1)) * w;
    const y = h - pad - ((v - min) / range) * (h - pad * 2);
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  }).join(' ');
  el.setAttribute('points', pts);
}

function drawBatteryBar() {
  const fill = $('#batt-fill');
  if (!fill) return;
  const pct = ctx.metrics.battery;
  fill.style.width = pct.toFixed(1) + '%';
  fill.classList.toggle('low', pct < 20);
}

// Live ring buffer of battery samples · used to compute drain rate
// honestly from data we've actually observed (not a synthetic curve).
const _battSamples = []; // [{ t: ms, level: 0..100 }]
function pushBatterySample(level) {
  const t = Date.now();
  // ignore duplicates within 5s
  if (_battSamples.length && t - _battSamples[_battSamples.length - 1].t < 5000) return;
  _battSamples.push({ t, level });
  // keep last 30 minutes
  const cutoff = t - 30 * 60 * 1000;
  while (_battSamples.length && _battSamples[0].t < cutoff) _battSamples.shift();
}
function computeBatteryDrain() {
  if (_battSamples.length < 2) return null;
  const first = _battSamples[0];
  const last  = _battSamples[_battSamples.length - 1];
  const dtH = (last.t - first.t) / (1000 * 60 * 60);
  if (dtH < 1 / 60) return null; // need at least a minute of data
  const dPct = first.level - last.level; // positive = draining
  if (dPct <= 0) return 0;
  return dPct / dtH;
}

function setPerfView(v) {
  state.perfView = v;
  document.body.classList.toggle('perf-list', v === 'list');
  $$('.perf-view-toggle button').forEach(b => b.classList.toggle('on', b.dataset.view === v));
  saveState();
}

function setChartStyle(n) {
  state.chartStyle = parseInt(n, 10);
  // Strip all chart-* classes, then add the active one
  for (let i = 1; i <= 10; i++) {
    document.body.classList.remove(`chart-${i}`);
  }
  document.body.classList.add(`chart-${state.chartStyle}`);
  $$('.chart-style-seg button').forEach(b => {
    b.classList.toggle('on', parseInt(b.dataset.style, 10) === state.chartStyle);
  });
  // Clear any injected per-style elements (e.g. chart-8 blocks)
  $$('.pc-ring .pc-blk').forEach(el => el.remove());
  // Re-render so rings recompute with the new circumference
  if (state.tab === 'performance') renderPerformance();
  saveState();
}

// Inject a one-time SVG <defs> for chart-3's gradient stroke
function ensureChartDefs() {
  if (document.getElementById('chart-defs')) return;
  const svgNS = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(svgNS, 'svg');
  svg.setAttribute('id', 'chart-defs');
  svg.setAttribute('width', '0');
  svg.setAttribute('height', '0');
  svg.style.position = 'absolute';
  svg.innerHTML = `
    <defs>
      <linearGradient id="ringGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%"  stop-color="#ffffff" />
        <stop offset="100%" stop-color="#9ea1ff" />
      </linearGradient>
    </defs>
  `;
  document.body.appendChild(svg);
}
const THERMAL_RANK = { nominal: 1, fair: 2, serious: 3, critical: 4 };
// Friendly label paired with each ProcessInfo.thermalState value.
// iOS does NOT expose a numeric temperature; this maps the 4-step enum
// to a human-readable hint about how the device feels.
const THERMAL_LABEL = {
  nominal:  'NORMAL',
  fair:     'WARMER',
  serious:  'HOT',
  critical: 'VERY HOT'
};

function renderPerformance() {
  const m = ctx.metrics;

  // ─ CPU
  setText('#perf-cpu', Math.round(m.cpu));
  setRing('cpu', m.cpu, 100);

  // ─ Memory · used / total
  setText('#perf-mem', m.memUsedGB.toFixed(1));
  setText('#perf-mem-src', `${m.memUsedGB.toFixed(1)} / ${m.memTotalGB.toFixed(1)} GB`);
  setRing('memory', m.memUsedGB, m.memTotalGB);

  // ─ FPS · target = 120 for ProMotion
  setText('#perf-fps', Math.round(m.fps));
  setBar('fps', m.fps, 120);

  // ─ Thermal · 4-step enum, no °C reading
  // Show the iOS state name + a friendly "feel" label
  setText('#perf-thermal', `${m.thermal.toUpperCase()} · ${THERMAL_LABEL[m.thermal] || ''}`);
  const lit = THERMAL_RANK[m.thermal] || 0;
  $$('.thermal-track .ts').forEach((seg, i) => {
    seg.classList.toggle('lit', i < lit);
  });

  // ─ Battery
  setText('#perf-batt', Math.round(m.battery));
  setText('#perf-batt-state', m.batteryState.toUpperCase());
  setRing('battery', m.battery, 100);

  // ─ Disk · free
  setText('#perf-disk', m.diskFreeGB.toFixed(0));
  setText('#perf-disk-src', `${m.diskFreeGB.toFixed(1)} / ${m.diskTotalGB.toFixed(0)} GB`);
  setRing('disk', m.diskFreeGB, m.diskTotalGB);

  // ─ Cores
  setText('#perf-cores', `${m.cores}/${m.coresTotal}`);
  setRing('cores', m.cores, m.coresTotal);

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
  setText('#perf-net',        m.network.toUpperCase());
  setText('#perf-cell',       m.cellTech);
  setText('#perf-refresh',    `${m.refreshHz} Hz`);
  setText('#perf-lowpower',   m.lowPower ? 'ON' : 'OFF');
  setText('#perf-uptime',     formatUptime(m.uptimeS));
  setText('#perf-device',     m.deviceModel);
  setText('#perf-chip',       m.chip);
  setText('#perf-ios',        m.iosVersion);
  setText('#perf-ram',        `${m.ramGB} GB`);
  setText('#perf-storage-total', `${m.diskTotalGB} GB`);
  setText('#perf-cpu-cores',  `${m.cores} / ${m.coresTotal}`);
  setText('#perf-display',    m.displayRes);
  setText('#perf-locale',     m.locale);
  setText('#perf-tz',         m.timeZone);

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

// Drive the SVG ring on a perf-card by adjusting stroke-dashoffset
// (default chart 2/3 use r=36 → 226.19)
const RING_C = 226.19;
const RING_C_BY_STYLE = {
  1: 169.65,   // chart-1: r=27
  2: 226.19,   // chart-2: r=36
  3: 226.19,   // chart-3: r=36
  4: 150.80,   // chart-4: r=24
  5: 226.19,   // chart-5: gauge, value goes through CSS var
  6: 226.19,   // chart-6: r=36
  7: 125.66,   // chart-7: half-gauge, half of 2π·40
  8: 226.19,   // chart-8: blocks, value goes through JS-built squares
  9: 226.19,   // chart-9: numeric, value via CSS var
  10: 226.19   // chart-10: HUD, value via CSS var
};
function setRing(metric, val, max) {
  const card = document.querySelector(`.perf-card[data-metric="${metric}"]`);
  if (!card) return;
  const arc = card.querySelector('.pc-ring-arc');
  const ring = card.querySelector('.pc-ring');
  const pct = Math.max(0, Math.min(1, val / max));
  // Pick the right circumference for the active style
  const c = RING_C_BY_STYLE[state.chartStyle] || RING_C;
  if (arc) arc.setAttribute('stroke-dashoffset', (c * (1 - pct)).toFixed(1));
  // Styles that render a CSS-driven gauge use --gauge
  if (ring) ring.style.setProperty('--gauge', `${(pct * 100).toFixed(1)}%`);

  // Style 8: stepped blocks — light up first N of 10 blocks
  if (state.chartStyle === 8 && ring) {
    let blocks = ring.querySelectorAll('.pc-blk');
    if (blocks.length === 0) {
      // Inject blocks lazily
      const frag = document.createDocumentFragment();
      for (let i = 0; i < 10; i++) {
        const b = document.createElement('span');
        b.className = 'pc-blk';
        // ascending heights so it looks more interesting than a flat row
        b.style.height = `${30 + (i / 9) * 70}%`;
        frag.appendChild(b);
      }
      // Insert before the value so the value sits on top
      const val = ring.querySelector('.pc-ring-val');
      ring.insertBefore(frag, val);
      blocks = ring.querySelectorAll('.pc-blk');
    }
    const litCount = Math.round(pct * 10);
    blocks.forEach((b, i) => b.classList.toggle('on', i < litCount));
  }
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

// ─────────────────────── CODE EXPORT
const exportState = { lang: 'swiftui' };

function generateCode(d, lang) {
  if (!d) return '';
  const isLong = state.size === 'long';
  const variant = isLong ? 'expanded' : 'compact';
  const idCamel = d.id.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
  const idPascal = idCamel.charAt(0).toUpperCase() + idCamel.slice(1);

  if (lang === 'swiftui') {
    return [
      `// ${d.name} · ${d.category}`,
      `// Variant: ${variant.toUpperCase()}`,
      ``,
      `import SwiftUI`,
      ``,
      `struct ${idPascal}View: View {`,
      `    let metric: Double  // bind to your live data source`,
      ``,
      `    var body: some View {`,
      `        HStack(spacing: ${isLong ? 18 : 8}) {`,
      `            // Replace with your widget content for "${d.name}"`,
      `            Text("${d.name.toUpperCase()}")`,
      `                .font(.system(size: ${isLong ? 14 : 11}, weight: .bold, design: .monospaced))`,
      `                .kerning(0.6)`,
      `                .foregroundStyle(.white)`,
      `            Text("\\(Int(metric))")`,
      `                .font(.system(size: ${isLong ? 22 : 14}, weight: .bold, design: .monospaced))`,
      `                .foregroundStyle(.white)`,
      `        }`,
      `        .padding(.horizontal, ${isLong ? 28 : 14})`,
      `        .frame(height: 34)`,
      `        .background(Color.black, in: Capsule())`,
      `    }`,
      `}`,
      ``,
      `#Preview {`,
      `    ${idPascal}View(metric: 42)`,
      `        .preferredColorScheme(.dark)`,
      `}`
    ].join('\n');
  }

  if (lang === 'activitykit') {
    return [
      `// ${d.name} · Live Activity (Dynamic Island)`,
      `// Variant shown: ${variant.toUpperCase()}`,
      ``,
      `import ActivityKit`,
      `import SwiftUI`,
      `import WidgetKit`,
      ``,
      `struct ${idPascal}Attributes: ActivityAttributes {`,
      `    public struct ContentState: Codable, Hashable {`,
      `        var value: Double`,
      `    }`,
      `    var name: String`,
      `}`,
      ``,
      `struct ${idPascal}LiveActivity: Widget {`,
      `    var body: some WidgetConfiguration {`,
      `        ActivityConfiguration(for: ${idPascal}Attributes.self) { context in`,
      `            // Lock screen / banner UI`,
      `            ${idPascal}View(metric: context.state.value)`,
      `                .activityBackgroundTint(Color.black)`,
      `        } dynamicIsland: { context in`,
      `            DynamicIsland {`,
      `                DynamicIslandExpandedRegion(.leading)  { Text("${d.name}") }`,
      `                DynamicIslandExpandedRegion(.trailing) { Text("\\(Int(context.state.value))") }`,
      `                DynamicIslandExpandedRegion(.bottom)   { ProgressView(value: context.state.value, total: 100) }`,
      `            } compactLeading: {`,
      `                Text("${d.name.split(' ')[0]}").font(.system(.caption2, design: .monospaced))`,
      `            } compactTrailing: {`,
      `                Text("\\(Int(context.state.value))").font(.system(.caption2, design: .monospaced))`,
      `            } minimal: {`,
      `                Text("\\(Int(context.state.value))").font(.system(.caption2, design: .monospaced))`,
      `            }`,
      `        }`,
      `    }`,
      `}`
    ].join('\n');
  }

  if (lang === 'html') {
    const inner = d.short(ctx).trim();
    return [
      `<!-- ${d.name} · ${d.category} -->`,
      `<div class="island ${isLong ? 'long' : ''}">`,
      `  ${inner.split('\n').map(l => l.trim()).filter(Boolean).join('\n  ')}`,
      `</div>`,
      ``,
      `<style>`,
      `.island {`,
      `  display: inline-flex;`,
      `  align-items: center;`,
      `  gap: ${isLong ? 18 : 10}px;`,
      `  height: 34px;`,
      `  padding: 0 ${isLong ? 28 : 14}px;`,
      `  background: #000;`,
      `  border-radius: 18px;`,
      `  font-family: ui-monospace, "JetBrains Mono", Menlo, monospace;`,
      `  color: #fff;`,
      `}`,
      `</style>`
    ].join('\n');
  }

  return '';
}

function openExportModal() {
  const d = designById(state.focusedId);
  if (!d) return;
  $('#export-name').textContent = d.name;
  $('#export-cat').textContent = `${d.category} · ${state.size.toUpperCase()}`;
  renderExportCode();
  const m = $('#export-modal');
  m.classList.add('is-open');
  m.setAttribute('aria-hidden', 'false');
}
function closeExportModal() {
  const m = $('#export-modal');
  m.classList.remove('is-open');
  m.setAttribute('aria-hidden', 'true');
}
function setExportLang(lang) {
  exportState.lang = lang;
  $$('#export-tabs .mt').forEach(b => b.classList.toggle('on', b.dataset.lang === lang));
  renderExportCode();
}
function renderExportCode() {
  const d = designById(state.focusedId);
  $('#export-code').textContent = generateCode(d, exportState.lang);
}
// ─────────────────────── DETAIL SCREEN
function openDetail(designId) {
  const d = designById(designId);
  if (!d) return;
  // Make this the focused design so renderPreview targets it
  state.focusedId = designId;

  // Header
  $('#detail-name').textContent = d.name;
  $('#detail-cat').textContent  = d.category;

  // Preview & apply state
  renderPreview();

  // Refresh-rate section is only relevant for CRYPTO (paid/free price APIs throttle)
  const refreshSection = $('#edit-refresh-section');
  const showRefresh = d.category === 'CRYPTO';
  if (refreshSection) {
    refreshSection.hidden = !showRefresh;
    refreshSection.style.display = showRefresh ? '' : 'none';
  }

  if (showRefresh) {
    const e = editFor(d.id);
    $('#edit-refresh-help').textContent = describeRefreshSource(d.category);
    $$('#edit-refresh button').forEach(b => {
      b.classList.toggle('on', parseInt(b.dataset.rate, 10) === e.refreshMs);
    });
  }

  // Color swatches
  const e = editFor(d.id);
  const colorRow = $('#edit-color');
  colorRow.innerHTML = COLOR_PALETTE.map(c => `
    <button class="color-sw ${e.color === c.key ? 'on' : ''}" data-color="${c.key}" title="${c.label}">
      <span class="dot" style="background:${c.css}"></span>
    </button>
  `).join('');
  colorRow.querySelectorAll('.color-sw').forEach(sw => {
    sw.addEventListener('click', () => {
      patchEdit(designId, { color: sw.dataset.color });
      colorRow.querySelectorAll('.color-sw').forEach(x => x.classList.toggle('on', x === sw));
    });
  });

  // Bold toggle
  $('#edit-bold').checked = e.bold;

  // Slide in
  const screen = $('#detail-screen');
  screen.classList.add('is-open');
  screen.setAttribute('aria-hidden', 'false');
}

function closeDetail() {
  const screen = $('#detail-screen');
  screen.classList.remove('is-open');
  screen.setAttribute('aria-hidden', 'true');
}

// Patch a single edit field for a design and re-render in place
function patchEdit(designId, patch) {
  const cur = state.edits[designId] || {};
  // Make sure unset fields use defaults so we always store a complete object
  state.edits[designId] = { ...editFor(designId), ...cur, ...patch };
  saveState();

  // Re-render preview pill
  renderPreview();
  // Re-render row preview classes
  $$(`.drow[data-id="${designId}"] .drow-preview`).forEach(el => {
    el.classList.remove(
      'accent-mono', 'accent-green', 'accent-orange', 'accent-blue', 'accent-pink', 'accent-yellow',
      'is-bold', 'has-pulse'
    );
    const e = editFor(designId);
    el.classList.add(`accent-${e.color}`);
    if (e.bold) el.classList.add('is-bold');
  });
}

function resetEditForDesign() {
  const id = state.focusedId;
  if (!id) return;
  delete state.edits[id];
  saveState();
  // Re-open with defaults
  openDetail(id);
  showToast('reset to defaults');
}

function describeRefreshSource(cat) {
  switch (cat) {
    case 'CRYPTO':  return 'how often to fetch new prices · APIs throttle below 5s';
    case 'SPORTS':  return 'how often to fetch live scores · push usually drives updates';
    case 'WEATHER': return 'how often to call WeatherKit · changes slowly';
    case 'HEALTH':  return 'how often to query HealthKit · observers fire on change';
    case 'DEVICE':  return 'how often to sample local sensors';
    case 'TIME':    return 'how often to refresh the clock';
    default:        return 'how often to refresh data';
  }
}

function formatRefreshLabel(ms) {
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${ms / 1000}s`;
  return `${ms / 60000}m`;
}

async function copyExport() {
  const code = $('#export-code').textContent;
  try {
    await navigator.clipboard.writeText(code);
    showToast('copied to clipboard');
  } catch (e) {
    // Fallback: select + execCommand
    const range = document.createRange();
    range.selectNode($('#export-code'));
    window.getSelection().removeAllRanges();
    window.getSelection().addRange(range);
    try {
      document.execCommand('copy');
      showToast('copied to clipboard');
    } catch (_) {
      showToast('copy failed');
    }
    window.getSelection().removeAllRanges();
  }
}

// ─────────────────────── TOAST
let toastTimer = null;
function showToast(msg) {
  const el = $('#toast');
  if (!el) return;
  el.textContent = msg;
  el.classList.add('is-open');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('is-open'), 1800);
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
  document.body.classList.toggle('no-anim', !!state.prefs.reduceMotion);
}
function applyCompactPref() {
  document.body.classList.toggle('compact', !!state.prefs.compact);
}
function applyThemePref() {
  document.body.classList.remove('theme-dark', 'theme-midnight', 'theme-paper');
  document.body.classList.add(`theme-${state.prefs.theme || 'dark'}`);
}
function applyCatTagsPref() {
  document.body.classList.toggle('hide-cat-tags', !state.prefs.catTags);
}

function wireSettings() {
  // ─ APPEARANCE
  $('#set-theme').querySelectorAll('button').forEach(b => {
    b.addEventListener('click', () => {
      state.prefs.theme = b.dataset.theme;
      $('#set-theme').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
      applyThemePref();
      saveState();
    });
  });
  $('#set-compact').addEventListener('change', e => {
    state.prefs.compact = e.target.checked;
    applyCompactPref();
    saveState();
  });
  $('#set-cat-tags').addEventListener('change', e => {
    state.prefs.catTags = e.target.checked;
    applyCatTagsPref();
    saveState();
  });
  $('#set-reduce-motion').addEventListener('change', e => {
    state.prefs.reduceMotion = e.target.checked;
    applyAnimPref();
    saveState();
  });

  // ─ UNITS
  bindSeg('#set-temp-unit', 'unit', v => { state.prefs.tempUnit = v; saveState(); });
  bindSeg('#set-distance-unit', 'unit', v => { state.prefs.distUnit = v; saveState(); });
  bindSeg('#set-time-fmt',  'fmt',  v => { state.prefs.timeFmt = v; saveState(); });
  bindSeg('#set-currency',  'cur',  v => { state.prefs.currency = v; saveState(); });
  bindSeg('#set-week-start','day',  v => { state.prefs.weekStart = v; saveState(); });

  // ─ NOTIFICATIONS
  bindToggle('#set-notify',  v => { state.prefs.notify = v; saveState(); });
  bindToggle('#set-sounds',  v => { state.prefs.sounds = v; saveState(); });
  bindToggle('#set-haptics', v => { state.prefs.haptics = v; saveState(); });
  bindToggle('#set-quiet',   v => { state.prefs.quiet = v; saveState(); });

  // ─ PRIVACY
  bindToggle('#set-analytics', v => { state.prefs.analytics = v; saveState(); });
  bindToggle('#set-crashes',   v => { state.prefs.crashes = v; saveState(); });
  $('#set-health').addEventListener('click', () => showToast('triggers HealthKit permission prompt'));
  $('#set-location').addEventListener('click', () => showToast('opens this app\'s settings page'));

  // ─ DATA
  bindToggle('#set-icloud', v => { state.prefs.icloud = v; saveState(); });
  $('#set-backup').addEventListener('click', () => {
    showToast('backup saved');
  });
  $('#set-export').addEventListener('click', () => {
    const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'x-widget-design-settings.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast('exported settings');
  });
  $('#set-reset').addEventListener('click', () => {
    state.appliedId = 'weather-now';
    setFocus('weather-now', { scroll: false });
    renderPreview();
    updateRowFocus();
    saveState();
    showToast('reset to weather now');
  });
  $('#set-clear').addEventListener('click', () => {
    state.edits = {};
    state.favorites = [];
    saveState();
    if (typeof renderList === 'function') renderList();
    showToast('customizations cleared');
  });

  // ─ ABOUT
  setText('#set-design-count', DESIGNS.length);
  try {
    const sz = localStorage.getItem(STORAGE_KEY) || '';
    setText('#set-storage-used', `${(sz.length / 1024).toFixed(2)} KB`);
  } catch (e) {
    setText('#set-storage-used', '— KB');
  }
  $('#set-feedback').addEventListener('click', () => {
    window.location.href = 'mailto:hello@x-widget.app?subject=Feedback';
  });
  $('#set-terms').addEventListener('click', () => {
    showToast('opens terms & privacy');
  });

  // Sync controls with restored state
  $('#set-compact').checked       = state.prefs.compact;
  $('#set-cat-tags').checked      = state.prefs.catTags;
  $('#set-reduce-motion').checked = state.prefs.reduceMotion;
  $('#set-notify').checked        = state.prefs.notify;
  $('#set-sounds').checked        = state.prefs.sounds;
  $('#set-haptics').checked       = state.prefs.haptics;
  $('#set-quiet').checked         = state.prefs.quiet;
  $('#set-analytics').checked     = state.prefs.analytics;
  $('#set-crashes').checked       = state.prefs.crashes;
  $('#set-icloud').checked        = state.prefs.icloud;

  syncSeg('#set-theme', 'theme', state.prefs.theme);
  syncSeg('#set-temp-unit', 'unit', state.prefs.tempUnit);
  syncSeg('#set-distance-unit', 'unit', state.prefs.distUnit);
  syncSeg('#set-time-fmt', 'fmt', state.prefs.timeFmt);
  syncSeg('#set-currency', 'cur', state.prefs.currency);
  syncSeg('#set-week-start', 'day', state.prefs.weekStart);
}

function bindSeg(sel, attr, cb) {
  const root = $(sel);
  if (!root) return;
  root.querySelectorAll('button').forEach(b => {
    b.addEventListener('click', () => {
      cb(b.dataset[attr]);
      root.querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
    });
  });
}
function syncSeg(sel, attr, value) {
  const root = $(sel);
  if (!root) return;
  root.querySelectorAll('button').forEach(b => {
    b.classList.toggle('on', b.dataset[attr] === String(value));
  });
}
function bindToggle(sel, cb) {
  const el = $(sel);
  if (!el) return;
  el.addEventListener('change', e => cb(e.target.checked));
}

// ─────────────────────── BOOT
function init() {
  // Restore persisted state before first render
  loadState();
  state.size = state.prefs.defaultSize || state.size;

  // Initial render
  renderChips();
  renderList();
  renderPreview();

  // Restore tab
  if (state.tab !== 'dashboard') {
    $$('.tab-panel').forEach(p => p.classList.toggle('is-active', p.dataset.tab === state.tab));
    $$('.tabbar .tab').forEach(b => b.classList.toggle('on', b.dataset.tab === state.tab));
    if (state.tab === 'performance') renderPerformance();
  }
  // Always render dashboard once so it's ready when switched to
  renderDashboard();
  renderSkills();

  // Apply
  $('#apply-btn').addEventListener('click', applyCurrent);

  // Size toggle (in detail screen)
  $$('.size-toggle button').forEach(b => {
    b.addEventListener('click', () => setSize(b.dataset.size));
  });

  // Detail screen back button
  $('#detail-back').addEventListener('click', closeDetail);

  // Inline edit controls in detail screen
  $$('#edit-refresh button').forEach(b => {
    b.addEventListener('click', () => {
      const ms = parseInt(b.dataset.rate, 10);
      patchEdit(state.focusedId, { refreshMs: ms });
      $$('#edit-refresh button').forEach(x => x.classList.toggle('on', x === b));
    });
  });
  $('#edit-bold').addEventListener('change', e => {
    patchEdit(state.focusedId, { bold: e.target.checked });
  });
  $('#edit-reset').addEventListener('click', resetEditForDesign);
  const input = $('#search-input');
  const bar = $('#search-bar');
  const toggle = $('#search-toggle');
  if (input && bar && toggle) {
    const closeSearch = () => {
      bar.hidden = true;
      toggle.classList.remove('on');
      if (state.query) {
        input.value = '';
        setQuery('');
      }
    };
    const openSearch = () => {
      bar.hidden = false;
      toggle.classList.add('on');
      requestAnimationFrame(() => input.focus());
    };
    toggle.addEventListener('click', () => {
      if (bar.hidden) openSearch();
      else closeSearch();
    });
    input.addEventListener('input', e => setQuery(e.target.value));
    input.addEventListener('keydown', e => {
      if (e.key === 'Escape') closeSearch();
    });
    $('#search-clear').addEventListener('click', () => {
      input.value = '';
      setQuery('');
      input.focus();
    });
  }

  // Tab bar
  $$('.tabbar .tab').forEach(b => {
    b.addEventListener('click', () => setTab(b.dataset.tab));
  });

  // Skills · disable all
  $('#skills-disable-all').addEventListener('click', disableAllSkills);

  // Performance · view-mode toggle (chart vs list)
  $$('.perf-view-toggle button').forEach(b => {
    b.addEventListener('click', () => setPerfView(b.dataset.view));
  });
  setPerfView(state.perfView || 'chart');

  // Performance · chart style locked to 1 (slim ring)
  ensureChartDefs();
  setChartStyle(1);

  // Skills · detail screen wiring
  $('#skill-detail-back').addEventListener('click', closeSkillDetail);
  $('#skill-enable-input').addEventListener('change', e => {
    if (!activeSkillId) return;
    const on = e.target.checked;
    setSkillEnabled(activeSkillId, on);
    const card = $('.skill-enable-card');
    card.classList.toggle('is-on', on);
    setText('#skill-enable-status', on ? 'currently enabled' : 'currently disabled');
    refreshSkillRow(activeSkillId);
    updateSkillCounts();
    showToast(on ? 'skill enabled' : 'skill disabled');
  });
  $('#skill-reset').addEventListener('click', () => {
    if (!activeSkillId) return;
    resetSkillConfig(activeSkillId);
    renderSkillParams();
    renderSkillRulePreview();
    refreshSkillRow(activeSkillId);
    showToast('reset to defaults');
  });

  // Export modal (only kept for Dashboard quick action; button itself was removed)
  if ($('#export-btn')) $('#export-btn').addEventListener('click', openExportModal);
  $('#copy-btn').addEventListener('click', copyExport);
  $$('#export-tabs .mt').forEach(b => {
    b.addEventListener('click', () => setExportLang(b.dataset.lang));
  });
  $$('#export-modal [data-close]').forEach(el => {
    el.addEventListener('click', closeExportModal);
  });

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
      closeExportModal();
      closeDetail();
      closeSkillDetail();
    }
  });

  // Settings
  wireSettings();
  applyAnimPref();
  applyCompactPref();
  applyThemePref();
  applyCatTagsPref();

  // Live data
  startTickTimer();
}

document.addEventListener('DOMContentLoaded', init);

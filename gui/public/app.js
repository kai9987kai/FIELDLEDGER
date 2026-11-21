/**
 * FIELDLEDGER Offline GUI Workbench Client
 * Zero external dependencies. Displays authentic outputs produced by
 * the compiled GnuCOBOL engine (build/fieldledger.exe).
 * Every dynamic table cell and text node uses DOM textContent (XSS-safe).
 */

const state = {
  studies: [],
  bundle: null,
  inputFiles: null,
  busy: false,
};

const $ = (id) => document.getElementById(id);

/* =====================================================================
 * 1. Theme / Color Scheme Management (modern-web-guidance: dark-mode-toggle)
 * ===================================================================== */
function getStoredScheme() {
  try {
    const v = localStorage.getItem('color-scheme');
    return v === 'light' || v === 'dark' ? v : null;
  } catch {
    return null;
  }
}

function getSystemScheme() {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function applyScheme(mode) {
  const meta = document.querySelector('meta[name="color-scheme"]');
  if (mode === 'light' || mode === 'dark') {
    meta.content = mode;
    try {
      localStorage.setItem('color-scheme', mode);
    } catch {}
  } else {
    meta.content = 'light dark';
    try {
      localStorage.removeItem('color-scheme');
    } catch {}
  }
  syncThemeControls();
}

function syncThemeControls() {
  const stored = getStoredScheme();
  const currentSystem = getSystemScheme();
  $('theme-system-label').textContent = `System default (currently ${currentSystem})`;
  const target = stored ?? 'system';
  for (const input of document.querySelectorAll('input[name="theme-mode"]')) {
    input.checked = input.value === target;
  }
}

window.addEventListener('storage', (e) => {
  if (e.key === 'color-scheme') {
    const meta = document.querySelector('meta[name="color-scheme"]');
    meta.content = getStoredScheme() ?? 'light dark';
    syncThemeControls();
  }
});

/* =====================================================================
 * 2. Native <dialog> Progressive Enhancement Fallbacks (modern-web-guidance: dialog)
 * ===================================================================== */
function setupDialogs() {
  // Invoker commands fallback (offline-safe, zero CDN polyfills)
  if (!('commandForElement' in HTMLButtonElement.prototype)) {
    for (const btn of document.querySelectorAll('[data-open-dialog]')) {
      btn.addEventListener('click', () => {
        const dlg = $(btn.dataset.openDialog);
        if (dlg && typeof dlg.showModal === 'function') dlg.showModal();
      });
    }
  }

  // Light-dismiss fallback when <dialog closedby="any"> is unsupported
  if (!('closedBy' in HTMLDialogElement.prototype)) {
    const isOutside = (e, dialog) => {
      const r = dialog.getBoundingClientRect();
      return e.clientX < r.left || e.clientX > r.right || e.clientY < r.top || e.clientY > r.bottom;
    };
    for (const dialog of document.querySelectorAll('dialog[closedby="any"]')) {
      let pressedOutside = false;
      dialog.addEventListener('pointerdown', (e) => {
        pressedOutside = isOutside(e, dialog);
      });
      dialog.addEventListener('pointerup', (e) => {
        if (pressedOutside && isOutside(e, dialog)) dialog.close();
      });
    }
  }

  // Init Study modal close handler (always reset returnValue to avoid stale state)
  const initDialog = $('init-dialog');
  initDialog.addEventListener('close', async () => {
    const action = initDialog.returnValue;
    initDialog.returnValue = '';
    if (action === 'create') {
      const targetPath = $('init-study-path').value.trim();
      if (targetPath) {
        await runAction('init', { studyPath: targetPath });
      }
    }
  });

  const settingsDialog = $('settings-dialog');
  settingsDialog.addEventListener('close', () => {
    settingsDialog.returnValue = '';
  });

  for (const input of document.querySelectorAll('input[name="theme-mode"]')) {
    input.addEventListener('change', () => applyScheme(input.value));
  }
}

/* =====================================================================
 * 3. Accessible Tabs with focusgroup + beforematch + Scroll Hints (tabs)
 * ===================================================================== */
function setupTabs() {
  const tablist = document.querySelector('[role="tablist"]');
  const tabs = [...tablist.querySelectorAll('[role="tab"]')];
  const panels = tabs.map((t) => $(t.dataset.panel));

  function selectTab(targetTab, shouldFocus = false) {
    for (let i = 0; i < tabs.length; i++) {
      const tab = tabs[i];
      const panel = panels[i];
      const active = tab === targetTab;
      tab.setAttribute('aria-selected', String(active));
      tab.toggleAttribute('focusgroupstart', active);
      if (!Object.hasOwn(HTMLElement.prototype, 'focusGroup')) {
        tab.tabIndex = active ? 0 : -1;
      }
      if (active) {
        panel.removeAttribute('hidden');
        panel.tabIndex = 0;
      } else {
        panel.setAttribute('hidden', 'until-found');
        panel.removeAttribute('tabindex');
      }
    }
    targetTab.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    if (shouldFocus) targetTab.focus();
  }

  for (const tab of tabs) {
    tab.addEventListener('click', () => selectTab(tab, false));
  }

  // Sync tab selection when browser Find-in-Page reveals a hidden="until-found" panel
  for (let i = 0; i < panels.length; i++) {
    panels[i].addEventListener('beforematch', () => selectTab(tabs[i], false));
  }

  // Offline roving-tabindex fallback when native focusgroup is unavailable
  if (!Object.hasOwn(HTMLElement.prototype, 'focusGroup')) {
    tabs.forEach((tab, idx) => {
      tab.tabIndex = idx === 0 ? 0 : -1;
    });
    tablist.addEventListener('keydown', (e) => {
      const idx = tabs.indexOf(document.activeElement);
      if (idx === -1) return;
      let next = idx;
      if (e.key === 'ArrowRight') next = (idx + 1) % tabs.length;
      else if (e.key === 'ArrowLeft') next = (idx - 1 + tabs.length) % tabs.length;
      else if (e.key === 'Home') next = 0;
      else if (e.key === 'End') next = tabs.length - 1;
      else return;
      e.preventDefault();
      selectTab(tabs[next], true);
    });
  }

  // Scroll-fade fallback when CSS scroll-driven animations are unavailable
  if (!CSS.supports('animation-timeline', 'scroll()')) {
    const [first, last] = [tablist.firstElementChild, tablist.lastElementChild];
    if (first && last) {
      const obs = new IntersectionObserver(
        (entries) => {
          for (const { target, intersectionRatio } of entries) {
            tablist.classList.toggle(target === first ? 'more-start' : 'more-end', intersectionRatio < 1);
          }
        },
        { root: tablist, threshold: 1, rootMargin: '1px' },
      );
      obs.observe(first);
      obs.observe(last);
    }
  }

  return { selectTabById: (id) => selectTab($(id), false) };
}

/* =====================================================================
 * 4. Safe DOM Helpers
 * ===================================================================== */
function clearEl(el) {
  while (el.firstChild) el.removeChild(el.firstChild);
}

function makeCell(tag, text, opts = {}) {
  const el = document.createElement(tag);
  if (opts.className) el.className = opts.className;
  if (opts.label) el.dataset.label = opts.label;
  if (opts.pill) {
    const span = document.createElement('span');
    span.className = `pill ${opts.pill}`;
    span.textContent = text;
    el.appendChild(span);
  } else {
    el.textContent = text;
  }
  return el;
}

function setPill(el, text, kind = 'pill-neutral') {
  el.textContent = text;
  el.className = `pill ${kind}`;
}

function setBanner(text, kind = 'banner-info') {
  const b = $('status-banner');
  b.textContent = text;
  b.className = `banner ${kind}`;
}

function svgEl(tag, attrs = {}, text = null) {
  const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
  for (const [k, v] of Object.entries(attrs)) {
    el.setAttribute(k, String(v));
  }
  if (text !== null) el.textContent = text;
  return el;
}

/* =====================================================================
 * 5. SVG Visualisations (Built Directly from COBOL CSV Outputs)
 * ===================================================================== */
function renderForestChart(rows) {
  const host = $('baci-forest-chart');
  clearEl(host);

  const valid = (rows || []).filter((r) => r.calculable === 'Y');
  if (valid.length === 0) {
    const p = document.createElement('p');
    p.className = 'muted-note';
    p.textContent = 'No calculable BACI estimates available for the current run.';
    host.appendChild(p);
    return;
  }

  const shown = valid.slice(0, 16);
  const vals = [0];
  for (const r of shown) {
    const est = Number(r.baci_estimate);
    if (Number.isFinite(est)) vals.push(est);
    if (r.ci_status === 'REPORTED') {
      vals.push(Number(r.ci_95_low), Number(r.ci_95_high));
    }
    if (r.loso_status === 'COMPUTED') {
      vals.push(Number(r.loso_min_baci), Number(r.loso_max_baci));
    }
  }
  const minVal = Math.min(...vals);
  const maxVal = Math.max(...vals);
  const span = Math.max(maxVal - minVal, 2);
  const lo = minVal - span * 0.16;
  const hi = maxVal + span * 0.22;

  const width = 560;
  const rowH = 44;
  const padL = 135;
  const padR = 115;
  const padT = 26;
  const padB = 34;
  const height = padT + shown.length * rowH + padB;
  const plotW = width - padL - padR;
  const xOf = (v) => padL + ((v - lo) / (hi - lo)) * plotW;

  const svg = svgEl('svg', {
    viewBox: `0 0 ${width} ${height}`,
    role: 'img',
    'aria-label': 'BACI point estimates with bootstrap confidence intervals and leave-one-site-out ranges',
  });

  // Grid ticks
  const ticks = 5;
  for (let t = 0; t <= ticks; t++) {
    const tv = lo + (t / ticks) * (hi - lo);
    const tx = xOf(tv);
    svg.appendChild(
      svgEl('line', {
        x1: tx,
        y1: padT - 6,
        x2: tx,
        y2: height - padB,
        stroke: 'currentColor',
        'stroke-opacity': '0.12',
      }),
    );
    svg.appendChild(
      svgEl(
        'text',
        {
          x: tx,
          y: height - 10,
          'text-anchor': 'middle',
          'font-size': '10.5',
          fill: 'currentColor',
          opacity: '0.65',
        },
        tv.toFixed(1),
      ),
    );
  }

  // Zero reference line
  const zeroX = xOf(0);
  svg.appendChild(
    svgEl('line', {
      x1: zeroX,
      y1: padT - 8,
      x2: zeroX,
      y2: height - padB,
      stroke: 'currentColor',
      'stroke-opacity': '0.5',
      'stroke-width': '1.5',
      'stroke-dasharray': '4,3',
    }),
  );
  svg.appendChild(
    svgEl(
      'text',
      { x: zeroX, y: 14, 'text-anchor': 'middle', 'font-size': '10.5', fill: 'currentColor', opacity: '0.72' },
      '0 (No diff)',
    ),
  );

  shown.forEach((r, idx) => {
    const y = padT + idx * rowH + rowH / 2;
    const est = Number(r.baci_estimate);
    const ex = xOf(est);
    const color = est >= 0 ? 'var(--accent)' : 'var(--neg)';

    svg.appendChild(
      svgEl(
        'text',
        {
          x: 6,
          y: y - 1,
          'font-size': '11.5',
          'font-weight': '600',
          'font-family': 'var(--font-mono)',
          fill: 'currentColor',
        },
        r.species_code,
      ),
    );
    svg.appendChild(
      svgEl(
        'text',
        {
          x: 6,
          y: y + 12,
          'font-size': '9.8',
          fill: 'currentColor',
          opacity: '0.68',
        },
        r.method.length > 20 ? `${r.method.slice(0, 19)}…` : r.method,
      ),
    );

    // LOSO sensitivity bracket (subtle thicker inner bar)
    if (r.loso_status === 'COMPUTED') {
      const lx1 = xOf(Number(r.loso_min_baci));
      const lx2 = xOf(Number(r.loso_max_baci));
      svg.appendChild(
        svgEl('line', {
          x1: lx1,
          y1: y,
          x2: lx2,
          y2: y,
          stroke: 'var(--warn)',
          'stroke-width': '6',
          'stroke-opacity': '0.35',
          'stroke-linecap': 'round',
        }),
      );
    }

    // 95% Bootstrap CI whisker (only when REPORTED)
    if (r.ci_status === 'REPORTED') {
      const cx1 = xOf(Number(r.ci_95_low));
      const cx2 = xOf(Number(r.ci_95_high));
      svg.appendChild(svgEl('line', { x1: cx1, y1: y, x2: cx2, y2: y, stroke: color, 'stroke-width': '2.2' }));
      svg.appendChild(svgEl('line', { x1: cx1, y1: y - 5, x2: cx1, y2: y + 5, stroke: color, 'stroke-width': '2' }));
      svg.appendChild(svgEl('line', { x1: cx2, y1: y - 5, x2: cx2, y2: y + 5, stroke: color, 'stroke-width': '2' }));
    }

    // Point estimate dot
    const dot = svgEl('circle', { cx: ex, cy: y, r: '5.5', fill: color, stroke: 'var(--surface)', 'stroke-width': '1.5' });
    const title = svgEl(
      'title',
      {},
      `${r.species_code} (${r.method}): BACI = ${r.baci_estimate} detections/hr | CI: ${
        r.ci_status === 'REPORTED' ? `[${r.ci_95_low}, ${r.ci_95_high}]` : r.ci_status
      }`,
    );
    dot.appendChild(title);
    svg.appendChild(dot);

    // Numeric label on right margin
    const sign = est > 0 ? '+' : '';
    const ciTag = r.ci_status === 'REPORTED' ? '95% CI' : 'CI withheld';
    svg.appendChild(
      svgEl(
        'text',
        { x: width - padR + 8, y: y + 1, 'font-size': '11.5', 'font-weight': '600', fill: color },
        `${sign}${est.toFixed(2)}`,
      ),
    );
    svg.appendChild(
      svgEl(
        'text',
        { x: width - padR + 8, y: y + 14, 'font-size': '9.5', fill: 'currentColor', opacity: '0.65' },
        ciTag,
      ),
    );
  });

  host.appendChild(svg);
}

function renderSlopeChart(siteRows, stratumKey) {
  const host = $('site-slope-chart');
  clearEl(host);

  const filtered = (siteRows || []).filter(
    (s) => `${s.species_code} | ${s.method}` === stratumKey && s.status === 'COMPLETE',
  );
  if (filtered.length === 0) {
    const p = document.createElement('p');
    p.className = 'muted-note';
    p.textContent = 'No complete sites (requiring both PRE and POST explicit observations) for this stratum.';
    host.appendChild(p);
    return;
  }

  const rates = [];
  for (const s of filtered) {
    rates.push(Number(s.pre_mean), Number(s.post_mean));
  }
  const minR = Math.min(0, ...rates);
  const maxR = Math.max(1, ...rates);
  const span = Math.max(maxR - minR, 1);
  const yLo = Math.max(0, minR - span * 0.08);
  const yHi = maxR + span * 0.14;

  const width = 490;
  const shownSites = filtered.slice(0, 40);
  const showLabels = shownSites.length <= 14;
  const minGap = 13.5;
  const height = showLabels ? Math.max(230, 62 + shownSites.length * 14.5) : 230;
  const xPre = 95;
  const xPost = 320;
  const padT = 30;
  const padB = 34;
  const yOf = (v) => height - padB - ((v - yLo) / (yHi - yLo)) * (height - padT - padB);

  const svg = svgEl('svg', {
    viewBox: `0 0 ${width} ${height}`,
    role: 'img',
    'aria-label': `Site-level PRE to POST observation rate trajectories for ${stratumKey}`,
  });

  // Period vertical axes
  for (const [x, lbl] of [
    [xPre, 'PRE (Before)'],
    [xPost, 'POST (After)'],
  ]) {
    svg.appendChild(
      svgEl('line', {
        x1: x,
        y1: padT,
        x2: x,
        y2: height - padB,
        stroke: 'currentColor',
        'stroke-opacity': '0.25',
        'stroke-width': '1.2',
      }),
    );
    svg.appendChild(
      svgEl('text', { x, y: height - 10, 'text-anchor': 'middle', 'font-size': '11', 'font-weight': '600', fill: 'currentColor' }, lbl),
    );
  }

  // Horizontal reference ticks
  for (let t = 0; t <= 4; t++) {
    const rv = yLo + (t / 4) * (yHi - yLo);
    const ty = yOf(rv);
    svg.appendChild(
      svgEl('line', { x1: xPre, y1: ty, x2: xPost, y2: ty, stroke: 'currentColor', 'stroke-opacity': '0.09' }),
    );
    svg.appendChild(
      svgEl('text', { x: xPre - 10, y: ty + 3, 'text-anchor': 'end', 'font-size': '10', fill: 'currentColor', opacity: '0.65' }, rv.toFixed(1)),
    );
  }

  // Legend
  svg.appendChild(svgEl('circle', { cx: xPre, cy: 13, r: 4, fill: 'var(--accent)' }));
  svg.appendChild(svgEl('text', { x: xPre + 9, y: 17, 'font-size': '11', fill: 'currentColor' }, 'IMPACT sites'));
  svg.appendChild(svgEl('circle', { cx: xPre + 125, cy: 13, r: 4, fill: 'var(--ctrl-color)' }));
  svg.appendChild(svgEl('text', { x: xPre + 134, y: 17, 'font-size': '11', fill: 'currentColor' }, 'CONTROL sites'));

  // Compute collision-free right-side label positions via vertical relaxation
  const labelSlots = shownSites
    .map((s) => ({
      s,
      isImp: s.site_role === 'IMPACT',
      y1: yOf(Number(s.pre_mean)),
      y2: yOf(Number(s.post_mean)),
      labelY: yOf(Number(s.post_mean)),
    }))
    .sort((a, b) => a.y2 - b.y2 || a.s.site_id.localeCompare(b.s.site_id));

  if (showLabels) {
    for (let pass = 0; pass < 8; pass++) {
      for (let i = 1; i < labelSlots.length; i++) {
        const diff = labelSlots[i].labelY - labelSlots[i - 1].labelY;
        if (diff < minGap) {
          const push = (minGap - diff) / 2;
          labelSlots[i - 1].labelY -= push;
          labelSlots[i].labelY += push;
        }
      }
      if (labelSlots.length > 0) {
        if (labelSlots[0].labelY < padT) labelSlots[0].labelY = padT;
        const maxY = height - padB;
        if (labelSlots[labelSlots.length - 1].labelY > maxY) {
          labelSlots[labelSlots.length - 1].labelY = maxY;
        }
      }
    }
  }

  labelSlots.forEach(({ s, isImp, y1, y2, labelY }) => {
    const color = isImp ? 'var(--accent)' : 'var(--ctrl-color)';
    const g = svgEl('g');
    const tip = `${s.site_id} (${s.site_role}): PRE=${Number(s.pre_mean).toFixed(2)} → POST=${Number(s.post_mean).toFixed(2)} (Δ=${Number(s.site_change).toFixed(2)})`;
    g.appendChild(svgEl('title', {}, tip));
    g.appendChild(
      svgEl('line', {
        x1: xPre,
        y1,
        x2: xPost,
        y2,
        stroke: color,
        'stroke-width': shownSites.length > 16 ? '1.6' : '2.2',
        'stroke-opacity': shownSites.length > 16 ? '0.65' : '0.88',
      }),
    );
    g.appendChild(svgEl('circle', { cx: xPre, cy: y1, r: '3.6', fill: color }));
    g.appendChild(svgEl('circle', { cx: xPost, cy: y2, r: '3.6', fill: color }));
    if (showLabels) {
      g.appendChild(
        svgEl('line', {
          x1: xPost + 4,
          y1: y2,
          x2: xPost + 14,
          y2: labelY,
          stroke: color,
          'stroke-width': '1',
          'stroke-opacity': '0.55',
        }),
      );
      g.appendChild(
        svgEl(
          'text',
          { x: xPost + 18, y: labelY + 3.5, 'font-size': '10.2', 'font-family': 'var(--font-mono)', fill: color },
          `${s.site_id} (${Number(s.site_change) >= 0 ? '+' : ''}${Number(s.site_change).toFixed(1)})`,
        ),
      );
    }
    svg.appendChild(g);
  });

  host.appendChild(svg);
}

/* =====================================================================
 * 6. Render Bundle into All Views
 * ===================================================================== */
function renderBundle(bundle) {
  state.bundle = bundle;
  const outParam = encodeURIComponent($('out-path').value.trim());
  const rawLink = $('open-raw-report');
  rawLink.href = `/api/raw-report?out=${outParam}`;
  rawLink.style.display = bundle?.hasHtmlReport ? 'inline-flex' : 'none';

  const dqMap = new Map();
  for (const r of bundle?.dataQuality?.rows || []) {
    dqMap.set(r.metric, r.value);
  }

  // Manifest header badge
  const manStatus = bundle?.receipt?.input_manifest?.status || dqMap.get('manifest_status') || (bundle?.manifestText ? 'PRESENT' : 'NOT_PRESENT');
  if (manStatus === 'PRESENT' || manStatus === 'VERIFIED') {
    setPill($('manifest-badge'), `Manifest: ${manStatus}`, 'pill-ok');
    setPill($('manifest-detail-badge'), manStatus, 'pill-ok');
  } else {
    setPill($('manifest-badge'), `Manifest: ${manStatus}`, 'pill-warn');
    setPill($('manifest-detail-badge'), manStatus, 'pill-warn');
  }

  // KPIs
  const studyId = bundle?.receipt?.study_id || dqMap.get('study_id') || '—';
  const activeMethod = bundle?.receipt?.analysis_configuration?.active_method || '—';
  $('kpi-study').textContent = studyId;
  $('kpi-method').textContent = `Method: ${activeMethod}`;

  const sitesValid = dqMap.get('sites_valid') ?? bundle?.receipt?.record_counts?.sites_valid ?? '—';
  const sitesImp = dqMap.get('sites_impact') ?? bundle?.receipt?.record_counts?.sites_impact ?? '—';
  const sitesCtrl = dqMap.get('sites_control') ?? bundle?.receipt?.record_counts?.sites_control ?? '—';
  const survValid = dqMap.get('surveys_valid') ?? bundle?.receipt?.record_counts?.surveys_valid ?? '—';
  const survTrans = dqMap.get('surveys_transition_excluded') ?? bundle?.receipt?.record_counts?.excluded_transition_surveys ?? '0';
  $('kpi-sites').textContent = `${sitesValid} (${sitesImp} / ${sitesCtrl})`;
  $('kpi-surveys').textContent = `Surveys: ${survValid} (Trans excl: ${survTrans})`;

  const obsValid = dqMap.get('observations_valid') ?? bundle?.receipt?.record_counts?.observations_valid ?? '—';
  const obsZero = dqMap.get('observations_explicit_zero') ?? bundle?.receipt?.record_counts?.observations_explicit_zero ?? '0';
  const obsMiss = dqMap.get('missing_species_survey_cells') ?? bundle?.receipt?.record_counts?.missing_species_survey_cells ?? '0';
  $('kpi-obs').textContent = `${obsValid}`;
  $('kpi-zero-miss').textContent = `Explicit 0: ${obsZero} · Missing: ${obsMiss}`;

  const baciRows = bundle?.baciResults?.rows || [];
  if (baciRows.length > 0 && baciRows[0].calculable === 'Y') {
    const first = baciRows[0];
    const v = Number(first.baci_estimate);
    $('kpi-baci').textContent = `${v > 0 ? '+' : ''}${first.baci_estimate}`;
    $('kpi-ci').textContent =
      first.ci_status === 'REPORTED'
        ? `95% CI: [${first.ci_95_low}, ${first.ci_95_high}]`
        : `95% CI: ${first.ci_status}`;
  } else if (baciRows.length > 0) {
    $('kpi-baci').textContent = 'NA';
    $('kpi-ci').textContent = 'Insufficient complete sites';
  } else {
    $('kpi-baci').textContent = '—';
    $('kpi-ci').textContent = 'Not computed';
  }

  const errCnt = Number(dqMap.get('validation_errors') ?? 0);
  const warnCnt = Number(dqMap.get('validation_warnings') ?? 0);
  $('kpi-val').textContent = errCnt > 0 ? `FAILED (${errCnt})` : 'PASSED';
  $('kpi-warn').textContent = `Warnings: ${warnCnt}`;

  // BACI Table & Charts
  renderBaciTable(baciRows);
  renderForestChart(baciRows);

  // Slope chart stratum selector
  const sel = $('slope-stratum');
  clearEl(sel);
  const strata = [...new Set((bundle?.siteSummaries?.rows || []).map((s) => `${s.species_code} | ${s.method}`))];
  strata.forEach((st) => {
    const opt = document.createElement('option');
    opt.value = st;
    opt.textContent = st;
    sel.appendChild(opt);
  });
  renderSlopeChart(bundle?.siteSummaries?.rows || [], strata[0] || '');

  // Site summaries table
  renderSitesTable(bundle?.siteSummaries?.rows || []);

  // Validation & Data quality tables
  renderValidationTable(bundle?.validationReport?.rows || []);
  renderQualityTable(bundle?.dataQuality?.rows || []);

  // Provenance, Manifest, Receipt, Ledger
  $('manifest-pre').textContent =
    bundle?.manifestText ||
    'No manifest.sha256 found in the study directory. Click "Gen SHA-256" to compute file digests using OS-native SHA-256 tools.';
  $('receipt-pre').textContent = bundle?.receipt
    ? JSON.stringify(bundle.receipt, null, 2)
    : 'No research-receipt.json present (validation-only or halted run).';
  renderSourcesTable(bundle?.sources?.rows || []);
  renderLedgerTable(bundle?.evidenceLedger?.rows || []);
}

function renderBaciTable(rows) {
  const tbody = $('baci-tbody');
  clearEl(tbody);
  if (rows.length === 0) {
    const tr = document.createElement('tr');
    const td = makeCell('td', 'No BACI results present for this output directory.');
    td.colSpan = 13;
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }

  for (const r of rows) {
    const tr = document.createElement('tr');
    tr.appendChild(makeCell('th', r.species_code));
    tr.appendChild(makeCell('td', r.method, { label: 'Method' }));
    tr.appendChild(makeCell('td', `${r.impact_sites} / ${r.control_sites}`, { className: 'num', label: 'Sites (I/C)' }));
    const impSpan = r.calculable === 'Y' ? `${r.impact_pre_mean} → ${r.impact_post_mean}` : 'NA';
    const ctrlSpan = r.calculable === 'Y' ? `${r.control_pre_mean} → ${r.control_post_mean}` : 'NA';
    tr.appendChild(makeCell('td', impSpan, { className: 'num', label: 'Imp PRE → POST' }));
    tr.appendChild(makeCell('td', ctrlSpan, { className: 'num', label: 'Ctrl PRE → POST' }));
    tr.appendChild(makeCell('td', r.impact_change, { className: 'num', label: 'Imp Chg' }));
    tr.appendChild(makeCell('td', r.control_change, { className: 'num', label: 'Ctrl Chg' }));
    tr.appendChild(makeCell('td', r.baci_estimate, { className: 'num mono', label: 'BACI Est' }));
    tr.appendChild(makeCell('td', `${r.coverage_pct}%`, { className: 'num', label: 'Coverage' }));
    tr.appendChild(makeCell('td', r.missing_observations, { className: 'num', label: 'Missing' }));

    const ciText = r.ci_status === 'REPORTED' ? `[${r.ci_95_low}, ${r.ci_95_high}]` : r.ci_status;
    const ciKind = r.ci_status === 'REPORTED' ? 'pill-ok' : 'pill-warn';
    tr.appendChild(makeCell('td', ciText, { pill: ciKind, label: '95% Site Bootstrap CI' }));

    const losoText =
      r.loso_status === 'COMPUTED'
        ? `[${r.loso_min_baci}, ${r.loso_max_baci}] (${r.loso_most_influential_site})`
        : r.loso_status;
    tr.appendChild(makeCell('td', losoText, { label: 'LOSO Sensitivity' }));
    tr.appendChild(makeCell('td', r.warnings || 'None', { label: 'Warnings' }));
    tbody.appendChild(tr);
  }
}

function renderSitesTable(rows) {
  const tbody = $('sites-tbody');
  clearEl(tbody);
  const roleFilter = $('site-role-filter').value;
  const shown = rows.filter((r) => roleFilter === 'ALL' || r.site_role === roleFilter);
  if (shown.length === 0) {
    const tr = document.createElement('tr');
    const td = makeCell('td', 'No site summary rows available.');
    td.colSpan = 13;
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }

  for (const r of shown) {
    const tr = document.createElement('tr');
    tr.appendChild(makeCell('th', r.site_id));
    tr.appendChild(makeCell('td', r.site_role, { pill: r.site_role === 'IMPACT' ? 'pill-ok' : 'pill-neutral', label: 'Role' }));
    tr.appendChild(makeCell('td', r.species_code, { className: 'mono', label: 'Species' }));
    tr.appendChild(makeCell('td', r.method, { label: 'Method' }));
    tr.appendChild(makeCell('td', `${r.pre_observations}/${r.pre_surveys}`, { className: 'num', label: 'PRE (Obs/Surv)' }));
    tr.appendChild(makeCell('td', `${r.post_observations}/${r.post_surveys}`, { className: 'num', label: 'POST (Obs/Surv)' }));
    tr.appendChild(makeCell('td', r.explicit_zero_observations, { className: 'num', label: 'Explicit 0' }));
    tr.appendChild(makeCell('td', r.missing_observations, { className: 'num', label: 'Missing' }));
    tr.appendChild(makeCell('td', r.pre_mean, { className: 'num', label: 'PRE Mean' }));
    tr.appendChild(makeCell('td', r.post_mean, { className: 'num', label: 'POST Mean' }));
    tr.appendChild(makeCell('td', r.site_change, { className: 'num mono', label: 'Site Change' }));
    tr.appendChild(makeCell('td', `${r.coverage_pct}%`, { className: 'num', label: 'Coverage %' }));
    tr.appendChild(
      makeCell('td', r.status, {
        pill: r.status === 'COMPLETE' ? 'pill-ok' : 'pill-warn',
        label: 'Status',
      }),
    );
    tbody.appendChild(tr);
  }
}

function renderValidationTable(rows) {
  const tbody = $('val-tbody');
  clearEl(tbody);
  if (rows.length === 0) {
    const tr = document.createElement('tr');
    const td = makeCell('td', 'Zero validation errors or warnings recorded.');
    td.colSpan = 6;
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }
  for (const r of rows) {
    const tr = document.createElement('tr');
    const sevKind = r.severity === 'ERROR' ? 'pill-err' : r.severity === 'WARNING' ? 'pill-warn' : 'pill-neutral';
    tr.appendChild(makeCell('th', r.severity, { pill: sevKind }));
    tr.appendChild(makeCell('td', r.code, { className: 'mono', label: 'Code' }));
    tr.appendChild(makeCell('td', r.file, { className: 'mono', label: 'File' }));
    tr.appendChild(makeCell('td', r.row, { className: 'num', label: 'Row' }));
    tr.appendChild(makeCell('td', r.field, { className: 'mono', label: 'Field' }));
    tr.appendChild(makeCell('td', r.message, { label: 'Explanation' }));
    tbody.appendChild(tr);
  }
}

function renderQualityTable(rows) {
  const tbody = $('dq-tbody');
  clearEl(tbody);
  for (const r of rows) {
    const tr = document.createElement('tr');
    tr.appendChild(makeCell('th', r.metric));
    tr.appendChild(makeCell('td', r.category, { label: 'Category' }));
    tr.appendChild(makeCell('td', r.value, { className: 'num mono', label: 'Value' }));
    tr.appendChild(makeCell('td', r.notes, { label: 'Notes' }));
    tbody.appendChild(tr);
  }
}

function renderSourcesTable(rows) {
  const tbody = $('sources-tbody');
  clearEl(tbody);
  if (rows.length === 0) {
    const tr = document.createElement('tr');
    const td = makeCell('td', 'No source rows loaded.');
    td.colSpan = 6;
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }
  for (const r of rows) {
    const tr = document.createElement('tr');
    tr.appendChild(makeCell('th', r.source_id));
    tr.appendChild(makeCell('td', r.source_type, { label: 'Type' }));
    tr.appendChild(makeCell('td', r.source_title, { label: 'Title' }));
    tr.appendChild(makeCell('td', r.organisation, { label: 'Organisation' }));
    tr.appendChild(makeCell('td', r.licence, { label: 'Licence' }));
    tr.appendChild(makeCell('td', r.accessed_date, { className: 'mono', label: 'Accessed' }));
    tbody.appendChild(tr);
  }
}

function renderLedgerTable(rows) {
  const tbody = $('ledger-tbody');
  clearEl(tbody);
  if (rows.length === 0) {
    const tr = document.createElement('tr');
    const td = makeCell('td', 'No evidence-ledger.csv history in this output directory yet.');
    td.colSpan = 11;
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }
  for (const r of [...rows].reverse()) {
    const tr = document.createElement('tr');
    tr.appendChild(makeCell('th', r.run_id));
    tr.appendChild(makeCell('td', r.timestamp, { className: 'mono', label: 'Timestamp' }));
    tr.appendChild(makeCell('td', r.command, { label: 'Command' }));
    tr.appendChild(makeCell('td', r.study_id, { className: 'mono', label: 'Study' }));
    tr.appendChild(
      makeCell('td', r.validation_outcome, {
        pill: r.validation_outcome === 'PASSED' ? 'pill-ok' : 'pill-err',
        label: 'Outcome',
      }),
    );
    tr.appendChild(makeCell('td', r.active_method, { label: 'Method' }));
    tr.appendChild(makeCell('td', r.seed, { className: 'num', label: 'Seed' }));
    tr.appendChild(makeCell('td', r.bootstrap_iterations, { className: 'num', label: 'Boot' }));
    tr.appendChild(makeCell('td', r.observations_valid, { className: 'num', label: 'Obs' }));
    tr.appendChild(makeCell('td', `${r.errors_count} / ${r.warnings_count}`, { className: 'num', label: 'Err / Warn' }));
    tr.appendChild(makeCell('td', r.manifest_status, { label: 'Manifest' }));
    tbody.appendChild(tr);
  }
}

/* =====================================================================
 * 7. Raw Input CSV Inspector
 * ===================================================================== */
async function loadStudyInputs() {
  const studyPath = $('study-path').value.trim();
  if (!studyPath) return;
  try {
    const res = await fetch(`/api/study-files?study=${encodeURIComponent(studyPath)}`);
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to read study files');
    state.inputFiles = data;
    renderSelectedInputFile();
  } catch (err) {
    $('input-file-meta').textContent = `Could not inspect study files: ${err.message}`;
  }
}

function renderSelectedInputFile() {
  const fname = $('input-file-select').value;
  const thead = $('input-thead');
  const tbody = $('input-tbody');
  clearEl(thead);
  clearEl(tbody);

  const entry = state.inputFiles?.files?.[fname];
  if (!entry || !entry.exists) {
    $('input-file-meta').textContent = `${fname} does not exist in ${$('study-path').value.trim()}.`;
    return;
  }

  const parsed = entry.parsed;
  $('input-file-meta').textContent = `${fname} · ${entry.sizeBytes} bytes · ${parsed?.totalRows ?? 0} data row(s)${
    parsed?.truncated ? ' (showing first 500)' : ''
  } · Read-only`;

  if (!parsed || parsed.headers.length === 0) return;

  const htr = document.createElement('tr');
  for (const h of parsed.headers) {
    htr.appendChild(makeCell('th', h));
  }
  thead.appendChild(htr);

  for (const row of parsed.rows) {
    const tr = document.createElement('tr');
    parsed.headers.forEach((h, idx) => {
      tr.appendChild(makeCell(idx === 0 ? 'th' : 'td', row[h] ?? '', { label: h }));
    });
    tbody.appendChild(tr);
  }
}

/* =====================================================================
 * 8. Execute Native COBOL Commands via Local Bridge
 * ===================================================================== */
function setBusy(flag) {
  state.busy = flag;
  for (const id of ['btn-analyze', 'btn-validate', 'btn-report', 'btn-manifest', 'btn-verify']) {
    $(id).disabled = flag;
  }
}

let tabApi = null;

async function runAction(action, overrides = {}) {
  if (state.busy) return;
  setBusy(true);
  setPill($('exec-status'), 'Running COBOL…', 'pill-warn');

  const payload = {
    action,
    studyPath: overrides.studyPath ?? $('study-path').value.trim(),
    outPath: overrides.outPath ?? $('out-path').value.trim(),
    seed: $('seed-input').value.trim(),
    bootstrap: $('bootstrap-input').value.trim(),
    species: $('species-filter').value.trim(),
    method: $('method-filter').value.trim(),
  };

  try {
    const res = await fetch('/api/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Request failed');

    const ex = data.exec;
    $('exec-cmd').textContent = ex.commandLine;
    const combined = [ex.stdout.trim(), ex.stderr.trim()].filter(Boolean).join('\n');
    $('exec-log').textContent = combined || `(completed with exit code ${ex.exitCode})`;
    setPill(
      $('exec-status'),
      `Exit ${ex.exitCode} · ${ex.durationMs} ms`,
      ex.ok ? 'pill-ok' : ex.exitCode === 2 ? 'pill-err' : 'pill-warn',
    );

    if (data.studies) populateStudyPresets(data.studies, payload.studyPath);
    if (data.bundle) renderBundle(data.bundle);
    await loadStudyInputs();

    if (action === 'init' && ex.ok) {
      $('study-path').value = payload.studyPath;
      $('out-path').value = `${payload.studyPath}-out`;
      setBanner(`Initialised new FIELDLEDGER study templates in "${payload.studyPath}".`, 'banner-ok');
      tabApi.selectTabById('tab-inputs');
    } else if (action === 'verify') {
      if (ex.ok) {
        setPill($('manifest-badge'), 'Manifest: VERIFIED', 'pill-ok');
        setBanner('SHA-256 integrity verification PASSED: all input CSV files matched stored digests and sizes.', 'banner-ok');
      } else {
        setPill($('manifest-badge'), 'Manifest: FAILED', 'pill-err');
        setBanner('SHA-256 integrity verification FAILED: input file modified, missing, or manifest corrupted.', 'banner-err');
      }
      tabApi.selectTabById('tab-provenance');
    } else if (action === 'manifest') {
      if (ex.ok) {
        setPill($('manifest-badge'), 'Manifest: PRESENT', 'pill-ok');
        setBanner('Generated manifest.sha256 using platform-native SHA-256 checksums.', 'banner-ok');
        if (state.bundle) {
          await loadExistingResults(payload.outPath, payload.studyPath);
        }
      } else {
        setBanner(`Manifest generation failed (exit ${ex.exitCode}). Check COBOL console.`, 'banner-err');
      }
      tabApi.selectTabById('tab-provenance');
    } else if (action === 'validate') {
      if (ex.ok) {
        setBanner(`Validation PASSED in ${ex.durationMs} ms with 0 errors.`, 'banner-ok');
      } else {
        setBanner(`Validation FAILED (exit ${ex.exitCode}). Inspect diagnostics below.`, 'banner-err');
      }
      tabApi.selectTabById('tab-validation');
    } else if (action === 'analyze') {
      if (ex.ok) {
        setBanner(`COBOL BACI analysis completed in ${ex.durationMs} ms. Research receipt and reports verified.`, 'banner-ok');
        tabApi.selectTabById('tab-baci');
      } else if (ex.exitCode === 2) {
        setBanner('Principle 1 Enforced: Dataset failed validation — BACI analysis was blocked. Inspect errors below.', 'banner-err');
        tabApi.selectTabById('tab-validation');
      } else {
        setBanner(`Analysis exited with code ${ex.exitCode}. Inspect COBOL execution console.`, 'banner-err');
      }
    } else if (action === 'report') {
      setBanner(
        ex.ok
          ? 'Regenerated report.md and report.html from verified research-receipt.json.'
          : 'Report regeneration refused: research-receipt.json missing or mismatched with study_id.',
        ex.ok ? 'banner-ok' : 'banner-err',
      );
    }
  } catch (err) {
    setPill($('exec-status'), 'Error', 'pill-err');
    $('exec-log').textContent = String(err.message || err);
    setBanner(`Execution error: ${err.message}`, 'banner-err');
  } finally {
    setBusy(false);
  }
}

async function loadExistingResults(outPath, studyPath) {
  const res = await fetch(
    `/api/results?out=${encodeURIComponent(outPath)}&study=${encodeURIComponent(studyPath)}`,
  );
  if (res.ok) {
    const bundle = await res.json();
    renderBundle(bundle);
  }
}

function populateStudyPresets(studies, selectedPath = null) {
  state.studies = studies;
  const sel = $('study-preset');
  const current = selectedPath ?? $('study-path').value.trim();
  clearEl(sel);

  const groups = new Map();
  for (const s of studies) {
    if (!groups.has(s.group)) groups.set(s.group, []);
    groups.get(s.group).push(s);
  }

  for (const [grpLabel, items] of groups.entries()) {
    const og = document.createElement('optgroup');
    og.label = grpLabel;
    for (const s of items) {
      const opt = document.createElement('option');
      opt.value = s.studyPath;
      opt.textContent = `${s.label} — ${s.title}`;
      if (s.studyPath === current) opt.selected = true;
      og.appendChild(opt);
    }
    sel.appendChild(og);
  }
}

/* =====================================================================
 * 9. Bootstrap Application
 * ===================================================================== */
async function initApp() {
  syncThemeControls();
  setupDialogs();
  tabApi = setupTabs();

  $('study-preset').addEventListener('change', async () => {
    const chosen = state.studies.find((s) => s.studyPath === $('study-preset').value);
    if (!chosen) return;
    $('study-path').value = chosen.studyPath;
    $('out-path').value = chosen.studyPath === 'examples/wetland-demo' ? 'output/wetland-demo' : chosen.defaultOutPath;
    $('study-blurb').textContent = chosen.description || chosen.title;
    await loadStudyInputs();
    await loadExistingResults($('out-path').value.trim(), chosen.studyPath);
  });

  $('slope-stratum').addEventListener('change', () => {
    renderSlopeChart(state.bundle?.siteSummaries?.rows || [], $('slope-stratum').value);
  });

  $('site-role-filter').addEventListener('change', () => {
    renderSitesTable(state.bundle?.siteSummaries?.rows || []);
  });

  $('input-file-select').addEventListener('change', renderSelectedInputFile);
  $('btn-reload-inputs').addEventListener('click', loadStudyInputs);

  $('btn-analyze').addEventListener('click', () => runAction('analyze'));
  $('btn-validate').addEventListener('click', () => runAction('validate'));
  $('btn-manifest').addEventListener('click', () => runAction('manifest'));
  $('btn-verify').addEventListener('click', () => runAction('verify'));
  $('btn-report').addEventListener('click', () => runAction('report'));

  $('btn-copy-receipt').addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText($('receipt-pre').textContent);
      $('btn-copy-receipt').textContent = 'Copied!';
      setTimeout(() => {
        $('btn-copy-receipt').textContent = 'Copy JSON';
      }, 1500);
    } catch {
      // Clipboard may be restricted in non-secure contexts
    }
  });

  // Load workspace discovery
  try {
    const res = await fetch('/api/workspace');
    const ws = await res.json();
    setPill(
      $('engine-badge'),
      ws.engineAvailable ? ws.engineVersion : 'COBOL binary missing',
      ws.engineAvailable ? 'pill-ok' : 'pill-err',
    );
    populateStudyPresets(ws.studies, 'examples/wetland-demo');
    const first = ws.studies.find((s) => s.studyPath === 'examples/wetland-demo');
    if (first) $('study-blurb').textContent = first.description || first.title;
    await loadStudyInputs();
    await loadExistingResults('output/wetland-demo', 'examples/wetland-demo');
  } catch (err) {
    setBanner(`Failed to connect to local FIELDLEDGER server: ${err.message}`, 'banner-err');
  }
}

initApp();

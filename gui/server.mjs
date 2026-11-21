#!/usr/bin/env node
/**
 * FIELDLEDGER Local GUI Workbench Server (Zero External Dependencies)
 * Thin offline HTTP server binding strictly to 127.0.0.1.
 * All validation, BACI statistics, bootstrap resampling, manifest hashing,
 * and report generation are executed directly by the compiled GnuCOBOL
 * binary (build/fieldledger.exe or build/fieldledger).
 */

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '..');
const PUBLIC_DIR = path.join(__dirname, 'public');
const IS_WIN = process.platform === 'win32';
const FL_EXE = path.join(REPO_ROOT, 'build', IS_WIN ? 'fieldledger.exe' : 'fieldledger');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.csv': 'text/csv; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
};

function parseArgs(argv) {
  let port = 4173;
  for (let i = 2; i < argv.length; i++) {
    if ((argv[i] === '--port' || argv[i] === '-p') && argv[i + 1]) {
      const parsed = Number.parseInt(argv[i + 1], 10);
      if (Number.isInteger(parsed) && parsed >= 1024 && parsed <= 65535) {
        port = parsed;
      }
      i++;
    }
  }
  return { port };
}

function sendJson(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  res.end(body);
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 1024 * 1024) {
        reject(new Error('Request body too large'));
      }
    });
    req.on('end', () => {
      if (!raw.trim()) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new Error('Invalid JSON payload'));
      }
    });
    req.on('error', reject);
  });
}

function resolveUserPath(inputPath) {
  if (typeof inputPath !== 'string' || !inputPath.trim()) {
    throw new Error('Path is required');
  }
  const trimmed = inputPath.trim();
  if (/[\x00-\x1f]/.test(trimmed)) {
    throw new Error('Path contains invalid control characters');
  }
  return path.isAbsolute(trimmed) ? path.normalize(trimmed) : path.resolve(REPO_ROOT, trimmed);
}

function runFieldledger(args) {
  return new Promise((resolve) => {
    if (!fs.existsSync(FL_EXE)) {
      resolve({
        ok: false,
        exitCode: -1,
        stdout: '',
        stderr: `Compiled COBOL binary not found at ${FL_EXE}. Run scripts/build.ps1 or scripts/build.sh first.`,
        durationMs: 0,
        commandLine: `fieldledger ${args.join(' ')}`,
      });
      return;
    }
    const start = process.hrtime.bigint();
    execFile(
      FL_EXE,
      args,
      { cwd: REPO_ROOT, timeout: 120000, maxBuffer: 8 * 1024 * 1024 },
      (err, stdout, stderr) => {
        const elapsedMs = Number((process.hrtime.bigint() - start) / 1000000n);
        const exitCode = err ? (typeof err.code === 'number' ? err.code : 1) : 0;
        resolve({
          ok: exitCode === 0,
          exitCode,
          stdout: String(stdout ?? ''),
          stderr: String(stderr ?? ''),
          durationMs: elapsedMs,
          commandLine: `fieldledger ${args.map((a) => (/\s/.test(a) ? `"${a}"` : a)).join(' ')}`,
        });
      },
    );
  });
}

/**
 * RFC 4180 CSV parser strictly for displaying COBOL-generated CSV outputs in the GUI.
 * Never performs scientific calculations.
 */
function parseCsvText(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  const src = text.replace(/^\uFEFF/, '');

  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (inQuotes) {
      if (ch === '"') {
        if (src[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === ',') {
      row.push(field);
      field = '';
    } else if (ch === '\r') {
      if (src[i + 1] === '\n') i++;
      row.push(field);
      field = '';
      if (row.some((cell) => cell !== '')) rows.push(row);
      row = [];
    } else if (ch === '\n') {
      row.push(field);
      field = '';
      if (row.some((cell) => cell !== '')) rows.push(row);
      row = [];
    } else {
      field += ch;
    }
  }
  if (field !== '' || row.length > 0) {
    row.push(field);
    if (row.some((cell) => cell !== '')) rows.push(row);
  }
  if (rows.length === 0) return { headers: [], rows: [] };
  const headers = rows[0];
  const objects = rows.slice(1).map((r) => {
    const obj = {};
    headers.forEach((h, idx) => {
      obj[h] = r[idx] ?? '';
    });
    return obj;
  });
  return { headers, rows: objects };
}

function safeReadCsv(filePath, maxRows = 2000) {
  if (!fs.existsSync(filePath)) return null;
  const text = fs.readFileSync(filePath, 'utf8');
  const parsed = parseCsvText(text);
  return {
    headers: parsed.headers,
    totalRows: parsed.rows.length,
    truncated: parsed.rows.length > maxRows,
    rows: parsed.rows.slice(0, maxRows),
  };
}

function discoverStudies() {
  const studies = [];
  const scanGroup = (baseRel, groupLabel) => {
    const absBase = path.join(REPO_ROOT, baseRel);
    if (!fs.existsSync(absBase)) return;
    for (const entry of fs.readdirSync(absBase, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const studyDir = path.join(absBase, entry.name);
      const studyCsv = path.join(studyDir, 'study.csv');
      if (!fs.existsSync(studyCsv)) continue;
      const relPath = path.join(baseRel, entry.name).replace(/\\/g, '/');
      let title = entry.name;
      let studyId = '';
      let description = '';
      try {
        const parsed = parseCsvText(fs.readFileSync(studyCsv, 'utf8'));
        if (parsed.rows[0]) {
          studyId = parsed.rows[0].study_id || '';
          title = parsed.rows[0].study_title || entry.name;
          description = parsed.rows[0].study_description || '';
        }
      } catch {
        // Malformed CSV fixtures (e.g. invalid-csv) still appear cleanly for testing
        title = `${entry.name} (malformed CSV fixture)`;
      }
      studies.push({
        id: relPath,
        label: entry.name,
        group: groupLabel,
        studyPath: relPath,
        defaultOutPath: `output/gui-${entry.name}`,
        studyId,
        title,
        description,
        hasManifest: fs.existsSync(path.join(studyDir, 'manifest.sha256')),
      });
    }
  };

  scanGroup('examples', 'Reference Examples');
  scanGroup('tests/fixtures', 'Statistical & Validation Fixtures');
  return studies;
}

function discoverOutputs() {
  const outRoot = path.join(REPO_ROOT, 'output');
  if (!fs.existsSync(outRoot)) return [];
  const list = [];
  for (const entry of fs.readdirSync(outRoot, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const dir = path.join(outRoot, entry.name);
    const hasReceipt = fs.existsSync(path.join(dir, 'research-receipt.json'));
    const hasVal = fs.existsSync(path.join(dir, 'validation-report.csv'));
    if (hasReceipt || hasVal) {
      list.push({
        name: entry.name,
        outPath: `output/${entry.name}`,
        hasReceipt,
        hasHtml: fs.existsSync(path.join(dir, 'report.html')),
      });
    }
  }
  return list;
}

function loadOutputBundle(outDir, studyDir) {
  const bundle = {
    outPath: outDir,
    exists: fs.existsSync(outDir),
    receipt: null,
    baciResults: null,
    siteSummaries: null,
    dataQuality: null,
    validationReport: null,
    evidenceLedger: null,
    reportMd: null,
    hasHtmlReport: false,
    manifestText: null,
    sources: null,
    studyMeta: null,
  };

  if (bundle.exists) {
    const receiptPath = path.join(outDir, 'research-receipt.json');
    if (fs.existsSync(receiptPath)) {
      try {
        bundle.receipt = JSON.parse(fs.readFileSync(receiptPath, 'utf8'));
      } catch {
        bundle.receipt = { parseError: 'Unable to parse research-receipt.json' };
      }
    }
    bundle.baciResults = safeReadCsv(path.join(outDir, 'baci-results.csv'));
    bundle.siteSummaries = safeReadCsv(path.join(outDir, 'site-summaries.csv'));
    bundle.dataQuality = safeReadCsv(path.join(outDir, 'data-quality.csv'));
    bundle.validationReport = safeReadCsv(path.join(outDir, 'validation-report.csv'));
    bundle.evidenceLedger = safeReadCsv(path.join(outDir, 'evidence-ledger.csv'));
    const mdPath = path.join(outDir, 'report.md');
    if (fs.existsSync(mdPath)) {
      bundle.reportMd = fs.readFileSync(mdPath, 'utf8');
    }
    bundle.hasHtmlReport = fs.existsSync(path.join(outDir, 'report.html'));
  }

  const effectiveStudy = studyDir || bundle.receipt?.analysis_configuration?.study_path;
  if (effectiveStudy) {
    try {
      const absStudy = resolveUserPath(effectiveStudy);
      const manPath = path.join(absStudy, 'manifest.sha256');
      if (fs.existsSync(manPath)) {
        bundle.manifestText = fs.readFileSync(manPath, 'utf8');
      }
      bundle.sources = safeReadCsv(path.join(absStudy, 'sources.csv'));
      bundle.studyMeta = safeReadCsv(path.join(absStudy, 'study.csv'));
    } catch {
      // Ignore invalid study path when loading outputs
    }
  }
  return bundle;
}

async function handleApi(req, res, urlObj) {
  const pathname = urlObj.pathname;

  if (req.method === 'GET' && pathname === '/api/workspace') {
    const ver = await runFieldledger(['--version']);
    sendJson(res, 200, {
      engineVersion: ver.stdout.trim() || 'FIELDLEDGER (not built)',
      engineAvailable: ver.ok,
      repoRoot: REPO_ROOT,
      studies: discoverStudies(),
      outputs: discoverOutputs(),
    });
    return;
  }

  if (req.method === 'GET' && pathname === '/api/results') {
    const outParam = urlObj.searchParams.get('out') || 'output/wetland-demo';
    const studyParam = urlObj.searchParams.get('study') || '';
    try {
      const absOut = resolveUserPath(outParam);
      const absStudy = studyParam ? resolveUserPath(studyParam) : '';
      sendJson(res, 200, loadOutputBundle(absOut, absStudy));
    } catch (err) {
      sendJson(res, 400, { error: err.message });
    }
    return;
  }

  if (req.method === 'GET' && pathname === '/api/study-files') {
    const studyParam = urlObj.searchParams.get('study');
    if (!studyParam) {
      sendJson(res, 400, { error: 'Missing ?study= parameter' });
      return;
    }
    try {
      const absStudy = resolveUserPath(studyParam);
      const names = ['study.csv', 'sources.csv', 'sites.csv', 'surveys.csv', 'observations.csv'];
      const files = {};
      for (const name of names) {
        const full = path.join(absStudy, name);
        if (fs.existsSync(full)) {
          try {
            files[name] = {
              exists: true,
              sizeBytes: fs.statSync(full).size,
              parsed: safeReadCsv(full, 500),
              rawPreview: fs.readFileSync(full, 'utf8').slice(0, 8192),
            };
          } catch (e) {
            files[name] = { exists: true, error: e.message };
          }
        } else {
          files[name] = { exists: false };
        }
      }
      const manPath = path.join(absStudy, 'manifest.sha256');
      sendJson(res, 200, {
        studyPath: studyParam,
        resolvedPath: absStudy,
        hasManifest: fs.existsSync(manPath),
        manifestText: fs.existsSync(manPath) ? fs.readFileSync(manPath, 'utf8') : null,
        files,
      });
    } catch (err) {
      sendJson(res, 400, { error: err.message });
    }
    return;
  }

  if (req.method === 'GET' && pathname === '/api/raw-report') {
    const outParam = urlObj.searchParams.get('out') || 'output/wetland-demo';
    try {
      const absOut = resolveUserPath(outParam);
      const htmlPath = path.join(absOut, 'report.html');
      if (!fs.existsSync(htmlPath)) {
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('report.html not found in the selected output directory.');
        return;
      }
      res.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'X-Content-Type-Options': 'nosniff',
      });
      res.end(fs.readFileSync(htmlPath, 'utf8'));
    } catch (err) {
      res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(err.message);
    }
    return;
  }

  if (req.method === 'POST' && pathname === '/api/run') {
    try {
      const body = await readJsonBody(req);
      const action = String(body.action || '').trim().toLowerCase();
      const args = [];
      let absStudy = '';
      let absOut = '';

      switch (action) {
        case 'analyze': {
          absStudy = resolveUserPath(body.studyPath);
          absOut = resolveUserPath(body.outPath);
          args.push('analyze', 'baci', '--study', absStudy, '--out', absOut, '--no-color');
          if (body.seed !== undefined && String(body.seed).trim() !== '') {
            args.push('--seed', String(body.seed).trim());
          }
          if (body.bootstrap !== undefined && String(body.bootstrap).trim() !== '') {
            args.push('--bootstrap', String(body.bootstrap).trim());
          }
          if (body.species && String(body.species).trim() !== '') {
            args.push('--species', String(body.species).trim());
          }
          if (body.method && String(body.method).trim() !== '') {
            args.push('--method', String(body.method).trim());
          }
          break;
        }
        case 'validate': {
          absStudy = resolveUserPath(body.studyPath);
          absOut = resolveUserPath(body.outPath);
          args.push('validate', '--study', absStudy, '--out', absOut, '--no-color');
          break;
        }
        case 'manifest': {
          absStudy = resolveUserPath(body.studyPath);
          absOut = body.outPath ? resolveUserPath(body.outPath) : '';
          args.push('manifest', '--study', absStudy, '--no-color');
          break;
        }
        case 'verify': {
          absStudy = resolveUserPath(body.studyPath);
          absOut = body.outPath ? resolveUserPath(body.outPath) : '';
          args.push('verify', '--study', absStudy, '--no-color');
          break;
        }
        case 'report': {
          absStudy = resolveUserPath(body.studyPath);
          absOut = resolveUserPath(body.outPath);
          args.push('report', '--study', absStudy, '--out', absOut, '--no-color');
          break;
        }
        case 'init': {
          absStudy = resolveUserPath(body.studyPath);
          args.push('init', '--study', absStudy, '--no-color');
          break;
        }
        case 'demo': {
          absOut = resolveUserPath(body.outPath || 'output/gui-demo');
          absStudy = path.join(absOut, 'wetland-demo');
          args.push('demo', '--out', absOut, '--no-color');
          if (body.seed !== undefined && String(body.seed).trim() !== '') {
            args.push('--seed', String(body.seed).trim());
          }
          if (body.bootstrap !== undefined && String(body.bootstrap).trim() !== '') {
            args.push('--bootstrap', String(body.bootstrap).trim());
          }
          break;
        }
        default:
          sendJson(res, 400, { error: `Unsupported action: ${action}` });
          return;
      }

      const execResult = await runFieldledger(args);
      const bundle = absOut ? loadOutputBundle(absOut, absStudy) : null;
      sendJson(res, 200, {
        action,
        exec: execResult,
        bundle,
        studies: discoverStudies(),
        outputs: discoverOutputs(),
      });
    } catch (err) {
      sendJson(res, 400, { error: err.message });
    }
    return;
  }

  sendJson(res, 404, { error: 'API endpoint not found' });
}

function serveStatic(res, urlObj) {
  let relPath = urlObj.pathname === '/' ? '/index.html' : urlObj.pathname;
  relPath = path.normalize(relPath).replace(/^(\.\.(\/|\\|$))+/, '');
  const fullPath = path.join(PUBLIC_DIR, relPath);

  if (!fullPath.startsWith(PUBLIC_DIR) || !fs.existsSync(fullPath) || fs.statSync(fullPath).isDirectory()) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }

  const ext = path.extname(fullPath).toLowerCase();
  res.writeHead(200, {
    'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
    'Cache-Control': 'no-cache',
    'X-Content-Type-Options': 'nosniff',
  });
  fs.createReadStream(fullPath).pipe(res);
}

const { port } = parseArgs(process.argv);
const server = http.createServer(async (req, res) => {
  const urlObj = new URL(req.url || '/', `http://127.0.0.1:${port}`);
  if (urlObj.pathname.startsWith('/api/')) {
    await handleApi(req, res, urlObj);
  } else {
    serveStatic(res, urlObj);
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`FIELDLEDGER GUI Workbench running offline at http://127.0.0.1:${port}`);
  console.log(`COBOL Engine: ${FL_EXE}`);
  console.log('Press Ctrl+C to stop.');
});

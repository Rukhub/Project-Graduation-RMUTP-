/* eslint-disable no-console */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { parse } = require('csv-parse/sync');
const xlsx = require('xlsx');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.substring(2);
    const next = argv[i + 1];
    if (next && !next.startsWith('--')) {
      args[key] = next;
      i++;
    } else {
      args[key] = true;
    }
  }
  return args;
}

function normalizeString(v) {
  if (v === undefined || v === null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
}

function parseNumber(v) {
  const s = normalizeString(v);
  if (!s) return null;
  const n = Number(String(s).replace(/,/g, ''));
  return Number.isFinite(n) ? n : null;
}

function parsePurchaseAt(v) {
  if (v instanceof Date && !Number.isNaN(v.getTime())) {
    return admin.firestore.Timestamp.fromDate(v);
  }

  const s = normalizeString(v);
  if (!s) return null;

  // Accept YYYY-MM-DD (recommended)
  // Also accept ISO timestamps.
  const d = new Date(s);
  if (!Number.isNaN(d.getTime())) return admin.firestore.Timestamp.fromDate(d);

  return null;
}

function getFirstValue(row, keys) {
  for (const k of keys) {
    if (row && Object.prototype.hasOwnProperty.call(row, k)) {
      const v = row[k];
      if (v !== undefined && v !== null && String(v).trim() !== '') return v;
    }
  }
  return undefined;
}

function buildAssetPayload(row) {
  const payload = {};

  const assetName = normalizeString(
    getFirstValue(row, ['asset_name', 'name_asset', 'ชื่อสินทรัพย์', 'ชื่อครุภัณฑ์']),
  );
  if (assetName) {
    payload.asset_name = assetName;
    payload.name_asset = assetName;
  }

  const assetType = normalizeString(row.asset_type ?? row.type);
  if (assetType) {
    payload.asset_type = assetType;
    payload.type = assetType;
  }

  const locationId = normalizeString(row.location_id);
  if (locationId) payload.location_id = locationId;

  const locationName = normalizeString(
    getFirstValue(row, ['location_name', 'สถานที่', 'สถานที่ (ลายมือ)']),
  );
  if (locationName) payload.location_name = locationName;

  const permanentId = normalizeString(
    getFirstValue(row, ['permanent_id', 'หมายเลขสินทรัพย์ถาวร', 'permanent', 'permanent_no']),
  );
  if (permanentId) payload.permanent_id = permanentId;

  const price = parseNumber(getFirstValue(row, ['price', 'มูลค่า (บาท)', 'มูลค่า', 'ราคา']));
  if (price !== null) payload.price = price;

  const purchaseAt = parsePurchaseAt(getFirstValue(row, ['purchase_at', 'วันที่ซื้อ', 'purchase_date']));
  if (purchaseAt) payload.purchase_at = purchaseAt;

  // Default statuses if not provided
  if (payload.asset_status === undefined) payload.asset_status = 1;

  return payload;
}

async function findAvailableAssetId(db, baseId) {
  const cleanBase = normalizeString(baseId);
  if (!cleanBase) return null;

  const firstRef = db.collection('assets').doc(cleanBase);
  const firstSnap = await firstRef.get();
  if (!firstSnap.exists) return cleanBase;

  for (let i = 2; i <= 9999; i++) {
    const candidate = `${cleanBase}_${i}`;
    const ref = db.collection('assets').doc(candidate);
    const snap = await ref.get();
    if (!snap.exists) return candidate;
  }

  return null;
}

function normalizeRowKeys(row) {
  const out = {};
  for (const [k, v] of Object.entries(row || {})) {
    const nk = normalizeString(k);
    if (!nk) continue;
    out[nk] = v;
    out[nk.toLowerCase()] = v;
  }
  return out;
}

function loadRecordsFromFile(inputPath) {
  const ext = path.extname(inputPath).toLowerCase();
  if (ext === '.xlsx' || ext === '.xls') {
    const wb = xlsx.readFile(inputPath, { cellDates: true });
    const sheetName = wb.SheetNames[0];
    if (!sheetName) return [];
    const sheet = wb.Sheets[sheetName];
    const json = xlsx.utils.sheet_to_json(sheet, { defval: '' });
    return json;
  }

  // default: csv
  const csvText = fs.readFileSync(inputPath, 'utf8');
  return parse(csvText, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  });
}

async function main() {
  const args = parseArgs(process.argv);

  const serviceAccountPath = args.serviceAccount || args.service_account;
  const inputPath = args.xlsx || args.xls || args.csv || args.file;
  const commit = Boolean(args.commit);
  const dryRun = Boolean(args['dry-run'] || args.dryRun || args.dry_run) || !commit;

  if (!serviceAccountPath) {
    console.error('Missing --serviceAccount "path_to_service_account.json"');
    process.exit(1);
  }
  if (!inputPath) {
    console.error('Missing --csv "path_to_csv" or --xlsx "path_to_xlsx"');
    process.exit(1);
  }

  const resolvedKey = path.resolve(serviceAccountPath);
  const resolvedInput = path.resolve(inputPath);

  if (!fs.existsSync(resolvedKey)) {
    console.error(`Service account not found: ${resolvedKey}`);
    process.exit(1);
  }
  if (!fs.existsSync(resolvedInput)) {
    console.error(`Input file not found: ${resolvedInput}`);
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(resolvedKey, 'utf8'));

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();

  const records = loadRecordsFromFile(resolvedInput);

  let ok = 0;
  let skipped = 0;
  let duplicates = 0;
  let errors = 0;

  console.log(`Rows: ${records.length}`);
  console.log(dryRun ? 'Mode: DRY-RUN (no writes)' : 'Mode: COMMIT (write to Firestore)');

  const usedIdsThisRun = new Set();
  const baseCounters = new Map();

  for (let idx = 0; idx < records.length; idx++) {
    const rawRow = records[idx];
    const row = normalizeRowKeys(rawRow);

    const permanentIdFromRow = normalizeString(
      getFirstValue(row, ['permanent_id', 'หมายเลขสินทรัพย์ถาวร']),
    );

    let assetId = normalizeString(
      getFirstValue(row, ['asset_id', 'id', 'รหัสครุภัณฑ์', 'หมายเลขครุภัณฑ์']),
    );

    if (!assetId && permanentIdFromRow) {
      // If Excel has only permanent number, use it as a base asset_id and suffix when repeated.
      const base = permanentIdFromRow;
      const next = (baseCounters.get(base) || 0) + 1;
      baseCounters.set(base, next);
      assetId = next === 1 ? base : `${base}_${next}`;
    }

    if (!assetId) {
      errors++;
      const keys = Object.keys(rawRow || {});
      const preview = keys.slice(0, 12).join(', ');
      console.error(
        `Row ${idx + 1}: missing asset_id. Available columns: ${preview}${keys.length > 12 ? ' ...' : ''}`,
      );
      continue;
    }

    // Ensure uniqueness inside this import run.
    if (usedIdsThisRun.has(assetId)) {
      const base = assetId;
      let c = 2;
      while (usedIdsThisRun.has(`${base}_${c}`)) c++;
      assetId = `${base}_${c}`;
    }
    usedIdsThisRun.add(assetId);

    try {
      let finalAssetId = assetId;
      const ref = db.collection('assets').doc(finalAssetId);
      const snap = await ref.get();
      if (snap.exists) {
        // If we auto-generated from permanent_id, try to find an available suffix instead of skipping.
        if (permanentIdFromRow && (finalAssetId === permanentIdFromRow || finalAssetId.startsWith(`${permanentIdFromRow}_`))) {
          const candidate = await findAvailableAssetId(db, permanentIdFromRow);
          if (!candidate) {
            duplicates++;
            console.warn(`Row ${idx + 1}: duplicate base asset_id=${permanentIdFromRow} (no free suffix, skipped)`);
            continue;
          }
          finalAssetId = candidate;
        } else {
          duplicates++;
          console.warn(`Row ${idx + 1}: duplicate asset_id=${finalAssetId} (skipped)`);
          continue;
        }
      }

      const payload = buildAssetPayload(row);
      payload.asset_id = finalAssetId;
      if (!payload.permanent_id && permanentIdFromRow) payload.permanent_id = permanentIdFromRow;
      payload.created_at = admin.firestore.FieldValue.serverTimestamp();

      if (!dryRun) {
        await db.collection('assets').doc(finalAssetId).set(payload);
      }

      ok++;
      if ((ok + skipped + duplicates + errors) % 20 === 0) {
        console.log(`Progress: ${idx + 1}/${records.length}`);
      }
    } catch (e) {
      errors++;
      console.error(`Row ${idx + 1}: failed asset_id=${assetId}:`, e.message || e);
    }
  }

  skipped += 0;

  console.log('---');
  console.log(`Imported: ${ok}`);
  console.log(`Duplicates skipped: ${duplicates}`);
  console.log(`Errors: ${errors}`);

  if (dryRun) {
    console.log('Dry-run finished. Re-run with --commit to write into Firestore.');
  }
}

main().catch((e) => {
  console.error('Fatal:', e);
  process.exit(1);
});

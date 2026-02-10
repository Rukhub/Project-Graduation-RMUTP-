# Firestore CSV Import (assets)

เครื่องมือนี้ใช้สำหรับนำเข้าข้อมูลครุภัณฑ์จำนวนมากจากไฟล์ CSV/Excel (.xlsx) ลง Firestore collection `assets`.

## ข้อควรระวัง

- ไฟล์ Service Account (`*.json`) เป็นกุญแจแอดมิน **ห้าม** commit ขึ้น GitHub
- แนะนำเก็บไฟล์ key ไว้นอก repo เช่น `C:\\firebase_keys\\serviceAccountKey.json`

## เตรียมเครื่อง

ต้องมี Node.js (LTS) ติดตั้งในเครื่องก่อน

## ติดตั้ง dependencies

เปิด PowerShell ในโฟลเดอร์นี้ แล้วรัน:

```powershell
npm install
```

## รูปแบบไฟล์ CSV/Excel

ดูตัวอย่างหัวคอลัมน์ที่ไฟล์ `assets_template.csv`

หมายเหตุ: สำหรับไฟล์ Excel (.xlsx) แนะนำให้ใช้หัวคอลัมน์เหมือนกับ CSV template (แถวแรกเป็น header)

คอลัมน์ที่รองรับ:

- `asset_id` (จำเป็น) -> จะถูกใช้เป็น Document ID ด้วย
- `asset_name`
- `asset_type`
- `location_id`
- `location_name`
- `permanent_id`
- `price` (ตัวเลข)
- `purchase_at` (แนะนำรูปแบบ `YYYY-MM-DD`)

## วิธีรัน (แนะนำเริ่มด้วย dry-run)

### 1) Dry-run (ไม่เขียนเข้า Firestore)

```powershell
node import_assets_csv.js --serviceAccount "C:\\firebase_keys\\serviceAccountKey.json" --csv "C:\\path\\to\\assets.csv" --dry-run

# หรือใช้ Excel (.xlsx)
node import_assets_csv.js --serviceAccount "C:\\firebase_keys\\serviceAccountKey.json" --xlsx "C:\\path\\to\\assets.xlsx" --dry-run
```

### 2) Commit (เขียนจริง)

```powershell
node import_assets_csv.js --serviceAccount "C:\\firebase_keys\\serviceAccountKey.json" --csv "C:\\path\\to\\assets.csv" --commit

# หรือใช้ Excel (.xlsx)
node import_assets_csv.js --serviceAccount "C:\\firebase_keys\\serviceAccountKey.json" --xlsx "C:\\path\\to\\assets.xlsx" --commit
```

## หมายเหตุเรื่องรหัสซ้ำ

- ถ้า `asset_id` ซ้ำ สคริปต์จะ **ข้าม** และรายงานว่า duplicate
- ถ้าต้องการให้ update แทน (เขียนทับ) ให้บอกผมก่อน แล้วผมจะเพิ่มโหมด `--upsert`

# Implementation Plan: เพิ่มการติดตามผู้สร้างครุภัณฑ์

## สรุป
เพิ่มฟิลด์ `created_by` ในตาราง `assets` เพื่อเก็บข้อมูลผู้สร้าง และแสดงชื่อผู้สร้างใน `checker_name` จนกว่าจะมีการตรวจสอบจริง

---

## สำหรับโบ: Backend Changes

### 1️⃣ รัน SQL นี้ (เพิ่มฟิลด์ created_by)

```sql
ALTER TABLE assets 
ADD COLUMN created_by INT DEFAULT NULL;
```

### 2️⃣ แก้ไข `POST /api/assets`

**แทนที่โค้ดเดิม (บรรทัดประมาณ 145-165):**

```javascript
app.post('/api/assets', upload.single('image'), (req, res) => {
    const { asset_id, asset_type, brand_model, location_id, status, created_by } = req.body;

    let imageUrl = '';
    if (req.file) {
        imageUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    }

    const sql = `
        INSERT INTO assets 
        (asset_id, asset_type, brand_model, location_id, status, image_url, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `;

    db.query(
        sql,
        [asset_id, asset_type, brand_model, location_id, status || 'รอตรวจสอบ', imageUrl, created_by],
        err => {
            if (err) return res.status(500).json(err);
            res.json({ success: true, image_url: imageUrl });
        }
    );
});
```

### 3️⃣ แก้ไข `GET /api/assets`

**แทนที่โค้ดเดิม (บรรทัดประมาณ 123-135):**

```javascript
app.get('/api/assets', (req, res) => {
    const sql = `
        SELECT a.*, l.room_name, l.floor,
        COALESCE(
          (SELECT u.fullname FROM check_logs cl 
           JOIN users u ON cl.checker_id = u.user_id
           WHERE cl.asset_id = a.asset_id 
           ORDER BY cl.check_date DESC LIMIT 1),
          (SELECT u2.fullname FROM users u2 WHERE u2.user_id = a.created_by)
        ) AS checker_name
        FROM assets a
        LEFT JOIN locations l ON a.location_id = l.location_id
        ORDER BY a.created_at DESC
    `;
    db.query(sql, (err, results) => res.json(results));
});
```

---

## สำหรับฉัน: Flutter Changes

### ✅ จะแก้ไขไฟล์ที่สร้างครุภัณฑ์ใหม่

ค้นหาส่วนที่เรียก `POST /api/assets` และเพิ่ม:
```dart
'created_by': currentUser['user_id']
```

---

## ผลลัพธ์ที่คาดหวัง

- ✅ ครุภัณฑ์ที่**พึ่งสร้างใหม่** → แสดงชื่อ**ผู้สร้าง**
- ✅ ครุภัณฑ์ที่**ถูกตรวจสอบแล้ว** → แสดงชื่อ**ผู้ตรวจสอบล่าสุด**
- ✅ ข้อมูลชัดเจน ไม่มี check_log ปลอม

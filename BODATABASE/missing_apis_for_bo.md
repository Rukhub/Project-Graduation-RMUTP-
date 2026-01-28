# 🔧 API ที่ต้องเพิ่ม (สำหรับโบ)

## ❌ ปัญหา
โค้ดปัจจุบันขาด API หลายอัน ทำให้:
- ข้อมูลครุภัณฑ์ในห้องไม่แสดง (0 ชิ้น)
- Dashboard อาจไม่ทำงาน
- ตรวจสอบอุปกรณ์ไม่ได้

---

## ✅ Copy โค้ดนี้ไปวางก่อน `app.listen()`

```javascript
// ==========================================
// --- API ที่ต้องเพิ่ม (วางก่อน app.listen) ---
// ==========================================

// ⭐ 1. ดึงครุภัณฑ์ตามห้อง (สำคัญมาก!)
app.get('/api/assets/room/:locationId', (req, res) => {
    const locationId = req.params.locationId;
    const sql = `
        SELECT a.*, l.room_name, l.floor,
        (SELECT u.fullname FROM check_logs cl JOIN users u ON cl.checker_id = u.user_id 
         WHERE cl.asset_id = a.asset_id ORDER BY cl.check_date DESC LIMIT 1) as checker_name
        FROM assets a 
        LEFT JOIN locations l ON a.location_id = l.location_id 
        WHERE a.location_id = ?
        ORDER BY a.created_at DESC`;
    db.query(sql, [locationId], (err, results) => {
        if (err) return res.status(500).json({ error: err });
        res.json(results);
    });
});

// ⭐ 2. ดึงรายการห้องทั้งหมด
app.get('/api/locations', (req, res) => {
    db.query("SELECT * FROM locations ORDER BY floor, room_name", (err, results) => {
        if (err) return res.status(500).json({ error: err });
        res.json(results);
    });
});

// ⭐ 3. เพิ่มห้องใหม่
app.post('/api/locations', (req, res) => {
    const { room_name, floor } = req.body;
    db.query("INSERT INTO locations (room_name, floor) VALUES (?, ?)", [room_name, floor], (err, result) => {
        if (err) return res.status(500).json({ error: err });
        res.json({ success: true, location_id: result.insertId });
    });
});

// ⭐ 4. Dashboard สถิติ
app.get('/api/dashboard/stats', (req, res) => {
    const sql = `
        SELECT 
            COUNT(*) as total,
            SUM(CASE WHEN status = 'ปกติ' THEN 1 ELSE 0 END) as normal,
            SUM(CASE WHEN status = 'ชำรุด' THEN 1 ELSE 0 END) as damaged,
            SUM(CASE WHEN status = 'อยู่ระหว่างซ่อม' THEN 1 ELSE 0 END) as pending
        FROM assets`;
    db.query(sql, (err, results) => {
        if (err) return res.status(500).json({ error: err });
        res.json(results[0]);
    });
});

// ⭐ 5. อัพเดทสถานะครุภัณฑ์
app.put('/api/assets/:assetId/status', (req, res) => {
    const { status } = req.body;
    db.query("UPDATE assets SET status = ? WHERE asset_id = ?", [status, req.params.assetId], (err) => {
        if (err) return res.status(500).json({ error: err });
        res.json({ success: true });
    });
});

// ⭐ 6. บันทึกการตรวจสอบ
app.post('/api/check-logs', (req, res) => {
    const { asset_id, checker_id, checker_name, status, note, image_url } = req.body;
    db.query(
        "INSERT INTO check_logs (asset_id, checker_id, checker_name, status, note, image_url) VALUES (?, ?, ?, ?, ?, ?)",
        [asset_id, checker_id, checker_name, status, note, image_url],
        (err) => {
            if (err) return res.status(500).json({ error: err });
            res.json({ success: true });
        }
    );
});

// ⭐ 7. ดึงประวัติการตรวจสอบ
app.get('/api/check-logs/:assetId', (req, res) => {
    const sql = `
        SELECT cl.*, u.fullname 
        FROM check_logs cl 
        LEFT JOIN users u ON cl.checker_id = u.user_id 
        WHERE cl.asset_id = ? 
        ORDER BY cl.check_date DESC`;
    db.query(sql, [req.params.assetId], (err, results) => {
        if (err) return res.status(500).json({ error: err });
        res.json(results);
    });
});

// ⭐ 8. ดึง Reports ของ Asset
app.get('/api/reports/asset/:assetId', (req, res) => {
    db.query("SELECT * FROM reports WHERE asset_id = ? ORDER BY report_date DESC", [req.params.assetId], (err, results) => {
        if (err) return res.status(500).json({ error: err });
        res.json(results);
    });
});

// ⭐ 9. ดึงรายการผู้ใช้ทั้งหมด
app.get('/api/users', (req, res) => {
    db.query("SELECT * FROM users ORDER BY created_at DESC", (err, results) => {
        if (err) return res.status(500).json({ error: err });
        res.json(results);
    });
});

// ⭐ 10. อนุมัติผู้ใช้
app.put('/api/users/approve/:userId', (req, res) => {
    db.query("UPDATE users SET is_approved = 1 WHERE user_id = ?", [req.params.userId], (err) => {
        if (err) return res.status(500).json({ error: err });
        res.json({ success: true });
    });
});

// ⭐ 11. เปลี่ยน Role ผู้ใช้
app.put('/api/users/role/:userId', (req, res) => {
    const { role } = req.body;
    db.query("UPDATE users SET role = ? WHERE user_id = ?", [role, req.params.userId], (err) => {
        if (err) return res.status(500).json({ error: err });
        res.json({ success: true });
    });
});

// ⭐ 12. ลบผู้ใช้
app.delete('/api/users/:userId', (req, res) => {
    db.query("DELETE FROM users WHERE user_id = ?", [req.params.userId], (err) => {
        if (err) return res.status(500).json({ error: err });
        res.json({ success: true });
    });
});
```

---

## 📋 Checklist สำหรับโบ

| # | API | เพิ่มแล้ว? |
|---|-----|----------|
| 1 | `/api/assets/room/:locationId` | ⬜ |
| 2 | `/api/locations` (GET) | ⬜ |
| 3 | `/api/locations` (POST) | ⬜ |
| 4 | `/api/dashboard/stats` | ⬜ |
| 5 | `/api/assets/:assetId/status` (PUT) | ⬜ |
| 6 | `/api/check-logs` (POST) | ⬜ |
| 7 | `/api/check-logs/:assetId` (GET) | ⬜ |
| 8 | `/api/reports/asset/:assetId` | ⬜ |
| 9 | `/api/users` (GET) | ⬜ |
| 10 | `/api/users/approve/:userId` | ⬜ |
| 11 | `/api/users/role/:userId` | ⬜ |
| 12 | `/api/users/:userId` (DELETE) | ⬜ |

---

## 🧪 ทดสอบหลังเพิ่ม

ลองเรียก API ใน Browser หรือ Postman:
```
GET http://localhost:3000/api/assets/room/1
```

ถ้าได้ข้อมูลครุภัณฑ์กลับมา = สำเร็จ! ✅

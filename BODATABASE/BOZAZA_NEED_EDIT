// ==========================================
// 🔴 นำ Code ชุดนี้ไปแปะเพิ่มใน index.js (ไฟล์ของโบ) 
// แนะนำให้แปะต่อจากบรรทัด app.get('/api/dashboard-stats' ...) 
// ในหมวด 6. API: Assets & Dashboard
// ==========================================
// 1. API ดึงครุภัณฑ์ทั้งหมด (แก้ปัญหาหาไม่เจอ 404)
app.get('/api/assets', (req, res) => {
    // JOIN กับตาราง locations เพื่อเอาชื่อห้องมาแสดงด้วย
    const sql = "SELECT a.*, l.room_name, l.floor FROM assets a LEFT JOIN locations l ON a.location_id = l.location_id ORDER BY a.created_at DESC";
    db.query(sql, (err, results) => {
        if (err) return res.status(500).json(err);
        res.json(results);
    });
});
// 2. API ดึงครุภัณฑ์ตามห้อง (แก้ปัญหาหน้าห้องว่างเปล่า)
app.get('/api/assets/room/:locationId', (req, res) => {
    const { locationId } = req.params;
    const sql = "SELECT a.*, l.room_name, l.floor FROM assets a LEFT JOIN locations l ON a.location_id = l.location_id WHERE a.location_id = ? ORDER BY a.asset_id ASC";
    db.query(sql, [locationId], (err, results) => {
        if (err) return res.status(500).json(err);
        res.json(results);
    });
});

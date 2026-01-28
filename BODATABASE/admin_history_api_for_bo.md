# 🔧 API สำหรับ "ประวัติการดำเนินการของ Admin" (ส่งให้โบ)

คุณรักขอเพิ่มหน้าประวัติการทำงานของ Admin และแก้บั๊กที่สถานะขึ้นเป็น "ไม่ระบุ"
รบกวนโบเพิ่ม/แก้ไข 2 API นี้ครับ

## 1. API ดึงประวัติ (GET) - *เพิ่มใหม่*
```javascript
// ⭐ ดึงประวัติการตรวจสอบของ Admin คนนั้นๆ
app.get('/api/check-logs/checker/:checkerName', (req, res) => {
    const checkerName = decodeURIComponent(req.params.checkerName);
    
    console.log('📋 Fetching check logs for:', checkerName);

    // SQL ดึงข้อมูลจาก check_logs + assets + locations
    // ⚠️ สำคัญ: ต้อง select `cl.status` หรือ `cl.result_status` ออกมาให้ครบ
    const sql = `
        SELECT cl.*, 
               a.asset_id, 
               a.asset_type, 
               a.type, 
               a.location_id,
               l.room_name, 
               l.floor
        FROM check_logs cl
        JOIN assets a ON cl.asset_id = a.asset_id
        LEFT JOIN locations l ON a.location_id = l.location_id
        WHERE cl.checker_name = ?
        ORDER BY cl.check_date DESC
    `;

    db.query(sql, [checkerName], (err, results) => {
        if (err) {
            console.error("❌ Database error:", err);
            return res.status(500).json({ error: err });
        }
        res.json(results);
    });
});
```

## 2. API บันทึกการตรวจสอบ (POST) - *เช็คว่าบันทึก status ถูกไหม*
ปัญหาก่อนหน้านี้คือสถานะใน `check_logs` เป็น NULL. รบกวนโบเช็ค SQL Insert ว่า map field ถูกต้องครับ

**Flutter ส่ง Data ไปหน้าตาแบบนี้:**
```json
{
  "asset_id": "123",
  "checker_id": 1,
  "result_status": "ปกติ",   <-- เช็ค field นี้
  "remark": "...",
  "image_url": "..."
}
```

**ตัวอย่าง Code Backend ที่ถูกต้อง:**
```javascript
app.post('/api/check-logs', (req, res) => {
    // รับค่า result_status จาก App
    const { asset_id, checker_id, result_status, remark, image_url } = req.body;

    // ⚠️ ระวัง: ใน Database column ชื่อ 'status' หรือ 'result_status'?
    // ถ้าชื่อ column คือ 'status' ต้อง map ค่าให้ถูก
    const sql = `
        INSERT INTO check_logs (asset_id, checker_id, status, remark, image_url, check_date)
        VALUES (?, ?, ?, ?, ?, NOW())
    `;

    // ใส่ result_status ลงไปในช่อง status
    db.query(sql, [asset_id, checker_id, result_status, remark, image_url], (err, result) => {
        if (err) return res.status(500).json({ error: err });
        res.json({ success: true, message: 'Saved successfully' });
    });
});
```

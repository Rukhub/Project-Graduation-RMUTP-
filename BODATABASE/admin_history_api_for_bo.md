# 🔧 API เพิ่มเติมสำหรับ "ประวัติการดำเนินการของ Admin"

คุณรักขอเพิ่มหน้าประวัติการทำงานของ Admin (เช่น ประวัติการตรวจสอบครุภัณฑ์)
ฝรบกวนโบเพิ่ม API นี้ให้หน่อยครับ

```javascript
// ⭐ ดึงประวัติการตรวจสอบของ Admin คนนั้นๆ
app.get('/api/check-logs/checker/:checkerName', (req, res) => {
    const checkerName = decodeURIComponent(req.params.checkerName);
    
    console.log('📋 Fetching check logs for:', checkerName);

    // ดึงข้อมูลการตรวจสอบ + รายละเอียดครุภัณฑ์ + สถานที่เก็บ
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
        
        console.log(`✅ Found ${results.length} logs for ${checkerName}`);
        res.json(results);
    });
});
```

---

## 🧪 วิธีทดสอบ
1. Restart Server
2. ลองเรียกใน Postman หรือ Browser:
`http://localhost:3000/api/check-logs/checker/โบ%20ผู้ดูแลระบบ`
(เปลี่ยนชื่อเป็นชื่อ Admin ที่มีในระบบ)

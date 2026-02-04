# 🚨 โบครับ! โค้ดมี Syntax Error นะ! แก้ด่วน!

## ❌ ปัญหาในโค้ดที่โบส่งมา

1. **บรรทัด 9:** `if (!asset_id  !new_location_id)` ➜ **ขาด `||`**
2. **บรรทัด 16:** `console.log(📦 ย้ายเครื่อง...)` ➜ **ขาด backticks** ` `` `
3. **บรรทัด 24:** `if (!assetIds  !Array.isArray...)` ➜ **ขาด `||`**
4. **บรรทัด 29:** `const sql = UPDATE assets...` ➜ **ขาด backticks** ` `` `
5. **บรรทัด 33, 34:** `console.log(...)` ➜ **ขาด backticks** ` `` `

---

## ✅ โค้ดที่ถูกต้อง (Copy ทับทั้งหมด)

```javascript
/* ==========================================
 * 6.1️⃣ ASSET MOVEMENT (ย้ายห้อง)
 * ========================================== */

// ✅ 1. ย้ายห้องทีละเครื่อง
app.put('/api/assets/move', (req, res) => {
    const { asset_id, new_location_id } = req.body;

    // ⚠️ แก้ตรงนี้: เพิ่ม ||
    if (!asset_id || !new_location_id) {
        return res.status(400).json({ success: false, message: "ข้อมูลไม่ครบนะจ๊ะ" });
    }

    const sql = "UPDATE assets SET location_id = ? WHERE asset_id = ?";
    db.query(sql, [new_location_id, asset_id], (err, result) => {
        if (err) {
            console.error("❌ ย้ายห้องล้มเหลว:", err.sqlMessage);
            return res.status(500).json({ success: false, message: err.sqlMessage });
        }
        // ⚠️ แก้ตรงนี้: เพิ่ม backticks
        console.log(`📦 ย้ายเครื่อง ${asset_id} ไปห้อง ID: ${new_location_id} แล้ว`);
        res.json({ success: true, message: "ย้ายห้องสำเร็จแล้วจ้า" });
    });
});

// ✅ 2. ย้ายห้องเป็นกลุ่ม (ยกพวกย้ายห้อง)
app.put('/api/assets/move-selected', (req, res) => {
    const { assetIds, new_location_id } = req.body;

    console.log('📦 [DEBUG] Received:', { assetIds, new_location_id });

    // ⚠️ แก้ตรงนี้: เพิ่ม ||
    if (!assetIds || !Array.isArray(assetIds) || !new_location_id) {
        return res.status(400).json({ success: false, message: "เลือกเครื่องและห้องใหม่ด้วยนะจ๊ะ" });
    }

    const placeholders = assetIds.map(() => '?').join(',');
    // ⚠️ แก้ตรงนี้: เพิ่ม backticks
    const sql = `UPDATE assets SET location_id = ? WHERE asset_id IN (${placeholders})`;

    console.log('📦 [DEBUG] SQL:', sql);
    console.log('📦 [DEBUG] Params:', [new_location_id, ...assetIds]);

    db.query(sql, [new_location_id, ...assetIds], (err, result) => {
        if (err) {
            console.error('❌ SQL Error:', err);
            return res.status(500).json(err);
        }
        
        console.log('📦 [DEBUG] Result:', {
            affectedRows: result.affectedRows,
            changedRows: result.changedRows
        });
        
        // ⚠️ แก้ตรงนี้: เพิ่ม backticks
        console.log(`📦 ย้ายกลุ่มเครื่อง ${result.affectedRows} เครื่องไปห้อง ID: ${new_location_id}`);
        res.json({ 
            success: true, 
            message: `ย้ายทั้งหมด ${result.affectedRows} เครื่องสำเร็จ!`,
            affected: result.affectedRows 
        });
    });
});
```

---

## 🔍 หลัง Restart ต้องเห็น Log นี้:

```
📦 [DEBUG] Received: { assetIds: [ 'RUK_CHAYANON' ], new_location_id: 12 }
📦 [DEBUG] SQL: UPDATE assets SET location_id = ? WHERE asset_id IN (?)
📦 [DEBUG] Params: [ 12, 'RUK_CHAYANON' ]
📦 [DEBUG] Result: { affectedRows: 1, changedRows: 1 }
📦 ย้ายกลุ่มเครื่อง 1 เครื่องไปห้อง ID: 12
```

---

## ⚠️ ถ้า affectedRows = 0

แสดงว่า:
- Asset ID `'RUK_CHAYANON'` **ไม่มีใน Database**
- หรือ **location_id เป็น 12 อยู่แล้ว** (ไม่มีอะไรเปลี่ยน)

**วิธีเช็ค:**
```sql
SELECT asset_id, location_id FROM assets WHERE asset_id = 'RUK_CHAYANON';
```

---

## 📌 สรุปสิ่งที่แก้

| บรรทัด | ก่อน | หลัง |
|--------|------|------|
| 9 | `if (!asset_id  !new_location_id)` | `if (!asset_id \|\| !new_location_id)` |
| 16 | `console.log(📦 ย้ายเครื่อง ${asset_id}...)` | `` console.log(`📦 ย้ายเครื่อง ${asset_id}...`) `` |
| 24 | `if (!assetIds  !Array.isArray...)` | `if (!assetIds \|\| !Array.isArray...)` |
| 29 | `const sql = UPDATE assets...` | `` const sql = `UPDATE assets...` `` |
| 33-34 | `console.log(...)` | `` console.log(`...`) `` |

---

**แก้แล้ว Restart Backend ด้วยนะ!** 🚀

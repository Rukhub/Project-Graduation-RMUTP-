const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// 1. เชื่อมต่อกับ MySQL
const db = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: 'password123', 
  database: 'krupandb' 
});

db.connect((err) => {
  if (err) {
    console.error('❌ Database connection failed:', err);
    return;
  }
  console.log('✅ Connected to MySQL Database');
});

// --- 🔐 ระบบผู้ใช้งาน (Login & Roles) ---

app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  const sql = "SELECT user_id, username, fullname, role, is_approved FROM users WHERE username = ? AND password = ?";
  
  db.query(sql, [username, password], (err, results) => {
    if (err) return res.status(500).json(err);
    if (results.length > 0) {
      const user = results[0];
      if (user.is_approved === 0) {
        return res.status(403).json({ message: "บัญชีนี้รอการอนุมัติจากแอดมินโบ" });
      }
      res.json({ message: "เข้าสู่ระบบสำเร็จ!", user: user });
    } else {
      res.status(401).json({ message: "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง" });
    }
  });
});

// --- 📊 Dashboard & Stats ---

app.get('/api/dashboard-stats', (req, res) => {
  const sql = `
    SELECT 
      COUNT(*) as total,
      SUM(CASE WHEN status = 'ปกติ' THEN 1 ELSE 0 END) as normal,
      SUM(CASE WHEN status = 'ชำรุด' THEN 1 ELSE 0 END) as damaged
    FROM assets`;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results[0]);
  });
});

// --- 📍 สถานที่ (Locations) ---

app.get('/api/locations', (req, res) => {
  db.query('SELECT * FROM locations ORDER BY floor, room_name', (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

app.post('/api/locations', (req, res) => {
  const { floor, room_name } = req.body;
  const sql = "INSERT INTO locations (floor, room_name) VALUES (?, ?)";
  db.query(sql, [floor, room_name], (err, result) => {
    if (err) return res.status(500).json({ success: false, message: 'Database error' });
    res.json({ success: true, location_id: result.insertId });
  });
});

app.delete('/api/locations/:id', (req, res) => {
  const { id } = req.params;
  db.query("DELETE FROM locations WHERE location_id = ?", [id], (err, result) => {
    if (err) {
      if (err.code === 'ER_ROW_IS_REFERENCED_2') {
        return res.status(400).json({ message: "ลบไม่ได้! เพราะมีครุภัณฑ์ลงทะเบียนอยู่ในห้องนี้" });
      }
      return res.status(500).json(err);
    }
    res.json({ message: "ลบห้องสำเร็จ!" });
  });
});

app.put('/api/locations/:id', (req, res) => {
    const { id } = req.params;
    const { floor, room_name } = req.body;
    const sql = "UPDATE locations SET floor = ?, room_name = ? WHERE location_id = ?";
    
    db.query(sql, [floor, room_name, id], (err, result) => {
        if (err) return res.status(500).json({ success: false, message: 'Database error' });
        res.json({ success: true, message: 'แก้ไขข้อมูลห้องสำเร็จ' });
    });
});

// --- 📦 ครุภัณฑ์ (Assets) ---

app.get('/api/assets/room/:location_id', (req, res) => {
    const locationId = req.params.location_id;
    const sql = 'SELECT * FROM assets WHERE location_id = ?';
    db.query(sql, [locationId], (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error' });
        res.json(results);
    });
});

app.get('/api/assets/:assetId', (req, res) => {
  const { assetId } = req.params;
  const sql = `
    SELECT a.*, l.room_name, l.floor 
    FROM assets a
    JOIN locations l ON a.location_id = l.location_id
    WHERE a.asset_id = ?`;
  db.query(sql, [assetId], (err, result) => {
    if (err) return res.status(500).json(err);
    if (result.length === 0) return res.status(404).json({ message: "ไม่พบรหัสครุภัณฑ์นี้" });
    res.json(result[0]);
  });
});

app.post('/api/assets', (req, res) => {
  const { asset_id, asset_type, brand_model, location_id, image_url } = req.body;
  const sql = "INSERT INTO assets (asset_id, asset_type, brand_model, location_id, image_url) VALUES (?, ?, ?, ?, ?)";
  db.query(sql, [asset_id, asset_type, brand_model, location_id, image_url], (err, result) => {
    if (err) {
        if (err.errno === 1062) return res.status(400).json({ message: "รหัสครุภัณฑ์นี้มีในระบบแล้ว" });
        return res.status(500).json(err);
    }
    res.json({ message: "เพิ่มครุภัณฑ์สำเร็จ!" });
  });
});

app.delete('/api/assets/:id', (req, res) => {
    const assetId = req.params.id;
    const sql = "DELETE FROM assets WHERE asset_id = ?";
    db.query(sql, [assetId], (err, result) => {
        if (err) return res.status(500).json({ message: "ลบไม่สำเร็จ", error: err });
        res.json({ message: "ลบครุภัณฑ์เรียบร้อยแล้ว" });
    });
});

// ⭐ จุดแก้ไข: เพิ่มฟิลด์ให้ครบตามที่รักส่งมาจากแอป
app.put('/api/assets/:asset_id', (req, res) => {
    const { asset_id } = req.params;
    const { asset_type, brand_model, location_id, status, image_url, reporter_name, issue_detail } = req.body;
    
    const sql = `
        UPDATE assets 
        SET asset_type = ?, 
            brand_model = ?, 
            location_id = ?, 
            status = ?, 
            image_url = ?,
            reporter_name = ?,
            issue_detail = ?
        WHERE asset_id = ?`;

    db.query(sql, [asset_type, brand_model, location_id, status, image_url, reporter_name, issue_detail, asset_id], (err, result) => {
        if (err) return res.status(500).json({ success: false, message: 'Database error' });
        res.json({ success: true, message: 'แก้ไขข้อมูลครุภัณฑ์สำเร็จ' });
    });
});

// --- 🛠️ การตรวจสอบสภาพ & แจ้งซ่อม ---

app.post('/api/check-logs', (req, res) => {
  const { asset_id, checker_id, result_status, remark } = req.body;
  const sqlLog = "INSERT INTO check_logs (asset_id, checker_id, result_status, remark) VALUES (?, ?, ?, ?)";
  const sqlUpdateAsset = "UPDATE assets SET last_check_date = NOW(), status = ? WHERE asset_id = ?";

  db.query(sqlLog, [asset_id, checker_id, result_status, remark], (err, result) => {
    if (err) return res.status(500).json(err);
    db.query(sqlUpdateAsset, [result_status, asset_id], (err2) => {
      if (err2) return res.status(500).json(err2);
      res.json({ message: "บันทึกการตรวจสอบเรียบร้อย!" });
    });
  });
});

app.post('/api/reports', (req, res) => {
  const { asset_id, reporter_name, issue_detail } = req.body;
  const sqlReport = "INSERT INTO reports (asset_id, reporter_name, issue_detail) VALUES (?, ?, ?)";
  const sqlUpdateAsset = `
    UPDATE assets 
    SET status = 'ชำรุด', 
        reporter_name = ?, 
        issue_detail = ?, 
        report_date = NOW() 
    WHERE asset_id = ?`;

  db.query(sqlReport, [asset_id, reporter_name, issue_detail], (err, result) => {
    if (err) return res.status(500).json(err);
    db.query(sqlUpdateAsset, [reporter_name, issue_detail, asset_id], (err2) => {
      if (err2) return res.status(500).json(err2);
      res.json({ message: "ส่งรายงานแจ้งซ่อมสำเร็จ!" });
    });
  });
});

app.listen(3000, () => {
  console.log('✅ Backend Ready: http://localhost:3000');
});

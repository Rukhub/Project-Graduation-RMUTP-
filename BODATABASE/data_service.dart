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

// --- ส่วนของระบบผู้ใช้งาน (Login) ---

app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  const sql = "SELECT id, username, fullname FROM users WHERE username = ? AND password = ?";
  db.query(sql, [username, password], (err, results) => {
    if (err) return res.status(500).json(err);
    if (results.length > 0) {
      res.json({ message: "เข้าสู่ระบบสำเร็จ!", user: results[0] });
    } else {
      res.status(401).json({ message: "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง" });
    }
  });
});

// --- ส่วนของ Dashboard (แผนข้อ 2) ---

app.get('/api/dashboard-stats', (req, res) => {
  const sql = `
    SELECT 
      COUNT(*) as total,
      SUM(CASE WHEN status = 'ตรวจสอบแล้ว' THEN 1 ELSE 0 END) as checked,
      SUM(CASE WHEN status = 'ไม่ได้ตรวจสอบ' THEN 1 ELSE 0 END) as pending,
      SUM(CASE WHEN status = 'ชำรุด' THEN 1 ELSE 0 END) as damaged
    FROM assets`;
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results[0]);
  });
});

// --- ส่วนของสถานที่ (แผนข้อ 3) ---

// ดึงรายชื่อห้องทั้งหมด
app.get('/api/locations', (req, res) => {
  db.query('SELECT * FROM locations ORDER BY floor, room_name', (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

// API สำหรับเพิ่มห้องใหม่ (แผนข้อ 3)
app.post('/api/locations', (req, res) => {
    const { floor, room_name } = req.body;
    const sql = "INSERT INTO locations (floor, room_name) VALUES (?, ?)";
    
    db.query(sql, [floor, room_name], (err, result) => {
        if (err) {
            console.error("Error adding location:", err);
            return res.status(500).json(err);
        }
        res.status(200).json({ 
            message: "เพิ่มห้องสำเร็จ!", 
            location_id: result.insertId 
        });
    });
});

// ลบห้อง (Locations)
app.delete('/api/locations/:id', (req, res) => {
    const { id } = req.params;
    const sql = "DELETE FROM locations WHERE location_id = ?";
    db.query(sql, [id], (err, result) => {
        if (err) {
            // ถ้าในห้องยังมีของอยู่ จะลบไม่ได้ (ป้องกันข้อมูลรวน)
            if (err.code === 'ER_ROW_IS_REFERENCED_2') {
                return res.status(400).json({ message: "ไม่สามารถลบได้ เนื่องจากมีครุภัณฑ์อยู่ในห้องนี้" });
            }
            return res.status(500).json(err);
        }
        res.json({ message: "ลบห้องสำเร็จ!" });
    });
});

// ลบทั้งชั้น (เฉพาะชั้นที่ไม่มีห้องเหลืออยู่แล้วเท่านั้น)
app.delete('/api/locations/floor/:floorName', (req, res) => {
    const { floorName } = req.params;

    // 1. เช็คก่อนว่าในชั้นนี้ยังมีห้องเหลืออยู่ไหม
    const checkSql = "SELECT COUNT(*) as roomCount FROM locations WHERE floor = ?";
    db.query(checkSql, [floorName], (err, results) => {
        if (err) return res.status(500).json(err);
        
        if (results[0].roomCount > 0) {
            // ถ้ายังมีห้องอยู่ ส่ง Error กลับไปบอกรัก
            return res.status(400).json({ 
                message: `ไม่สามารถลบได้! เนื่องจากยังมีอีก ${results[0].roomCount} ห้องในชั้นนี้ รบกวนลบห้องออกให้หมดก่อนครับ` 
            });
        }

        // 2. ถ้าไม่มีห้องเหลือแล้ว ถึงจะทำการลบข้อมูลชั้นนั้น (ถ้ามีตารางแยก) หรือแจ้งว่าชั้นว่างเปล่า
        res.status(200).json({ message: `${floorName} ว่างเปล่าและพร้อมจัดการใหม่แล้ว` });
    });
});

// --- ส่วนของครุภัณฑ์ (แผนข้อ 4 & 5) ---

// ดึงข้อมูลแยกตามห้อง (เพื่อให้รักกดเข้าห้องแล้วเจอของ)
app.get('/api/assets/room/:locationId', (req, res) => {
  const { locationId } = req.params;
  const sql = "SELECT * FROM assets WHERE location_id = ?";
  db.query(sql, [locationId], (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

// เพิ่มครุภัณฑ์ใหม่
app.post('/api/assets', (req, res) => {
  const { asset_id, asset_name, brand_model, location_id, status, checker_name } = req.body;
  const sql = "INSERT INTO assets (asset_id, asset_name, brand_model, location_id, status, checker_name) VALUES (?, ?, ?, ?, ?, ?)";
  db.query(sql, [asset_id, asset_name, brand_model, location_id, status, checker_name], (err, result) => {
    if (err) return res.status(500).json(err);
    res.json({ message: "บันทึกข้อมูลสำเร็จ!", id: result.insertId });
  });
});

// ลบครุภัณฑ์
app.delete('/api/assets/:id', (req, res) => {
  const { id } = req.params;
  db.query("DELETE FROM assets WHERE id = ?", [id], (err, result) => {
    if (err) return res.status(500).json(err);
    res.json({ message: "ลบข้อมูลสำเร็จ!" });
  });
});

// 3. เริ่มทำงาน
app.listen(3000, () => {
  console.log('✅ Backend Ready: http://localhost:3000');
});

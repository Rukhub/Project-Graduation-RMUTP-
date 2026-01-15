const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// 1. เชื่อมต่อกับ MySQL ใน Docker
const db = mysql.createConnection({
  host: 'localhost',
  user: 'root',
  password: 'password123', 
  database: 'krupandb'
});

// --- ส่วนของครุภัณฑ์ (Assets) ---

app.get('/api/assets', (req, res) => {
  db.query('SELECT * FROM assets', (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

app.post('/api/assets', (req, res) => {
  const { asset_id, asset_name, location, status } = req.body;
  const sql = "INSERT INTO assets (asset_id, asset_name, location, status) VALUES (?, ?, ?, ?)";
  db.query(sql, [asset_id, asset_name, location, status], (err, result) => {
    if (err) return res.status(500).json(err);
    res.json({ message: "บันทึกข้อมูลสำเร็จ!", id: result.insertId });
  });
});

app.delete('/api/assets/:id', (req, res) => {
  const { id } = req.params;
  const sql = "DELETE FROM assets WHERE id = ?";
  db.query(sql, [id], (err, result) => {
    if (err) return res.status(500).json(err);
    res.json({ message: "ลบข้อมูลสำเร็จ!" });
  });
});

// --- ส่วนของระบบผู้ใช้งาน (Register & Login) ---

// API สำหรับสมัครสมาชิก (Register)
app.post('/api/register', (req, res) => {
  const { username, password, fullname } = req.body;
  const sql = "INSERT INTO users (username, password, fullname) VALUES (?, ?, ?)";
  
  db.query(sql, [username, password, fullname], (err, result) => {
    if (err) {
      if (err.code === 'ER_DUP_ENTRY') return res.status(400).json({ message: "ชื่อผู้ใช้นี้มีคนใช้แล้ว" });
      return res.status(500).json(err);
    }
    res.json({ message: "สมัครสมาชิกสำเร็จ!", id: result.insertId });
  });
});

// API สำหรับเข้าสู่ระบบ (Login)
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  const sql = "SELECT * FROM users WHERE username = ? AND password = ?";
  
  db.query(sql, [username, password], (err, results) => {
    if (err) return res.status(500).json(err);
    
    if (results.length > 0) {
      res.json({ 
        message: "เข้าสู่ระบบสำเร็จ!", 
        user: { id: results[0].id, username: results[0].username, fullname: results[0].fullname } 
      });
    } else {
      res.status(401).json({ message: "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง" });
    }
  });
});

// 3. เริ่มทำงาน
app.listen(3000, () => {
  console.log('✅ Backend Ready: http://localhost:3000');
});

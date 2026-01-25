const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();

// --- 1. Middleware Config ---
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// --- 2. Database Connection ---
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: 'password123',
    database: 'krupandb',
    timezone: '+07:00'
});

db.connect((err) => {
    if (err) {
        console.error('❌ Database connection failed:', err);
        return;
    }
    console.log('✅ Connected to MySQL Database');
});

// --- 3. Multer Config (Storage) ---
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + '-' + file.originalname);
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 } 
});

// ==========================================
// --- 4. API: Users & Authentication ---
// ==========================================

app.post('/api/login', (req, res) => {
    const { username, password } = req.body;
    const sql = "SELECT user_id, username, fullname, role, is_approved FROM users WHERE username = ? AND password = ?";
    db.query(sql, [username, password], (err, results) => {
        if (err) return res.status(500).json(err);
        if (results.length > 0) {
            const user = results[0];
            if (user.is_approved === 0) return res.status(403).json({ message: "บัญชีนี้รอการอนุมัติจากแอดมินโบ" });
            res.json({ message: "เข้าสู่ระบบสำเร็จ!", user: user });
        } else {
            res.status(401).json({ message: "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง" });
        }
    });
});

app.post('/api/auth/google-login', (req, res) => {
    const { google_id, email, fullname, photo_url } = req.body;
    if (!email || !email.endsWith('@rmutp.ac.th')) {
        return res.status(403).json({ message: "จำกัดเฉพาะอีเมล @rmutp.ac.th เท่านั้น" });
    }

    const sqlCheck = "SELECT * FROM users WHERE google_id = ? OR email = ?";
    db.query(sqlCheck, [google_id, email], (err, results) => {
        if (err) return res.status(500).json({ message: "Database error", error: err });

        if (results.length > 0) {
            const user = results[0];
            const sqlUpdate = "UPDATE users SET google_id = ?, photo_url = ?, fullname = ? WHERE user_id = ?";
            db.query(sqlUpdate, [google_id, photo_url, fullname, user.user_id], (errUpdate) => {
                if (errUpdate) return res.status(500).json({ message: "Update error" });
                if (user.is_approved === 0) return res.status(403).json({ message: "บัญชีนี้รอการอนุมัติ" });
                res.json({ message: "เข้าสู่ระบบสำเร็จ!", user: { ...user, google_id, photo_url, fullname } });
            });
        } else {
            const sqlInsert = "INSERT INTO users (google_id, email, fullname, photo_url, role, is_approved, username) VALUES (?, ?, ?, ?, 'user', 0, ?)";
            db.query(sqlInsert, [google_id, email, fullname, photo_url, email], (errInsert, result) => {
                if (errInsert) return res.status(500).json({ message: "Register error" });
                res.json({ message: "ลงทะเบียนสำเร็จ! กรุณารอแอดมินอนุมัติ", user_id: result.insertId });
            });
        }
    });
});

// ==========================================
// --- 5. API: Admin User Management ---
// ==========================================

app.get('/api/users/pending', (req, res) => {
    const sql = "SELECT user_id, fullname, email, photo_url, role FROM users WHERE is_approved = 0";
    db.query(sql, (err, results) => {
        if (err) return res.status(500).json(err);
        res.json(results);
    });
});

app.get('/api/users/all', (req, res) => {
    const sql = "SELECT user_id, fullname, email, photo_url, role, is_approved FROM users ORDER BY is_approved ASC, fullname ASC";
    db.query(sql, (err, results) => {
        if (err) return res.status(500).json(err);
        res.json(results);
    });
});

app.put('/api/users/approve/:id', (req, res) => {
    const sql = "UPDATE users SET is_approved = 1 WHERE user_id = ?";
    db.query(sql, [req.params.id], (err) => {
        if (err) return res.status(500).json({ message: "Database error" });
        res.json({ success: true, message: "อนุมัติเรียบร้อยแล้ว" });
    });
});

// ==========================================
// --- 6. API: Assets & Dashboard ---
// ==========================================

// Dashboard: ดึงเลขจริงจากฐานข้อมูลไปใส่ 4 กล่องของรัก
app.get('/api/dashboard-stats', (req, res) => {
    const sql = `
        SELECT 
            COUNT(*) as total, 
            SUM(CASE WHEN status = 'ปกติ' THEN 1 ELSE 0 END) as normal, 
            SUM(CASE WHEN status = 'ชำรุด' THEN 1 ELSE 0 END) as damaged,
            (SELECT COUNT(*) FROM users WHERE is_approved = 0) as pending
        FROM assets
    `;
    db.query(sql, (err, results) => {
        if (err) return res.status(500).json(err);
        res.json(results[0]);
    });
});

app.get('/api/assets/:assetId', (req, res) => {
    const sql = "SELECT a.*, l.room_name, l.floor FROM assets a JOIN locations l ON a.location_id = l.location_id WHERE a.asset_id = ?";
    db.query(sql, [req.params.assetId], (err, result) => {
        if (err) return res.status(500).json(err);
        if (result.length === 0) return res.status(404).json({ message: "ไม่พบรหัสครุภัณฑ์" });
        res.json(result[0]);
    });
});

app.post('/api/assets', (req, res) => {
    const { asset_id, asset_type, brand_model, location_id, image_url, created_by } = req.body;
    const sql = "INSERT INTO assets (asset_id, created_by, asset_type, brand_model, location_id, image_url, status) VALUES (?, ?, ?, ?, ?, ?, 'ปกติ')";
    db.query(sql, [asset_id, created_by, asset_type, brand_model, location_id, image_url], (err) => {
        if (err) return res.status(500).json(err);
        res.json({ message: "เพิ่มครุภัณฑ์สำเร็จ!" });
    });
});

// แก้ไขข้อมูลครุภัณฑ์ + ลบรูปเก่าทิ้งอัตโนมัติ
app.put('/api/assets/:asset_id', (req, res) => {
    const { asset_id } = req.params;
    const { image_url, brand_model, asset_type } = req.body;

    db.query("SELECT image_url FROM assets WHERE asset_id = ?", [asset_id], (err, results) => {
        if (results.length > 0 && results[0].image_url && image_url) {
            const oldUrl = results[0].image_url;
            const fileNames = oldUrl.split(',');
            fileNames.forEach(url => {
                const fileName = url.split('/').pop();
                const filePath = path.join(__dirname, 'uploads', fileName);
                if (fs.existsSync(filePath)) {
                    fs.unlink(filePath, (err) => {
                        if (!err) console.log("✅ Auto-deleted old file:", fileName);
                    });
                }
            });
        }

        const sql = "UPDATE assets SET image_url = COALESCE(?, image_url), brand_model = COALESCE(?, brand_model), asset_type = COALESCE(?, asset_type) WHERE asset_id = ?";
        db.query(sql, [image_url, brand_model, asset_type, asset_id], (err) => {
            if (err) return res.status(500).json({ message: "Update Error", error: err });
            res.json({ success: true, message: "อัปเดตและล้างไฟล์เก่าเรียบร้อย!" });
        });
    });
});

// ลบข้อมูลแบบ Triple Kill (ลบรูป -> ลบประวัติแจ้งซ่อม -> ลบตัวเครื่อง)
app.delete('/api/assets/:assetId', (req, res) => {
    const { assetId } = req.params;

    db.query("SELECT image_url FROM assets WHERE asset_id = ?", [assetId], (err, results) => {
        if (results.length > 0 && results[0].image_url) {
            const fileNames = results[0].image_url.split(',');
            fileNames.forEach(url => {
                const fileName = url.split('/').pop();
                const filePath = path.join(__dirname, 'uploads', fileName);
                if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
            });
        }

        // ลบข้อมูลในรายงานก่อนเพื่อเลี่ยง Error Foreign Key
        db.query("DELETE FROM reports WHERE asset_id = ?", [assetId], (err) => {
            db.query("DELETE FROM assets WHERE asset_id = ?", [assetId], (err2) => {
                if (err2) return res.status(500).json(err2);
                res.json({ success: true, message: "ลบข้อมูลและรูปภาพเกลี้ยงทั้งระบบ!" });
            });
        });
    });
});

// ==========================================
// --- 7. API: Uploads & Reports ---
// ==========================================

app.post('/api/upload', upload.single('image'), (req, res) => {
    if (!req.file) return res.status(400).json({ message: "กรุณาเลือกไฟล์ภาพ" });
    const host = req.get('host'); 
    const protocol = req.protocol;
    const imageUrl = `${protocol}://${host}/uploads/${req.file.filename}`;
    res.json({ success: true, image_url: imageUrl });
});

app.post('/api/reports', (req, res) => {
    const { asset_id, reporter_name, issue_detail, image_url } = req.body; 
    const sqlReport = "INSERT INTO reports (asset_id, reporter_name, issue_detail, image_url) VALUES (?, ?, ?, ?)";
    const sqlUpdateAsset = "UPDATE assets SET status = 'ชำรุด', reporter_name = ?, issue_detail = ?, report_date = NOW() WHERE asset_id = ?";

    db.query(sqlReport, [asset_id, reporter_name, issue_detail, image_url], (err) => {
        if (err) return res.status(500).json({ message: "บันทึกรายงานไม่สำเร็จ", error: err });
        db.query(sqlUpdateAsset, [reporter_name, issue_detail, asset_id], (err2) => {
            if (err2) return res.status(500).json({ message: "อัปเดตสถานะไม่สำเร็จ" });
            res.json({ success: true, message: "แจ้งซ่อมเรียบร้อย!" });
        });
    });
});

// ==========================================
// --- 8. API: Locations ---
// ==========================================

app.get('/api/locations', (req, res) => {
    db.query('SELECT * FROM locations ORDER BY floor, room_name', (err, results) => {
        if (err) return res.status(500).json(err);
        res.json(results);
    });
});

app.post('/api/locations', (req, res) => {
    const { floor, room_name } = req.body;
    db.query("INSERT INTO locations (floor, room_name) VALUES (?, ?)", [floor, room_name], (err, result) => {
        if (err) return res.status(500).json({ success: false });
        res.json({ success: true, location_id: result.insertId });
    });
});

app.listen(3000, () => {
    console.log('✅ Backend Ready: http://localhost:3000');
});

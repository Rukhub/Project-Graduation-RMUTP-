// --- 🌐 ระบบ Google Login (ฉบับจำกัดเฉพาะอีเมล rmutp.ac.th เท่านั้น) ---
app.post('/api/auth/google-login', (req, res) => {
  const { google_id, email, fullname, photo_url } = req.body;

  // 1. ด่านตรวจ: เช็กว่าลงท้ายด้วย @rmutp.ac.th หรือไม่
  if (!email || !email.endsWith('@rmutp.ac.th')) {
    return res.status(403).json({ 
      message: "เข้าใช้งานไม่ได้! ระบบนี้จำกัดเฉพาะอีเมล @rmutp.ac.th เท่านั้นนะจ๊ะ" 
    });
  }

  // 2. เช็กว่า User คนนี้เคยมีในระบบหรือยัง
  const sqlCheck = "SELECT * FROM users WHERE google_id = ? OR email = ?";
  
  db.query(sqlCheck, [google_id, email], (err, results) => {
    if (err) return res.status(500).json({ message: "Database error", error: err });

    if (results.length > 0) {
      // --- กรณีที่ 1: มีผู้ใช้งานเดิมอยู่แล้ว (หรืออีเมลนี้เคยลงทะเบียนไว้แบบ Manual) ---
      const user = results[0];
      
      // อัปเดตข้อมูล Google ID และรูปล่าสุดเข้าไป
      const sqlUpdate = "UPDATE users SET google_id = ?, photo_url = ? WHERE user_id = ?";
      db.query(sqlUpdate, [google_id, photo_url, user.user_id], (errUpdate) => {
        if (errUpdate) console.error("❌ Update Google Info Error:", errUpdate);
        
        // เช็กสถานะการอนุมัติ
        if (user.is_approved === 0) {
          return res.status(403).json({ message: "บัญชีนี้รอการอนุมัติจากแอดมินโบนะจ๊ะ" });
        }
        
        res.json({ 
          message: "เข้าสู่ระบบสำเร็จ!", 
          user: { ...user, google_id, photo_url } 
        });
      });

    } else {
      // --- กรณีที่ 2: เป็นนักศึกษา/บุคลากรใหม่ (เพิ่งเคยล็อกอินครั้งแรก) ---
      // password จะเป็น NULL เพราะล็อกอินผ่าน Google
      const sqlInsert = "INSERT INTO users (google_id, email, fullname, photo_url, role, is_approved) VALUES (?, ?, ?, ?, 'user', 0)";
      
      db.query(sqlInsert, [google_id, email, fullname, photo_url], (err2, result) => {
        if (err2) return res.status(500).json({ message: "Register error", error: err2 });
        
        res.json({ 
          message: "ลงทะเบียนด้วย Google สำเร็จ! กรุณารอแอดมินโบอนุมัติเข้าใช้งานนะ",
          user_id: result.insertId
        });
      });
    }
  });
});

// --- ส่วนของครุภัณฑ์ (แผนข้อ 4 & 5) ---

// 1. ดึงครุภัณฑ์แยกตามห้อง (เพื่อให้รักกดเข้าห้องแล้วเจอของ)
app.get('/api/assets/room/:locationId', (req, res) => {
  const { locationId } = req.params;
  const sql = "SELECT * FROM assets WHERE location_id = ?";
  db.query(sql, [locationId], (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

// 2. ดึงครุภัณฑ์ "ทั้งหมด"
app.get('/api/assets', (req, res) => {
  const sql = "SELECT * FROM assets";
  db.query(sql, (err, results) => {
    if (err) return res.status(500).json(err);
    res.json(results);
  });
});

// 3. เพิ่มครุภัณฑ์ใหม่ (เพิ่ม image_url เข้าไป)
app.post('/api/assets', (req, res) => {
  const { asset_id, asset_type, brand_model, location_id, status, checker_name, image_url } = req.body;
  const sql = "INSERT INTO assets (asset_id, asset_type, brand_model, location_id, status, checker_name, image_url) VALUES (?, ?, ?, ?, ?, ?, ?)";
  db.query(sql, [asset_id, asset_type, brand_model, location_id, status, checker_name, image_url], (err, result) => {
    if (err) return res.status(500).json(err);
    res.json({ message: "บันทึกข้อมูลสำเร็จ!", id: result.insertId });
  });
});

// 4. แก้ไขข้อมูลครุภัณฑ์ (เพิ่ม image_url ให้แก้ไขได้ด้วย)
app.put('/api/assets/:id', (req, res) => {
  const { id } = req.params;
  const { asset_id, asset_type, brand_model, location_id, status, checker_name, image_url } = req.body;
  const sql = "UPDATE assets SET asset_id = ?, asset_type = ?, brand_model = ?, location_id = ?, status = ?, checker_name = ?, image_url = ? WHERE id = ?";
  db.query(sql, [asset_id, asset_type, brand_model, location_id, status, checker_name, image_url, id], (err, result) => {
    if (err) return res.status(500).json(err);
    res.json({ message: "แก้ไขข้อมูลสำเร็จ!" });
  });
});

// 5. ลบครุภัณฑ์
app.delete('/api/assets/:id', (req, res) => {
  const { id } = req.params;
  db.query("DELETE FROM assets WHERE id = ?", [id], (err, result) => {
    if (err) return res.status(500).json(err);
    res.json({ message: "ลบข้อมูลสำเร็จ!" });
  });
});
